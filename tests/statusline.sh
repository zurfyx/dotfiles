#!/bin/bash
#
# Tests for the token totals in dot_claude/executable_statusline.sh. Builds
# synthetic transcripts in a scratch directory, feeds the real script a
# synthetic payload, waits for its detached refresh, and checks what the next
# render prints between the cost and the elapsed time.
#
#   bash tests/statusline.sh        (or /bin/bash on macOS, to test bash 3.2)
#
# Needs what the script needs, bash and jq, and nothing else. Every transcript
# here is made up on the spot; never check in a real one.

set -u

# CDPATH='' because with CDPATH set, cd resolves a relative path through it and
# prints where it went, which would land in HERE ahead of pwd's answer.
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
SCRIPT="$HERE/../dot_claude/executable_statusline.sh"
[ -f "$SCRIPT" ] || { echo "no script at [$SCRIPT]" >&2; exit 1; }

# The script caches under $TMPDIR. Point that at a scratch directory, so the
# test neither reads nor disturbs the cache of a live session.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"
CACHE="$TMPDIR/claude-statusline.$(id -u)"
# Refresh on every render, and render the default glyphs unless a case asks.
export STATUSLINE_TTL=0
unset STATUSLINE_ICONS

FAILS=0
check() { # name, expected, actual
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n     expected [%s]\n     got      [%s]\n' "$1" "$2" "$3"
    FAILS=$((FAILS + 1))
  fi
}

# One assistant line. An empty request or message id leaves that field out.
asst() { # request id, message id, input, cache creation, cache read, output, [extra fields]
  local req="" mid=""
  [ -n "$1" ] && req="\"requestId\":\"$1\","
  [ -n "$2" ] && mid="\"id\":\"$2\","
  printf '{"type":"assistant",%s"message":{%s"role":"assistant","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}%s}\n' \
    "$req" "$mid" "$3" "$4" "$5" "$6" "${7:-}"
}

payload() { # session id, transcript path ("" for none)
  jq -nc --arg s "$1" --arg t "$2" --arg d "$WORK" '
    { model: { display_name: "Test" }, workspace: { current_dir: $d },
      cost: { total_cost_usd: 1.5, total_duration_ms: 65000 }, session_id: $s }
    + (if $t == "" then {} else { transcript_path: $t } end)'
}

