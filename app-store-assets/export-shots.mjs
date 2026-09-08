import puppeteer from "puppeteer";
import { pathToFileURL } from "node:url";
import path from "node:path";
import fs from "node:fs";

const root = path.resolve(import.meta.dirname);
const htmlPath = path.join(root, "screenshots", "export.html");
const outDir = path.join(root, "screenshots");
fs.mkdirSync(outDir, { recursive: true });

const names = [
  "01-know-whats-due",
  "02-snap-a-bill",
  "03-nudge-then-quiet",
  "04-pay-in-two-taps",
  "05-stays-on-phone",
  "06-one-calm-place",
];

const browser = await puppeteer.launch({
  headless: true,
  args: ["--no-sandbox", "--disable-gpu", "--font-render-hinting=none"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 3000, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(htmlPath).href, { waitUntil: "networkidle0", timeout: 120_000 });
// Give Google Fonts a moment
await new Promise((r) => setTimeout(r, 2500));

const shots = await page.$$(".shot");
if (shots.length !== names.length) {
  console.error(`Expected ${names.length} .shot nodes, got ${shots.length}`);
}
for (let i = 0; i < shots.length; i++) {
  const out = path.join(outDir, `${names[i] ?? `shot-${i + 1}`}.png`);
  await shots[i].screenshot({ path: out, type: "png" });
  console.log("wrote", out);
}
await browser.close();
