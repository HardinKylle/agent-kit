# Standing rules

The invariants that govern HOW seats behave, regardless of which step of the loop you're in.
The step sequence itself is in [LOOP.md](./LOOP.md); role → model mapping is in [MODELS.md](./MODELS.md).

## 1. Role discipline — the Orchestrator does NOT do the work (hard rule)
The Orchestrator coordinates, routes, and arbitrates conflicting reports. It must NOT personally:
- read/judge screenshots or UI composition   → that is the **Design Critic (Gemini)** seat
- interpret test / behavioral verdicts        → that is the **QA (Claude Sonnet)** seat
- review or write implementation code         → that is the **Reviewer / Implementer (Codex)** seats

If a step needs eyes, hands, or a verdict, **spawn the assigned seat and relay its verdict** — do
NOT collapse seats by "wearing the hat" yourself, even when another seat uses a familiar runtime.
The Orchestrator may launch deterministic commands, but seat-owned judgments still come from that
seat's report. The Orchestrator's only direct outputs are routing, briefs, and final arbitration when
seats disagree. A milestone verdict must cite the ASSIGNED seat's report, never the Orchestrator's
own glance.

## 1a. Adaptive workflow mode — full team is available, not mandatory
At the start of each milestone, the Orchestrator chooses and records the lightest responsible mode:

```
bin/team.sh mode . M3 tiny       "docs-only wording fix"
bin/team.sh mode . M4 logic      "state behavior change; reviewer required"
bin/team.sh mode . M5 ui         "responsive toolbar change; QA screenshot required"
bin/team.sh mode . M6 production "release milestone; full gates"
```

- **tiny:** Orchestrator runs direct local checks. No cold seats unless the change stops being tiny.
- **logic:** use Codex Implementer/Reviewer; add QA if behavior is not objectively covered by checks.
- **ui:** use the Codex Implementer for the UI and QA behavioral screenshot; add Design Critic for composition/taste risk (run it in parallel once the shell exists).
- **production:** run the full loop: research/architect if needed, implement, review, QA, design, scribe.
- Escalate modes when uncertainty appears. Never downgrade a mode just to avoid a failing gate.
- Folding a seat is fine when the chosen mode does not need it; record the mode so it is intentional.

## 1b. One persistent session per role (hard rule)
Every seat is a fixed `(model, session)` pair, captured once and resumed by id each turn so it never
re-derives context. `ask-codex.sh` keys the session on `CODEX_ROLE`; `ask-gemini.sh` on the role label.

- **Implementer (Codex, session A)** — writes all code (logic + UI/CSS) and applies fixes.
- **Reviewer (Codex, session B)** — finds bugs in the diff. A separate thread from the Implementer, so
  it sees only diffs, never the writer's reasoning: an independent reviewer that stays warm.
- **QA (Claude Sonnet, own session)** — runs the objective checks; independent of Codex and Gemini, and
  cheap enough to keep the Opus Orchestrator out of testing. Spawn once, resume by name.
- **Researcher + Design Critic (Gemini, own sessions)** — Researcher covers all external lookup (topics,
  designs, references, libraries); the Critic judges screenshots.
- Independence is structural (separate session), so each seat resumes warm — never collapse two roles
  into one session.

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

## 3. QA gate (owner: QA / Tester = Claude Sonnet)
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

## 4. UI visual check (owner: Design Critic = Gemini)
If the milestone materially changes layout, responsive behavior, visual hierarchy, brand/taste, or a
neighboring UI region, the Design Critic MUST run before the gate. Copy-only UI and mechanically
obvious one-control fixes can stay in tiny/ui mode with QA screenshot only, but the Orchestrator must
record that mode choice. A green build and a captured screenshot are not enough for visual-risk UI.

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
- The Design Critic runs in PARALLEL with ongoing implementation once the UI shell exists — batch its
  findings back to the Implementer rather than blocking every turn.
- Trigger threshold: visual-risk UI changes loop at least once. A *major* UI change (new control,
  layout reflow) re-screenshots after each fix so a fix can't silently break a neighbor.
- Converges on a round with only P2s or NONE. At the cap with P0/P1 left, the Orchestrator escalates.

## 4c. Mechanical gate — the verdict must be scoped, not in the Orchestrator's head
A milestone passes only when the assigned seats' verdicts are physically present in
`<project>/.team/verdicts/<milestone>.jsonl`. The gate reads structured records, not memory:

