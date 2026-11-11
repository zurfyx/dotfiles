# Build workflow

For requests to implement, change, fix, or write something. The deliverable is working code or a finished document, verified and reviewed, inside the budget. Research exists to make the first implementation right, not to be complete.

## Phases

### 1. Frame
Same as audit step 1, plus: the concrete outcome and its observable completion criteria, and whether the target exists yet. Write the budget from `references/roles.md` (build column). Capture the baseline: tests, build, lint, the current behavior.

### 2. Research (one wave; two in the large tier)
From `references/roles.md`, pick the roles that change the design: intent, architecture of what exists, external contracts, and always the contrarian. Investigation and document targets pick the equivalent roles from their mode. Each writes an evidence ledger.

### 3. Brief (coordinator, same turn)
Write `20-brief.md`, one page:

```text
# Brief — <target>
## Outcome and completion criteria
## Decisions (each with the ledger evidence that drove it)
## Non-goals
## Ownership map: implementer -> files or sections it owns, and what it must not touch
## Integration points between owners (interfaces, names, formats)
## Test and check plan: what proves each decision, who runs it
## Assumptions made instead of asking (max three)
```

Then spawn the first implementation wave in the same turn. Do not spawn further research until code exists; a question that comes up during implementation goes to the implementer that owns it or to one follow-up on an existing researcher.

### 4. Implement (waves partitioned by ownership)
Each implementer gets the brief path, its ownership entry, the integration points it touches, the check it must run, and the rule that it edits only what it owns. Implementers follow existing patterns, keep changes scoped to the brief, add abstractions only when they remove real complexity, and never discard unrelated uncommitted work. The coordinator integrates between waves: reads each result file, resolves interface mismatches with `send_message` or a follow-up, and runs the fast checks. Parallel edits to one file are never allowed; serialize by ownership or by waves.

Implementer result file `60-implementation/<owner>.md`:

```text
owner | files changed | what changed and why | checks run -> result | open interface questions | anything left undone
```

### 5. Verify (one wave)
Run the test and check plan from the brief in proportion to blast radius: targeted tests, then broader tests, type checks, linters, builds, and a real end-to-end exercise of the affected workflow. One agent per check group. Failures go back to the owning implementer as a follow-up, then the check re-runs.

### 6. Review (one wave, then batched skeptics)
Reviewers work on the actual diff and the affected end-to-end behavior, never on the brief alone. Use the grouped lenses in `references/validation.md` for the mode (three to four reviewers). Findings `F-nn` go through `references/adversarial.md` with the build budget: one skeptic per finding, batched. Confirmed findings return to the owning implementer; affected checks re-run.

### 7. Report
`90-report.md`: what changed, by file and owner; decisions and the evidence behind them; checks run with baseline versus final; confirmed review findings and their fixes; anything unverified or left undone and why; fleet used against the budget with wall-clock. Do not report completion while required checks fail or were not run.

## Budget rules specific to build

- Research is capped at one wave (two in large). If the research wave ends with open design questions, decide them in the brief as labeled assumptions rather than spawning more research.
- The brief is a page. Requirement matrices, closure conditions, and test matrices belong in the code and tests, not in the brief.
- Skeptics verify review findings only. Design decisions are not verified by skeptics; they are verified by the implementation passing its checks.
- No gap loop. The review wave is the completeness check.

## Implementer brief template

```text
Read <absolute audit dir>/00-scope.md and <absolute audit dir>/20-brief.md first.
You own: <files or sections>. Do not edit anything else; if you need a change outside your ownership, write it under "open interface questions" and stop at the boundary.
Implement: <the decisions from the brief that fall in your ownership>.
Integration points you touch: <names, formats, interfaces and who owns the other side>.
Follow existing patterns in <paths>; keep the change scoped; do not discard unrelated uncommitted work; no destructive commands; no spawning agents.
Run before reporting: <check command(s)>.
Write your result to <absolute audit dir>/60-implementation/<owner>.md in exactly this format:
<paste the implementer result format>
Reply with three lines: what changed, check result, open questions.
```
