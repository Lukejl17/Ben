# Postmark inbound: Ben Support Desk

Support mail is separate from bill ingestion. **Do not change** the existing bills
Postmark server or its inbound webhook (`ben-email-in` worker).

| Pipe | Postmark server | Worker | Inbound domain |
|------|-----------------|--------|----------------|
| Bills | existing (bill attachments) | `ben-email-in` | `in.benandbill.app` |
| Support desk | **new:** Ben Support Desk | `ben-support-desk` | see below |

## Recommended approach: separate Postmark server

Postmark allows **one inbound message stream per server**, with **one custom inbound
domain per stream**. Domains are unique across the whole Postmark account.

`in.benandbill.app` is already on the bills server. You cannot attach the same
domain to a second server.

Create a second server named **Ben Support Desk** with its own inbound webhook and
secrets. Leave the bills server untouched.

### Inbound address options

**Preferred (no extra DNS): forward `support@benandbill.app` to the Postmark hash address**

Forward `support@benandbill.app` to the support server's default inbound address:

```
<InboundHash>@inbound.postmarkapp.com
```

Find **InboundHash** on Postmark → **Ben Support Desk** → **Message streams** →
**Inbound** → settings. No MX changes; bills keep using `in.benandbill.app`.

**Alternative (custom subdomain, if you want `support-desk@…` on your domain)**

Add a **new** subdomain only for support inbound, e.g. `desk-in.benandbill.app`:

1. MX: `desk-in` → priority `10` → `inbound.postmarkapp.com` (Cloudflare DNS).
2. Postmark → Ben Support Desk → Inbound stream → add inbound domain
   `desk-in.benandbill.app` and verify MX.
3. Use `support-desk@desk-in.benandbill.app` (or forward Gmail to that address).

Do **not** reuse `in.benandbill.app` on the support server; it stays on bills.

`support-desk@in.benandbill.app` only works if that address is received on the
**bills** server (same MX). That would hit the bills webhook, not support. Avoid.

## Webhook URL (support desk worker)

After deploy from `backend/support-desk` (see [SETUP.md](./SETUP.md)):

```
https://ben-support-desk.<account>.workers.dev/inbound?secret=<WEBHOOK_SECRET>
```

Replace `<account>` with your Cloudflare workers.dev subdomain.

Save `WEBHOOK_SECRET` locally as `.webhook-secret.local` (gitignored). Put the
same value in the Cloudflare worker secrets. Never commit it.

Paste the full webhook URL (including `?secret=…`) into Postmark → Ben Support Desk
→ Inbound stream → **Inbound webhook URL**.

## Postmark UI checklist

1. **Servers** → **Add server** → name: `Ben Support Desk`.
2. Open **Inbound** message stream → **Settings**.
3. Set **Inbound webhook URL** to the support worker URL above.
4. Choose inbound mail path:
   - Forward `support@benandbill.app` → `<InboundHash>@inbound.postmarkapp.com`, or
   - **Custom subdomain** → add `desk-in.benandbill.app` (or similar) + MX.
5. **Send test** on the inbound stream; worker should return `ok` (once deployed).
6. Copy the **Server API token** for outbound replies into the Cloudflare secret
   `POSTMARK_SERVER_TOKEN` (never commit).
7. Confirm the **bills** server inbound URL still points at `ben-email-in` only.

## Outbound (replies from Slack approve)

Support replies send from `support@benandbill.app` (`SUPPORT_FROM_EMAIL` in
`wrangler.toml`). That uses the support server's **Server API token**, not the
account token. Verify the From address is allowed on that server (sender signature).

## Local secrets (gitignored)

| File | Purpose |
|------|---------|
| `backend/support-desk/.webhook-secret.local` | `WEBHOOK_SECRET` for curl smoke tests |
| `backend/support-desk/.postmark-server-token.local` | Server API token (optional local copy) |

Do not reuse the bills inbound webhook secret for support.

## Smoke test (after deploy)

```bash
cd backend/support-desk
SECRET=$(cat .webhook-secret.local)
curl -s -X POST "https://ben-support-desk.<account>.workers.dev/inbound?secret=${SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"MessageID":"test-1","From":"user@example.com","FromName":"Test","Subject":"help","TextBody":"test","ToFull":[{"Email":"support@benandbill.app"}]}'
```

Expect `ok` once the worker is deployed.

## API setup (optional)

If you have an account API token in `.postmark-account-token.local` (gitignored),
run `backend/support-desk/scripts/postmark-setup-notes.sh`. It lists servers and
prints next steps without echoing tokens.

## Related

- Support worker config: `backend/support-desk/wrangler.toml`
- Playbooks: `docs/support-playbook/`
