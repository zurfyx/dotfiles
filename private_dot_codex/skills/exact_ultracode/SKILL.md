---
name: ultracode
description: Ultracode-style research and adversarial validation of a target with a multi-agent fleet run in waves, optionally followed by implementation with the same rigor. Works for code (a feature, module, or PR), for documents (announcements, proposals, designs, filings), and for investigations or decisions (an answer, a root cause, a recommendation). Use for deep audits, "make sure this is correct and complete", grounded research before drafting, adversarial fact-checking, or complex engineering work that must be right.
metadata:
  short-description: Research, adversarial validation, rigorous delivery
---

# Ultracode

Run the target through **scope → research → dossier → validation → adversarial verification → gap loop → report**, then an implementation phase only if the user asked for changes. The primary agent coordinates; every subagent owns one distinct question. Optimize for confidence and completeness, not speed.

Invoking this skill authorizes multi-agent orchestration. It does not authorize code changes, edits to the target document, destructive commands, production access, or external mutations unless the user separately asked for them. When the request is audit-only, make no fixes.

## Principles

- Research before judging. Establish intent and actual behavior before looking for defects.
- The coordinator does not research, validate, or verify. It reads the target only enough to write briefs, reads agent output files, and owns scope, the roster, deduplication, evidence reconciliation, stopping decisions, and the report.
- Every agent owns one distinct question, subsystem, source set, or failure mode. More agents help only when their work is independent; never add agents that repeat a question.
- Claims need evidence: file and line, executed check, primary-source link, quoted text, or reproduction. Separate `CONFIRMED`, `REFUTED`, and `UNVERIFIED`. A failed check is not a refutation; consensus is not evidence.
- Prefer a reproducer, targeted test, trace, or primary-source contract check over voting.
- Do not attribute pre-existing failures to the target; that is what the baseline is for.
- Parallel work is read-only. If fixes were explicitly requested, partition file ownership or serialize edits.
- Do not claim exhaustive completeness because the fleet was large. Report coverage and its limits.
- Do not stop at the first plausible answer. Finish the gap loop.
- Messages to other agents and the final answer may be read by a human; keep them legible.

## Target modes

Pick one mode in step 1. Every mode runs the full pipeline, including adversarial verification of research claims.

- **code**: an implementation, diff, module, or system behavior.
- **document**: an announcement, proposal, design, report, or filing that must be factually grounded and complete.
- **investigation**: a question, root cause, recommendation, or decision that must be evidence-backed.

## Fleet mechanics

1. **Slots.** Read the collaboration system message: "N available concurrency slots, including you". A wave is N−1 agents. The fleet is flat: subagents must not spawn agents.
2. **Roster before spawning.** Step 1 writes a named roster into `00-scope.md`: every research role and validation lens for the mode and tier (see `references/roles.md` and `references/validation.md`), grouped into numbered waves of N−1. Applicability is decided while writing the roster, with a one-line reason per omitted role. Once written, the roster is binding.
3. **Waves.** Spawn a full wave in one turn. Then call `wait_agent` with a minutes-scale timeout and repeat until `list_agents` shows every agent in the wave completed or errored. A timeout is not completion. An errored agent is re-spawned once, non-forked; a second failure is logged in `fleet.md` and carried into `00-scope.md` as a coverage gap. Spawn the next wave. A phase is complete only when every roster entry for it has a `fleet.md` line with a result file.
4. **Context.** Default `fork_turns: "none"` with a self-contained brief from the reference templates. Fork history (`"all"`, or a positive integer as a string) only for a researcher that genuinely needs the conversation. Validators and skeptics never fork: a forked skeptic inherits the coordinator's assumptions and cannot be adversarial. Never pass `model` or `reasoning_effort` with a full-history fork; the runtime rejects it.
5. **Reuse.** `followup_task` may reuse an idle researcher or validator for another roster entry in the same phase when its loaded context is an asset. Never reuse an agent as a skeptic, and never give a skeptic an item its earlier role touched. A follow-up counts as an invocation only when it covers a distinct roster entry. Use `send_message` to push a newly discovered fact to agents still running.
6. **Files.** Every agent writes its result to the audit directory (`references/audit-files.md`) and replies with a short summary. The coordinator hands skeptics file paths, never summaries, and reads the file rather than the reply.
7. **Resume.** After context compaction, re-read `00-scope.md` and `fleet.md` and continue from the first roster entry without a result file.

