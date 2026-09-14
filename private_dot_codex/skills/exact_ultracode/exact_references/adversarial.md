# Adversarial verification

Skeptics exist to refute. They are spawned fresh (`fork_turns: "none"`), never reused from another role, and receive only the item under test, its evidence file, and the sources. Never give a skeptic the coordinator's opinion.

## What gets verified

1. Every deduplicated finding (`F-nn`).
2. Every material research claim (`C-nn`). A claim is material when it will appear in the deliverable and contains a number, a date, a name or attribution, a causal assertion, a commitment, or is the headline point. Everything else is context and is not verified individually. The coordinator lists the `C-` claims in `20-dossier.md` with the ledger row each came from.

## Skeptics per item

| Item | Skeptics |
|---|---|
| critical or high severity finding, or a headline claim | 3 |
| medium or low finding, or an ordinary material claim | 2 |
| low finding with a deterministic reproduction | 1 |

Give each skeptic on the same item a different angle from the mode's menu. With fewer skeptics than angles, use the angles in the order listed.

**Code angles**: (a) re-derive from the source and the stated requirement; (b) build a reproduction or a counter-example; (c) check the requirement or contract the item assumes against its primary documentation.

**Document angles**: (a) does the cited source actually assert this, at this strength, in this context; (b) is it stale or superseded: find the later artifact, decision, or number; (c) identify the stakeholder or reader who would dispute it and what they would cite.

**Investigation angles**: (a) re-derive from the primary evidence; (b) steelman the strongest competing hypothesis from the alternative-hypothesis ledger and argue that it beats the answer; (c) re-run the written reproduction or observation from a cold start and report where the steps fail.

## Verdict format

```text
item: <F-nn or C-nn> — <title or claim>
angle: <a|b|c>
verdict: CONFIRMED | REFUTED | UNVERIFIED
evidence: <exact file:line, output, quote, or URL>
confidence: high | medium | low
what would change the verdict: <one line>
```

## Skeptic brief template

```text
Assume the following item is WRONG. Your job is to refute it.
Read <absolute audit dir>/00-scope.md first for the target and mode.
Item: <F-nn or C-nn> — <title or claim>
Evidence file: <absolute path> (section or ledger row)
Sources: <paths, URLs, commands>
Angle: <one angle from the mode menu, spelled out>
Rules: read the original sources; do not accept the evidence file's reading of them. Run safe, read-only checks. No edits, no destructive commands, no state mutation in the shared working directory, no spawning agents.
Write your result to <absolute audit dir>/40-verification/<item id>-skeptic-<n>.md in exactly this format:
<paste the verdict format>
Reply with the verdict line only.
```

## Verdict precedence

- `REFUTED` requires positive evidence that the item is wrong. Failure to reproduce, missing access, a tool error, or ambiguity is `UNVERIFIED`.
- A single `REFUTED` does not kill an item; it triggers a tie-breaker skeptic briefed on the exact disputed premise, not the whole item.
- An item is dropped when the tie-breaker refutes it, or when no skeptic confirms it with evidence. A finding that ends `UNVERIFIED` moves to "unverified risks"; a claim that ends `UNVERIFIED` stays in the deliverable only with that label.
- A `REFUTED` claim is removed from the dossier and from any draft that used it.
- Record what each skeptic actually checked. Agreement without independent evidence counts once.
