#!/usr/bin/env bash
# Postmark setup helper for Ben Support Desk.
# Safe to run: never prints full API tokens.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACCOUNT_TOKEN_FILE="${ROOT}/.postmark-account-token.local"
SERVER_TOKEN_FILE="${ROOT}/.postmark-server-token.local"
WEBHOOK_SECRET_FILE="${ROOT}/.webhook-secret.local"
WORKER_SUBDOMAIN="${WORKER_SUBDOMAIN:-luke-9e7}"
WORKER_NAME="ben-support-desk"
SUPPORT_SERVER_NAME="Ben Support Desk"

redact() {
  local v="$1"
  if [[ ${#v} -le 8 ]]; then
    echo "(set)"
  else
    echo "${v:0:4}…${v: -4}"
  fi
}

echo "=== Ben Support Desk: Postmark setup notes ==="
echo ""
echo "Docs: docs/support/POSTMARK.md"
echo ""
echo "--- Do not touch bills pipe ---"
echo "  Server: existing bills server"
echo "  Domain: in.benandbill.app"
echo "  Webhook: ben-email-in worker (do not change that server)"
echo ""

if [[ -f "${WEBHOOK_SECRET_FILE}" ]]; then
  echo "WEBHOOK_SECRET local file: present ($(redact "$(cat "${WEBHOOK_SECRET_FILE}")"))"
else
  echo "WEBHOOK_SECRET local file: missing"
  echo "  Run: openssl rand -hex 32 | tee ${WEBHOOK_SECRET_FILE}"
  echo "  Then: cd ${ROOT} && npx wrangler secret put WEBHOOK_SECRET"
fi
echo ""

WEBHOOK_URL="https://${WORKER_NAME}.${WORKER_SUBDOMAIN}.workers.dev/inbound?secret=<WEBHOOK_SECRET>"
echo "--- Support inbound webhook (paste into Postmark UI) ---"
echo "  ${WEBHOOK_URL}"
echo ""

echo "--- Postmark UI checklist ---"
echo "  1. Add server: ${SUPPORT_SERVER_NAME}"
echo "  2. Inbound stream → Settings → set webhook URL above (with real secret)"
echo "  3. Gmail: forward support@benandbill.app → <InboundHash>@inbound.postmarkapp.com"
echo "     (or use desk-in.benandbill.app; see docs/support/POSTMARK.md)"
echo "  4. Send test on inbound stream"
echo "  5. wrangler secret put POSTMARK_SERVER_TOKEN (server token from new server)"
echo "  6. Confirm bills server inbound URL unchanged"
echo ""

if [[ ! -f "${ACCOUNT_TOKEN_FILE}" ]]; then
  echo "No ${ACCOUNT_TOKEN_FILE}; skipping Postmark API calls."
  echo "To enable API listing, save your Postmark *account* API token there (gitignored)."
  exit 0
fi

ACCOUNT_TOKEN="$(tr -d '[:space:]' < "${ACCOUNT_TOKEN_FILE}")"
echo "--- Postmark API (account token $(redact "${ACCOUNT_TOKEN}")) ---"

list_servers() {
  curl -sf "https://api.postmarkapp.com/servers?count=50&offset=0" \
    -H "Accept: application/json" \
    -H "X-Postmark-Account-Token: ${ACCOUNT_TOKEN}"
}

if ! SERVERS_JSON="$(list_servers 2>&1)"; then
  echo "Failed to list servers (check account token)."
  exit 1
fi

echo "Servers:"
python3 - <<'PY' "${SERVERS_JSON}"
import json, sys
data = json.loads(sys.argv[1])
for s in data.get("Servers", []):
    domain = s.get("InboundDomain") or "(none)"
    hook = s.get("InboundHookUrl") or "(none)"
    print(f"  - [{s.get('ID')}] {s.get('Name')}")
    print(f"      InboundDomain: {domain}")
    print(f"      InboundHookUrl: {hook[:60]}{'…' if len(hook) > 60 else ''}")
    if s.get("InboundHash"):
        print(f"      InboundHash address: {s['InboundHash']}@inbound.postmarkapp.com")
PY

SUPPORT_ID="$(python3 - <<'PY' "${SERVERS_JSON}" "${SUPPORT_SERVER_NAME}"
import json, sys
data = json.loads(sys.argv[1])
name = sys.argv[2]
for s in data.get("Servers", []):
    if s.get("Name") == name:
        print(s["ID"])
        break
PY
)"

if [[ -z "${SUPPORT_ID}" ]]; then
  echo ""
  echo "Server '${SUPPORT_SERVER_NAME}' not found."
  echo "Create it in Postmark UI, or POST manually:"
  echo "  curl -X POST https://api.postmarkapp.com/servers \\"
  echo "    -H 'X-Postmark-Account-Token: <account-token>' \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"Name\":\"${SUPPORT_SERVER_NAME}\",\"Color\":\"blue\"}'"
else
  echo ""
  echo "Found '${SUPPORT_SERVER_NAME}' (id ${SUPPORT_ID}). Set InboundHookUrl via UI or:"
  echo "  curl -X PUT https://api.postmarkapp.com/servers/${SUPPORT_ID} \\"
  echo "    -H 'X-Postmark-Account-Token: <account-token>' \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"InboundHookUrl\":\"<full-webhook-url-with-secret>\"}'"
fi

if [[ -f "${SERVER_TOKEN_FILE}" ]]; then
  echo ""
  echo "Server token file present ($(redact "$(cat "${SERVER_TOKEN_FILE}")")); use for POSTMARK_SERVER_TOKEN secret."
fi
