// Pure playbook matching and draft rendering. No Worker or I/O dependencies.

import billing from "../../../docs/support-playbook/billing.json" with { type: "json" };
import deleteAccount from "../../../docs/support-playbook/delete-account.json" with { type: "json" };
import addBill from "../../../docs/support-playbook/add-bill.json" with { type: "json" };
import notifications from "../../../docs/support-playbook/notifications.json" with { type: "json" };
import privacy from "../../../docs/support-playbook/privacy.json" with { type: "json" };
import refundTrial from "../../../docs/support-playbook/refund-trial.json" with { type: "json" };
import bugReport from "../../../docs/support-playbook/bug-report.json" with { type: "json" };
import general from "../../../docs/support-playbook/general.json" with { type: "json" };

/** Playbooks in priority order; `general` is the fallback. */
export const DEFAULT_PLAYBOOKS = [
  billing,
  deleteAccount,
  addBill,
  notifications,
  privacy,
  refundTrial,
  bugReport,
  general,
];

const FALLBACK_ID = "general";

/**
 * Score playbooks against inbound text. Higher score = stronger match.
 * Keyword hits are weighted; longer multi-word phrases score more.
 */
export function scorePlaybook(playbook, text) {
  const haystack = normalise(text);
  if (!haystack) return 0;

  let score = 0;
  for (const keyword of playbook.keywords ?? []) {
    const needle = normalise(keyword);
    if (!needle) continue;
    if (haystack.includes(needle)) {
      score += needle.includes(" ") ? 3 : 1;
    }
  }
  return score;
}

/** Pick the best-matching playbook, or the fallback when nothing scores. */
export function matchPlaybook(text, playbooks = DEFAULT_PLAYBOOKS) {
  const candidates = playbooks.filter((p) => p.id !== FALLBACK_ID);
  let best = null;
  let bestScore = 0;

  for (const playbook of candidates) {
    const score = scorePlaybook(playbook, text);
    if (score > bestScore) {
      bestScore = score;
      best = playbook;
    }
  }

  if (best) return best;
  return playbooks.find((p) => p.id === FALLBACK_ID) ?? playbooks[playbooks.length - 1];
}

/** Build searchable text from a Postmark-style inbound message. */
export function inboundSearchText(message) {
  const parts = [
    message.Subject ?? "",
    message.TextBody ?? "",
    stripHtml(message.HtmlBody ?? ""),
    message.From ?? "",
  ];
  return parts.join("\n");
}

/** Render subject/body templates with calm defaults. */
export function renderDraft(playbook, context) {
  const vars = buildTemplateVars(context);
  return {
    playbookId: playbook.id,
    subject: applyTemplate(playbook.subject ?? "Re: {original_subject}", vars),
    body: applyTemplate(playbook.body ?? "", vars),
  };
}

export function buildTemplateVars(context) {
  const fromName = (context.fromName ?? "").trim();
  const fromEmail = (context.fromEmail ?? "").trim();
  const originalSubject = (context.originalSubject ?? "Your message").trim() || "Your message";

  const fromNameGreeting = fromName ? ` ${fromName}` : "";

  return {
    from_name: fromName,
    from_email: fromEmail,
    from_name_greeting: fromNameGreeting,
    original_subject: originalSubject,
  };
}

function applyTemplate(template, vars) {
  return template.replace(/\{([a-z_]+)\}/g, (_, key) => vars[key] ?? "");
}

function normalise(text) {
  return (text ?? "").toLowerCase().replace(/\s+/g, " ").trim();
}

function stripHtml(html) {
  return (html ?? "")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
