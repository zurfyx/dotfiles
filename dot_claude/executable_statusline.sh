#!/bin/bash
#
# A status line for Claude Code: model, repository state, context usage, what
# the session has spent, and subscription quota, on one line.
#
#   [Opus 5] myrepo |  main +412/-88 | ████████░░ 78% 󰈸47m | $12.40 ↑22M ↓146k 18m3s | 41% 2h 63% 4d
#
# The 󰈸 is the prompt cache: time left before the cached prefix goes cold. Once
# it has, the flame becomes a bare 󰜗.
#
# ↑ and ↓ are tokens in and out over the whole session, subagents included,
# each API request counted once. In is everything sent, cache reads and writes
# included, so it runs far ahead of out and grows with every turn of a long
# context. The host does not send these totals. A background refresh sums them
# from the transcripts on disk, at most once per STATUSLINE_TTL, and a render
# shows the last sum that finished. So they trail the cost beside them by up to
# the TTL plus a render while the session is busy, and by up to two
# refreshInterval ticks once it goes idle: the render for a turn's last message
# can fall inside the TTL and start nothing. Transcripts from Claude Code
# 2.1.152 and older can overcount; see "Tokens in and out" below.
#
# Install
#   1. Save as ~/.claude/statusline.sh, then `chmod +x ~/.claude/statusline.sh`
#   2. Add to ~/.claude/settings.json:
#        "statusLine": { "type": "command", "command": "~/.claude/statusline.sh"
#                      , "refreshInterval": 60 }
#
# refreshInterval is worth setting for this particular status line. Renders are
# otherwise event-driven — a new assistant message, a mode change, the end of a
# /compact — so nothing redraws while the session sits idle, and every countdown
# here (cache, quota windows, elapsed) freezes at whatever it last said. A
# 60-second timer thaws them without being wasteful: no field is finer-grained
# than a minute, so a faster tick would redraw an identical string. One render
# costs ~70ms with the repository cache warm, and the expensive part already
# runs detached behind that cache.
#
# Requires jq. Works in a git, Sapling (sl), or Mercurial (hg) checkout —
# whichever the directory turns out to be — and simply omits the repository
# segment anywhere else. Nothing else is assumed about the host.
#
# Configuration, all optional, all environment variables:
#
#   STATUSLINE_ICONS=ascii    Plain ASCII instead of Unicode and nerd-font
#                             glyphs. Use this if the bar renders as ??? or the
#                             icons render as boxes — it means the terminal font
#                             is not patched.
#   STATUSLINE_TTL=2          Seconds to cache repository state and token
#                             totals for.
#   STATUSLINE_VCS_REASON=1   Pass --reason to sl/hg. Some Sapling deployments
#                             ask for it for audit logging; upstream Sapling and
#                             Mercurial reject the flag, so this is off by
#                             default.
#   STATUSLINE_LABEL_TPL=...  Override the sl/hg template for the revision
#                             label. Default prefers an active bookmark, then a
#                             code-review id where the host provides one, then
#                             the short hash.
#
# Notes for anyone editing this:
#   - macOS /bin/bash is 3.2: no associative arrays, no ${x,,}, no mapfile.
#   - macOS has no timeout(1), and its stat wants -f where GNU's wants -c. See
#     TO and STAT.
#   - macOS tail -c +N copies byte by byte, ~3 s per 100 MB. See tok_chunk.
#   - Do NOT build the bar with `tr`. GNU tr is byte-oriented and keeps only the
#     leading byte of each 3-byte block glyph, emitting invalid UTF-8 that shows
#     up as replacement characters. Concatenate instead.

: "${STATUSLINE_TTL:=2}"

input=$(cat)

