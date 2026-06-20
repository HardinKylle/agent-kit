# Model → Role mapping & token strategy

Principle: **the cheapest model that can do the job.** Judgment/taste/code get strong models; mechanical work gets cheap ones. Subagents keep heavy reading out of the main context.

| Role | Model | Why |
|------|-------|-----|
| Orchestrator | Claude **Opus** | coordination + final judgment |
| Design Critic | Claude **Opus** | taste was the weak spot — give it the best |
| Researcher | Claude **Sonnet** | web research; good enough, cheaper than Opus |
| QA / Tester | Claude **Sonnet** | behavioral checks + screenshot reading |
| Architect | Claude **Opus** | structural decisions (or fold into Orchestrator) |
| Implementer | **Codex** (gpt-5.x) | writes the code |
| Code Reviewer | **Codex** (gpt-5.x) | internal code review / bug hunting |
| Scribe | Claude **Haiku** | structured low-judgment summarization |
| File-Finder | Claude **Haiku** / Explore | mechanical search & navigation |

User preference encoded here: **Claude for design/orchestration/QA/research/docs; Codex for implementing + reviewing code; Haiku for the cheap grunt work.**

## Token levers
- Route file search/navigation to Haiku/Explore — never grep from Opus.
- Each teammate is a SEPARATE context: deep doc-diving / file-reading never bloats the main thread.
- Reuse `bin/` scripts so harnesses aren't re-derived per project.
- Scribe runs on Haiku and stays terse.