# Wait for every detached refresh to finish: each holds a lock directory until
# its result is in place. Bounded, and by polling, since macOS has no timeout.
settle() {
  local i=0
  while :; do
    set -- "$CACHE"/*.lock
    [ -e "$1" ] || return 0
    i=$((i + 1))
    if [ "$i" -ge 400 ]; then echo "FAIL a refresh never finished" >&2; exit 1; fi
    sleep 0.05
  done
}

# Wait, bounded, for a path to appear.
wait_for() {
  local i=0
  until [ -e "$1" ]; do
    i=$((i + 1))
    if [ "$i" -ge 400 ]; then echo "FAIL never appeared: $1" >&2; exit 1; fi
    sleep 0.05
  done
}

# Render once and print the spend group: the text between the cost ($1.50) and
# the elapsed time (1m5s), empty when absent. Matched on the raw line, escapes
# and all, so a segment that is not dimmed, is not reset before the elapsed
# time, or leaves a double space where it is absent prints UNEXPECTED instead.
ESC=$(printf '\033')
render() { # session id, transcript path
  local line
  line=$(payload "$1" "$2" | "$BASH" "$SCRIPT")
  line="${line##* | }"                       # the last group: "$1.50 ... 1m5s"
  case "$line" in
    "\$1.50 1m5s") ;;
    "\$1.50 ${ESC}[2m"*"${ESC}[0m 1m5s")
      line="${line#"\$1.50 ${ESC}[2m"}"; printf '%s' "${line%"${ESC}[0m 1m5s"}" ;;
    *) printf 'UNEXPECTED LINE: %s' "$(printf '%s' "$line" | sed "s/$ESC/\\\\e/g")" ;;
  esac
}

# The state file the script keeps for a session and transcript: named after a
# plain session id, and after a hash of both otherwise. The ids here are short.
state() { # session id, transcript path
  local c
  case "$1" in
    ''|*[!A-Za-z0-9_-]*)
      c=$(printf '%s %s' "$1" "$2" | cksum); printf '%s' "$CACHE/tok.c.${c%% *}" ;;
    *) printf '%s' "$CACHE/tok.$1" ;;
  esac
}

# A jq that leaves a mark when the refresh folds transcripts with it, told
# apart from the render's own jq by its flags.
JQ_SHIM="$WORK/jqshim"; mkdir -p "$JQ_SHIM"
cat > "$JQ_SHIM/jq" <<EOF
#!/bin/sh
[ "\$1" = -nrR ] && : > "$JQ_SHIM/folded"
exec "$(command -v jq)" "\$@"
EOF
chmod +x "$JQ_SHIM/jq"
folds() { # session id, transcript path: did a refresh run the fold?
  rm -f "$JQ_SHIM/folded"
  PATH="$JQ_SHIM:$PATH" tokens "$1" "$2" >/dev/null
  if [ -e "$JQ_SHIM/folded" ]; then echo yes; else echo no; fi
}

# What the line shows once the refresh has caught up with the files as they
# are now: one render to start a refresh, then another to read its result.
tokens() { # session id, transcript path
  render "$1" "$2" >/dev/null; settle
  render "$1" "$2"; settle
}

# --- dedupe: the last line of each request, snapshots and tool results between
T="$WORK/dedupe/s.jsonl"; mkdir -p "${T%/*}"
{
  printf '{"type":"user","message":{"role":"user","content":"hi"}}\n'
  asst r1 m1 1 20 300 1                 # streaming snapshot
  asst r1 m1 1 20 300 5                 # streaming snapshot
  printf '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}\n'
  asst r1 m1 1 20 300 20                # final: in 321, out 20
  asst r2 m2 3 0 0 7
  asst "" m3 1 0 0 1                    # no requestId: a request of its own
  asst "" m3 1 0 0 1                    # and so is this one
  printf '{"type":"user","usage":{"input_tokens":5000,"output_tokens":5000}}\n'
  printf 'not json, though it says "usage"\n'
} > "$T"
check "cold cache renders without the segment" "" "$(render dedupe "$T")"
settle
check "dedupe keeps the last line of each request" "↑326 ↓29" "$(tokens dedupe "$T")"
check "an idle refresh changes nothing" "↑326 ↓29" "$(tokens dedupe "$T")"
check "and does not start the fold" no "$(folds dedupe "$T")"
asst r9 m9 1 0 0 1 >> "$T"
check "one after an append does" yes "$(folds dedupe "$T")"
check "and counts it" "↑327 ↓30" "$(tokens dedupe "$T")"
check "ascii glyphs" "in327 out30" "$(STATUSLINE_ICONS=ascii tokens dedupe "$T")"

# --- the TTL holds: a render inside it reads the state and starts nothing,
# which also shows the mtime helper reads a real time on this platform
T="$WORK/ttl/s.jsonl"; mkdir -p "${T%/*}"
asst r1 m1 1 0 0 1 > "$T"
tokens ttl "$T" >/dev/null
asst r2 m2 1 0 0 1 >> "$T"
check "inside the TTL a render starts no refresh" "↑1 ↓1" "$(STATUSLINE_TTL=3600 tokens ttl "$T")"
check "past it, one does" "↑2 ↓2" "$(tokens ttl "$T")"

# --- forkedFrom: history copied from a parent session is not this session's
T="$WORK/fork/s.jsonl"; mkdir -p "${T%/*}"
{
  asst r1 m1 100 0 0 50 ',"forkedFrom":{"sessionId":"parent","messageUuid":"u1"}'
  asst r1 m1 100 0 0 50 ',"forkedFrom":{"sessionId":"parent","messageUuid":"u2"}'
  asst r2 m2 7 0 0 3 ',"forkedFrom":null'
  asst r3 m3 5 0 0 2
} > "$T"
check "forkedFrom lines are skipped" "↑12 ↓5" "$(tokens fork "$T")"

# --- a line Claude Code wrote itself, between two blocks of one request
T="$WORK/synthetic/s.jsonl"; mkdir -p "${T%/*}"
{
  asst r1 m1 100 0 0 10
  printf '{"type":"assistant","requestId":"r1","message":{"id":"m-synthetic","model":"<synthetic>","role":"assistant","usage":{"input_tokens":0,"output_tokens":0}}}\n'
  asst r1 m1 100 0 0 10
} > "$T"
check "a synthetic line does not split a request" "↑100 ↓10" "$(tokens synthetic "$T")"

# --- a transcript line shaped like a header is a line like any other
T="$WORK/header/s.jsonl"; mkdir -p "${T%/*}"
{
  asst r1 m1 10 0 0 1
  printf '["@file",0,0,0,"-",0,0,"usage"]\n'
  asst r2 m2 5 0 0 1
} > "$T"
check "a line shaped like a header does not reset the file" "↑15 ↓2" "$(tokens header "$T")"

# --- counts no request could have are taken as 0, and break nothing
T="$WORK/absurd/s.jsonl"; mkdir -p "${T%/*}"
{ asst r1 m1 1e20 0 0 5; asst r2 m2 -7 0 0 1; asst r3 m3 10 0 0 -3; } > "$T"
check "huge and negative counts count as 0" "↑10 ↓6" "$(tokens absurd "$T")"
check "and leave a state that stands" no "$(folds absurd "$T")"
asst r4 m4 1 0 0 1 >> "$T"
check "so the next refresh adds as usual" "↑11 ↓7" "$(tokens absurd "$T")"

# --- a file whose sum jq would print as 1e+16 is left out, not fatal: bash
# arithmetic cannot take that form, and the refresh used to die on it
T="$WORK/huge/s.jsonl"; B="${T%.jsonl}"; mkdir -p "$B/subagents"
asst r1 m1 10 0 0 1 > "$T"
L=$(asst "" "" 500000000000 500000000000 0 0)
yes "$L" | head -n 10000 > "$B/subagents/agent-h.jsonl"
check "a sum past what bash reads is left out" "↑10 ↓1" "$(tokens huge "$T")"
asst r2 m2 5 0 0 1 >> "$T"
check "and the other files carry on" "↑15 ↓2" "$(tokens huge "$T")"

# --- a session id unfit for a file name is hashed with the transcript path
T="$WORK/oddsession/s.jsonl"; mkdir -p "${T%/*}"
asst r1 m1 3 0 0 3 > "$T"
check "a session id with a slash still counts" "↑3 ↓3" "$(tokens 'odd id/1' "$T")"
check "in a state file of its own" yes "$([ -f "$(state 'odd id/1' "$T")" ] && echo yes)"
LONG=$(printf '%0300d' 7)
check "so does one too long for a file name" "↑3 ↓3" "$(tokens "$LONG" "$T")"

# --- a transcript reached through a symlink is sized as the file it names
T="$WORK/link/s.jsonl"; mkdir -p "${T%/*}"
asst r1 m1 7 0 0 7 > "$WORK/link/real.jsonl"; ln -s real.jsonl "$T"
check "a symlinked transcript counts" "↑7 ↓7" "$(tokens link "$T")"

# --- a new session sweeps out state left idle for over a week
mkdir -p "$CACHE"
printf '5 5\n' > "$CACHE/tok.stale"; touch -t 200001010000 "$CACHE/tok.stale"
printf '5 5\n' > "$CACHE/tok.recent"
printf '5 5\n' > "$CACHE/vcs.stale"; touch -t 200001010000 "$CACHE/vcs.stale"
T="$WORK/sweep/s.jsonl"; mkdir -p "${T%/*}"; asst r1 m1 1 0 0 1 > "$T"
tokens sweep "$T" >/dev/null
check "stale token state is deleted" "" "$([ -e "$CACHE/tok.stale" ] && echo kept)"
check "recent token state is kept" kept "$([ -e "$CACHE/tok.recent" ] && echo kept)"
check "other cache files are left alone" kept "$([ -e "$CACHE/vcs.stale" ] && echo kept)"

# --- subagents, at any depth, and nothing else beside the transcript
T="$WORK/sub/s.jsonl"; B="${T%.jsonl}"
mkdir -p "$B/subagents/workflows/wf_1" "$B/tool-results"
asst r1 m1 100 0 0 10 > "$T"
{ asst r2 m2 20 0 0 1; asst r2 m2 20 0 0 2; } > "$B/subagents/agent-a.jsonl"
asst r3 m3 3 0 0 300 > "$B/subagents/workflows/wf_1/agent-b.jsonl"
asst r4 m4 5000 0 0 5000 > "$B/subagents/agent-a.meta.json"
asst r5 m5 5000 0 0 5000 > "$B/tool-results/other.jsonl"
check "subagent transcripts count, nested ones included" "↑123 ↓312" "$(tokens sub "$T")"
asst r6 m6 4 0 0 0 >> "$B/subagents/workflows/wf_1/agent-b.jsonl"
asst r7 m7 0 0 0 1 > "$B/subagents/workflows/wf_1/agent-c.jsonl"
check "subagent appends and new files are picked up" "↑127 ↓313" "$(tokens sub "$T")"
rm "$B/subagents/workflows/wf_1/agent-c.jsonl"
check "a deleted transcript keeps what it spent" "↑127 ↓313" "$(tokens sub "$T")"

# --- ids that could not be written back safely make no key: each line alone
T="$WORK/odd/s.jsonl"; mkdir -p "${T%/*}"
{ asst "r 1" m1 1 0 0 1; asst "r 1" m1 1 0 0 1; } > "$T"
check "odd ids stand alone" "↑2 ↓2" "$(tokens odd "$T")"
asst r2 m2 1 0 0 1 >> "$T"
check "and leave the saved state readable" "↑3 ↓3" "$(tokens odd "$T")"

# --- a partial last line waits for its newline, then counts once
T="$WORK/partial/s.jsonl"; mkdir -p "${T%/*}"
asst r1 m1 10 0 0 1 > "$T"
L=$(asst r2 m2 20 0 0 2)
printf '%s' "${L%???????}" >> "$T"      # all but the tail of the line
check "a partial trailing line is not parsed" "↑10 ↓1" "$(tokens partial "$T")"
printf '%s\n' "${L: -7}" >> "$T"       # the rest, and the newline
check "the completed line counts" "↑30 ↓3" "$(tokens partial "$T")"
check "and counts once" "↑30 ↓3" "$(tokens partial "$T")"

# --- a request whose lines straddle two reads is corrected, not added twice
asst r3 m3 100 0 0 10 >> "$T"
check "first line of a request" "↑130 ↓13" "$(tokens partial "$T")"
asst r3 m3 100 0 0 40 >> "$T"
check "its final line, read later, replaces it" "↑130 ↓43" "$(tokens partial "$T")"
asst r4 m4 1 0 0 1 >> "$T"
check "and the next request adds as usual" "↑131 ↓44" "$(tokens partial "$T")"

# --- a file that shrinks was rewritten: read it again from zero
asst r9 m9 4 0 0 4 > "$T"
check "truncation resets that file" "↑4 ↓4" "$(tokens partial "$T")"

# --- a damaged state line is dropped, and its file read again from zero
T="$WORK/damage/s.jsonl"; B="${T%.jsonl}"; mkdir -p "$B/subagents"
asst r1 m1 10 0 0 10 > "$T"
asst r2 m2 5 0 0 5 > "$B/subagents/agent-x.jsonl"
check "state before the damage" "↑15 ↓15" "$(tokens damage "$T")"
S=$(state damage "$T")
sed 's/ r2|m2 / r2"m2 /' "$S" > "$S.x" && mv "$S.x" "$S"
check "the damaged key is in place" 1 "$(grep -c 'r2"m2' "$S")"
asst r3 m3 100 0 0 100 >> "$T"; asst r4 m4 5 0 0 5 >> "$B/subagents/agent-x.jsonl"
check "a key that would break the header is damage" "↑120 ↓120" "$(tokens damage "$T")"
asst r5 m5 100 0 0 100 >> "$T"
check "and the next refresh adds as usual" "↑220 ↓220" "$(tokens damage "$T")"
L=$(sed -n 2p "$S"); printf '%s\n' "$L" >> "$S"     # one file, listed twice
asst r6 m6 1 0 0 1 >> "$T"
check "a file listed twice counts once" "↑221 ↓221" "$(tokens damage "$T")"

# --- a refresh that outlives its lock neither breaks nor rolls back the next
# Refresh A is held just after it lists the files, by a grep that waits for a
# go-ahead, while more files arrive. Its lock is aged past the 60 s reaping
# point, so the next render reaps it and refresh B runs to the end. Another
# lock is then put in place, standing for a refresh C still running, and A is
# let go. An mv that leaves a mark says when A has finished.
T="$WORK/race/s.jsonl"; B="${T%.jsonl}"; mkdir -p "$B/subagents"
S=$(state race "$T"); SHIM="$WORK/shim"; mkdir -p "$SHIM"
cat > "$SHIM/grep" <<EOF
#!/bin/sh
if [ "\$1" = -aF ] && mkdir "$SHIM/held" 2>/dev/null; then
  i=0; while [ ! -e "$SHIM/go" ] && [ \$i -lt 400 ]; do sleep 0.05; i=\$((i + 1)); done
fi
exec "$(command -v grep)" "\$@"
EOF
cat > "$SHIM/mv" <<EOF
#!/bin/sh
"$(command -v mv)" "\$@"; s=\$?
for a; do d=\$a; done
: > "$SHIM/moved.\${d##*/}"
exit \$s
EOF
chmod +x "$SHIM/grep" "$SHIM/mv"
asst r0 m0 1000 0 0 1 > "$T"
for i in 1 2; do asst "r$i" "m$i" 100 0 0 1 > "$B/subagents/agent-$i.jsonl"; done
PATH="$SHIM:$PATH" render race "$T" >/dev/null
wait_for "$SHIM/held"
for i in 3 4 5 6; do asst "r$i" "m$i" 100 0 0 1 > "$B/subagents/agent-$i.jsonl"; done
touch -t 200001010000 "$S.lock"
render race "$T" >/dev/null; settle
check "the refresh that reaped the lock counts everything" "1600 7" "$(head -n 1 "$S")"
mkdir "$S.lock"
: > "$SHIM/go"; wait_for "$SHIM/moved.${S##*/}"; sleep 0.3
check "a late refresh leaves a newer one's lock alone" "held" "$([ -d "$S.lock" ] && echo held)"
check "and does not put back its older count" "1600 7" "$(head -n 1 "$S")"
check "and leaves no temp file behind" "" "$(set -- "$CACHE"/*.new.*; [ -e "$1" ] && echo "$1")"
rmdir "$S.lock" 2>/dev/null
check "the count carries on from there" "↑1.6k ↓7" "$(tokens race "$T")"

