# Ben support desk — Slack-approved replies from support@benandbill.app
#
# Customers → Google Workspace support@ → forward copy to Postmark
# → this Worker drafts from the playbook → Slack #ben-support
# → Approve sends via Postmark From support@; Reject sends nothing.
# Approved novel/edited replies upsert into D1 playbook (Phase 2).

## Layout

| Path | Role |
|------|------|
| `src/worker.js` | Routes: `/inbound`, `/slack/interactions`, cron digest |
| `src/draft.js` | Playbook match + draft (pure; unit-tested) |
| `src/mail.js` | Postmark parse/send |
| `src/slack.js` | Block Kit + signature verify |
| `schema.sql` | D1 tickets + playbook_entries |

Human setup checklist: [docs/support/SETUP.md](../../docs/support/SETUP.md).
Seed copy: [docs/support-playbook/](../../docs/support-playbook/).

## Deploy

```bash
cd backend/support-desk
npx wrangler d1 create ben-support
# paste database_id into wrangler.toml
npx wrangler d1 execute ben-support --file=./schema.sql --remote
npx wrangler secret put WEBHOOK_SECRET
npx wrangler secret put SLACK_BOT_TOKEN
npx wrangler secret put SLACK_SIGNING_SECRET
npx wrangler secret put POSTMARK_SERVER_TOKEN
npx wrangler deploy
```

Set `SLACK_CHANNEL_ID` as a Worker var (dashboard or `[vars]`).

Postmark inbound webhook:

```
https://ben-support-desk.<your-subdomain>.workers.dev/inbound?secret=<WEBHOOK_SECRET>
```

Slack Interactivity Request URL:

```
https://ben-support-desk.<your-subdomain>.workers.dev/slack/interactions
```

## Local tests

```bash
node --test src/draft.test.js
```

## Edit flow

In the Slack thread, reply:

```
edit: Thanks for writing in.

Here’s the corrected reply…

— Ben Support
```

Then press **Approve & send**.
