# Research roles and tiers

Every role is one agent with one question. Give each a self-contained brief (template at the end) with `fork_turns: "none"` unless the role needs the conversation.

## Tiers

The tier is chosen in step 1 with a stated reason and recorded in `00-scope.md`. It fixes the roster; skeptic counts are derived per item and are never part of the tier.

| Tier | Qualifies when | Research roster | Validation roster | Gap rounds |
|---|---|---|---|---|
| small | a single file, function, short document, or single question | contrarian + 2 roles chosen for the target | 4 lenses chosen for the target | at least 1 |
| medium (default) | a module, feature, full document, or multi-part investigation | every role for the mode | every lens for the mode | at least 2 |
| large | cross-cutting or multi-system code, a long document with many claims, or a high-stakes decision | every role, with the primary-evidence role sharded (one agent per subsystem, section group, or sub-question) | every lens, with the primary lens sharded the same way | at least 2 |

Sharding means several agents share a lens or role but each owns a disjoint slice; record the slices in the roster. With three agents per wave, a medium code audit is roughly 3 research waves, 4 validation waves, and as many verification waves as the items require. That is expected. Run more waves rather than fewer agents.

Per-mode counts of defined roles and lenses: code 8 roles and 12 lenses; document 7 roles and 8 lenses; investigation 6 roles and 7 lenses.

## Code mode

- **Intent researcher**: requirements, tickets, design docs, README, comments, explicit user expectations. Output: requirement list with a source for each.
- **Architecture mapper**: entry points, callers, callees, state transitions, data flow, side effects, trust boundaries, external systems. Output: map with file:line anchors. Shard this role in the large tier.
- **History researcher**: relevant commits, blame, migrations, compatibility decisions, prior fixes and reverts.
- **Contract researcher**: version-matched primary documentation for frameworks, protocols, APIs, formats, dependencies. Fetch and read the source; do not rely on search snippets.
- **Test researcher**: what tests prove, what fixtures assume, missing behavioral coverage, whether tests exercise production paths.
- **Operations researcher**: deployment config, flags, observability, failure recovery, production constraints. Omit only with a reason in the roster.
- **Threat and failure modeler**: misuse, partial failures, races, corrupt state, boundary values, hostile input.
- **Contrarian researcher** (always): assume the implementation is wrong or incomplete in a way the other roles will miss. Look for the requirement nobody wrote down, the caller nobody mapped, the doc version nobody checked. Output: the strongest case against the target, with evidence.

## Document mode

- **Purpose and audience researcher**: who reads this, what decision or action it drives, what the author has said about intent, what prior comparable documents looked like.
- **Fact researcher**: every factual claim the document makes or will make, each traced to a primary source: code, commit, diff, dashboard, wiki, post, ticket, or named person. Flag claims with no source. Shard this role in the large tier.
- **History and context researcher**: earlier posts, decisions, and threads the document builds on or contradicts; what has already been announced or promised.
- **Stakeholder researcher**: teams, owners, and reviewers affected; sensitivities, approvals, embargoes, naming and terminology conventions.
- **Style researcher**: the author's or org's prior artifacts of the same kind; extract the concrete conventions actually used, with examples.
- **Mechanism researcher**: how the thing the document describes actually works or was built, from code, diffs, configs, or data, so that every capability, limitation, and number in the document is grounded in behavior rather than in earlier prose about it.
- **Contrarian researcher** (always): find evidence that the document's central claim, framing, or timing is wrong, overstated, already known, or contested. Name the reader who would object and what they would cite.

## Investigation mode

- **Question framer**: restate the question, the decision it feeds, and what a sufficient answer must contain. Identify implicit sub-questions.
- **Primary-evidence researcher**: logs, code, configs, data, reproductions; whatever directly answers the question. Shard this role in the large tier, one agent per sub-question.
- **Prior-work researcher**: earlier investigations, tickets, posts, or docs that already answered part of it, and whether their conclusions still hold.
- **Mechanism mapper**: how the system or process in question actually works end to end, with anchors.
- **Alternative-hypothesis researcher**: list every competing explanation or option and what evidence would distinguish them.
- **Contrarian researcher** (always): assume the emerging answer is wrong. Find the evidence that would overturn it.

## Evidence ledger format

Every researcher writes this to its result file:

```text
# <role> — <target>
## Ledger
claim | evidence (file:line, URL, command + output, quoted text) | confidence (high/med/low) | contradiction or uncertainty | validation implication
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
Role: <role name> for a <mode> audit of <target>.
Question you own: <one question>. <For a shard: the slice you own.>
Read: <paths, URLs, commands>. Read sources; do not rely on summaries.
Do not: edit files, run destructive commands, spawn agents, or research outside your question.
Write your result to <absolute audit dir>/10-research/<role>.md in exactly this format:
<paste the evidence ledger format>
Reply with three lines: what you found, the strongest contradiction, what remains unverified.
```
