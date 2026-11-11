# Validation and review lenses

Each validator (audit) or reviewer (build) owns one lens group. Everyone gets the dossier or brief path plus the original sources; reviewers also get the diff. Findings go to `30-validation/<group>.md`. Each finding needs a concrete failure path; otherwise it is a hypothesis.

## Finding format

```text
# <lens group> — <target>
## Findings
id (F-<group>-n) | title | severity (critical/high/medium/low) | violated requirement, claim, or brief decision | exact evidence | failure scenario or reproduction | impact | confidence | remaining uncertainty
...
## Hypotheses (no failure path yet)
- <concern> — <what evidence would make it a finding>
## Checks executed
- <command or action> → <result>
```

The coordinator renumbers to `F-nn` after deduplication.

## Code mode lens groups

1. **Behavior**: requirement and end-to-end compliance; algorithmic and state-machine correctness; boundary values, empty/null/malformed input, error handling. Shard by subsystem in the large tier.
2. **State and concurrency**: persistence, data integrity, idempotency, retries, partial failure; concurrency, ordering, cancellation, resource lifetime, leaks.
3. **Contracts and compatibility**: callers, downstream consumers, schemas, APIs, protocols; migrations, rollback, configuration, feature flags; performance, scaling, backpressure, unbounded work.
4. **Security and operability**: authn, authz, injection, secrets, privacy, abuse; observability, diagnostics, recovery; UX, accessibility, localization, platform differences when user-facing.
5. **Tests** (build review always; audit when tests exist): false-positive tests, missing assertions, unexercised production paths, checks that do not prove the brief's decisions.

Medium: groups 1 to 4 (audit) or 1, 3, 4, 5 (build review). Small: groups 1 and 3. Large: all, group 1 sharded.

## Document mode lens groups

1. **Accuracy**: every factual statement against the fact ledger; overstatement and omission; consistency with prior communications. Shard by section in the large tier.
2. **Fit**: completeness against purpose; audience fit and tone; structure and scannability.
3. **Readiness**: stakeholder and sensitivity review; actionability, links, owners, dates.

## Investigation mode lens groups

1. **Sufficiency**: answer covers every sub-question; scope and generalization; staleness of prior work relied on.
2. **Evidence**: evidence chain without gaps; reproduction from the written steps.
3. **Alternatives**: each competing hypothesis ruled out with evidence or listed open; recommendation quality when a decision is requested.

## Validator or reviewer brief template

Paste the finding format into the brief; the agent has not read this file.

```text
Read <absolute audit dir>/00-scope.md first, then <absolute audit dir>/<20-dossier.md|20-brief.md>, then the original sources. <Build: then the diff: `git diff <base>`.> Do not trust the dossier or brief; check it.
Lens group: <group name and its lenses> for a <mode> <audit|review> of <target>. <For a shard: the slice you own.>
Execute safe checks where they exist (tests, greps, link checks, reproductions). No edits, no destructive commands, no spawning agents.
Write your result to <absolute audit dir>/30-validation/<group>.md in exactly this format:
<paste the finding format>
Reply with: count of findings by severity and the single most important one.
```