# One jq pass for every scalar we need. Joined on U+001F rather than a tab
# because tab is IFS whitespace: bash collapses runs of it, so an empty field
# followed by a populated one would silently shift every later field left.
#
# TZ=UTC is load-bearing, not tidiness. jq 1.6's fromdateiso8601 leaves tm_isdst
# set and glibc's mktime then "corrects" an already-UTC timestamp, so a reset
# time comes back an hour late while DST is in effect and exactly right in
# winter — which is precisely how it escapes notice. jq 1.7 is unaffected, but
# pinning costs nothing: every value here is TZ-agnostic and date +%s is epoch.
#
# The comments inside the program avoid apostrophes: it is single-quoted, and
# one would end the string.
FIELDS=$(echo "$input" | TZ=UTC jq -r '
  def e:  if . == null then "" else . end;
  def ep: if . == null then ""
          elif type == "string" then (sub("\\.[0-9]+"; "") | fromdateiso8601)
          else . end;
  [ (.model.display_name // "?")
  , (.workspace.current_dir // .cwd // "")
  # Report the host own context_window.used_percentage verbatim: the raw fill of
  # the model window (total_input_tokens / context_window_size). We do not model
  # the footer undocumented auto-compact reserve, so the footer may read a
  # couple of points higher near the top; that divergence is expected. Fall back
  # to the direct ratio only if the field is absent entirely.
  , ( if (.context_window.used_percentage // null) != null
        then .context_window.used_percentage
      elif (.context_window.context_window_size // 0) > 0
        then (.context_window.total_input_tokens // 0) * 100 / .context_window.context_window_size
      else 0 end
      | round | if . > 100 then 100 elif . < 0 then 0 else . end )
  , (.cost.total_cost_usd // 0)
  , (.cost.total_duration_ms // 0)
  , (.rate_limits.five_hour.used_percentage | e)
  , (.rate_limits.five_hour.resets_at       | ep)
  , (.rate_limits.seven_day.used_percentage | e)
  , (.rate_limits.seven_day.resets_at       | ep)
  # Warm only. Gate on caching_observed too, else a provider that never caches
  # looks permanently cold. Compare with == true: jq // treats false as absent.
  , ( if (.prompt_cache.caching_observed == true and .prompt_cache.warm == true)
        then (.prompt_cache.expires_at | ep) else "" end )
  # Has this session ever cached? Distinguishes "cooled down" — which earns the
  # cold glyph — from "provider never caches", where the segment stays absent.
  , (if (.prompt_cache.caching_observed == true) then 1 else "" end)
  # Where the session transcript lives, for the token totals.
  , (.transcript_path // "")
  , (.session_id // "")
  ] | map(tostring) | join("\u001f")')

IFS=$'\037' read -r MODEL DIR_PATH PCT COST_RAW DURATION_MS \
  FIVE FIVE_AT WEEK WEEK_AT CACHE_EXP CACHE_SEEN TRANSCRIPT SESSION_ID <<< "$FIELDS"

# Defaults for the malformed-payload case: each of these feeds arithmetic or a
# numeric test below, where an empty string is a hard error rather than a zero.
: "${PCT:=0}" "${DURATION_MS:=0}" "${COST_RAW:=0}"

DIR="${DIR_PATH##*/}"
# Resolve symlinks before looking for a repository. A working directory is often
# a link into a checkout, and walking its *logical* parents climbs out to the
# home directory and never sees the marker below the link target. `cd && pwd -P`
# rather than `readlink -f`, which older macOS does not have.
PHYS=$(cd "$DIR_PATH" 2>/dev/null && pwd -P) || PHYS=""
[ -z "$PHYS" ] && PHYS="$DIR_PATH"
COST=$(printf '$%.2f' "$COST_RAW")
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))
NOW=$(date +%s)

# Palette, defined up here because the VCS block already needs it — a segment
# that emits a color without a reset bleeds into the next separator. Basic
# 16-color on purpose: the shade is whatever the terminal theme maps it to, so
# one file follows each machine's scheme instead of imposing one. For fixed
# colors independent of the theme, use 38;5;211 / 38;5;220 / 38;5;108.
DIM='\033[2m'; R='\033[0m'; YEL='\033[33m'
RED='\033[31m'; GOLD='\033[33m'; GRN='\033[32m'

# Glyphs.  is nf-dev-git-branch, 󰈸 is nf-md-fire and 󰜗 is nf-md-snowflake, all
# nerd-font private-use codepoints. They are deliberately not 🔥/❄️ or similar:
# emoji are painted in the terminal's own color and ignore the dim attribute,
# whereas private-use glyphs are plain outlines that take the color they are
# given. The bar blocks and the token arrows are ordinary Unicode and widely
# available, but they travel with the same switch so one setting covers every
# non-ASCII character in the output.
if [ "$STATUSLINE_ICONS" = ascii ]; then
  I_VCS="@"; I_FIRE="~"; I_COLD="*"; B_FULL="#"; B_EMPTY="-"; B_OPEN="["; B_CLOSE="]"
  I_IN="in"; I_OUT="out"
else
  I_VCS=""; I_FIRE="󰈸"; I_COLD="󰜗"; B_FULL="█"; B_EMPTY="░"; B_OPEN=""; B_CLOSE=""
  I_IN="↑"; I_OUT="↓"
fi

# macOS ships no timeout(1), and no gtimeout unless coreutils is installed. That
# is survivable only because every VCS call runs in the detached refresh below,
# which no render ever waits on: a hung repository costs a stale segment, not a
# stalled status line. Do not move a TO call onto the foreground path.
if command -v timeout >/dev/null 2>&1; then TO() { timeout "$@"; }
elif command -v gtimeout >/dev/null 2>&1; then TO() { gtimeout "$@"; }
else TO() { shift; "$@"; }; fi

# stat is the one tool here whose flags split by platform: BSD's, macOS's among
# them, takes -f FORMAT and GNU's -c FORMAT. Pick by $OSTYPE, which bash sets
# without starting a process, rather than try GNU's and fall back: on a Mac the
# failed try is a second exec on every call, ~3 ms of each render. The full
# path on the BSDs, since a GNU stat first on PATH would read -f as
# --file-system. -L so a symlinked transcript reports the file it points to.
case "$OSTYPE" in
  darwin*|*bsd*|dragonfly*) STAT=(/usr/bin/stat -L -f); ST_MTIME=%m; ST_SIZE='%z %N' ;;
  *)                        STAT=(stat -L -c);          ST_MTIME=%Y; ST_SIZE='%s %n' ;;
esac
mtime() { "${STAT[@]}" "$ST_MTIME" "$1" 2>/dev/null || echo 0; }

# ---------------------------------------------------------------------------
# Work in flight
#
# The number beside the revision is the diff this work would land as: every
# change since it forked from upstream, working tree included. With no upstream
# to compare against, the fork point collapses to the current commit and the
# same expression degrades to "just my uncommitted changes", identically for
# git, Sapling and Mercurial. It measures the work, not the session — reopening
# a branch tomorrow still shows the whole thing, which is what you want when
# judging whether a change has grown too big to review.
# ---------------------------------------------------------------------------

# Count untracked lines. Neither git nor hg reports untracked files in a diff,
# but a brand-new file is exactly the kind of work this number exists to
# measure. Capped at 200 files: reading an unbounded tree costs more than the
# accuracy is worth. Listing stays exact, so only the reading is capped.
NEWLINES=0; TRUNC=""
count_new() { # repository root, then newline-separated paths
  local root=$1 new=$2
  [ -z "$new" ] && return
  # Both tools report paths relative to the repository *root*, while this
  # process's working directory is wherever the harness launched it. Read them
  # from the root or every file silently misses and the count comes out zero.
  NEWLINES=$(echo "$new" | head -200 | tr '\n' '\0' \
    | (cd "$root" 2>/dev/null && xargs -0 cat 2>/dev/null) | wc -l | tr -d ' ')
  # Past the cap the total is a floor, not a count. Say so, loudly: a number
  # that is silently 9x low is worse than no number at all.
  [ "$(echo "$new" | wc -l | tr -d ' ')" -gt 200 ] && TRUNC=" ${YEL}(!!)${R}"
}

# Nothing changed yet: show the revision alone rather than a hollow +0/-0.
emit_vcs() {
  local seg="$1"
  if [ "${2:-0}" -gt 0 ] || [ "${3:-0}" -gt 0 ]; then
    seg="${seg} ${DIM}+${2}/-${3}${R}${TRUNC}"
  fi
  printf ' | %s %s' "$I_VCS" "$seg"
}

shortstat() { # "N files changed, A insertions(+), D deletions(-)" -> A and D
  A=$(echo "$1" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
  D=$(echo "$1" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+')
}

# --no-optional-locks keeps a status line that renders on every keystroke from
# fighting a real git command for the index lock.
vcs_git() {
  local branch base from
  g() { git --no-optional-locks -C "$PHYS" "$@" 2>/dev/null; }
  branch=$(g branch --show-current)
  [ -z "$branch" ] && return
  base=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD)
  from=$(g merge-base HEAD "${base:-origin/main}")
  shortstat "$(g diff --shortstat "${from:-HEAD}")"
  count_new "$(g rev-parse --show-toplevel)" "$(g ls-files --others --exclude-standard)"
  emit_vcs "$branch" "$((${A:-0} + NEWLINES))" "${D:-0}"
}

# Sapling and Mercurial share this command surface: --cwd, `log -r REV -T TPL`,
# `diff --stat -r REV`, `status -u -n`, and the revsets below are all standard
# in both. --cwd is not optional: without it the tool resolves the repository
# from the *process* working directory, which is whatever the harness happened
# to launch us in, and aborts outright when that differs from the reported one.
v() {
  if [ -n "$STATUSLINE_VCS_REASON" ]; then
    TO 6 "$VCS_BIN" --cwd "$PHYS" "$@" --reason 'claude-code status line' 2>/dev/null
  else
    TO 6 "$VCS_BIN" --cwd "$PHYS" "$@" 2>/dev/null
  fi
}

TPL_PLAIN='{ifeq(bookmarks,"","{node|short}","{bookmarks}")}'
# Prefers an active bookmark; else the code-review id, but only on a draft
# commit, since a landed commit still carries one and showing it would read as
# if the work were still in flight; else the short hash.
TPL_RICH='{ifeq(bookmarks,"","{ifeq(phase,"public","{node|short}","{ifeq(phabdiff,"","{node|short}","{phabdiff}")}")}","{bookmarks}")}'

# {phabdiff} is an extension keyword that some Sapling deployments add and that
# upstream Sapling and Mercurial fail to parse. Probe once and remember, so the
# common path stays at one process per query instead of a failed call plus a
# retry on every refresh. Keyed on the binary and its mtime, so an upgrade or a
# move to a different host re-probes rather than trusting a stale answer.
label_tpl() {
  local f
  [ -n "$STATUSLINE_LABEL_TPL" ] && { printf '%s' "$STATUSLINE_LABEL_TPL"; return; }
  f="$CACHE_DIR/tpl.$(printf '%s %s' "$VCS_BIN" "$(mtime "$VCS_BIN")" | cksum | cut -d' ' -f1)"
  if [ ! -f "$f" ]; then
    if v log -r . -T '{phabdiff}' >/dev/null 2>&1
      then printf '%s' "$TPL_RICH"  > "$f"
      else printf '%s' "$TPL_PLAIN" > "$f"
    fi
  fi
  cat "$f"
}

vcs_hg() {
  local label base
  label=$(v log -r . -T "$(label_tpl)")
  [ -z "$label" ] && return
  # The analog of git's merge-base: the newest public ancestor is where this
  # stack of drafts forks from upstream, so diffing the working copy against it
  # covers the whole stack plus pending edits in one pass. A repository with no
  # public commits at all yields nothing, and the base collapses to the current
  # commit — the same degradation as git's merge-base fallback.
  base=$(v log -r 'max(::. & public())' -T '{node|short}')
  shortstat "$(v diff --stat -r "${base:-.}" | tail -1)"
  count_new "$(v root)" "$(v status -u -n)"
  emit_vcs "$label" "$((${A:-0} + NEWLINES))" "${D:-0}"
}

vcs_segment() {
  local d="$PHYS"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    # Sapling writes .sl in a fresh clone but keeps .hg in checkouts made before
    # the rename, and Mercurial always uses .hg, so all three mean "not git".
    if [ -e "$d/.hg" ] || [ -e "$d/.sl" ]; then
      VCS_BIN=$(command -v sl || command -v hg) || return
      vcs_hg; return
    fi
    [ -e "$d/.git" ] && { vcs_git; return; }
    d="${d%/*}"
  done
}

# Serve the last known segment instantly and refresh behind it. A cold cache
# costs one render with no repository segment, which then fills itself in —
# cheaper than making every keystroke wait on a network-backed filesystem. The
# refresh must not inherit the captured stdout, or the harness blocks waiting
# for that pipe to close. The repository and template entries are never
# deleted: a few bytes each, they wait for the OS's temp cleanup. Token state
# runs larger, and is pruned; see tok_refresh.
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline.$(id -u)"
mkdir -p "$CACHE_DIR" 2>/dev/null

# Once per STATUSLINE_TTL, and never two at a time, replace a cache file with
# the output of a command run fully detached. The file changes only by an
# atomic rename, so a render never reads one half-written.
#
# A refresh that stalls past 60 s loses its lock to the next render, and may
# still wake up after its successor has finished. So each refresh writes a temp
# file of its own, never a shared name: with one shared name, the late refresh
# writes its older output into the very file its successor has just renamed into
# place, and the token state, which each refresh builds on the last, keeps the
# splice for good. The lock holds a file named after that temp file, which says
# whose it is: reaping deletes both, so the late refresh's rename then fails
# rather than put back older data, and a refresh releases the lock only while
# its own name is still in it.
refresh_behind() { # cache file, then the command that prints its new contents
  local cf=$1 lock="$1.lock" t; shift
  [ $((NOW - $(mtime "$cf"))) -ge "$STATUSLINE_TTL" ] || return 0
  # Reap a lock orphaned by a refresh that died, or this wedges permanently.
  if [ -d "$lock" ] && [ $((NOW - $(mtime "$lock"))) -ge 60 ]; then
    for t in "$lock"/*; do [ -e "$t" ] && rm -f "$t" "${cf%/*}/${t##*/}"; done
    rmdir "$lock" 2>/dev/null
  fi
  mkdir "$lock" 2>/dev/null || return 0
  ( if ! tmp=$(mktemp "$cf.new.XXXXXX") || ! : > "$lock/${tmp##*/}"; then
      rm -f "$tmp"; rmdir "$lock"; exit 1
    fi
    if "$@" > "$tmp" 2>/dev/null; then mv -f "$tmp" "$cf"; else rm -f "$tmp"; fi
    rm "$lock/${tmp##*/}" 2>/dev/null && rmdir "$lock" 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
}

# Key on the resolved path, so two routes to one directory share an entry. The
# icon setting is part of the key because what gets cached is the *rendered*
# segment, glyphs included, so flipping the setting must not serve back a
# segment drawn in the other alphabet.
CF="$CACHE_DIR/vcs.$(printf '%s %s' "$PHYS" "$STATUSLINE_ICONS" | cksum | cut -d' ' -f1)"
VCS=""
[ -f "$CF" ] && VCS=$(cat "$CF" 2>/dev/null)
refresh_behind "$CF" vcs_segment

# ---------------------------------------------------------------------------
# Tokens in and out
#
# The payload carries no session totals: context_window.total_input_tokens is
# the current context size and total_output_tokens the last response alone. So
# they are summed from the transcripts, which log every API request's usage:
# the session's own file, plus every *.jsonl at any depth under
# <transcript minus .jsonl>/subagents/, where subagents and workflow agents
# write theirs. Hundreds of those are normal in a long session.
#
# What counts, and why:
#   - Assistant lines with a message.usage object and no forkedFrom. /branch
#     and resume copy the parent's history into the new file with forkedFrom
#     set, and counting those bills the parent's requests twice (in one
#     branched session, 252 of 289 usage lines were such copies).
#   - One request is logged as several lines, one per content block, sharing a
#     requestId and message.id. In subagent transcripts the early ones are
#     streaming snapshots with a smaller output_tokens and the last is final,
#     so a run of consecutive lines with the same pair counts once, as its
#     last line. Consecutive among usage lines only: tool results land between
#     the blocks of one request, and treating them as breaks counts about a
#     third of the requests twice (280 instead of 214 in one transcript). A
#     line missing either id stands alone.
#   - Not lines whose model is "<synthetic>". Claude Code writes those itself,
#     an API error for instance, always with zero usage, and one can land
#     between two blocks of a request with the request's own requestId, which
#     would split it and count it twice.
#   - In is input_tokens + cache_creation_input_tokens + cache_read_input_tokens;
#     out is output_tokens.
#
# One known overcount. Before transcripts had forkedFrom (Claude Code 2.1.152
# and older), a session that was compacted and then continued could append its
# whole history to its own file again, unmarked, and those replays count a
# second time: one such transcript reads 3.1B in where its requests add up to
# 2.2B. Telling a replay from a new request would take every key a file has
# ever had, where the state keeps one per file. No newer transcript checked
# had any.
#
# Every file is read incrementally. The state records, per file: how far it
# has been read, always to the end of a complete line since a writer can be
# caught mid-line; its running sums; and the key and counts of the last
# request seen, so one whose lines straddle two reads is corrected rather than
# counted twice. A file that shrinks below that offset was rewritten, and is
# read again from zero. The state is keyed by session, so /clear, which starts
# a new session id, starts from zero, the same as the cost beside it.
# ---------------------------------------------------------------------------

# Folds new usage lines into each file's saved state, for every file with
# something new, in one jq: jq 1.6 takes ~20 ms just to start, which across
# hundreds of subagent files would be most of the refresh. On stdin, each
# file's lines follow a header carrying its saved state,
#   <U+001E>["@file", index, in, out, key, last in, last out]
# and out comes one line per file: index, in, out, key, last in, last out. The
# last request is held apart from the settled sums because a later line for it
# replaces it rather than adding to it. -R and fromjson? rather than letting
# jq parse the stream: a malformed line then costs that line, not the read.
tok_fold() {
  jq -nrR '
    # A usage number outside [0, 1e12) is no real count, so it counts as 0.
    # Negative, it would fail the check on the saved state and have its file
    # read again from zero on every refresh; from about 1e16 up jq prints it
    # as 1e+16, which bash arithmetic cannot take.
    def n: if type == "number" and . >= 0 and . < 1e12 then floor else 0 end;
    # Ids go into the state file and the headers verbatim, so only plain ones
    # make a key; anything else stands alone, as a missing id does.
    def id: if type == "string" and test("^[A-Za-z0-9_-]+$") then . else null end;
    # A header starts with U+001E, which no transcript line can: JSON has no
    # raw control characters, in strings or out. So whatever a transcript line
    # holds, it is never taken for a header. A header that does not parse
    # still opens a file, one that prints nothing, or its lines would land on
    # the file before it. Of the rest, only objects are usage lines.
    def line:
      if startswith("\u001e") then
        (ltrimstr("\u001e") | fromjson? // null)
        | if type == "array" and .[0] == "@file" then . else ["@bad"] end
      else fromjson? // empty | select(type == "object") end;
    reduce (inputs | line) as $l ([];
      if ($l | type) == "array" then
        if $l[0] == "@bad" then . + [{ i: null }]
        else . + [{ i: $l[1], sin: ($l[2] - $l[5]), sout: ($l[3] - $l[6]),
                    key: (if $l[4] == "-" then null else $l[4] end),
                    gin: $l[5], gout: $l[6] }] end
      elif length > 0 and $l.type == "assistant"
           and $l.forkedFrom == null and ($l.message | type) == "object"
           and $l.message.model != "<synthetic>"
           and ($l.message.usage | type) == "object" then
        ($l.message.usage) as $u
        | (($l.requestId | id) as $r | ($l.message.id | id) as $m
           | if $r != null and $m != null then $r + "|" + $m else null end) as $k
        | (length - 1) as $f
        | .[$f] |= ( if $k == null or $k != .key
                       then .sin += .gin | .sout += .gout | .key = $k else . end
                   | .gin = (($u.input_tokens | n) + ($u.cache_creation_input_tokens | n)
                             + ($u.cache_read_input_tokens | n))
                   | .gout = ($u.output_tokens | n) )
      else . end)
    | .[] | select(.i != null)
    | "\(.i) \(.sin + .gin) \(.sout + .gout) \(.key // "-") \(.gin) \(.gout)"'
}

# Bytes [from, to) of a file. From zero it is head alone, because macOS tail -c
# copies byte by byte, ~3 s per 100 MB, where head reads in blocks. Past zero
# tail seeks first, and what it copies is only what was appended since.
tok_chunk() { # file, from, to
  if [ "$2" -eq 0 ]; then head -c "$3" "$1"
  else tail -c +"$(($2 + 1))" "$1" | head -c "$(($3 - $2))"; fi
}

# "size path" for every transcript of the session. find hands stat every file
# in one call, so listing costs a few processes however many subagents there
# are. stat, not wc -c: wc opens each file, and on a VM's shared filesystem
# 517 opens took 160 ms where 517 stats took 8. Regular files only, since
# anything else is never read: a read of a FIFO waits for a writer that never
# comes, and would hold the lock until it is reaped, then start another
# refresh that waits the same way.
tok_sources() {
  [ -f "$TRANSCRIPT" ] && "${STAT[@]}" "$ST_SIZE" "$TRANSCRIPT" 2>/dev/null
  [ -d "$TOK_BASE/subagents" ] &&
    find "$TOK_BASE/subagents" -type f -name '*.jsonl' \
      -exec "${STAT[@]}" "$ST_SIZE" {} + 2>/dev/null
}

# Pairs each current size with the file's saved state, one line per file:
#   size offset in out key last-in last-out path
# A new file starts at zero. A vanished one keeps its line, counts and all:
# what a deleted transcript spent was still spent. The path goes last so that
# nothing in it can shift the fields before it.
#
# When no file has a size other than its offset, and the saved state needed no
# repair, it prints the single line "same" instead: the saved state stands as
# it is, and the refresh skips its per-file loops and the jq. Most refreshes
# are such, and without this one cost ~0.3 s for a session of 516 files.
tok_join() { # saved state file; "size path" lines on stdin
  LC_ALL=C awk '
    function rest(n,  s) { s = $0; while (n-- > 0) sub(/^ *[^ ]+ /, "", s); return s }
    FILENAME == ARGV[1] {
      # A damaged line is dropped, and its file read again from zero. The key
      # counts too: it goes back into a JSON header, and one that breaks the
      # header would hand this file'"'"'s lines to another. A path listed twice
      # keeps its first line, since summing both would count it twice for good.
      if (FNR == 1) { if ($0 !~ /^[0-9]+ [0-9]+$/) changed = 1; next }
      if (($1 $2 $3 $5 $6) !~ /^[0-9]+$/ ||
          $4 !~ /^(-|[A-Za-z0-9_-]+[|][A-Za-z0-9_-]+)$/) { changed = 1; next }
      p = rest(6); if (p in saved) { changed = 1; next }
      saved[p] = $1 " " $2 " " $3 " " $4 " " $5 " " $6; off[p] = $1; order[++n] = p
      next
    }
    $1 ~ /^[0-9]+$/ {
      p = rest(1); size[p] = $1
      if (!(p in saved)) { saved[p] = "0 0 0 - 0 0"; order[++n] = p; changed = 1 }
      else if ($1 + 0 != off[p] + 0) changed = 1
    }
    END {
      if (!changed) { print "same"; exit }
      for (i = 1; i <= n; i++) {
        p = order[i]; split(saved[p], f, " ")
        print ((p in size) ? size[p] : f[1]), saved[p], p
      }
    }' "$1" -
}

# The refresh: print the new state, totals on the first line so a render reads
# one line, then a line per file. A file whose size still equals its offset
# is not opened, so an idle refresh is the listing, one awk and a copy.
tok_refresh() { # saved state file
  local saved=$1 n=0 grew=0 i size off tin tout key gin gout path end frag
  local sum_in=0 sum_out=0
  local -a F_PATH F_OFF F_END F_IN F_OUT F_KEY F_LIN F_LOUT
  if [ ! -f "$saved" ]; then
    saved=/dev/null
    # A new session sweeps out the state of any left idle for a week. Nothing
    # else deletes these files, which run to a line per transcript, and on
    # Linux the cache dir lasts until reboot. A session that does come back is
    # read again from zero: slower, and the same count.
    find "$CACHE_DIR" -maxdepth 1 -type f -name 'tok.*' -mtime +7 \
      -exec rm -f {} + 2>/dev/null
  fi

  # Where each file stands, and how far a read of it can go now.
  while read -r size off tin tout key gin gout path; do
    [ "$size" = same ] && { cat "$saved"; return; }
    [ "$size" -lt "$off" ] && { off=0; tin=0; tout=0; key=-; gin=0; gout=0; }
    end=$off
    if [ "$size" -gt "$off" ]; then
      # Stop at the last complete line. A snapshot that ends mid-line backs off
      # by the fragment, which is read whole once its newline lands. A file
      # that does not end in a newline has a fragment of one byte at least, so
      # none at all means the read failed: the file is unreadable, whatever
      # [ -r ] said (some shared filesystems answer it yes regardless). It stays
      # where it was, rather than be skipped past uncounted.
      end=$size
      if [ "$(tail -c +"$size" "$path" | head -c 1 | wc -l)" -eq 0 ]; then
        frag=$(tok_chunk "$path" "$off" "$size" | tail -n 1 | wc -c)
        end=$((size - frag)); [ "$frag" -eq 0 ] && end=$off
      fi
    fi
    [ "$end" -gt "$off" ] && grew=1
    F_PATH[n]=$path; F_OFF[n]=$off; F_END[n]=$end
    F_IN[n]=$tin; F_OUT[n]=$tout; F_KEY[n]=$key; F_LIN[n]=$gin; F_LOUT[n]=$gout
    n=$((n + 1))
  done < <(tok_sources | tok_join "$saved")

  # Everything new, through one jq. grep goes first: every usage line contains
  # "usage", and dropping the tool output that makes up most of a transcript
  # makes the read ~5x faster. If jq fails it prints nothing, no file moves,
  # and the next refresh tries again. A line of jq's that is not five whole
  # numbers and a key is dropped the same way, so bash arithmetic never sees
  # one: that file stays where it was, and the others move on.
  if [ "$grew" -eq 1 ]; then
    while read -r i tin tout key gin gout; do
      case "$i.$tin.$tout.$gin.$gout." in *[!0-9.]*|*..*|.*) continue ;; esac
      F_IN[i]=$tin; F_OUT[i]=$tout; F_KEY[i]=$key; F_LIN[i]=$gin; F_LOUT[i]=$gout
      F_OFF[i]=${F_END[i]}
    done < <(
      for ((i = 0; i < n; i++)); do
        [ "${F_END[i]}" -gt "${F_OFF[i]}" ] || continue
        printf '\036["@file",%d,%s,%s,"%s",%s,%s]\n' \
          "$i" "${F_IN[i]}" "${F_OUT[i]}" "${F_KEY[i]}" "${F_LIN[i]}" "${F_LOUT[i]}"
        tok_chunk "${F_PATH[i]}" "${F_OFF[i]}" "${F_END[i]}" | LC_ALL=C grep -aF '"usage"'
      done | tok_fold)
  fi

  for ((i = 0; i < n; i++)); do
    sum_in=$((sum_in + F_IN[i])); sum_out=$((sum_out + F_OUT[i]))
  done
  printf '%s %s\n' "$sum_in" "$sum_out"
  for ((i = 0; i < n; i++)); do
    printf '%s %s %s %s %s %s %s\n' "${F_OFF[i]}" "${F_IN[i]}" "${F_OUT[i]}" \
      "${F_KEY[i]}" "${F_LIN[i]}" "${F_LOUT[i]}" "${F_PATH[i]}"
  done
}

# Token counts at the precision a glance can use: 999, 1k, 2.3k, 10k, 999k,
# 1M, 2.3M, 10M, 1B. One decimal below ten of a unit, whole units above, and no
# trailing .0. Rounds half up, and picks the unit after rounding, so 999,500
# reads 1M rather than 1000k. Integer arithmetic, since bash has no floats.
fmt_tok() { # count, name of the variable to set
  local n=$1 u=1 unit t
  if [ "$n" -lt 1000 ]; then printf -v "$2" '%d' "$n"; return; fi
  for unit in k M B; do
    u=$((u * 1000))
    t=$(((n + u / 20) / (u / 10)))           # tenths of a unit, rounded
    if [ "$t" -lt 100 ]; then
      if [ $((t % 10)) -eq 0 ]; then printf -v "$2" '%d%s' $((t / 10)) "$unit"
      else printf -v "$2" '%d.%d%s' $((t / 10)) $((t % 10)) "$unit"; fi
      return
    fi
    t=$(((n + u / 2) / u))                    # whole units, rounded
    if [ "$t" -lt 1000 ] || [ "$unit" = B ]; then
      printf -v "$2" '%d%s' "$t" "$unit"; return
    fi
  done
}

# The render reads the totals line and nothing else; every transcript is read
# by the detached refresh. That refresh runs on the STATUSLINE_TTL clock, not
# on a change signature: a signature means stat-ing every subagent file, the
# very directory walk that has to stay off this path. Change detection lives
# in the refresh instead, where it is cheap. The price is the lag the header
# describes: a render shows the last refresh that finished, and starts the next
# only if the last one is TTL old. A cold cache renders without the segment,
# which appears on the first render after the first refresh finishes.
TOK=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
  TOK_BASE="${TRANSCRIPT%.jsonl}"
  # Named after the session id, a UUID that is safe in a file name as it is,
  # which saves every render a cksum process. A session writes one transcript,
  # so the id alone is enough. Anything else, or none, is hashed together with
  # the transcript path. A plain id has no ".", so "tok.c.<hash>" is never
  # also some session's name.
  TS=$SESSION_ID
  case "$TS" in ''|*[!A-Za-z0-9_-]*) TS="" ;; esac
  if [ -n "$TS" ] && [ "${#TS}" -le 100 ]; then
    TS="$CACHE_DIR/tok.$TS"
  else
    TS=$(printf '%s %s' "$SESSION_ID" "$TRANSCRIPT" | cksum)
    TS="$CACHE_DIR/tok.c.${TS%% *}"
  fi
  TIN=0; TOUT=0
  [ -f "$TS" ] && read -r TIN TOUT < "$TS"
  case "$TIN"  in ''|*[!0-9]*) TIN=0  ;; esac
  case "$TOUT" in ''|*[!0-9]*) TOUT=0 ;; esac
  refresh_behind "$TS" tok_refresh "$TS"
  if [ "$TIN" -gt 0 ] || [ "$TOUT" -gt 0 ]; then
    fmt_tok "$TIN" TIN_TXT; fmt_tok "$TOUT" TOUT_TXT
    # Dim, so the cost stays the number that reads first.
    TOK=" ${DIM}${I_IN}${TIN_TXT} ${I_OUT}${TOUT_TXT}${R}"
  fi
fi

# Color by context usage.
if [ "$PCT" -ge 90 ]; then C="$RED"
elif [ "$PCT" -ge 70 ]; then C="$GOLD"
else C="$GRN"; fi

# Round rather than floor, so a bar at 78% shows 8 blocks and not 7.
FILLED=$(((PCT + 5) / 10)); [ "$FILLED" -gt 10 ] && FILLED=10; EMPTY=$((10 - FILLED))
BAR="$B_OPEN"
for ((i = 0; i < FILLED; i++)); do BAR="${BAR}${B_FULL}"; done
for ((i = 0; i < EMPTY;  i++)); do BAR="${BAR}${B_EMPTY}"; done
BAR="${BAR}${B_CLOSE}"

fmt_left() { # seconds remaining -> single coarsest unit, e.g. 2d / 1h / 47m
  local s=$1
  [ "$s" -le 0 ] && { printf 'now'; return; }
  local m=$(((s + 59) / 60)) # round up, so we never show a misleading 0m
  if [ "$s" -ge 86400 ]; then printf '%dd' $((s / 86400))
  elif [ "$m" -ge 60 ]; then printf '%dh' $(((m + 30) / 60)) # 60m -> 1h
  else printf '%dm' "$m"; fi
}

# Subscription quota. The host only sends .rate_limits on subscription auth, so
# on an API key the whole segment self-hides. Shown as consumed, the way the API
# reports it: 0% on a fresh window, 100% when exhausted, so it counts up to
# match the context bar beside it. Time math stays in bash and jq on purpose —
# `date -d` (GNU) and `date -r` (BSD) are mutually incompatible.
quota_seg() { # used_pct, resets_at(epoch), fallback_label
  local used=$1 reset=$2 label=$3 col tail
  [ -z "$used" ] && return
  used=$(printf '%.0f' "$used")
  if [ "$used" -ge 90 ]; then col="$RED"
  elif [ "$used" -ge 70 ]; then col="$GOLD"
  else col="$DIM"; fi
  # Prefer a live countdown; fall back to the static window label if the server
  # did not send a reset time.
  if [ -n "$reset" ]; then tail=$(fmt_left $((reset - NOW))); else tail="$label"; fi
  printf "%b%s%%%b %b%s%b " "$col" "$used" "$R" "$DIM" "$tail" "$R"
}
QUOTA="$(quota_seg "$FIVE" "$FIVE_AT" 5h)$(quota_seg "$WEEK" "$WEEK_AT" 7d)"
[ -n "$QUOTA" ] && QUOTA=" | ${QUOTA% }"

# Prompt cache: time left before the cached prefix goes cold. Rides in the
# context group — how full this conversation is, and how long it stays cached,
# are the same subject, and the flame keeps the two numbers apart without a
# separator between them. Once the window has lapsed there is no countdown left
# to show, so the flame gives way to a bare snowflake: the next turn will pay
# full price for the prefix, which is worth seeing at a glance. A provider that
# never caches at all shows neither glyph rather than a permanent snowflake.
#
# Both states render at the same weight, uncolored. One segment changing state
# should not also change how loud it is: the glyph already says which state it
# is in, and dimming the cold one would make the swap read as two changes
# instead of one. A dim outline glyph is also the first thing to disappear on a
# low-contrast theme, which is the wrong thing to hide.
CACHE=""
if [ -n "$CACHE_EXP" ]; then
  CACHE=" ${I_FIRE}$(fmt_left $((CACHE_EXP - NOW)))"
elif [ -n "$CACHE_SEEN" ]; then
  CACHE=" ${I_COLD}"
fi

# Groups run left to right by increasing time horizon: the working tree right
# now, then this conversation (how full, how long cached), then this session's
# spend, then the quota windows measured in hours and days. Cost, tokens and
# elapsed share a group because all three are session totals that only count
# up.
echo -e "[$MODEL] ${DIM}${DIR}${R}${VCS} | ${C}${BAR}${R} ${PCT}%${CACHE} | ${COST}${TOK} ${MINS}m${SECS}s${QUOTA}"
