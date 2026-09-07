/**
 * Pure draft helpers — match playbook, classify topic, build reply.
 * Runnable under `node --test` without Workers runtime.
 */

export const SEED_PLAYBOOK = [
  {
    id: "reminders",
    topic: "reminders",
    tags: "reminder,notification,quiet,didn't ping,no alert,did not fire",
    title: "Reminders did not fire",
    body:
      "Thanks for writing in.\n\n" +
      "Reminders on Ben are local on your phone — there's no server push. A few things worth checking:\n\n" +
      "1. iOS Settings → Notifications → Ben → Allow Notifications is on.\n" +
      "2. Focus / Sleep modes aren't silencing Ben.\n" +
      "3. The bill still shows a reminder set on its detail screen (and the due date hasn't already passed the reminder window).\n\n" +
      "If those look right, tell me the issuer and due date (no need to send the bill PDF) and we'll dig in.\n\n" +
      "— Ben Support",
  },
  {
    id: "ocr",
    topic: "ocr",
    tags: "wrong amount,wrong date,ocr,misread,edit bill",
    title: "OCR / extracted details wrong",
    body:
      "Thanks for the note.\n\n" +
      "Ben reads bills on your device and always asks you to confirm before anything is saved — nothing should lock in wrong details without that once-over.\n\n" +
      "Open the bill → Edit, fix the field, and save. Reminders follow the due date you confirm.\n\n" +
      "If a particular provider misreads often, tell us which one and we'll sharpen the heuristics when we can.\n\n" +
      "— Ben Support",
  },
  {
    id: "delete-data",
    topic: "delete-data",
    tags: "delete,erase,gdpr,privacy request,remove account",
    title: "Delete my data / leave Ben",
    body:
      "Thanks for getting in touch.\n\n" +
      "Bills and reminders live on your phone (local-first). To clear them: remove bills in the app, or delete the app after exporting anything you need.\n\n" +
      "If you signed in, sign out clears the local shelf for that account on the device. For anything held for email-in forwarding on our side, reply with the email you use to sign in and we'll remove the mailroom mapping.\n\n" +
      "We don't sell your data — you pay for Ben, so you're the customer.\n\n" +
      "— Ben Support",
  },
  {
    id: "subscription",
    topic: "subscription",
    tags: "cancel,subscription,trial,refund,ben pro,paywall",
    title: "Subscription / Ben Pro / cancel",
    body:
      "Thanks for writing.\n\n" +
      "Ben's trial and Ben Pro are billed through Apple. To cancel or change renewal:\n\n" +
      "Settings → Apple ID → Subscriptions → Ben\n\n" +
      "Refunds are handled by Apple when required by their rules — we can't reverse a charge from inside the app.\n\n" +
      "If something looks wrong with the trial timing, say what you're seeing on the paywall and we'll help interpret it.\n\n" +
      "— Ben Support",
  },
  {
    id: "email-in",
    topic: "email-in",
    tags: "forward,email-in,bills@,not arriving,mailroom",
    title: "Forwarded bill not showing",
    body:
      "Thanks for flagging that.\n\n" +
      "Forwarded bills go to your personal bills-…@in.benandbill.app address (in Settings), not to support@. Check:\n\n" +
      "1. You forwarded to the exact address shown in Ben → Settings.\n" +
      "2. The message had a PDF (or a clear bill image) — logos and signature images are ignored on purpose.\n" +
      "3. Pull to refresh on Home, or open the email-in sheet once so Ben can check.\n\n" +
      "If it's still missing, tell us the approx. time you forwarded and the issuer (no PDF needed) and we'll trace the mailroom.\n\n" +
      "— Ben Support",
  },
  {
    id: "sign-in",
    topic: "sign-in",
    tags: "login,sign in,google,apple,password,account",
    title: "Sign-in issues",
    body:
      "Thanks for writing.\n\n" +
      "Try the same provider you used at setup (Google, Apple, or email). If Google shows an unfamiliar project name on the consent screen, cancel and try again after updating the app.\n\n" +
      "Signing out clears local bills for that account on the device — sign-in won't restore cloud bills in v1 (there isn't a bill sync server yet).\n\n" +
      "If you're stuck on a blank consent page, tell us which button you used (Google / Apple / email) and your iOS version.\n\n" +
      "— Ben Support",
  },
  {
    id: "what-is-ben",
    topic: "what-is-ben",
    tags: "what is ben,how it works,overview",
    title: "What is Ben?",
    body:
      "G'day — thanks for asking.\n\n" +
      "Ben keeps your bills in one calm place on your phone, reads them on-device, and reminds you when one needs you. The rest of the time, silence is the feature.\n\n" +
      "There's no account required to try the basics; sign-in unlocks email forwarding and keeps settings tidy. Privacy policy: https://benandbill.app/privacy\n\n" +
      "— Ben Support",
  },
  {
    id: "privacy",
    topic: "privacy",
    tags: "privacy,on-device,data,tracking,sell data,sell my data",
    title: "Privacy / on-device reading",
    body:
      "Thanks for asking — fair question.\n\n" +
      "Bill reading happens on your device. Your bill list is local-first. We don't sell your data; you pay for Ben, so you're the customer.\n\n" +
      "Privacy policy: https://benandbill.app/privacy\n" +
      "Terms: https://benandbill.app/terms\n\n" +
      "Happy to go deeper on any specific concern.\n\n" +
      "— Ben Support",
  },
];

