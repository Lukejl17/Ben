# Ben support desk backend

Support email triage: Postmark inbound → D1 ticket → playbook draft → Slack
approval → Postmark outbound reply.

**Not** the bills inbound worker (`ben-email-in`). This uses worker name
`ben-support-desk`, its own D1 database `ben-support-tickets`, and its own
`WEBHOOK_SECRET`. Do not point bills Postmark inbound at this worker.

## Endpoints

| Route | Auth | Purpose |
|-------|------|---------|
| `GET /health` | none | liveness check |
| `POST /inbound?secret=…` | `WEBHOOK_SECRET` | Postmark inbound → ticket + Slack |
| `POST /slack/interactions` | Slack signing secret | Approve / Reject / Send to Engineer |

## Docs

- [docs/support/SETUP.md](../../docs/support/SETUP.md): deploy, secrets, Postmark
- [docs/support/SLACK.md](../../docs/support/SLACK.md): Slack app checklist
- [docs/support/ENGINEER.md](../../docs/support/ENGINEER.md): Lola → Engineer handoff
- [docs/support/POSTMARK.md](../../docs/support/POSTMARK.md): inbound server setup
- [docs/support-playbook/](../../docs/support-playbook/): reply templates

## Tests

```bash
npm test
```

Playbook matching, Slack HMAC, inbound and Approve/Reject/handoff behaviour.
