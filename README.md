# Ben starter pack — run tonight, test tomorrow

## Setup (5 minutes)

```bash
# 1. Move this folder somewhere permanent and make it a repo
mv ~/Downloads/ben-starter ~/dev/ben && cd ~/dev/ben
git init && git add -A && git commit -m "Ben starter pack: specs, tokens, scaffold config"

# 2. Prereqs (Claude Code can also do this itself, but faster now)
brew install xcodegen swiftlint
xcodebuild -version   # confirm Xcode 26+ CLI tools are active

# 3. Launch
claude
```

## The overnight kickoff

Paste this as your first message in Claude Code:

> Read CLAUDE.md, then KICKOFF.md, then both docs in docs/. Execute the KICKOFF plan
> phase by phase. Build and test after every phase; never advance on a red build; commit
> per phase. Anything requiring accounts or credentials goes to HUMAN_TODO.md — stub it
> and keep moving. Finish with BUILD_REPORT.md including simulator screenshots.

Permissions: `.claude/settings.json` pre-allowlists xcodegen/xcodebuild/simctl/swiftlint/git
(and denies push, curl, sudo, rm -rf). With that in place you can run headless:

```bash
claude -p "$(cat KICKOFF.md)" --permission-mode acceptEdits
```

or start interactively, watch Phase 0 complete once, then walk away.

## Morning checklist (10 minutes)

1. Read `BUILD_REPORT.md` + screenshots.
2. `open Ben.xcodeproj` → Run on iPhone simulator → walk S1→S10 with a real bill photo
   (screenshot a bill on your phone, AirDrop it, add via photo picker).
3. Set a bill due date 2 days out → check the scheduled notification arrives.
4. Skim `git log` — each commit is one reviewable slice.
5. Check `HUMAN_TODO.md` for what needs your accounts (RevenueCat, Sign in with Apple, team ID).

## What's in the box

- `CLAUDE.md` — Claude Code's standing brief: constitution guardrails, locked tech decisions, commands, working rules
- `KICKOFF.md` — the overnight plan: 7 phases with acceptance criteria
- `docs/onboarding-flow.md` — S1–S10 + branches, copy, events (condensed from ben-onboarding-flow-v1.html)
- `docs/design-system.md` — tokens + rules (condensed from ben-design-system-v1.html)
- `Ben/Theme/BenTheme.swift` — colour/type tokens + StatusPill, BenVoiceText, BenCard atoms
- `project.yml` — XcodeGen manifest (never hand-edit the xcodeproj)
- `.claude/settings.json` — pre-approved toolchain permissions
- `HUMAN_TODO.md` — the account-gated work only you can do
