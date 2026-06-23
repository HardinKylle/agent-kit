# Changelog

Maintained by the Scribe. One entry per change.

## Role/model consolidation — fewer seats, one session per role — 2026-06-23

### What
- Reduced the team to a fixed `(model, session)` per role: Orchestrator (Opus), Researcher (Gemini —
  all external/net lookup: topics, designs, references), Implementer (Codex, session A — all code incl.
  UI + fixes), Reviewer (Codex, session B — separate thread, finds bugs), QA (Claude **Sonnet**),
  Design Critic (Gemini, parallel), Scribe/File-Finder (Haiku).
- **Removed the Gemini Frontend seat** — the Implementer (Codex) now writes UI/CSS too.
- **QA moved Codex → Claude Sonnet**, its own persistent session (independent of the Codex author and
  of Gemini; keeps the Opus Orchestrator out of testing).
- **Researcher moved Claude Sonnet → Gemini.**
- RULES §1b is now "one persistent session per role" (Implementer session A ‖ Reviewer session B keep
  author≠reviewer via separate threads, resumed warm — not via `--reset`). Updated LOOP, MODELS,
  README, role briefs, and `team.sh` roster/aliases to match.

### Why
- User asked to cut distributed seats for speed and to stop re-introducing context every call: each
  role keeps one warm session. Independence is structural (separate session), not from resetting.

### Who
- Decision = user; encoded into the kit by Orchestrator (Opus). Docs/config + `team.sh` roster.

## Gemini session isolation, log locking, and ui-review timeout fixes — 2026-06-21

