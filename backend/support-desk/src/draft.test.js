import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  SEED_PLAYBOOK,
  matchPlaybook,
  buildDraft,
  snippetForSlack,
  playbookEntryFromApproval,
  scoreEntry,
} from "./draft.js";

describe("support desk draft", () => {
  it("matches reminder language to the reminders playbook", () => {
    const { entry, score } = matchPlaybook(
      SEED_PLAYBOOK,
      "No notification",
      "Ben did not fire a reminder for my AGL bill"
    );
    assert.equal(entry?.id, "reminders");
    assert.ok(score >= 2);
  });

  it("matches cancel / Ben Pro to subscription", () => {
    const drafted = buildDraft({
      subject: "How do I cancel Ben Pro?",
      body: "I want to cancel my subscription and stop renewal.",
      entries: SEED_PLAYBOOK,
    });
    assert.equal(drafted.playbookId, "subscription");
    assert.match(drafted.draft, /Apple ID/);
  });

  it("falls back calmly when nothing matches", () => {
    const drafted = buildDraft({
      subject: "Yellow balloons",
      body: "Do you sell party supplies?",
      entries: SEED_PLAYBOOK,
    });
    assert.equal(drafted.topic, "other");
    assert.equal(drafted.playbookId, null);
    assert.match(drafted.draft, /checking it with the team/);
  });

  it("redacts long digit runs in Slack snippets", () => {
    const snip = snippetForSlack("BPAY ref 21881234567890 thanks");
    assert.ok(!snip.includes("21881234567890"));
    assert.match(snip, /\[digits\]/);
  });

  it("builds an approved playbook upsert shape", () => {
    const entry = playbookEntryFromApproval({
      topic: "other",
      subject: "Widget sync failed on Tuesday",
      draftReply: "Thanks — we're looking into widget sync.\n\n— Ben Support",
    });
    assert.equal(entry.source, "approved");
    assert.match(entry.id, /^approved-/);
    assert.ok(entry.tags.includes("widget") || entry.tags.includes("sync"));
  });

  it("scores longer tags higher", () => {
    const entry = {
      id: "x",
      topic: "ocr",
      tags: "wrong amount,ocr",
      title: "t",
      body: "b",
    };
    assert.ok(scoreEntry(entry, "the wrong amount showed up") >= 2);
  });
});
