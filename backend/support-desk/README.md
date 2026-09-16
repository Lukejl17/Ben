# Ben support desk backend

Support email triage: Postmark inbound → D1 ticket → playbook draft → Slack
approval → Postmark outbound reply.

**Not** the bill email-in worker (`backend/email-in`). This uses
`ben-support-desk`, `support-desk@in.benandbill.app`, and its own `WEBHOOK_SECRET`.

## Endpoints

| Route | Auth | Purpose |
|-------|------|---------|
| `GET /health` | none | liveness check |
| `POST /inbound?secret=…` | `WEBHOOK_SECRET` | Postmark inbound → ticket + Slack |
| `POST /slack/interactions` | Slack signing secret | Approve / Reject / Send to Engineer |

## Docs

- [docs/support/SETUP.md](../../docs/support/SETUP.md) — deploy, secrets, Postmark
- [docs/support/SLACK.md](../../docs/support/SLACK.md) — Slack app checklist
- [docs/support/ENGINEER.md](../../docs/support/ENGINEER.md) — Lola → Engineer handoff
- [docs/support/POSTMARK.md](../../docs/support/POSTMARK.md) — inbound server setup
- [docs/support-playbook/](../../docs/support-playbook/) — reply templates

## Tests

```bash
npm test
```

Pure playbook matching, draft rendering, and Engineer handoff text.
