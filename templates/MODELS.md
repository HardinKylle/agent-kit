# Model → Role mapping & token strategy

Principle: **the cheapest model that can do the job.** Judgment/taste/code get strong models; mechanical work gets cheap ones. Subagents keep heavy reading out of the main context.

`team.config.yaml` is the source of truth for role names, aliases, models, and gate profiles. Keep this
file explanatory; update the config first when routing changes.

| Role | Model | Session | Why |
|------|-------|---------|-----|
| Orchestrator | Claude **Opus** | main | coordination + final judgment |
| Researcher | **Gemini** (Antigravity) | own | external facts/web; multimodal; on the unmetered Pro sub |
| Implementer | **Codex** (gpt-5.x) | A | ALL code: logic/engine/state + UI/CSS + applying fixes |
| Code Reviewer | **Codex** (gpt-5.x) | B (separate) | finds bugs in the diff; never inherits the writer's context |
| QA / Tester | Claude **Sonnet** | own | runs the official checks (build, vitest, behavioral) |
| Design Critic | **Gemini** (Antigravity) | own | multimodal taste; reads the screenshot directly; runs parallel |
| Architect | Claude **Opus** | own | structural decisions (rare; or fold into Orchestrator) |
| Scribe | Claude **Haiku** | own | structured low-judgment summarization |
| File-Finder | Claude **Haiku** / Explore | own | mechanical search & navigation |

Routing: **Codex implements everything (logic + UI + fixes) in session A and reviews in a separate session B; Gemini researches and critiques design; Claude orchestrates (Opus) and runs QA (Sonnet).** Each role is one `(model, session)` pair, resumed by id every turn.

> **Sessions (RULES §1b).** `ask-codex.sh` keys the session on `CODEX_ROLE`: Implementer = session A,
> Reviewer = session B. The Reviewer sees only diffs, so it's an independent pair of eyes that keeps its
> context warm. Gemini seats and QA each hold their own thread the same way.

> **QA = Claude Sonnet.** Runs the objective checks (build/vitest/console-errors) and views the
> screenshot to confirm the UI rendered. Cheap, and independent of the Codex author and Gemini.

> **Design Critic = Gemini.** The visual-taste seat, separate from QA's pass/fail, run in parallel once
> the UI shell exists.

## Runtimes
- **Codex** seats (Implementer = session A, Reviewer = session B) → `bin/ask-codex.sh` with
  `CODEX_ROLE=implementer|reviewer` (OAuth'd to the Codex account, separate billing). The role keys
  the persistent session id, so the two threads never collide.
- **Gemini** seats (Researcher, Design Critic) → `bin/ask-gemini.sh` (`agy`, OAuth'd to the Google AI
  Pro subscription — NOT a metered API key), each with its own `--continue` session id. Override the
  model with `GEMINI_MODEL`; default `Gemini 3.1 Pro (High)`. Available on the Pro plan: Gemini 3.5
  Flash (Low/Med/High), Gemini 3.1 Pro (Low/High), Claude Sonnet/Opus 4.6, GPT-OSS 120B (`agy models`).
- **Claude** seats (Orchestrator = Opus main, QA = Sonnet, Architect/Scribe/File-Finder) → `Agent`
  subagents (this runtime). Spawn QA once and resume it by name via `SendMessage` so its session
  persists across milestones.
- Fallback: if `agy` is unavailable, the Design Critic falls back to Claude **Opus** (its prior home).

## Token levers
- Route file search/navigation to Haiku/Explore — never grep from Opus.
- Each teammate is a SEPARATE context: deep doc-diving / file-reading never bloats the main thread.
- Reuse `bin/` scripts so harnesses aren't re-derived per project.
- Scribe runs on Haiku and stays terse.