## Workflow

### 1. Frame

Read `references/audit-files.md`, create the audit directory, and start `fleet.md` before any other action. Read repository or project instructions and identify entry points, tests, configuration, generated code, and recent changes. Then write `00-scope.md`: target, mode, the user-visible outcome being validated, whether changes are in scope, tier with its reason, the roster, assumptions made instead of asking, and the baseline (tests, build, reproduction, current draft, known failures). Ask one focused question only if the ambiguity would change the audit materially.

If the user asked for incremental or collaborative work (for example "agree the direction before drafting"), scale the audit to the current step and rerun phases 2 to 7 at each later step. Do not skip validation and verification because the deliverable is partial.

### 2. Research

Spawn the research roster from `references/roles.md`. The contrarian researcher is always on it. Each researcher writes an evidence ledger file in the format given there.

### 3. Dossier

The coordinator writes `20-dossier.md`: requirement and invariant matrix (claim matrix for document and investigation modes); architecture or argument map; dependency and external-contract assumptions; baseline and known failures; risk-ranked validation plan; unresolved contradictions; which requirements are inferred; and the list of **claims requiring verification** with ids `C-01`, `C-02`, … selected by the filter in `references/adversarial.md`. Source hierarchy when sources disagree: explicit current user requirements; authoritative current project specs and accepted designs; version-matched primary external documentation; executable behavior and tests; comments and names. Tests describe current behavior, not intended behavior.

### 4. Independent validation

Spawn the validation roster from `references/validation.md`. Each validator gets the dossier path plus the original sources, never only another agent's summary, and writes findings with ids `F-01`, `F-02`, … in the format given there. A concern without a concrete failure path is a hypothesis, not a finding.

### 5. Adversarial verification

Deduplicate findings while preserving each independent piece of evidence. Then, for every finding and every `C-` claim, spawn skeptics per `references/adversarial.md`. Verification is derived, not budgeted: it is the sum over items of the per-item skeptic count and normally exceeds research and validation combined. Apply the verdict precedence rules from that file.

### 6. Gap loop

Run two completeness critics per round: one checks results against every requirement, claim, path, and contract in the dossier; one hunts blind spots from shared assumptions, correlated briefs, missing sources, or overreliance on tests. Each critic writes `50-gaps/round-<n>-<critic>.md` listing concrete new assignments. Run the assignments, verify new findings, repeat. Minimum rounds: one for the small tier, two otherwise. Stop after a round in which neither critic produced a new assignment, or after round three, and state which.

### 7. Report

Before writing, confirm every finding and claim in the report has a `40-verification/` file with its final verdict. Write `90-report.md` and present it. Lead with confirmed findings by severity, each with violated requirement or claim, exact location or source, failure scenario, impact, confidence, and fix direction. Then: coverage matrix; research summary with sources and versions or dates; checks run with baseline versus final; refuted and unverified claims; unverified risks and open questions; the fleet actually used per phase from `fleet.md` against the roster; the gap-loop stopping reason; and a completeness assessment of `high`, `moderate`, or `low` with its limiting factor. Do not report hypotheses as defects. If nothing is confirmed, say so and still describe coverage.

## 8. Implementation (only when the user asked for changes)

Research and validate first; the dossier is the plan. Then:

- Partition ownership by file or section and record it in `60-fixes/ownership.md`. Serialize anything that cannot be partitioned.
- Follow existing patterns, keep changes scoped to the confirmed findings, add abstractions only when they remove real complexity, and never discard unrelated uncommitted user work.
- Verify in proportion to blast radius: targeted tests first, then broader tests, type checks, linters, builds, or a real end-to-end exercise of the affected workflow.
- Re-run phases 4 to 7 against the final state. Validators re-check end-to-end behavior or the whole document, not the diff alone.
- Finish end to end. Do not report completion while required checks fail or were not run; state the limitation plainly.
