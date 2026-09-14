# Validation lenses

Assign each validator one lens (or one shard of a lens). Every validator gets the dossier path and the original sources. Findings go to `30-validation/<lens>.md`. Each finding needs a concrete failure path; otherwise it is recorded under "hypotheses" for the gap loop.

## Finding format

```text
# <lens> — <target>
## Findings
id (F-nn) | title | severity (critical/high/medium/low) | violated requirement or claim | exact evidence | failure scenario or reproduction | impact | confidence | remaining uncertainty
...
## Hypotheses (no failure path yet)
- <concern> — <what evidence would make it a finding>
## Checks executed
- <command or action> → <result>
```

Ids are assigned by the coordinator after deduplication; validators number findings `F-<lens-abbrev>-n` and the coordinator renumbers.

## Code mode (12 lenses)

- requirement and end-to-end behavior compliance (shard by subsystem in the large tier)
- algorithmic and state-machine correctness
- boundary values, empty/null/malformed input, error handling
- persistence, data integrity, idempotency, retries, partial failure
- concurrency, ordering, cancellation, resource lifetime, leaks
- authn, authz, injection, secrets, privacy, abuse cases
- callers, downstream consumers, schemas, APIs, protocols, integration contracts
- compatibility, migrations, rollback, configuration, feature flags
- performance, scaling, backpressure, unbounded work
- UX, accessibility, localization, platform differences (for user-facing targets; otherwise omit with a reason in the roster)
- observability, diagnostics, operability, recovery
- test quality: false-positive tests, missing assertions, unexercised production paths

## Document mode (8 lenses)

- **Claim accuracy** (shard by section in the large tier): every factual statement against the fact ledger; anything unsupported is a finding.
- **Completeness against purpose**: what the target reader needs to act or decide that is missing.
- **Consistency with prior communications**: contradictions with earlier posts, promises, names, dates, numbers.
- **Audience fit and tone**: matches the conventions the style researcher extracted; reading level; length.
- **Overstatement and omission**: claims stronger than the evidence, benefits without caveats, risks or limitations left out.
- **Stakeholder and sensitivity review**: attributions, credits, embargoes, terminology, anything a named team would object to.
- **Actionability**: next steps, links, owners, dates are present and correct; every link resolves.
- **Structure and scannability**: the headline carries the point; sections in the order the reader needs.

## Investigation mode (7 lenses)

- **Answer sufficiency** (shard by sub-question in the large tier): does the answer cover every sub-question the framer identified.
- **Evidence chain**: each conclusion traces to primary evidence without a gap; inference is labeled.
- **Alternative hypotheses**: each competitor from the research phase is explicitly ruled out with evidence, or listed as open.
- **Reproduction**: the key claim can be reproduced or observed by an independent agent following the written steps.
- **Scope and generalization**: the answer does not overreach beyond what was tested or observed.
- **Recommendation quality** (when a decision is requested; otherwise omit with a reason): options, tradeoffs, reversibility, what would change the recommendation.
- **Staleness**: prior-work conclusions relied on are still true in the current state.

## Validator brief template

Paste the finding format into the brief; the agent has not read this file.

```text
Read <absolute audit dir>/00-scope.md first, then <absolute audit dir>/20-dossier.md, then the original sources the dossier cites. Do not trust the dossier; check it.
Lens: <lens> for a <mode> audit of <target>. <For a shard: the slice you own.>
Execute safe checks where they exist (tests, greps, link checks, reproductions). No edits, no destructive commands, no spawning agents.
Write your result to <absolute audit dir>/30-validation/<lens>.md in exactly this format:
<paste the finding format>
Reply with: count of findings by severity and the single most important one.
```
