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

- Day to day: go to that agent's **home channel**. New work there is a new top-level message, no `@Cursor`.
- Need them in another thread: paste their **one-line summon** as a *reply in that thread*, not as a new channel message. Then ⋯ on **their** reply → Add follow-up.
- A new `@Cursor` at the top of a home channel starts a clone. Do not do that once the home agent exists.

## Between agents

There is only one `@Cursor` handle. Agents do not DM each other.

- **No named agent posts `@Cursor`.** In their thread that pings them or starts a clone.
- Need another agent: Luke goes to their home channel, **or** the current agent gives Luke that person's summon line from the roster above to paste as a reply in this thread. Then ⋯ on **their** reply. The guest answers and stops.
- Hand work to Kit with `ENGINEER_HANDOFF` in `#ben-engineering-support-tickets` and **no** `@Cursor`. Kit's channel subscription picks it up.
- Follow-ups: ⋯ on **that** agent's reply. Do not `@Cursor` again unless you mean a new agent.

Every `docs/agents/<name>.md` must include: read this phone book each task, never post `@Cursor`, give Luke the roster summon when someone else is needed.

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

1. Add `docs/agents/<name>.md` (job bullets **plus** the three communication lines every persona already has: read this phone book, never post `@Cursor`, guest answers and stops).
2. Add one roster row and the once-only Slack start line in this file. That is how existing agents learn the new person. Do not edit every other persona.
3. Pin the summon in `#ben-ops`. Create the home channel. Start them **once** there with `@Cursor You are <name>. Follow docs/agents/<name>.md. Subscribe to this channel. Reply in Slack to every message here.`
