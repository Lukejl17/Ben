# Ben Slack team

Cursor has one handle: `@Cursor`. Named agents are **channels + a one-line summon**.
Do not memorise a paragraph.

## Roster

| Agent | Home channel | Job | Summon (guest in someone else's thread) |
|---|---|---|---|
| **Buck** | `#ben-ceo` | CEO. Direction, priorities, hiring of agents. No code. | `@Cursor agent You are Buck. Follow docs/agents/buck.md` |
| **Lola** | `#ben-support` | Support. Users, tickets, no code. | `@Cursor agent You are Lola. Follow docs/agents/lola.md` |
| **Kit** | `#ben-engineering-support-tickets` | Engineer / CTO. Review and merge. | `@Cursor agent You are Kit. Follow docs/agents/kit.md` |
| **Emily** | `#ben-marketing` | Marketing. UGC and influencers, no code. | `@Cursor agent You are Emily. Follow docs/agents/emily.md` |

Pin those summon lines in `#ben-ops`. That is the phone book.

## Rule

- Day to day: go to that agent's **home channel**. `@Cursor` there is that agent.
- Need them in another thread: paste their **one-line summon**. Then ⋯ on **their** reply → Add follow-up.
- A new `@Cursor` at the top of a channel starts a new agent. Do not do that once the home agent exists.

## Slack setup (Luke — this agent cannot create Slack channels)

Public channels, invite `@Cursor` to each:

1. `#ben-ops` — pin this file's roster. Topic: `Phone book. Summon lines in the pin.`
2. `#ben-support` — Lola. Topic: `Lola. @Cursor in this channel. Do not @Cursor agent here unless you mean a second Lola.`
3. `#ben-engineering-support-tickets` — Kit. Topic: `Kit. @Cursor in this channel.`
4. `#ben-marketing` — Emily. Topic: `Emily. @Cursor in this channel. Do not @Cursor agent here unless you mean a second Emily.`
5. `#ben-ceo` — Buck. Topic: `Buck. @Cursor in this channel. Do not @Cursor agent here unless you mean a second Buck.`

Then **once** in Lola's channel:

```text
@Cursor You are Lola. Follow docs/agents/lola.md. Subscribe to this channel. Reply in Slack to every message here.
```

Once in Kit's channel:

```text
@Cursor You are Kit. Follow docs/agents/kit.md. Subscribe to this channel. Reply in Slack to every message here.
```

Once in Emily's channel:

```text
@Cursor You are Emily. Follow docs/agents/emily.md. Subscribe to this channel. Reply in Slack to every message here.
```

Once in Buck's channel:

```text
@Cursor You are Buck. Follow docs/agents/buck.md. Subscribe to this channel. Reply in Slack to every message here.
```

Rename the Ben Support Slack app display name to **Lola** if you want email cards to read as Lola. That is a different bot from `@Cursor`.

## Future agents

Add a public channel, add a `docs/agents/<name>.md`, add one summon line to the roster, pin it in `#ben-ops`, start them once with `@Cursor You are <name>. Follow docs/agents/<name>.md. Subscribe to this channel.`
