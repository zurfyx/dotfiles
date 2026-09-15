# Audit files

All agents share the working directory, so results live in files, not in chat. Files survive context compaction, let the coordinator inspect any agent's work, and let skeptics read evidence without inheriting the coordinator's context.

## Layout

`<slug>` is `<yyyy-mm-dd>-<short-kebab-name>`. Write the resolved absolute directory into `00-scope.md` and paste it into every brief.

```text
.audit/<slug>/
  00-scope.md            target, mode, workflow (audit|build), outcome, tier + reason, budget (wave count, invocation cap, wall-clock target), roster grouped into waves, assumptions, baseline, absolute audit dir
  fleet.md               append-only log, one line per agent invocation
  10-research/<role>.md
  20-dossier.md          audit: coordinator synthesis, incl. C-nn claims in document mode
  20-brief.md            build: the one-page brief with the ownership map
  30-validation/<group>.md
  40-verification/<batch id>.md
  50-gaps/round-<n>-<critic>.md   audit only
  60-implementation/<owner>.md    build, and audit fixes
  90-report.md
```

If the working directory is a git repository, append `.audit/` to the file named by `git rev-parse --git-path info/exclude` (the literal `.git/info/exclude` does not exist in worktrees or submodules). This is local metadata, not a change to the project. If the working directory is not a git repository, or is a synced folder such as a cloud drive, create the audit directory under `${TMPDIR:-/tmp}/audit/<slug>/` instead and record that path in the report.

## fleet.md

One line per invocation, appended at spawn time and updated on completion:

```text
phase | wave | agent name | roster entry | fork_turns | spawned or followup | started | finished | result file | status (running / completed / errored / respawned)
```

The report's "fleet used" section, including wall-clock per phase, is derived from this file against the roster and budget in `00-scope.md`.

## Coordinator discipline

- Create the directory and `fleet.md` before the first spawn; write `00-scope.md` with the roster and budget before the first spawn; write `20-dossier.md` or `20-brief.md` before the first validator, reviewer, or implementer.
- Hand agents absolute file paths and inline formats. Do not paste ledgers into briefs.
- When an agent reports, read its file, not only its reply.
- A phase is complete only when every roster entry for it has a `fleet.md` line with a result file.
- Before exceeding the invocation cap or the wall-clock target, stop and check in with the user with what is done and what remains.
- Before the report, confirm every `F-` and `C-` item in it has a `40-verification/` block with a final verdict.
- After context compaction, re-read `00-scope.md` and `fleet.md` and continue from the first roster entry without a result file.
