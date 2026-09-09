# Slack app for Ben support desk

The support desk worker posts each inbound email to `#ben-support` with
**Approve**, **Reject**, and **Send to Engineer** buttons. Approving sends the
playbook draft via Postmark; rejecting marks the ticket dismissed; Send to
Engineer posts `ENGINEER_HANDOFF` to `#ben-engineering-support-tickets`.

Bug-report playbooks also auto-post that handoff on inbound (no button click).

## Create the Slack app

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**.
2. Name: `Ben Support` (or similar). Workspace: your team workspace.

## Bot token scopes

Under **OAuth & Permissions** → **Bot Token Scopes**, add:

| Scope | Why |
|-------|-----|
| `chat:write` | Post ticket messages, Engineer handoffs, and updates after Approve/Reject |

Install the app to the workspace and copy the **Bot User OAuth Token**
(`xoxb-…`). Store as Cloudflare secret `SLACK_BOT_TOKEN` (dashboard or
`npx wrangler secret put SLACK_BOT_TOKEN`). Never commit it.

## Signing secret

Under **Basic Information** → **App Credentials**, copy **Signing Secret**.
Store as Cloudflare secret `SLACK_SIGNING_SECRET`. Never commit it.

## Interactive components URL

Under **Interactivity & Shortcuts**:

1. Turn **Interactivity** on.
2. **Request URL**:

   ```
   https://<worker-url>/slack/interactions
   ```

   Use your deployed `ben-support-desk` workers.dev URL (or custom domain).

Slack POSTs `application/x-www-form-urlencoded` with a `payload` field when
someone clicks Approve, Reject, or Send to Engineer. The worker verifies
`X-Slack-Signature` before acting.

## Channel

1. Create `#ben-support` (or use an existing private channel).
2. Invite the bot: `/invite @Ben Support`
3. The channel ID for `#ben-support` is already `C0BV6LP1X8F` in
   `wrangler.toml` `[vars]` (`SLACK_CHANNEL_ID`). Change that var only if the
   channel is recreated.

4. Invite the same bot to **`#ben-engineering-support-tickets`** (`C0C0CAR1P9S`).
   `ENGINEER_CHANNEL_ID` is already set in `wrangler.toml` `[vars]`. Handoffs
   fail with `not_in_channel` until the bot is a member.

## Message flow

1. Customer emails `support@benandbill.app`.
2. Postmark webhooks the worker → playbook match → D1 row `pending`.
3. Bot posts to `#ben-support` with inbound preview and draft reply.
4. If the playbook has `escalate_to_engineer: true` (bug-report), the bot also
   posts `ENGINEER_HANDOFF` to `#ben-engineering-support-tickets`. Do not
   `@Cursor` in that post; Kit is already subscribed.
5. Human clicks:
   - **Approve** → Postmark sends `draft_subject` / `draft_body` to customer; ticket → `sent`; Slack message updated.
   - **Reject** → ticket → `dismissed`; Slack message updated (no email sent).
   - **Send to Engineer** → same `ENGINEER_HANDOFF` post (idempotent if already sent).

## Troubleshooting

| Symptom | Check |
|---------|-------|
| No Slack message | `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`; bot invited to channel |
| Engineer never wakes | Invite `@Ben Support` to `#ben-engineering-support-tickets`; look for `ENGINEER_HANDOFF` |
| Buttons do nothing | Interactivity URL points at deployed worker; `SLACK_SIGNING_SECRET` matches app |
| Approve fails | `POSTMARK_SERVER_TOKEN`; `support@benandbill.app` verified as sender in Postmark |
| `invalid signature` | Clock skew; signing secret mismatch; body modified before verify |

## Security notes

- Never commit tokens. Use wrangler secrets and local `*.local` files.
- Only `pending` tickets accept Approve/Reject; duplicate clicks are ignored after status changes.
- Slack signature verification rejects requests older than five minutes.
