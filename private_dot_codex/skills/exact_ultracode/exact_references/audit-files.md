# Audit files

All agents share the working directory, so results live in files, not in chat. Files survive context compaction, let the coordinator inspect any agent's work, and let skeptics read evidence without inheriting the coordinator's context.

## Layout

`<slug>` is `<yyyy-mm-dd>-<short-kebab-name>`. Write the resolved absolute directory into `00-scope.md` and paste it into every brief.

```text
.audit/<slug>/
  00-scope.md            target, mode, tier + reason, roster grouped into waves, assumptions, baseline, absolute audit dir
  fleet.md               append-only log, one line per agent invocation
  10-research/<role>.md
  20-dossier.md          coordinator synthesis, including the C-nn claims requiring verification
  30-validation/<lens>.md
  40-verification/<item id>-skeptic-<n>.md
  50-gaps/round-<n>-<critic>.md
  60-fixes/              only when changes were requested: ownership.md and check results
  90-report.md
```

If the working directory is a git repository, append `.audit/` to the file named by `git rev-parse --git-path info/exclude` (the literal `.git/info/exclude` does not exist in worktrees or submodules). This is local metadata, not a change to the project, so it is within the audit-only authorization. If the working directory is not a git repository, or is a synced folder such as a cloud drive, create the audit directory under `${TMPDIR:-/tmp}/audit/<slug>/` instead and record that path in the report.

## fleet.md

One line per invocation, appended at spawn time and updated on completion:

```text
phase | wave | agent name | roster entry | fork_turns | spawned or followup | result file | status (running / completed / errored / respawned)
```

The report's "fleet used" section is derived from this file against the roster in `00-scope.md`, so planned and actual counts cannot drift.

## Coordinator discipline

- Create the directory and `fleet.md` before the first spawn; write `00-scope.md` with the roster before the first spawn; write `20-dossier.md` before the first validator.
- Hand agents absolute file paths and inline formats. Do not paste ledgers into briefs.
- When an agent reports, read its file, not only its reply.
- A phase is complete only when every roster entry for it has a `fleet.md` line with a result file.
- Before the report, confirm every `F-` and `C-` item in `90-report.md` has `40-verification/` files and a final verdict.
- After context compaction, re-read `00-scope.md` and `fleet.md` and continue from the first roster entry without a result file.
