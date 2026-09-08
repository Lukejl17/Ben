# Ben Slack team

Cursor has one handle: `@Cursor`. Named agents are **channels + a one-line summon**.
Do not memorise a paragraph.

## Roster

| Agent | Home channel | Job | Summon (guest in someone else's thread) |
|---|---|---|---|
| **Lola** | `#ben-support` | Support. Users, tickets, no code. | `@Cursor agent You are Lola. Follow docs/agents/lola.md` |
| **Kit** | `#ben-engineering-support-tickets` | Engineer / CTO. PRs, no merge. | `@Cursor agent You are Kit. Follow docs/agents/kit.md` |

Pin those two summon lines in `#ben-ops`. That is the phone book.

## Rule

- Day to day: go to that agent's **home channel**. `@Cursor` there is that agent.
- Need them in another thread: paste their **one-line summon**. Then ⋯ on **their** reply → Add follow-up.
- A new `@Cursor` at the top of a channel starts a new agent. Do not do that once the home agent exists.

## Slack setup (Luke — this agent cannot create Slack channels)

Public channels, invite `@Cursor` to each:

1. `#ben-ops` — pin this file's roster. Topic: `Phone book. Summon lines in the pin.`
2. `#ben-support` — Lola. Topic: `Lola. @Cursor in this channel. Do not @Cursor agent here unless you mean a second Lola.`
3. `#ben-engineering-support-tickets` — Kit. Topic: `Kit. @Cursor in this channel.`

Then **once** in Lola's channel:

```text
@Cursor You are Lola. Follow docs/agents/lola.md. Subscribe to this channel. Reply in Slack to every message here.
```

Once in Kit's channel:

```text
@Cursor You are Kit. Follow docs/agents/kit.md. Subscribe to this channel. Reply in Slack to every message here.
```

Rename the Ben Support Slack app display name to **Lola** if you want email cards to read as Lola. That is a different bot from `@Cursor`.

## Future agents

Add a public channel, add a `docs/agents/<name>.md`, add one summon line to the roster, pin it in `#ben-ops`, start them once with `@Cursor You are <name>. Follow docs/agents/<name>.md. Subscribe to this channel.`