# --- nothing to show
check "no transcript_path omits the segment" "" "$(tokens none "")"
check "a missing transcript omits the segment" "" "$(tokens gone "$WORK/gone.jsonl")"
# Unreadable files. Root reads a file whatever its mode, so there the case
# cannot be set up. Where [ -r ] answers yes regardless, as on some shared
# filesystems, the refresh runs and must not skip past what it cannot read.
if [ "$(id -u)" -ne 0 ]; then
  T="$WORK/locked/s.jsonl"; B="${T%.jsonl}"; mkdir -p "$B/subagents"
  asst r1 m1 10 0 0 1 > "$T"; chmod 000 "$T"
  check "an unreadable transcript omits the segment" "" "$(tokens locked "$T")"
  chmod 600 "$T"
  check "once readable, it counts in full" "↑10 ↓1" "$(tokens locked "$T")"
  asst r2 m2 5 0 0 2 > "$B/subagents/agent-l.jsonl"; chmod 000 "$B/subagents/agent-l.jsonl"
  check "an unreadable subagent file is left out" "↑10 ↓1" "$(tokens locked "$T")"
  chmod 600 "$B/subagents/agent-l.jsonl"
  check "until it can be read" "↑15 ↓3" "$(tokens locked "$T")"
else
  echo "skip unreadable transcripts: running as root"
