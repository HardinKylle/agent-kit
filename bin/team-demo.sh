#!/usr/bin/env bash
# team-demo.sh — replay a realistic milestone with FULL agent replies (not summaries),
# so the transcript pane looks like a real Opus/Codex/Sonnet build conversation.
set -uo pipefail
PROJECT="${1:?usage: team-demo.sh <project>}"
T="$(cd "$(dirname "$0")" && pwd)/team.sh"
S()   { bash "$T" set "$PROJECT" "$@"; }
BLD() { bash "$T" build "$PROJECT" "$@"; }
MSG() { bash "$T" msg "$PROJECT" "$@"; }   # role model [to]  (body on stdin)
P()   { sleep "${1:-1}"; }

bash "$T" init "$PROJECT"

# ── Orchestrator opens the milestone ───────────────────────────────────────
S orchestrator routing "open M3"
MSG orchestrator Opus architect <<'EOF'
Milestone M3: wire the step grid to the audio engine. Constraints: 16 steps,
Tone.js transport, must stay 60fps with 64 cells. Architect — give me the module
split and the state shape before anyone writes code.
EOF
P 2

# ── Architect (Opus) — full proposal ───────────────────────────────────────
S architect working "module layout"
MSG architect Opus implementer <<'EOF'
Proposal — split simulation from rendering so the audio clock never blocks paint:

  src/audio/engine.ts     Tone.Transport wrapper; schedule() reads steps[] each tick
  src/state/useGrid.ts    Zustand store: steps: boolean[16], bpm, playing, current
  src/ui/Grid.tsx         pure render of steps + current playhead; dispatches toggle

Key calls:
 1. Store holds ONLY serializable state (boolean[]), not Tone nodes — keeps it testable.
 2. engine subscribes to the store; on each 16n tick it triggers synths for active
    steps and setState({current}) so the playhead is derived, not pushed per-cell.
 3. Toggling a cell mutates steps[i] immutably; engine reads the latest on next tick.

Trade-off I'm rejecting: storing Tone nodes in Zustand. It couples render to audio
and makes the store unserializable (kills presets in M5). Implementer — push back if
the per-tick setState causes re-render churn; we may need a ref for `current`.
EOF
S architect done "proposed layout"; P 3

# ── Implementer (Codex) — full reply + diff ────────────────────────────────
S implementer working "wire grid -> audio"
MSG implementer Codex reviewer <<'EOF'
Implemented per the split. One pushback landed: per-tick setState({current}) DID
cause the whole Grid to re-render 16x/sec. Fixed by keeping `current` in a ref and
only re-rendering the single active cell via a tiny <Playhead/> subscriber.

  diff --git a/src/audio/engine.ts  (+96)
    + transport.scheduleRepeat((time) => {
    +   const { steps } = useGrid.getState();
    +   steps.forEach((on, i) => { if (on) synth.triggerAttackRelease("C2", "16n", time); });
    +   currentRef.current = (currentRef.current + 1) % 16;
    + }, "16n");

  diff --git a/src/ui/Grid.tsx       (+71 -14)
    - {steps.map((on,i) => <Cell active={i===current} .../>)}   // re-rendered all
    + {steps.map((on,i) => <Cell on={on} index={i} onToggle={toggle} />)}
    + <Playhead/>   // subscribes to currentRef, moves a single absolutely-positioned bar

Build is green locally. Reviewer — flagging the synth is mono; rapid steps may clip
the tail. Want me to pool voices now or defer to polish?
EOF
S implementer done "M3 patch"; P 3

# ── Reviewer (Codex) — full critique ───────────────────────────────────────
S reviewer working "reading diff"
MSG reviewer Codex implementer <<'EOF'
Read the diff. Two findings:

  [P0] Visual: an ON step and an OFF step are nearly identical (#2a2a2a vs #303030).
       On a real screenshot you cannot tell what the pattern is. This fails the
       "done = observed behavior" gate. Fix the contrast before this counts.

  [P1] Leak: scheduleRepeat is registered on mount but never cleared; toggling play
       twice stacks two repeats → double triggers + a runaway rAF on stop. Add
       transport.clear(id) + cancelAnimationFrame in the cleanup.

Mono synth tail: DEFER to polish, not a blocker. Sign-off is blocked on P0+P1.
EOF
S reviewer blocked "P0+P1 raised"; P 3

# ── Implementer fixes ──────────────────────────────────────────────────────
S implementer working "fix P0+P1"
MSG implementer Codex reviewer <<'EOF'
Both addressed:
  P0  ON cell now filled cobalt (#2563EB) with a 1px inset ring; OFF is bare #141414.
      Contrast ratio 6.1:1 — pattern is unmistakable in the screenshot.
  P1  Stored the repeat id; cleanup now does transport.clear(id) and
      cancelAnimationFrame(rafId). Toggling play 5x → exactly one active repeat.
Re-running build + QA.
EOF
S implementer done "P0/P1 fixed"; S reviewer done "sign-off clean"; P 2

# ── Gate: build + QA verify on real screenshot ─────────────────────────────
S orchestrator routing "gate M3"
BLD "pnpm build … ✓ 412 modules, built in 1.42s"; P 1
S qa-tester verifying "ui-review screenshot"
BLD "node ui-review.mjs --url :5173 --name m3 … shot saved, console: 0 errors"
MSG qa-tester Sonnet orchestrator <<'EOF'
Behavioral check on the rendered app (not the build):
  • Loaded :5173, clicked 6 cells in a backbeat pattern — all 6 fill cobalt, clear pattern.
  • Hit play — playhead bar sweeps left→right, lands on each lit step audibly on the beat.
  • Toggled play 5x — no double-trigger, no stuck playhead (P1 confirmed fixed).
  • Console: 0 errors, 0 warnings. Screenshot: artifacts/m3.png.
Verdict: M3 behavior VERIFIED.
EOF
S qa-tester done "M3 verified"; P 2

# ── Design critic (Opus) — taste pass ──────────────────────────────────────
S design-critic verifying "judging taste"
MSG design-critic Opus orchestrator <<'EOF'
Score 7 → 8. The cobalt fill fixed legibility — pattern reads instantly now. Two
notes, both NON-blocking (log for polish M6):
  - Cell radius (8px) feels soft against the brutalist frame; try 2px or 0.
  - Playhead is 1px and easy to lose at 140bpm; bump to 2px + slight glow.
Taste is shippable. No P0.
EOF
S design-critic done "score 8/10"; P 2

# ── Scribe records, gate passes ────────────────────────────────────────────
S scribe working "CHANGELOG"
BLD "git commit 367f294  feat(grid): wire steps to audio engine"
MSG scribe Haiku orchestrator <<'EOF'
CHANGELOG ← ## M3 Interactive grid — 2026-06-20
  What: grid wired to audio; ON fills cobalt, playhead sweeps, no leak.
  Who: Codex (impl); Codex reviewer (P0/P1); QA Sonnet + Design-Critic Opus (7→8).
  Why: reviewer P0 — on/off steps were indistinguishable.
  Verified: build green; screenshot shows pattern + moving playhead; 0 console errors.
  Commit: 367f294
EOF
S scribe done "logged 367f294"
S orchestrator routing "M3 GATE PASSED → plan M4"
MSG orchestrator Opus architect <<'EOF'
M3 passed all gates (build + observed behavior + clean review). Moving on.
Architect — next is M4: named presets + PNG export. Same drill: layout before code.
EOF
P 1
