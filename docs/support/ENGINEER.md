# Lola → Engineer

Lola (support-desk worker) posts this block to `#ben-engineering-support-tickets`
when a ticket needs a code change. Engineer is subscribed to that channel and
ignores messages that do not contain `ENGINEER_HANDOFF`.

Do **not** `@cursor` in the handoff. That would start a second agent.

```text
ENGINEER_HANDOFF
severity: P0 | P1 | P2 | P3
ticket: <id>
user_impact: <one sentence>
repro: <steps, or "not reproduced, inferred from …">
expected:
actual:
lola_hypothesis: <playbook or file>
evidence: <inbound email>
do_not: HUMAN_TODO credential work
```

## When it fires

| Path | Severity |
|---|---|
| Playbook `bug-report` (`escalate_to_engineer: true`) on inbound | P1 |
| Slack button **Send to Engineer** | P2 |

Duplicate clicks are ignored once `engineer_message_ts` is stored.

## Engineer

Reply in the same Slack thread, signature `Engineer · Ben`. Push a PR. Do not merge.
Cloud Linux VMs cannot run Xcode; say so if tests could not run.

Standing listener: Cloud Agent conversation subscribed to `C0C0CAR1P9S`.
If that subscription expires, recreate it or add a Cursor automation filtered
on `ENGINEER_HANDOFF` against repo `Lukejl17/Ben`.