fi
T="$WORK/zero/s.jsonl"; mkdir -p "${T%/*}"
{ printf '{"type":"user","message":{"content":"hi"}}\n'; asst r1 m1 0 0 0 0; } > "$T"
check "zero totals omit the segment" "" "$(tokens zero "$T")"

# --- units: round half up, and never 1000k or 1000M
unit() { # input tokens, output tokens, expected
  local t="$WORK/units/$1-$2.jsonl"
  mkdir -p "${t%/*}"
  asst r1 m1 "$1" 0 0 "$2" > "$t"
  check "units: $1 in, $2 out" "$3" "$(tokens "units-$1-$2" "$t")"
}
unit 999 1000 "↑999 ↓1k"
unit 1049 1050 "↑1k ↓1.1k"
unit 2345 9949 "↑2.3k ↓9.9k"
unit 9950 10499 "↑10k ↓10k"
unit 999499 999500 "↑999k ↓1M"
unit 2345678 9950000 "↑2.3M ↓10M"
unit 999499999 999500000 "↑999M ↓1B"
unit 1234567890 12345678901 "↑1.2B ↓12B"
unit 0 5 "↑0 ↓5"

# --- a transcript that is not a regular file is never opened: reading a FIFO
# waits for a writer, and would hold the lock until reaped, then start another
# refresh that waits the same way. Last, because on a regression that refresh
# never finishes, and settle would give up on it.
T="$WORK/fifo/s.jsonl"; mkdir -p "${T%/*}"; mkfifo "$T"
check "a FIFO omits the segment" "" "$(render fifo "$T")"
check "and starts no refresh" "" "$([ -e "$(state fifo "$T").lock" ] && echo held)"

if [ "$FAILS" -gt 0 ]; then
  echo "$FAILS failed"; exit 1
fi
echo "all passed"
