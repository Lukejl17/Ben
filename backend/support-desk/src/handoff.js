// Pure ENGINEER_HANDOFF formatting. No Worker or Slack I/O.

const AUTO_SEVERITY = {
  "bug-report": "P1",
};

const DO_NOT =
  "HUMAN_TODO credential work (RevenueCat keys, PostHog, App Store). Engineer is already listening on this channel.";

/** Playbooks with escalate_to_engineer: true auto-post to the Engineer channel. */
export function shouldEscalateToEngineer(playbook) {
  return playbook?.escalate_to_engineer === true;
}

export function severityForPlaybook(playbookId, { manual = false } = {}) {
  if (manual) return "P2";
  return AUTO_SEVERITY[playbookId] ?? "P2";
}

/** Slack text block Lola posts so Engineer wakes on #ben-engineering-support-tickets. */
export function formatEngineerHandoff(ticket, options = {}) {
  const severity = options.severity ?? severityForPlaybook(ticket.playbook_id, options);
  const hypothesis = options.hypothesis ?? `playbook ${ticket.playbook_id ?? "unknown"}`;
  const inbound = clip(ticket.body_text, 800);
  const repro = inbound || "not reproduced, inferred from inbound email";

  return [
    "Lola · support",
    "",
    "ENGINEER_HANDOFF",
    `severity: ${severity}`,
    `ticket: ${ticket.id ?? ""}`,
    `user_impact: ${oneLine(ticket.subject) || "Support-reported product issue"}`,
    `repro: ${oneLine(repro)}`,
    "expected: App behaves as documented in docs/onboarding-flow.md and CLAUDE.md",
    "actual: See inbound below",
    `lola_hypothesis: ${hypothesis}`,
    `evidence: inbound email from ${formatFrom(ticket)}`,
    `do_not: ${DO_NOT}`,
    "",
    "inbound:",
    clip(ticket.body_text, 1200) || "(empty body)",
  ].join("\n");
}

function formatFrom(ticket) {
  if (ticket.from_name) return `${ticket.from_name} <${ticket.from_email}>`;
  return ticket.from_email ?? "unknown";
}

function oneLine(text) {
  return clip((text ?? "").replace(/\s+/g, " ").trim(), 240);
}

function clip(text, max) {
  const value = (text ?? "").trim();
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}
