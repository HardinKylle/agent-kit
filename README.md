# agent-kit

A reusable toolkit + standard for running autonomous multi-agent builds (Claude orchestrator + Codex implementer + specialist subagents). Codifies the workflow proven on Studio → THUMP so every new project starts ahead instead of re-deriving it.

## What's here
```
roles/        Canonical role briefs (one per teammate)
  orchestrator · researcher · architect · implementer · reviewer
  qa-tester · design-critic · scribe · file-finder
templates/
  MODELS.md           model → role mapping + token strategy + runtimes
  LOOP.md             the adaptive milestone loop (the flow)
  RULES.md            standing rules (role discipline, gates, convergence, visibility, context)
  prompts/            reusable seat brief templates
  CHANGELOG-template.md
bin/
  ask-codex.sh        drive one Codex turn (implement = session A / review = session B), live + logged
  ask-gemini.sh       drive one Gemini turn (research / design critic) via `agy`, live + logged
  team.sh             tmux visualizer: feed + roster + build + live dev-server panes
  ui-review.mjs       Playwright: screenshot + console errors + behavioral asserts
```

## The team (one persistent session per role, right-sized models)
Orchestrator (Opus) routes; **Researcher** (Gemini) looks OUTSIDE at the web — topics, designs, references, anything online; **Implementer** (Codex, session A) writes all code, logic and UI, and applies fixes; **Reviewer** (Codex, session B — separate thread) looks INSIDE the diff and finds bugs; **QA** (Claude Sonnet) runs the official build/test/behavioral checks; **Design Critic** (Gemini, multimodal) reads real screenshots and judges taste in parallel; Scribe (Haiku) keeps the audit log; File-Finder (Haiku) does cheap search. Each role is one fixed `(model, session)` pair, resumed across turns — never re-introducing context. Codex seats run via `ask-codex.sh`, Gemini seats via `ask-gemini.sh` (`agy`, on the Google AI Pro subscription). `team.config.yaml` is the source of truth for role names, aliases, models, workflow modes, and gate profiles; see [MODELS.md](templates/MODELS.md).

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
