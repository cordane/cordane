---
name: cordane
description: Hand files to the people you work with from inside Cordane — a terminal in a Cordane space, or a ticket worktree. Use when asked to send, share, show, export, download or attach a file, screenshot, report, log or build artifact, or when you produced one the person should look at. Covers `cordane get <path>` (offer a file or directory for download right now), `.cordane/outputs/` (attach files to the ticket when the run ends) and where files the humans attached land (`.cordane/attachments/`).
---

<!-- cordane-skill v1: installed by the Cordane hub and rewritten when the hub ships a newer one — edits made here are lost. Source: https://github.com/cordane/cordane/tree/main/skills -->

# Handing files to the humans (Cordane)

This machine is a Cordane worker. The people you work with watch a web UI (the hub), not this terminal, so a file you leave on disk is invisible to them until you hand it over. There are two channels; pick by timing.

| You want the person to… | Do | Where it lands |
|---|---|---|
| see a file **now** — a screenshot, a log, a report, an export | `cordane get <path>` | a download button for everyone watching this space, immediately |
| keep a file **with the ticket** — deliverables, the final report | write it into `.cordane/outputs/`, next to `.cordane/TICKET.md` | attached to the ticket when your run ends |

Both are fine for the same file. Never paste a file's contents or base64 into the conversation to "send" it, and never try to upload it somewhere else.

## `cordane get` — offer a file for download, right now

```
cordane get <path> [<path>...]
```

- Files or whole directories (a directory arrives as a `.tar.gz`); several paths at once are fine.
- Prints one line per path, e.g. `offered file report.pdf (1.2 MiB) — download it from the space's files ▾ menu`. That line is your confirmation: tell the person the file is offered, by name.
- Nothing is copied at offer time — the bytes are pulled through when someone clicks. Offering a large directory is cheap, but the file must still exist when they click, so don't delete or overwrite it right after.
- It only works inside a Cordane terminal. **Check `$CORDANE_SESSION_ID` first: if it is empty you are not in one** (a headless run, a plain ssh shell) — use `.cordane/outputs/` instead and say so. `cordane get` refuses with a clear message in that case, and a hub or worker that predates the command says so too.
- The offer goes to the **space** — the people watching this terminal — not to the ticket.

## `.cordane/outputs/` — attach to the ticket when the run ends

When you work a ticket, the directory your session started in (Cordane's prompts call it `$WORKING_DIR`) holds `.cordane/TICKET.md`. Write deliverables to `.cordane/outputs/` beside it, creating the directory if it is missing. When your run ends, every regular file there — up to 25 MB each; folders and symlinks are ignored — becomes an attachment on the ticket. The directory is git-excluded and is NOT for source changes: code stays in the repo.

On a multi-repo ticket that directory is the workspace root that CONTAINS the repo checkouts, not one of them.

## Files from the humans

Files attached to the ticket are synced into the worktree at `.cordane/attachments/`, and `TICKET.md` lists them. Read them from there rather than asking for them again.
