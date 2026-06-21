# agent-kit

A reusable toolkit + standard for running autonomous multi-agent builds (Claude orchestrator + Codex implementer + specialist subagents). Codifies the workflow proven on Studio → THUMP so every new project starts ahead instead of re-deriving it.

## What's here
```
roles/        Canonical role briefs (one per teammate)
  orchestrator · researcher · architect · implementer · reviewer
  qa-tester · design-critic · frontend-developer · scribe · file-finder
templates/
  MODELS.md           model → role mapping + token strategy + runtimes
  LOOP.md             the adaptive milestone loop (the flow)
  RULES.md            standing rules (role discipline, gates, convergence, visibility, context)
  prompts/            reusable seat brief templates
  CHANGELOG-template.md
bin/
  ask-codex.sh        drive one Codex turn (engine/logic impl + review), live + logged
  ask-gemini.sh       drive one Gemini turn (frontend dev / design critic) via `agy`, live + logged
  team.sh             tmux visualizer: feed + roster + build + live dev-server panes
  ui-review.mjs       Playwright: screenshot + console errors + behavioral asserts
```

## The team (separate contexts, right-sized models)
Orchestrator (Opus) routes; **Researcher** (Sonnet) looks OUTSIDE at the web; **Reviewer** (Codex) looks INSIDE at the code; **Implementer** (Codex) writes the engine/logic; **Frontend Developer** (Gemini) builds the UI; **Design Critic** (Gemini, multimodal) reads real screenshots and judges taste; QA (Codex) verifies behavior; Scribe (Haiku) keeps the audit log; File-Finder (Haiku) does cheap search. Codex seats run via `ask-codex.sh`, Gemini seats via `ask-gemini.sh` (`agy`, on the Google AI Pro subscription). `team.config.yaml` is the source of truth for role names, aliases, models, workflow modes, and gate profiles; see [MODELS.md](templates/MODELS.md).

## The loop
The Orchestrator first chooses a workflow mode (`tiny`, `logic`, `ui`, or `production`), then routes
only the seats that mode needs. Production still runs research → architect → implement → review →
**verify behavior (not just build)** → record → commit → push → deploy. Smaller changes use fewer
seats and escalate when risk appears. See [LOOP.md](templates/LOOP.md) and [RULES.md](templates/RULES.md).

## Core principles (hard-won)
1. "Done" = observed running behavior; a green build is not done.
2. Verify every milestone, not just the end.
3. Distinctive design beats safe-default; no glass/shadcn/Inter reflexes.
4. Real purpose + direct interaction over a parameter panel.
5. Cheapest capable model per task; subagents keep heavy reading off the main thread.

## Usage
Per project: `npm i -D playwright` once (chromium binary caches globally). Record the chosen mode with
`bin/team.sh mode <project> <milestone> ui "reason"`. Drive Codex with `bin/ask-codex.sh <project>
<prompt-file>`; verify UI with `node ui-review.mjs --url <url> --name <shot> [--viewport desktop,mobile]
[--json]`. Record scoped verdicts with `bin/team.sh verdict <project> <milestone> qa-tester pass "..."`,
then gate with `bin/team.sh gate <project> --milestone <milestone> qa design-critic`. Watch live in a
tmux session with a conversation pane.
