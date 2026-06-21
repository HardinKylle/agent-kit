# The adaptive milestone loop

The Orchestrator chooses the lightest workflow mode that can responsibly ship the change, then
routes only the seats that add value. The full loop is the **production** path, not the default tax
for every edit. Policies live in [RULES.md](./RULES.md). Role → model mapping is in [MODELS.md](./MODELS.md).

```
0. MODE        Orchestrator records mode: tiny | logic | ui | production
               team.sh mode . M3 ui "layout change; needs screenshot + QA"
1. PLAN        Orchestrator → milestone breakdown (TaskCreate)
               Researcher (web) de-risks unknowns BEFORE code
2. ARCHITECT   (new structure only) propose file/module layout
─── per milestone ───────────────────────────────────────────
3. IMPLEMENT   Route by LAYER (RULES §1b):
                 • logic/engine/state → Implementer (Codex) via ask-codex.sh
                 • UI/view layer      → Frontend (Gemini) via ask-gemini.sh
               (these two can run in PARALLEL; Codex never writes UI)
4. REVIEW      Reviewer (Codex) ⇄ Implementer, when mode/risk requires it → RULES: Review convergence
5. QA          QA (Codex) runs official checks + behavioral when required  → RULES: QA gate
5b. DESIGN     Design Critic ⇄ FRONTEND (Gemini), for visual-risk UI      → RULES: UI visual check
6. GATE        counts ONLY when required scoped verdicts exist             → RULES 4c
7. RECORD      Scribe/Orchestrator records change according to mode
8. COMMIT      Conventional Commit → push → confirm auto-deploy (ask before push/deploy)
─────────────────────────────────────────────────────────────
9. FINISH      final verify, README, auto-open / live URL
```

## Modes
- **tiny:** Orchestrator only. Use for copy/docs/config or one-file low-risk fixes. Run the local
  check directly and record the mode/summary; do not spawn cold seats by default.
- **logic:** Codex Implementer + Reviewer. Add QA when tests/build cannot prove behavior.
- **ui:** Gemini Frontend + QA screenshot/behavior. Add Design Critic when composition, hierarchy,
  responsive layout, brand/taste, or neighbor regressions matter.
- **production:** Full loop. Use for releases, deploys, broad refactors, high-risk user-facing work,
  or when a lighter mode finds real uncertainty.

## Per-step pointers
- **Step 3 — Implement.** Routed by layer (RULES §1b): Codex writes LOGIC, Gemini Frontend writes
  UI — in parallel where they don't block. One seat = one context; resume Codex across review→fix
  rather than cold `--reset` each turn. Codex never styles.
- **Step 4 — Review.** Codex reviewer hunts bugs and loops with the implementer to ~zero P0/P1.
  Convergence rule + round cap → RULES.md.
- **Step 5 — QA.** Codex runs *official* checks (typecheck, tests, behavioral). No test runner =
  a finding, not a pass → RULES.md.
- **Step 5b — Design.** For visual-risk UI, the Design Critic actually LOOKS at the screenshot and
  loops with the **Frontend (Gemini)** until composition converges — a fix can't silently break a
  neighbor. Feedback goes Critic ⇄ Frontend directly, never via Codex → RULES.md.
- **Step 6 — Gate.** The Orchestrator gates on milestone-scoped verdicts in `.team/verdicts/`
  (`team.sh verdict` + `team.sh gate --milestone ...`) — never its own glance (role discipline + 4c → RULES.md).

> Seats read `.team/CONTEXT.md` for project context — briefs point there, don't re-explain (RULES 6).

> Every seat must be visible in the feed pane as it works — see RULES.md "Visibility".