/** Lowercase haystack for matching. */
export function normalizeText(value) {
  return String(value ?? "")
    .toLowerCase()
    .replace(/['']/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Score a playbook entry against subject+body. Higher = better.
 */
export function scoreEntry(entry, haystack) {
  const text = normalizeText(haystack);
  let score = 0;
  const tags = String(entry.tags ?? "")
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean);
  for (const tag of tags) {
    if (tag.length >= 3 && text.includes(normalizeText(tag))) {
      score += tag.length >= 8 ? 3 : 2;
    }
  }
  if (entry.topic && text.includes(normalizeText(entry.topic.replace(/-/g, " ")))) {
    score += 2;
  }
  return score;
}

/**
 * Pick best playbook entry from a list, or null if nothing confident.
 */
export function matchPlaybook(entries, subject, body, minScore = 2) {
  let best = null;
  let bestScore = 0;
  const haystack = `${subject}\n${body}`;
  for (const entry of entries) {
    const score = scoreEntry(entry, haystack);
    if (score > bestScore) {
      best = entry;
      bestScore = score;
    }
  }
  if (!best || bestScore < minScore) return { entry: null, score: bestScore };
  return { entry: best, score: bestScore };
}

/**
 * Privacy-safe snippet for Slack (no long digit runs that look like refs).
 */
export function snippetForSlack(body, maxLen = 280) {
  let text = String(body ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/[0-9]{6,}/g, "[digits]")
    .replace(/\s+/g, " ")
    .trim();
  if (text.length > maxLen) text = `${text.slice(0, maxLen - 1)}…`;
  return text;
}

/**
 * Build a draft: prefer playbook body; otherwise a calm "we'll look" stub.
 */
export function buildDraft({ subject, body, entries }) {
  const { entry, score } = matchPlaybook(entries, subject, body);
  if (entry) {
    return {
      topic: entry.topic,
      playbookId: entry.id,
      draft: entry.body,
      matchedScore: score,
    };
  }
  return {
    topic: "other",
    playbookId: null,
    draft:
      "Thanks for writing in.\n\n" +
      "I've got your note and I'm checking it with the team. " +
      "I'll follow up as soon as I have something useful — no need to resend the bill PDF unless we ask.\n\n" +
      "— Ben Support",
    matchedScore: score,
  };
}

/**
 * Upsert shape for an approved novel reply (Phase 2).
 */
export function playbookEntryFromApproval({ topic, subject, draftReply }) {
  const id = `approved-${Date.now().toString(36)}`;
  const tags = normalizeText(subject)
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length >= 4)
    .slice(0, 8)
    .join(",");
  return {
    id,
    topic: topic || "other",
    tags: tags || "general",
    title: subject.slice(0, 120) || "Approved reply",
    body: draftReply,
    source: "approved",
  };
}
