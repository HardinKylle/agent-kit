# Changelog

Maintained by the Scribe. One entry per change.

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
