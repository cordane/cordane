# Agent skills

The [Agent Skills](https://agentskills.io) that a Cordane hub installs on its
workers, so the coding agents running there — Claude Code, Codex, opencode, pi —
know how to work with Cordane without being told in every prompt.

| Skill | What it teaches |
|---|---|
| [`cordane`](cordane/SKILL.md) | Handing files to the humans: `cordane get <path>` for a download button right now, `.cordane/outputs/` to attach files to the ticket when a run ends, and where files attached to a ticket land. |

## You don't normally install these

A worker joined to a hub gets them on its first connect, into the user-level
skill directories every client scans:

```
~/.agents/skills/cordane/SKILL.md          Codex, opencode, pi
~/.claude/skills/cordane/SKILL.md          Claude Code (written only if ~/.claude exists)
```

and the hub keeps them current: when it ships a newer skill, every worker gets
the new file the next time it connects — which a hub upgrade makes them all do.
Workers that predate this get an **Install** button on their worker page, next
to the agent-state hook; **Remove** takes the files away and stops the
re-installs. A `cordane/SKILL.md` that Cordane did not write is never touched.

## Installing by hand

For a machine that is not a worker (you still run `cordane get` from a Cordane
terminal, but want the skill on a laptop that only reads the ticket, say), copy
the file into a skills directory your client reads. Your hub serves the exact
version it installs:

```sh
mkdir -p ~/.agents/skills/cordane
curl -fsSL https://<your hub>/skills/cordane/SKILL.md -o ~/.agents/skills/cordane/SKILL.md
```

The copies in this directory are published from the hub's source tree on each
release; edit them there, not here.
