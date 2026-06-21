#!/usr/bin/env bash
# team-demo.sh — replay the intended pane style:
# orchestrator prompt → filtered agent response → changed files/verdicts.
set -uo pipefail
PROJECT="${1:?usage: team-demo.sh <project>}"
T="$(cd "$(dirname "$0")" && pwd)/team.sh"
S()   { bash "$T" set "$PROJECT" "$@"; }
BLD() { bash "$T" build "$PROJECT" "$@"; }
MSG() { bash "$T" msg "$PROJECT" "$@"; }       # role model [to]  (body on stdin)
H()   { bash "$T" handoff "$PROJECT" "$@"; }   # from to milestone [body]
P()   { sleep "${1:-1}"; }

bash "$T" init "$PROJECT"

# ── Orchestrator chooses a mode and sends the actual task prompt ───────────
S orchestrator routing "M3 mode + handoff"
bash "$T" mode "$PROJECT" M3 logic "audio-state change; reviewer required; no UI styling"
H orchestrator implementer M3 <<'EOF'
Task: wire the step grid to the audio engine.
Scope: audio engine + grid state only. Do not touch CSS.
Success: play/stop does not stack scheduled repeats; build passes.
Handoff: end with changed files, checks, and READY FOR REVIEW.
EOF
P 2

# ── Implementer response: normal prose, no raw diff/code ───────────────────
S implementer working "wire grid playback"
MSG implementer Codex reviewer <<'EOF'
I checked the existing grid state first so the audio clock would use the current pattern without
coupling Tone nodes into the store. The implementation keeps the transport wrapper responsible for
scheduling and stores the repeat id so cleanup is explicit.

Changed files:
- M src/audio/engine.ts — schedules active steps and clears the repeat id on stop/unmount
- M src/state/useGrid.ts — exposes the current pattern read path used by the engine

Checks:
- npm run build: pass

READY FOR REVIEW
EOF
bash "$T" post "$PROJECT" implementer "CHANGES vs HEAD — 2 files changed, +84/-12 | M:src/audio/engine.ts M:src/state/useGrid.ts"
S implementer done "ready for review"; P 2

# ── Orchestrator prompt to reviewer ────────────────────────────────────────
H orchestrator reviewer M3 <<'EOF'
Review the M3 diff for correctness and leaks.
Focus: repeated play/stop, cleanup, stale state reads, and missed scope.
Do not comment on visual taste.
EOF
S reviewer working "review M3 diff"; P 1

MSG reviewer Codex implementer <<'EOF'
I checked the scheduling path, stop path, and the state read used by the transport. The separation is
right, but there is one blocker.

Findings:
- P1 src/audio/engine.ts — stop clears the Tone repeat but leaves the animation frame active, so a
  play/stop loop can leave a stale playhead update running.

No UI-scope drift found.

REVIEWER: FAIL
EOF
S reviewer blocked "P1 cleanup"; P 2

# ── Implementer fix response ───────────────────────────────────────────────
H orchestrator implementer M3 <<'EOF'
Fix reviewer P1 only.
Scope: cleanup path for playhead animation. Do not refactor unrelated engine code.
EOF
S implementer working "fix cleanup"; P 1

MSG implementer Codex reviewer <<'EOF'
I kept the fix limited to cleanup. The engine now stores the animation frame id beside the repeat id
and cancels it on stop/unmount.

Changed files:
- M src/audio/engine.ts — cancels the playhead animation frame during cleanup

Checks:
- npm run build: pass
- manual play/stop loop: one active repeat, no stale playhead update

READY FOR REVIEW
EOF
bash "$T" post "$PROJECT" implementer "CHANGES vs HEAD — 1 file changed, +9/-2 | M:src/audio/engine.ts"
S implementer done "P1 fixed"
bash "$T" verdict "$PROJECT" M3 reviewer converged "cleanup finding fixed"; P 2

# ── QA prompt + response ───────────────────────────────────────────────────
H orchestrator qa-tester M3 <<'EOF'
Run objective checks for M3.
Checks: build and browser behavior.
Behavior: grid plays active steps, play/stop does not double-trigger, no console errors.
EOF
S qa-tester verifying "build + browser check"
BLD "npm run build … pass"; P 1
BLD "ui-review --url :5173 --name m3 --viewport desktop,mobile … pass"
MSG qa-tester Codex orchestrator <<'EOF'
I ran the build and browser behavior check. The grid rendered, active steps played on the beat, and
repeated play/stop did not double-trigger.

Artifacts:
- shots/m3-desktop.png
- shots/m3-mobile.png

QA: PASS
EOF
bash "$T" verdict "$PROJECT" M3 qa-tester pass "build + behavior pass; screenshots clean"
S qa-tester done "M3 verified"; P 2

# ── Gate ───────────────────────────────────────────────────────────────────
bash "$T" gate "$PROJECT" --milestone M3 reviewer qa
S orchestrator done "M3 gate passed"
MSG orchestrator Opus user <<'EOF'
M3 passed in logic mode. Full design/scribe loop was intentionally skipped because this was not a
visual-risk milestone. Next: decide whether M4 is ui or production mode before routing agents.
EOF
P 1
