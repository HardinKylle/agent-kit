# Standing rules

The invariants that govern HOW seats behave, regardless of which step of the loop you're in.
The step sequence itself is in [LOOP.md](./LOOP.md); role → model mapping is in [MODELS.md](./MODELS.md).

## 1. Role discipline — the Orchestrator does NOT do the work (hard rule)
The Orchestrator coordinates, routes, and arbitrates conflicting reports. It must NOT personally:
- read/judge screenshots or UI composition   → that is the **Design Critic (Opus)** seat
- run or interpret tests / behavioral checks  → that is the **QA (Sonnet)** seat
- review or write implementation code         → that is the **Reviewer / Implementer (Codex)** seats

If a step needs eyes, hands, or a verdict, **spawn the assigned seat and relay its verdict** — do
NOT collapse seats by "wearing the hat" yourself, even when the Orchestrator runs the same model
(Opus orchestrator ≠ Opus design critic; separate seats, separate context). The Orchestrator's only
direct outputs are routing, briefs, and final arbitration when seats disagree. A milestone verdict
must cite the ASSIGNED seat's report, never the Orchestrator's own glance.

## 2. Review convergence (owner: Code Reviewer = Codex)
The reviewer is the bug *detector*, so the drive-to-zero loop lives here.

```
round = 1
loop:
  reviewer (Codex) reads the diff → findings tagged P0/P1/P2 (+ "NONE" if clean)
  if no P0/P1 findings OR round > MAX_REVIEW_ROUNDS (default 3): break
  implementer (Codex) fixes every P0/P1 (P2 if cheap)
  round += 1
```
- A round that surfaces only P2s (or NONE) **converges** — stop, don't chase cosmetics forever.
- The cap (`MAX_REVIEW_ROUNDS`, default 3) prevents infinite spin. If P0/P1 remain at the cap, the
  Orchestrator escalates (re-scopes or decides) — never silently passes.
- The Orchestrator arbitrates reviewer disagreements from first principles; a reviewer's tag is an
  input, not a verdict.

## 3. QA gate (owner: QA / Tester = Sonnet)
QA runs the project's **official, objective** checks — not vibes:

```
1. typecheck / compile   (e.g. tsc -b, build)
2. unit tests            (e.g. vitest run, npm test) — REQUIRED if the project has a suite
3. behavioral check      (ui-review.mjs: screenshot + console errors + download)
```
- No test runner yet = itself a finding: QA flags the gap; the team adds at least smoke tests for
  the milestone's surface before the gate can pass.
- QA reports pass/fail per check verbatim; a single red check blocks the gate.
- QA judges "does it work / is anything broken" — NOT taste/composition (that's the Design Critic).

## 4. UI visual check (owner: Design Critic = Opus) — REQUIRED for any UI change
If the milestone added or altered ANY UI element/layout/style, the Design Critic MUST run before the
gate. A green build and a captured screenshot are NOT enough — someone has to actually LOOK.

```
1. screenshot the running app (ui-review.mjs)
2. Design Critic READS the image and judges COMPOSITION, not just function:
   - nothing overlapping / covered / clipped (wordmark, labels, values)
   - alignment & balance (is it placed where it should be?)
   - new element fits the existing visual language
   - check the responsive breakpoints too
3. Findings → routed to the Implementer like any other P-tagged issue
```
- The Reviewer (Codex) sees the DIFF only — it cannot catch "the logo is covered." That is the
  Design Critic's job.

## 5. Visibility — every seat shows up in the feed (not just Codex)
Codex seats stream into `feed.log` because the orchestrator `tee`s their output. Claude seats
(Design Critic, QA, Researcher…) run as subagents whose replies return to the orchestrator only —
INVISIBLE in the feed pane unless surfaced. Two-layer rule:
1. Each Claude seat's brief instructs it to append its findings to `<project>/.team/feed.log` as it
   works (it has shell access), so the team pane shows it live.
2. The orchestrator ALSO posts each seat's returned verdict to the feed (`team.sh msg`) as a backup,
   so no seat is ever silent in the pane.
The user watches the team in the feed pane — a seat that never appears there looks like it never ran.

## 6. Non-negotiable gates
- **Behavioral verification, not just builds.** Look at the running output every milestone.
- **Any UI change gets a Design Critic visual check before it counts.** Build-green ≠ looks-right.
- **Verify per-milestone**, not only at the end.
- **Automate the "show me"** (terminal + browser) from turn one.
- **Honor plan commitments** (e.g. tests) or announce the cut explicitly.
- **Ask before `git push` / deploy** — outward-facing, hard-to-undo actions need explicit OK.
