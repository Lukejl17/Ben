# Lola → Engineer handoff

Lola posts this block in the Slack thread when a ticket needs a code change. Engineer ignores support chatter that does not include it.

```text
ENGINEER_HANDOFF
severity: P0 | P1 | P2 | P3
user_impact: <one sentence>
repro: <steps, or "not reproduced, inferred from …">
expected:
actual:
lola_hypothesis: <file or area if known>
evidence: <screenshots / logs already in the thread>
do_not: <HUMAN_TODO items, credentials, anything out of scope>
```

Post it only as the last block of an escalation. Do not use the words `ENGINEER_HANDOFF` in ordinary support replies.

## Channels

| Channel | Purpose |
|---|---|
| `#ben-support` (Ben Support bot) | Email tickets: Approve / Reject customer replies |
| Cursor intake `C0C0CAR1P9S` | Lola asks Engineer to write a PR |

Those are different bots. Approving a customer email is not an Engineer handoff.

## Engineer response

1. Re-read the whole thread, including images.
2. Investigate in `github.com/Lukejl17/Ben`.
3. Fix, test, open a PR.
4. Reply in the same thread starting with `Engineer · Ben`. Do not paste the PR URL (Cursor attaches it).
