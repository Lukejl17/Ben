# Slack app for Ben support desk

The support desk worker posts each inbound email to a Slack channel with
**Approve** and **Reject** buttons. Approving sends the playbook draft via
Postmark; rejecting marks the ticket dismissed.

## Create the Slack app

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**.
2. Name: `Ben Support` (or similar). Workspace: your team workspace.

## Bot token scopes

Under **OAuth & Permissions** → **Bot Token Scopes**, add:

| Scope | Why |
|-------|-----|
| `chat:write` | Post ticket messages and update after Approve/Reject |

Install the app to the workspace and copy the **Bot User OAuth Token**
(`xoxb-…`). Store as `SLACK_BOT_TOKEN`:

```bash
cd backend/support-desk
npx wrangler secret put SLACK_BOT_TOKEN
```

## Signing secret

Under **Basic Information** → **App Credentials**, copy **Signing Secret**.
Store as `SLACK_SIGNING_SECRET`:

```bash
npx wrangler secret put SLACK_SIGNING_SECRET
```

## Interactive components URL

Under **Interactivity & Shortcuts**:

1. Turn **Interactivity** on.
2. **Request URL**:

   ```
   https://<worker-url>/slack/interactions
   ```

   Use your deployed `ben-support-desk` workers.dev URL (or custom domain).

Slack POSTs `application/x-www-form-urlencoded` with a `payload` field when
someone clicks Approve or Reject. The worker verifies `X-Slack-Signature` before
acting.

## Channel

1. Create `#ben-support` (or use an existing private channel).
2. Invite the bot: `/invite @Ben Support`
3. Copy the channel ID (right-click channel → **View channel details** → scroll
   to the ID, or use Slack's channel list API).

Store as `SLACK_CHANNEL_ID`:

```bash
npx wrangler secret put SLACK_CHANNEL_ID
```

## Message flow

1. Customer emails `support@benandbill.app`.
2. Postmark webhooks the worker → playbook match → D1 row `pending`.
3. Bot posts to `#ben-support` with inbound preview and draft reply.
4. Human clicks:
   - **Approve** → Postmark sends `draft_subject` / `draft_body` to customer; ticket → `sent`; Slack message updated.
   - **Reject** → ticket → `dismissed`; Slack message updated (no email sent).

## Troubleshooting

| Symptom | Check |
|---------|-------|
| No Slack message | `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`; bot invited to channel |
| Buttons do nothing | Interactivity URL points at deployed worker; `SLACK_SIGNING_SECRET` matches app |
| Approve fails | `POSTMARK_SERVER_TOKEN`; `support@benandbill.app` verified as sender in Postmark |
| `invalid signature` | Clock skew; signing secret mismatch; body modified before verify |

## Security notes

- Never commit tokens. Use wrangler secrets and local `*.local` files.
- Only `pending` tickets accept Approve/Reject; duplicate clicks are ignored after status changes.
- Slack signature verification rejects requests older than five minutes.
