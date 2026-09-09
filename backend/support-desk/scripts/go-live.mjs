#!/usr/bin/env node
// Create D1, apply schema, deploy ben-support-desk.
// Never writes secrets. Never touches ben-email-in (bills inbound).
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const PLACEHOLDER = "00000000-0000-0000-0000-000000000000";
const DB_NAME = "ben-support-tickets";

function wrangler(args, { allowFail = false } = {}) {
  const result = spawnSync("npx", ["--yes", "wrangler", ...args], {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0 && !allowFail) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
  return result;
}

const whoami = wrangler(["whoami"], { allowFail: true });
if (whoami.status !== 0) {
  console.error("Wrangler is not logged in. Cannot create D1 or deploy from this machine.");
  console.error("Dashboard steps: docs/support/SETUP.md (What still needs a login).");
  process.exit(2);
}

spawnSync(process.execPath, [join(root, "scripts", "sync-playbooks.js")], {
  cwd: root,
  stdio: "inherit",
});

const tomlPath = join(root, "wrangler.toml");
let toml = readFileSync(tomlPath, "utf8");
let databaseId = toml.match(/database_id\s*=\s*"([^"]+)"/)?.[1];

if (!databaseId || databaseId === PLACEHOLDER) {
  console.log(`Creating or locating D1 database ${DB_NAME}...`);
  const created = wrangler(["d1", "create", DB_NAME], { allowFail: true });
  const combined = `${created.stdout}\n${created.stderr}`;
  const parsed =
    combined.match(/database_id\s*=\s*"([0-9a-fA-F-]{36})"/) ??
    combined.match(
      /([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/
    );

  if (parsed) {
    databaseId = parsed[1];
  } else {
    const list = wrangler(["d1", "list", "--json"], { allowFail: true });
    try {
      const rows = JSON.parse(list.stdout);
      const entries = Array.isArray(rows) ? rows : (rows.result ?? []);
      const found = entries.find((d) => d.name === DB_NAME || d.Name === DB_NAME);
      databaseId = found?.uuid ?? found?.id ?? found?.uuid;
    } catch {
      databaseId = undefined;
    }
  }

  if (!databaseId) {
    console.error(
      "Could not create or find D1. In Cloudflare: Workers & Pages → D1 → Create database named ben-support-tickets, then paste database_id into wrangler.toml."
    );
    process.exit(1);
  }

  toml = toml.replace(/database_id\s*=\s*"[^"]+"/, `database_id = "${databaseId}"`);
  writeFileSync(tomlPath, toml);
  console.log(`Wrote database_id ${databaseId} to wrangler.toml`);
}

wrangler(["d1", "execute", DB_NAME, "--file=schema.sql", "--remote"]);
const migrate = wrangler(
  ["d1", "execute", DB_NAME, "--file=schema-engineer.sql", "--remote"],
  { allowFail: true }
);
if (migrate.status !== 0) {
  console.log("schema-engineer.sql skipped (new database already has those columns).");
}

const deployed = wrangler(["deploy"]);
process.stdout.write(deployed.stdout);
if (deployed.stderr) process.stderr.write(deployed.stderr);

console.log("");
console.log("Worker deployed. Secrets are not set by this script.");
console.log("In Cloudflare → Workers → ben-support-desk → Settings → Variables, set:");
console.log("  WEBHOOK_SECRET");
console.log("  SLACK_BOT_TOKEN");
console.log("  SLACK_SIGNING_SECRET");
console.log("  POSTMARK_SERVER_TOKEN");
console.log("Then point Postmark inbound at /inbound?secret=<WEBHOOK_SECRET>");
console.log("and invite @Ben Support to #ben-support and #ben-engineering-support-tickets.");
console.log("Do not change the bills inbound worker or its Postmark webhook.");
