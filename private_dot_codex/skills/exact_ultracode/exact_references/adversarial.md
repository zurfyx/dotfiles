# Adversarial verification

Skeptics exist to refute. They are spawned fresh (`fork_turns: "none"`), never reused from a role that produced the item, and receive only the items under test, their evidence files, and the sources. Never give a skeptic the coordinator's opinion.

## What gets verified

1. Every deduplicated finding `F-nn`, in both workflows.
2. Material research claims `C-nn`, **document mode only**. A claim is material when it will appear in the deliverable and contains a number, a date, a name or attribution, a causal assertion, a commitment, or is the headline point. The coordinator lists them in the dossier with the ledger row each came from.

Design decisions in a build are not verified by skeptics; they are verified by the implementation passing its checks.

## Budget

| Item | Skeptics |
|---|---|
| any finding or claim | 1, briefed with every angle for the mode |
| critical finding | 2, second one on a different angle first |
| a split verdict (REFUTED against CONFIRMED on the same item) | 1 tie-breaker, briefed on the disputed premise only |

**Batching.** One skeptic brief carries three or four related items (same file, same subsystem, same section). The skeptic reads the sources once and verifies each item in turn. A brief never mixes an item with one that depends on it.

## Angles (all go into each brief)

**Code**: (a) re-derive from the source and the stated requirement; (b) build a reproduction or a counter-example; (c) check the requirement or contract the item assumes against its primary documentation.

**Document**: (a) does the cited source actually assert this, at this strength, in this context; (b) is it stale or superseded: find the later artifact, decision, or number; (c) identify the stakeholder or reader who would dispute it and what they would cite.

**Investigation**: (a) re-derive from the primary evidence; (b) steelman the strongest competing hypothesis and argue that it beats the answer; (c) re-run the written reproduction from a cold start and report where the steps fail.

## Verdict format (one block per item)

```text
item: <F-nn or C-nn> — <title or claim>
verdict: CONFIRMED | REFUTED | UNVERIFIED
strongest refutation attempt: <which angle, what was checked>
evidence: <exact file:line, output, quote, or URL>
confidence: high | medium | low
what would change the verdict: <one line>
```

## Skeptic brief template

```text
Assume every item below is WRONG. Your job is to refute each one.
Read <absolute audit dir>/00-scope.md first for the target and mode.
Items:
  <F-nn> — <title>; evidence file <absolute path> (section or row)
  <F-nn> — ...
Sources: <paths, URLs, commands>
Angles to try on each item: <paste the three angles for the mode>
Rules: read the original sources; do not accept the evidence file's reading of them. Run safe, read-only checks. No edits, no destructive commands, no state mutation in the shared working directory, no spawning agents.
Write your result to <absolute audit dir>/40-verification/<batch id>.md, one verdict block per item, in exactly this format:
<paste the verdict format>
Reply with one verdict line per item.
```

## Verdict rules

- `REFUTED` requires positive evidence that the item is wrong. Failure to reproduce, missing access, a tool error, or ambiguity is `UNVERIFIED`.
- A finding is reported only when its skeptic confirmed it with evidence. `UNVERIFIED` findings go to "unverified risks". A `REFUTED` finding is dropped, with the refutation kept in the file.
- A critical finding with a split between its two skeptics gets the tie-breaker; the tie-breaker's verdict is final.
- A `REFUTED` claim is removed from the dossier and from any draft that used it; an `UNVERIFIED` claim stays only with that label.
- Record what the skeptic actually checked. Agreement without independent evidence counts once.
