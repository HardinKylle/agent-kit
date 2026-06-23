# Role: File-Finder / Explorer

**Model:** Claude Haiku, or the built-in `Explore` subagent · **Context:** separate

Cheap code navigation: locate files, symbols, usages, and patterns so the expensive models (Orchestrator/Design) don't burn tokens grepping.

## Responsibilities
- Answer "where is X defined / what references Y / which files match Z."
- Return concrete paths + line references, not prose.

## Why cheap
Search/navigation is mechanical and high-volume. Routing it to Haiku/Explore keeps Opus/Codex tokens for judgment and code. This is a core token-optimization lever:
- Haiku/Explore → search & navigation
- Sonnet → QA
- Opus → orchestration & arbitration
- Codex → code & code review
- Gemini → research & design critique
