---
name: ultracode
description: Ultracode for Codex. Research with a multi-agent fleet, then either build the thing (build mode) or adversarially validate an existing one (audit mode). Works for code, documents, and investigations. Use for complex or high-risk engineering work, "go ahead with the implementation", deep audits, "make sure this is correct and complete", grounded research before drafting, or adversarial fact-checking. Not for ordinary lightweight review.
metadata:
  short-description: Fleet-backed research, build, and adversarial validation
---

# Ultracode

Two request kinds, one coordinator:

- **build**: the user wants something implemented, changed, fixed, or written, or the target does not exist yet. Pipeline: **scope → research → brief → implement → verify → review → report**. Read `references/build.md`.
- **audit**: the target exists and the user wants to know whether it is correct and complete. Pipeline: **scope → research → dossier → validate → verify → gap round → report**, plus fixes only if asked.

"Go ahead with the implementation" is build. Never audit a design in place of building it: validators and skeptics work on things that exist.

Invoking this skill authorizes multi-agent orchestration. It does not authorize destructive commands, production access, or external mutations. In audit mode it does not authorize changes to the target unless the user asked for fixes.

## Principles

- The coordinator does not research, validate, or verify. It reads the target only enough to write briefs, reads agent output files, integrates, and owns scope, the roster, the budget, deduplication, stopping decisions, and the report.
- Every agent owns one distinct question, slice, or file set. Agents that repeat a question are waste; on this runtime, agents are wall-clock time.
- Claims need evidence: file and line, executed check, primary-source link, quoted text, or reproduction. `CONFIRMED`, `REFUTED`, and `UNVERIFIED` stay separate. A failed check is not a refutation; consensus is not evidence.
- Do not attribute pre-existing failures to the target; that is what the baseline is for.
- Research and review agents are read-only. Implementers own disjoint files.
- Do not claim exhaustive completeness because the fleet was large. Report coverage and its limits.
- Messages to other agents and the final answer may be read by a human; keep them legible.

## Target modes

- **code**: an implementation, diff, module, or system behavior.
- **document**: an announcement, proposal, design, report, or filing.
- **investigation**: a question, root cause, recommendation, or decision.

## Fleet mechanics

1. **Slots.** Read the collaboration system message: "N available concurrency slots, including you". A wave is N−1 agents. The fleet is flat: subagents must not spawn agents.
2. **Budget before spawning.** Step 1 writes into `00-scope.md` the tier, the wave count and invocation cap for that tier from `references/roles.md`, and the wall-clock target. The roster is grouped into numbered waves and is binding: nothing is spawned that is not on it, and a phase is complete only when every roster entry has a `fleet.md` line with a result file. Exceeding the invocation cap requires a checkpoint with the user first.
3. **Waves.** Spawn a full wave in one turn. Call `wait_agent` with the longest timeout the runtime allows (minutes, up to an hour) and repeat until `list_agents` shows every agent in the wave completed or errored. A timeout is not completion. An errored agent is re-spawned once, non-forked; a second failure is logged and carried into the report as a coverage gap.
4. **Context.** Default `fork_turns: "none"` with a self-contained brief from the reference templates. Fork history only for a researcher that genuinely needs the conversation. Reviewers and skeptics never fork. Never pass `model` or `reasoning_effort` with a full-history fork.
5. **Reuse.** `followup_task` reuses an idle agent for another roster entry in the same phase when its loaded context is an asset; this is the default way to run gap assignments and fix-ups. Never reuse an agent as a skeptic on an item its earlier role produced. Use `send_message` to push a newly discovered fact to running agents.
6. **Files.** Every agent writes its result to the audit directory (`references/audit-files.md`) and replies with a short summary. Skeptics get file paths, never summaries.
7. **Resume.** After context compaction, re-read `00-scope.md` and `fleet.md` and continue from the first roster entry without a result file.

## Audit workflow

### 1. Frame
Read `references/audit-files.md`, create the audit directory, and start `fleet.md`. Read repository or project instructions; identify entry points, tests, configuration, generated code, and recent changes. Write `00-scope.md`: target, mode, user-visible outcome, whether fixes are in scope, tier with reason and budget, roster, assumptions, baseline. Tier is medium unless the user names another. Ask one focused question only if the ambiguity would change the audit materially.

### 2. Research
Spawn the research roster from `references/roles.md`; the contrarian is always on it. Each researcher writes an evidence ledger in the format given there.

### 3. Dossier
Write `20-dossier.md`: requirement and invariant matrix (claim matrix for document and investigation modes); architecture or argument map; dependency and contract assumptions; baseline and known failures; risk-ranked validation plan; unresolved contradictions; inferred requirements marked. In document mode also list the material claims `C-nn` using the filter in `references/adversarial.md`. Source hierarchy when sources disagree: explicit current user requirements; authoritative project specs and accepted designs; version-matched primary documentation; executable behavior and tests; comments and names.

### 4. Validate
Spawn the validation roster from `references/validation.md`: each validator owns a group of related lenses and writes findings `F-nn` in the format given there. A concern without a concrete failure path is a hypothesis, not a finding.

### 5. Verify
Deduplicate findings, keeping each independent piece of evidence. Spawn skeptics per `references/adversarial.md`: one per finding with all angles in the brief, batched three or four related items per skeptic, a second skeptic only for critical findings, and claims only in document mode. Apply the verdict rules there.

### 6. Gap round
Two critics, one round (a second only in the large tier). Each writes `50-gaps/round-<n>-<critic>.md` with at most three concrete assignments. Run assignments as follow-ups to existing researchers or validators; verify any new finding with one skeptic. Stop after the round.

### 7. Report
Confirm every `F-` and `C-` item in the report has a `40-verification/` file with a final verdict. Write `90-report.md`: confirmed findings by severity with requirement, location, failure scenario, impact, confidence, and fix direction; coverage matrix; research summary with sources and dates; checks run, baseline versus final; refuted and unverified items; the fleet used per phase from `fleet.md` against the roster and budget, with wall-clock; the completeness assessment (`high`, `moderate`, `low`) and its limiting factor. Hypotheses are not defects. If nothing is confirmed, say so and still describe coverage.

### 8. Fixes (only if the user asked)
Switch to the build workflow from its implement phase, using the report as the brief.

## Build workflow

Follow `references/build.md`. The shape: one research wave, a one-page brief, implementation waves partitioned by file ownership that begin in the same turn as the brief, a verification wave, one review wave over the actual diff with batched skeptics, then the report. No research spawns after the brief until code exists.
