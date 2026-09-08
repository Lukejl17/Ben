import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  buildTemplateVars,
  matchPlaybook,
  renderDraft,
  scorePlaybook,
} from "../src/playbooks.js";

const FIXTURES = [
  {
    id: "billing",
    title: "Billing",
    keywords: ["subscription", "billing", "charge"],
    subject: "Re: {original_subject}",
    body: "Hi{from_name_greeting}, billing help.",
  },
  {
    id: "delete-account",
    title: "Delete",
    keywords: ["delete", "account"],
    subject: "Re: {original_subject}",
    body: "Hi{from_name_greeting}, deletion help.",
  },
  {
    id: "general",
    title: "General",
    keywords: [],
    subject: "Re: {original_subject}",
    body: "Hi{from_name_greeting}, general help.",
  },
];

describe("scorePlaybook", () => {
  it("scores keyword hits", () => {
    const billing = FIXTURES[0];
    assert.equal(scorePlaybook(billing, "question about my subscription"), 1);
    assert.equal(scorePlaybook(billing, "unrelated hello"), 0);
  });

  it("weights multi-word phrases higher", () => {
    const addBill = {
      id: "add-bill",
      keywords: ["add bill", "upload"],
      subject: "Re: {original_subject}",
      body: "body",
    };
    assert.equal(scorePlaybook(addBill, "how do I add bill"), 3);
    assert.equal(scorePlaybook(addBill, "upload issue"), 1);
  });
});

describe("matchPlaybook", () => {
  it("picks the highest-scoring playbook", () => {
    const match = matchPlaybook("Please delete my account", FIXTURES);
    assert.equal(match.id, "delete-account");
  });

  it("falls back to general when nothing matches", () => {
    const match = matchPlaybook("just saying hello", FIXTURES);
    assert.equal(match.id, "general");
  });

  it("matches billing keywords from real playbooks import", async () => {
    const { DEFAULT_PLAYBOOKS, matchPlaybook: match } = await import("../src/playbooks.js");
    const result = match("I was charged twice for my subscription", DEFAULT_PLAYBOOKS);
    assert.equal(result.id, "billing");
  });

  it("matches bundled playbooks for common topics", async () => {
    const { DEFAULT_PLAYBOOKS, matchPlaybook: match } = await import("../src/playbooks.js");
    assert.equal(match("App crash\nBen crashes when I open a bill", DEFAULT_PLAYBOOKS).id, "bug-report");
    assert.equal(match("Trial\nI would like a refund for my subscription", DEFAULT_PLAYBOOKS).id, "refund-trial");
    assert.equal(match("Help\nHow do I upload a new bill?", DEFAULT_PLAYBOOKS).id, "add-bill");
    assert.equal(match("Quiet\nI am not receiving notifications for my bills", DEFAULT_PLAYBOOKS).id, "notifications");
    assert.equal(match("Hi\nQuestion about privacy and tracking", DEFAULT_PLAYBOOKS).id, "privacy");
    assert.equal(match("Account\nPlease delete account and my data", DEFAULT_PLAYBOOKS).id, "delete-account");
  });
});

describe("renderDraft", () => {
  it("substitutes template variables", () => {
    const playbook = FIXTURES[0];
    const draft = renderDraft(playbook, {
      fromName: "Alex",
      fromEmail: "alex@example.com",
      originalSubject: "Billing question",
    });
    assert.equal(draft.playbookId, "billing");
    assert.equal(draft.subject, "Re: Billing question");
    assert.ok(draft.body.includes("Hi Alex"));
  });

  it("omits name greeting when from name is empty", () => {
    const vars = buildTemplateVars({ fromName: "", originalSubject: "Hi" });
    assert.equal(vars.from_name_greeting, "");
    const draft = renderDraft(FIXTURES[2], { originalSubject: "Hi" });
    assert.ok(draft.body.startsWith("Hi,"));
  });
});
