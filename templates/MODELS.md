# Model → Role mapping & token strategy

Principle: **the cheapest model that can do the job.** Judgment/taste/code get strong models; mechanical work gets cheap ones. Subagents keep heavy reading out of the main context.

`team.config.yaml` is the source of truth for role names, aliases, models, and gate profiles. Keep this
file explanatory; update the config first when routing changes.

| Role | Model | Why |
|------|-------|-----|
| Orchestrator | Claude **Opus** | coordination + final judgment |
| Design Critic | **Gemini** (Antigravity) | strong multimodal taste; reads the screenshot directly |
| Frontend Developer | **Gemini** (Antigravity) | owns the UI layer (components/layout/CSS); works from screenshots |
| Researcher | Claude **Sonnet** | web research; good enough, cheaper than Opus; rarely invoked |
| QA / Tester | **Codex** (gpt-5.x) | runs the official checks (build, vitest, behavioral) — text-driven |
| Architect | Claude **Opus** | structural decisions (rare; or fold into Orchestrator) |
| Implementer | **Codex** (gpt-5.x) | engine/logic/state code |
| Code Reviewer | **Codex** (gpt-5.x) | internal code review / bug hunting |
| Scribe | Claude **Haiku** | structured low-judgment summarization |
| File-Finder | Claude **Haiku** / Explore | mechanical search & navigation |

User preference encoded here: **Gemini for the UI seats (frontend build + design critique); Codex for the code seats (implement + review + QA/run-tests); Claude only for orchestration + the rare judgment seats (architect/research) + cheap Haiku grunt.** Keeps the Claude main thread thin; pushes heavy build/verify onto the Codex + Gemini subscriptions.

> **HARD RULE (RULES §1b): Codex never writes UI/CSS.** UI implementation is a Gemini Frontend seat
> (`ask-gemini.sh`), on the Pro subscription (unmetered). Putting UI on Codex is the worst trade in
> the kit — it is slow at CSS AND it spends the metered budget that should guard the logic/review/QA
> seats. Logic → Codex, UI → Gemini, and they run in parallel. Design feedback loops Critic ⇄ Gemini
> directly. Only a project with NO meaningful UI folds the Frontend seat (announce it).

> QA-on-Codex: Codex IS multimodal — `codex exec -i <shot.png> -- "<prompt>"` (verified it reads a
> screenshot). So QA on Codex runs the objective checks (build/vitest/console-errors) AND can view the
> shot to confirm the UI rendered. The **Design Critic stays Gemini by choice (taste), not capability** —
> it's the independent visual-taste seat, separate from QA's pass/fail. Run QA as a fresh `--reset`
> Codex session so it isn't blessing the same context that wrote the code.

## Runtimes
- **Codex** seats → `bin/ask-codex.sh` (OAuth'd to the Codex account, separate billing).
- **Gemini** seats → `bin/ask-gemini.sh` (`agy`, OAuth'd to the Google AI Pro subscription — NOT a
  metered API key). Override the model with `GEMINI_MODEL`; default `Gemini 3.1 Pro (High)`. Available
  on the Pro plan: Gemini 3.5 Flash (Low/Med/High), Gemini 3.1 Pro (Low/High), Claude Sonnet/Opus 4.6,
  GPT-OSS 120B (`agy models`).
- **Claude** seats → `Agent` subagents (this runtime).
- Fallback: if `agy` is unavailable, the Design Critic falls back to Claude **Opus** (its prior home).

## Token levers
- Route file search/navigation to Haiku/Explore — never grep from Opus.
- Each teammate is a SEPARATE context: deep doc-diving / file-reading never bloats the main thread.
- Reuse `bin/` scripts so harnesses aren't re-derived per project.
- Scribe runs on Haiku and stays terse.
