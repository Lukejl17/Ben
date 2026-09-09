import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  formatEngineerHandoff,
  severityForPlaybook,
  shouldEscalateToEngineer,
} from "../src/handoff.js";

const TICKET = {
  id: "abc123",
  playbook_id: "bug-report",
  from_email: "sam@example.com",
  from_name: "Sam",
  subject: "App crashes on bill confirm",
  body_text: "I tapped Confirm and Ben closed. iOS 26. Happens every time.",
};

describe("shouldEscalateToEngineer", () => {
  it("is true only when the playbook opts in", () => {
    assert.equal(shouldEscalateToEngineer({ escalate_to_engineer: true }), true);
    assert.equal(shouldEscalateToEngineer({ id: "billing" }), false);
    assert.equal(shouldEscalateToEngineer(undefined), false);
  });
});

describe("severityForPlaybook", () => {
  it("uses P1 for auto bug-report and P2 for a manual button", () => {
    assert.equal(severityForPlaybook("bug-report"), "P1");
    assert.equal(severityForPlaybook("bug-report", { manual: true }), "P2");
    assert.equal(severityForPlaybook("billing"), "P2");
  });
});

describe("formatEngineerHandoff", () => {
  it("starts with Lola signature and the ENGINEER_HANDOFF token", () => {
    const text = formatEngineerHandoff(TICKET);
    assert.ok(text.startsWith("Lola · support"));
    assert.ok(text.includes("\nENGINEER_HANDOFF\n"));
    assert.ok(text.includes("severity: P1"));
    assert.ok(text.includes("ticket: abc123"));
    assert.ok(text.includes("App crashes on bill confirm"));
    assert.ok(text.includes("Sam <sam@example.com>"));
    assert.ok(!text.toLowerCase().includes("@cursor"));
  });

  it("marks manual escalations as P2", () => {
    const text = formatEngineerHandoff(TICKET, { manual: true, hypothesis: "notifications.swift" });
    assert.ok(text.includes("severity: P2"));
    assert.ok(text.includes("lola_hypothesis: notifications.swift"));
  });
});
