# Research roles, tiers, and budgets

Every role is one agent with one question. Brief template at the end; `fork_turns: "none"` unless the role needs the conversation.

## Tiers and budgets

The tier is medium unless the user names another. On this runtime, invocations are wall-clock time: a wave of fresh-context agents takes about five minutes. Write the budget into `00-scope.md` and check in with the user before exceeding the invocation cap.

| Tier | Qualifies when | Audit: research / validators / skeptics / critics | Audit cap | Build: research / implementers / verifiers / reviewers / skeptics | Build cap |
|---|---|---|---|---|---|
| small | a single file, function, short document, or single question | contrarian + 2 / 2 / batched / 1 | 10 invocations | 2 incl. contrarian / 1–2 / 1 / 2 / batched | 8 |
| medium (default) | a module, feature, full document, or multi-part investigation | contrarian + 3 / 3–4 / batched / 2 | 18 invocations | 3–4 incl. contrarian / 3–6 / 2–3 / 3–4 / batched | 20 |
| large (only when the user says so) | cross-cutting or multi-system code, a long document with many claims, a high-stakes decision | every role / every lens group, primary group sharded / batched, 2 on critical / 2 rounds | 40 invocations | 2 waves / by ownership map / by check group / 4 / batched | 40 |

"Batched" skeptics: one per finding, three or four related items per skeptic brief; see `references/adversarial.md`. Follow-ups count as invocations when they cover a distinct roster entry. Wall-clock targets with a wave of three: small under 20 minutes, medium 30 to 45 minutes, large 60 to 90 minutes; with larger waves, proportionally less.

Sharding means several agents share a role or lens group but each owns a disjoint slice; record the slices in the roster.

## Code mode

- **Intent researcher**: requirements, tickets, design docs, README, comments, explicit user expectations. Output: requirement list with a source for each.
- **Architecture mapper**: entry points, callers, callees, state transitions, data flow, side effects, trust boundaries, external systems, with file:line anchors. Shard in the large tier.
- **History researcher**: relevant commits, blame, migrations, compatibility decisions, prior fixes and reverts.
- **Contract researcher**: version-matched primary documentation for frameworks, protocols, APIs, formats, dependencies. Fetch and read the source; do not rely on search snippets.
- **Test researcher**: what tests prove, what fixtures assume, missing behavioral coverage, whether tests exercise production paths.
- **Operations researcher**: deployment config, flags, observability, failure recovery, production constraints.
- **Threat and failure modeler**: misuse, partial failures, races, corrupt state, boundary values, hostile input.
- **Contrarian researcher** (always): assume the target, or the proposed design, is wrong or incomplete in a way the other roles will miss. Output: the strongest case against it, with evidence.

Medium audit default pick: intent, architecture, contracts, contrarian. Medium build default pick: architecture, contracts, contrarian, plus intent when requirements are not already explicit.

## Document mode

- **Purpose and audience researcher**: who reads this, what decision or action it drives, what the author has said about intent, what prior comparable documents looked like.
- **Fact researcher**: every factual claim the document makes or will make, each traced to a primary source. Flag claims with no source. Shard in the large tier.
- **History and context researcher**: earlier posts, decisions, and threads the document builds on or contradicts; what has already been announced or promised.
- **Stakeholder researcher**: teams, owners, and reviewers affected; sensitivities, approvals, embargoes, terminology conventions.
- **Style researcher**: the author's or org's prior artifacts of the same kind; extract the concrete conventions actually used, with examples.
- **Mechanism researcher**: how the thing the document describes actually works or was built, from code, diffs, configs, or data, so that every capability, limitation, and number is grounded in behavior.
- **Contrarian researcher** (always): find evidence that the central claim, framing, or timing is wrong, overstated, already known, or contested. Name the reader who would object and what they would cite.

Medium default pick: fact, mechanism, style, contrarian.

## Investigation mode

- **Question framer**: restate the question, the decision it feeds, and what a sufficient answer must contain, including implicit sub-questions.
- **Primary-evidence researcher**: logs, code, configs, data, reproductions. Shard in the large tier, one agent per sub-question.
- **Prior-work researcher**: earlier investigations, tickets, posts, or docs that already answered part of it, and whether their conclusions still hold.
- **Mechanism mapper**: how the system or process in question actually works end to end, with anchors.
- **Alternative-hypothesis researcher**: every competing explanation or option and what evidence would distinguish them.
- **Contrarian researcher** (always): assume the emerging answer is wrong. Find the evidence that would overturn it.

Medium default pick: primary evidence, mechanism, alternative hypotheses, contrarian.

## Evidence ledger format

```text
# <role> — <target>
## Ledger
claim | evidence (file:line, URL, command + output, quoted text) | confidence (high/med/low) | contradiction or uncertainty | implication for the brief or validation
...
## Sources read
- <path or URL> (version/date)
## Could not verify
- <what, why>
```

## Researcher brief template

Paste the format block above into the brief; the agent has not read this file.

```text
Read <absolute audit dir>/00-scope.md first for the target, mode, baseline, and what the user asked.
Role: <role name> for a <mode> <audit|build> of <target>.
Question you own: <one question>. <For a shard: the slice you own.>
Read: <paths, URLs, commands>. Read sources; do not rely on summaries.
Do not: edit files, run destructive commands, spawn agents, or research outside your question.
Write your result to <absolute audit dir>/10-research/<role>.md in exactly this format:
<paste the evidence ledger format>
Reply with three lines: what you found, the strongest contradiction, what remains unverified.
```
