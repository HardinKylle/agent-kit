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

This is a **convergence loop**, same shape as the reviewer's (§2) — one pass is not enough. The swing
milestone proved it: a single Design Critic pass missed regressions that took three separate human
corrections (clipped BPM → covered wordmark → off-center visualizer). Loop it:

```
round = 1
loop:
  screenshot the running app at every responsive breakpoint (ui-review.mjs)
  Design Critic READS the images and judges COMPOSITION, not just function:
    - nothing overlapping / covered / clipped (wordmark, labels, values)
    - alignment & balance (is it placed where it should be?)
    - new element fits the existing visual language
    - the change didn't REGRESS a neighbor (the classic: new control squishes an old readout)
  findings tagged P0/P1/P2 (+ "NONE" if clean)
  if no P0/P1 findings OR round > MAX_DESIGN_ROUNDS (default 3): break
  Implementer (Codex) fixes every P0/P1; round += 1
```
- The Reviewer (Codex) sees the DIFF only — it cannot catch "the logo is covered." That is the
  Design Critic's job.
- Trigger threshold: ANY UI change loops at least once. A *major* UI change (new control, layout
  reflow) re-screenshots after each fix so a fix can't silently break a neighbor.
- Converges on a round with only P2s or NONE. At the cap with P0/P1 left, the Orchestrator escalates.

## 4c. Mechanical gate — the verdict must be IN THE LOG, not in the Orchestrator's head
A milestone passes only when the assigned seats' verdicts are physically present in
`<project>/.team/feed.log`. The gate is a grep, not a memory:

```
QA gate      → log line matching  'QA: PASS'            (or per-check PASS lines)
Design gate  → log line matching  'DESIGN-CRITIC: PASS' (UI milestones only)

# enforced by:  team.sh gate <project> <seat...>   (exit 1 + names the missing seat)
#   e.g.  bin/team.sh gate . qa design-critic       # UI milestone
#         bin/team.sh gate . qa                      # non-UI milestone
```
- No line → no pass. This converts "I promise I routed it" into proof a separate seat ran, and is the
  structural backstop to §1 (role discipline): the Orchestrator literally cannot self-certify because
  its own glance never writes a seat verdict line.

## 5. Visibility — every seat shows up in the feed (not just Codex)
Codex seats stream into `feed.log` because the orchestrator `tee`s their output. Claude seats
(Design Critic, QA, Researcher…) run as subagents whose replies return to the orchestrator only —
INVISIBLE in the feed pane unless surfaced. Two-layer rule:
1. Each Claude seat's brief instructs it to append its findings to `<project>/.team/feed.log` as it
   works (it has shell access), so the team pane shows it live.
2. The orchestrator ALSO posts each seat's returned verdict to the feed (`team.sh msg`) as a backup,
   so no seat is ever silent in the pane.
The user watches the team in the feed pane — a seat that never appears there looks like it never ran.

## 6. Shared context file — brief seats by POINTER, not by re-explaining
Every subagent seat (Design Critic, QA, Researcher…) spawns COLD and re-derives the project from its
brief. Re-pasting "this is a React/Tone.js groovebox, stack is…, current milestone is…" into every
brief is the biggest avoidable Claude-token cost in a build.

- `team.sh init` seeds `<project>/.team/CONTEXT.md` — a short, stable brief: one paragraph on what the
  app IS, the stack, the public URL, and the CURRENT milestone. Keep it under ~20 lines.
- Every seat brief says **"read `.team/CONTEXT.md` first"** instead of inlining that context. The brief
  itself only carries the seat-specific task ("review THIS diff", "judge THIS screenshot").
- The Orchestrator updates the `CURRENT milestone` line each milestone (one `set`-style edit), so a
  cold seat always reads accurate state. Heavy source reads still go to the Haiku File-Finder, never
  the Orchestrator's own context.

## 7. Documentation — the Scribe records EVERY change (owner: Scribe = Haiku)
Nothing the team changes is "done" until the Scribe has written it down. This is not per-LARGE-milestone
only — **every change to any repo gets a Scribe entry** (a feature, a fix, a tooling/kit edit, a config
change). Haiku is cheap; there is no excuse to skip it.

- The Scribe maintains `CHANGELOG.md` (per `templates/CHANGELOG-template.md`): one entry per change with
  What / Who (which seats) / Why / Verified / Commit. It also keeps the decision log when a non-obvious
  call was made (who decided, why).
- The Orchestrator MUST dispatch the Scribe at step 6 RECORD of every loop — before COMMIT. A change
  that reaches commit without a CHANGELOG entry is a process failure, same severity as skipping QA.
- The Scribe runs on Haiku in its own context (cheap, terse, factual — no embellishment) and posts a
  `SCRIBE: …` line to the feed so its work is visible (§5).
- This applies to the kit itself: edits to agent-kit (roles, templates, bin/) get a CHANGELOG entry too.

## 8. Non-negotiable gates
- **Behavioral verification, not just builds.** Look at the running output every milestone.
- **Any UI change gets a Design Critic visual check before it counts.** Build-green ≠ looks-right.
- **Verify per-milestone**, not only at the end.
- **Record every change** — the Scribe writes the CHANGELOG before commit (§7). No entry = not done.
- **Automate the "show me"** (terminal + browser) from turn one.
- **Honor plan commitments** (e.g. tests) or announce the cut explicitly.
- **Ask before `git push` / deploy** — outward-facing, hard-to-undo actions need explicit OK.