### What
- **Gemini Session Isolation:** Added role-isolated conversation tracking in [bin/ask-gemini.sh](file:///home/kyllehardin/repos-linux/agent-kit/bin/ask-gemini.sh). It reads `~/.gemini/antigravity-cli/cache/last_conversations.json` to capture conversation IDs and passes them back via the `--conversation` argument when continuing, preventing context bleeding between the `frontend` and `design-critic` seats. Added `--reset` support to clear the cached conversation.
- **Log Write Locking:** Added `flock 9` logging locks to the `say` and `msg` commands in [bin/team.sh](file:///home/kyllehardin/repos-linux/agent-kit/bin/team.sh) to ensure concurrent agent runs do not interleave or mangle the central transcript feed.
- **ui-review.mjs Early Exit:** Optimised [bin/ui-review.mjs](file:///home/kyllehardin/repos-linux/agent-kit/bin/ui-review.mjs) to skip waiting for the 15-second Playwright `download` event if the triggering click selector execution fails.

### Why
- Bypassed locking on `say` and `msg` risked log mangling during parallel runs. Gemini seats had no session isolation, leading to either bleeding contexts when using `--continue` globally or token-heavy cold re-reads. Playwright tests would hang for 15 seconds waiting for downloads even when the trigger click selector failed.

### Verified
- Checked syntax validation (`bash -n` and `node --check`).
- Ran git diff and verified script output structure.

### Who
- Implemented and verified by Antigravity.

## Adaptive modes + structured milestone gates — 2026-06-21

### What
- Added `team.config.yaml` as the source of truth for role names, model routing, aliases, verdict
  labels, workflow modes, and gate profiles.
- Added adaptive workflow modes (`tiny`, `logic`, `ui`, `production`) so the Orchestrator records the
  lightest responsible process instead of running the full team by default.
- Added `team.sh mode <project> <milestone> <tiny|logic|ui|production> [reason]` to make that routing
  decision visible in `.team/modes.jsonl` and the feed.
- Added lightweight `team.sh handoff` support and wired Codex/Gemini runners to show the actual
  Orchestrator prompt in the feed before the filtered agent response.
- Added reusable seat prompt templates under `templates/prompts/` for implementer, frontend,
  reviewer, QA, and design critic briefs. Kept them concise: no extra live-note/report commands.
- Added `team.sh verdict <project> <milestone> <seat> <pass|fail|converged> [summary]`, writing
  milestone-scoped JSONL records to `.team/verdicts/<milestone>.jsonl`; `team.sh gate` now supports
  `--milestone` so old PASS lines cannot satisfy a new milestone.
- Upgraded `ui-review.mjs` with `--json`, multi-viewport screenshots, output directory creation,
  and nonzero exits for failed navigation, click, download, or console/page errors.
- Updated `team-demo.sh` to show prompt → agent response → changed files/verdict without raw code or
  fake diffs in the conversation pane.
- Aligned docs/roles with the current routing: QA = Codex, Design Critic = Gemini, UI fixes route
  through Frontend, and new gates use structured verdicts.

### Why
- The prior feed-grep gate was global and could be opened by stale `QA: PASS` / `DESIGN-CRITIC: PASS`
  lines from an older milestone. Role/model assignments had also drifted across docs, forcing agents
  to spend turns reconciling instructions. The full loop was also too heavy as a default for tiny or
  low-risk changes.

### Verified
- `bash -n` passed for `team.sh`, `ask-codex.sh`, `ask-gemini.sh`, and `team-demo.sh`.
- `node --check bin/ui-review.mjs` passed.
- Structured gate smoke in `/tmp`: `gate --milestone M1 qa` blocked before verdicts, then passed
  after `qa-tester pass` + `reviewer converged` records.
- Latest-verdict smoke in `/tmp`: a `qa-tester fail` after an earlier pass blocked the gate until a
  newer pass was recorded.
- Mode smoke in `/tmp`: `team.sh mode <project> M1 tiny "reason"` recorded to `.team/modes.jsonl`
  and feed.
- Handoff smoke in `/tmp`: `team.sh handoff` printed the Orchestrator prompt into `.team/feed.log`.
- `team-demo.sh` replay ran successfully and produced the lightweight pane transcript.
- `ui-review.mjs --json` returns structured error output for missing `--url` and missing Playwright.
  Full screenshot capture was not run because Playwright is not installed in this environment.

### Who
- Orchestrator (Codex) implemented from user-requested workflow optimization.

## Per-role Codex sessions + change-summary feed — 2026-06-21

### What
- **ask-codex.sh now persists a PER-ROLE session id** (`.codex_session_<role>.id`) and resumes that
  thread by id (`codex exec resume <id>`) instead of cold `--reset` each turn. The implementer keeps
  context across review→fix→re-review even when reviewer/QA turns interleave; each seat stays an
  independent thread (reviewer never inherits the writer's context). `--reset` starts a seat's thread
  over. Session id captured from the newest `$CODEX_HOME/sessions/*.jsonl` whose `session_meta.cwd`
  matches the project.
- **Change-summary feed (RULES §5):** ask-codex.sh + ask-gemini.sh post `CHANGES vs HEAD — <shortstat>
  | <name-status>` after every turn. `team.sh feedfilter` tightened to drop code lines (anything
  ending in `{ } ; ( ,`, JS/CSS keywords, bare selectors) so raw CSS/JS never streams into the pane.

### Why
- Tally feedback: cold Codex re-reads on every review/fix turn wasted budget + time; and raw CSS/JS
  leaked into the feed pane, drowning progress. User asked for change summaries + faster Codex.

### Verified
- `bash -n` on all three scripts. feedfilter smoke: the exact leaked lines (CSS decls, `@media`,
  `import {…}`, `createRoot(`) are dropped; prose + `P0 …:42:` findings kept. Resume-by-id smoke:
  2-turn test recalled a token from the prior turn (context persisted, no re-read). CHANGES summary
  renders `1 file changed, 2 insertions(+) | M:src/styles.css`.

### Who
- Decision = user; implemented + verified by Orchestrator (Opus). (No Scribe seat live; recorded here.)

## Route-by-layer: Codex never writes UI — 2026-06-21

### What
- New hard rule **RULES §1b**: UI/CSS/view-layer work goes to the **Gemini Frontend seat**
  (`ask-gemini.sh`, unmetered Pro sub); the metered **Codex budget is reserved for logic + review +
  QA**. Codex never styles. Logic and UI run in PARALLEL. Design feedback loops Critic ⇄ Frontend
  directly (no Codex hop). Folding the Frontend seat is allowed ONLY for projects with no meaningful
  UI, and must be announced.
- Token-discipline corollary: resume one Codex session across review→fix→re-review instead of cold
  `--reset` re-reads.
- LOOP.md step 2 split by layer (Codex logic ∥ Gemini UI); step 4b design loop now Critic ⇄ Frontend.
- MODELS.md + orchestrator.md updated to match; orchestrator must surface CHANGE SUMMARIES (not raw
  diffs) in the feed.

### Why
- On the Tally build the orchestrator ran Codex as UI implementer too: slow at CSS, burned the
  metered budget, and forced a Design → Codex → Frontend hop with cold re-reads. User feedback:
  "making codex the UI implementer is too much token for him and the process is too slow."

### Who
- Decision = user; encoded into kit by Orchestrator (Opus). Docs-only change (bash -n N/A).

## Feed overhaul wired + session isolation — 2026-06-21

### Feed pipeline wired
- ask-codex.sh and ask-gemini.sh now emit feed bookends via `team.sh post` ("▶ working" before turn, "✓ done" after) and stream seat stdout through `team.sh feedfilter`. Result: each seat's thinking shows live in feed pane, tagged by seat.
- Verified: "▶ working" and "✓ done" bookends land in .team/feed.log; prose lines forward with seat "│" separator; awk filter correctly drops Codex banner, echoed prompt, "+"/"-" diff lines, "?? " git-status noise, and "tokens used" marker; flock'd append confirmed.

### ask-gemini per-seat session isolation
- ask-gemini.sh now starts fresh Gemini session by DEFAULT; `--continue` opts in to reuse prior. Fixes cross-seat context bleed (plain `agy -c` grabbed GLOBAL most-recent conversation, mixing different seats' contexts).

### Verification
- Smoke-tested post + feedfilter pipeline against realistic raw-Codex output sample.
- All shell scripts pass `bash -n`.

### Who
- Implementer/tooling = Codex; wiring verified by Orchestrator (Opus).

## Agent-kit workflow upgrade — 2026-06-20

### Gemini seats added
- New `bin/ask-gemini.sh` drives Antigravity CLI (`agy`) on Google AI Pro subscription (not metered API key). Default model Gemini 3.1 Pro (High), override via GEMINI_MODEL.
- Design Critic reassigned Claude Opus → Gemini (multimodal; verified reads PNG screenshots).
- New Frontend Developer seat → Gemini (owns UI layer: components/layout/CSS).
- Added roles/frontend-developer.md; updated roles/design-critic.md, MODELS.md, README.md, bin/team.sh roster.

### QA reassigned
- QA / Tester reassigned Claude Sonnet → Codex (runs build, vitest, behavioral checks).
- Confirmed Codex IS multimodal via `codex exec -i <image>` (verified reads screenshot); QA can visually confirm renders; Design Critic stays Gemini by taste-choice, not capability.
- Added optional image attachment support to bin/ask-codex.sh (`-i ... --`).

### Rules / loop (templates/)
- Split standing rules into templates/RULES.md (separate from templates/LOOP.md flow).
- RULES section 4: Design Critic convergence loop (MAX_DESIGN_ROUNDS=3; re-screenshot after each fix to prevent silent breakage).
- RULES section 4c: mechanical gate — milestone passes only when seat verdict lines (QA: PASS, DESIGN-CRITIC: PASS) physically present in .team/feed.log; enforced by `team.sh gate`.
- RULES section 6: shared .team/CONTEXT.md — brief seats by pointer, not re-explaining (token saver).
- RULES section 7: Scribe records EVERY change before commit (new rule).

### team.sh tooling
- New `gate` command (greps feed.log for seat verdicts; exit 1 + names missing seat).
- New `post` command (flock'd, uniform feed writer — prevents torn lines from concurrent appends).
- New `feedfilter` command (streams seat stdout to feed live, drops code/diff/ls/metadata noise, keeps prose — feed shows agent thinking).
- `view` now labels panes (CONVERSATION / BUILD-VERIFY / DEV SERVER / ROSTER) and adds live dev-server pane.
- `init` now seeds .team/CONTEXT.md.

### Verification
- All shell scripts pass `bash -n`.
- `team.sh gate` correctly blocks when verdict missing, opens when present.
- `feedfilter` tested against 41k-line conversation.log (keeps prose, drops code).
- `agy` and `codex exec -i` image reads both verified live.