```
QA gate      → team.sh verdict . M3 qa-tester pass "build + behavior clean"
Design gate  → team.sh verdict . M3 design-critic pass "no visual blockers"

# enforced by:  team.sh gate <project> --milestone <id> <seat...>
#   e.g.  bin/team.sh gate . --milestone M3 qa design-critic       # UI milestone
#         bin/team.sh gate . --milestone M3 qa                      # non-UI milestone
```
- No record → no pass. This converts "I promise I routed it" into proof a separate seat ran, and is the
  structural backstop to §1 (role discipline): the Orchestrator literally cannot self-certify because
  its own glance never writes a seat verdict record.
- Legacy `team.sh gate <project> <seat...>` still greps `feed.log` for compatibility, but new
  milestones should always pass `--milestone` so old PASS lines cannot leak into a new gate.

## 5. Visibility — every seat shows up in the feed (not just Codex)
Codex/Gemini seats stream into `feed.log` because the runner scripts `tee` their output. Claude seats
(Researcher, Architect, Scribe…) run as subagents whose replies return to the orchestrator only —
INVISIBLE in the feed pane unless surfaced. Two-layer rule:
1. Each Claude seat's brief instructs it to append its findings to `<project>/.team/feed.log` as it
   works (it has shell access), so the team pane shows it live.
2. The orchestrator ALSO posts each seat's returned verdict to the feed (`team.sh msg`) as a backup,
   so no seat is ever silent in the pane.
The user watches the team in the feed pane — a seat that never appears there looks like it never ran.

**Change summaries, not raw code.** The feed shows what CHANGED, never a wall of diff/CSS. `feedfilter`
drops code lines (anything ending in `{ } ; ( ,`, JS/CSS keywords, selectors) and forwards only prose;
`ask-codex.sh`/`ask-gemini.sh` post a `CHANGES vs HEAD — N files, +X/-Y | M:path …` summary after every
turn. Brief implementer turns to END with a one-line WHAT summary. The reader tracks progress from
summaries + prose, never from streamed source.

## 6. Shared context file — brief seats by POINTER, not by re-explaining
Every subagent seat (Design Critic, QA, Researcher…) spawns COLD and re-derives the project from its
brief. Re-pasting "this is a React/Tone.js groovebox, stack is…, current milestone is…" into every
brief is the biggest avoidable Claude-token cost in a build.

- `team.sh init` seeds `<project>/.team/CONTEXT.md` — a short, stable brief: one paragraph on what the
  app IS, the stack, the public URL, and the CURRENT milestone. Keep it under ~20 lines.
- Every seat brief says **"read `.team/CONTEXT.md` first"** instead of inlining that context. The brief
  itself only carries the seat-specific task ("review THIS diff", "judge THIS screenshot").
- The Orchestrator updates the `CURRENT milestone` line each milestone (one `set`-style edit), so a
  cold seat always reads accurate state. Use `templates/prompts/` for seat-specific briefs. Heavy
  source reads still go to the Haiku File-Finder, never the Orchestrator's own context.

## 7. Documentation — record proportional to mode (owner: Scribe = Haiku when needed)
Nothing substantial is "done" until the decision and verification are written down. Documentation
effort scales by workflow mode:

- The Scribe maintains `CHANGELOG.md` (per `templates/CHANGELOG-template.md`): one entry per change with
  What / Who (which seats) / Why / Verified / Commit. It also keeps the decision log when a non-obvious
  call was made (who decided, why).
- **tiny:** Orchestrator may record a one-line summary in the feed/commit message; no Scribe seat.
- **logic/ui:** Orchestrator records the summary unless the change has non-obvious decisions.
- **production:** dispatch the Scribe before COMMIT. A production milestone without a CHANGELOG entry
  is a process failure.
- The Scribe runs on Haiku in its own context when invoked (cheap, terse, factual — no embellishment)
  and posts a `SCRIBE: …` line to the feed so its work is visible (§5).
- This applies to the kit itself: edits to agent-kit (roles, templates, bin/) get a CHANGELOG entry too.

## 8. Non-negotiable gates
- **Behavioral verification, not just builds.** Look at the running output every milestone.
- **Visual-risk UI gets a Design Critic check before it counts.** Build-green ≠ looks-right.
- **Verify per-milestone**, not only at the end.
- **Record proportional to mode** — production gets Scribe/CHANGELOG before commit (§7).
- **Automate the "show me"** (terminal + browser) from turn one.
- **Honor plan commitments** (e.g. tests) or announce the cut explicitly.
- **Ask before `git push` / deploy** — outward-facing, hard-to-undo actions need explicit OK.
