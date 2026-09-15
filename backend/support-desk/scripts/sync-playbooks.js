#!/usr/bin/env node
// Copy canonical playbooks from docs/ into src/playbooks/ before deploy.
import { cpSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const source = join(root, "..", "..", "docs", "support-playbook");
const target = join(root, "src", "playbooks");

for (const file of readdirSync(source).filter((f) => f.endsWith(".json"))) {
  cpSync(join(source, file), join(target, file));
  console.log(`synced ${file}`);
}
