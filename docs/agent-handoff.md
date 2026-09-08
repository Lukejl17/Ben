# Lola → Engineer handoff

Lola posts this block when a ticket needs a code change. Engineer ignores
support chatter that does not include it. Do not `@cursor` in the handoff;
Engineer is already subscribed to the intake channel.

```text
ENGINEER_HANDOFF
severity: P0 | P1 | P2 | P3
ticket: <id>
user_impact: <one sentence>
repro: <steps, or "not reproduced, inferred from …">
expected:
actual:
lola_hypothesis: <file or area if known>
evidence: <screenshots / logs already in the thread>
do_not: <HUMAN_TODO items, credentials, anything out of scope>
```

## Channels

| Channel | Purpose |
|---|---|
| `#ben-support` (Ben Support bot) | Email tickets: Approve / Reject / Send to Engineer |
| `#ben-engineering-support-tickets` (`C0C0CAR1P9S`) | Lola posts `ENGINEER_HANDOFF`; Engineer writes the PR |

Those are different bots. Approving a customer email is not an Engineer handoff.

## How Lola fires it

On the support-desk worker (see PR stack on `copy/no-em-dashes`):

- Playbook `bug-report` auto-posts to the Engineer channel (P1)
- **Send to Engineer** on any ticket (P2)
- Duplicate posts are stored on the D1 ticket and skipped

## Engineer response

1. Re-read the whole thread, including images.
2. Investigate in `github.com/Lukejl17/Ben`.
3. Fix, test, open a PR. Cloud Linux VMs cannot run Xcode; say so if you could not build.
4. Reply in the same Slack thread starting with `Engineer · Ben`. Do not paste the PR URL (Cursor attaches it).
5. Do not merge.
