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
3. IMPLEMENT   Implementer (Codex, session A) writes ALL code — logic + UI/CSS — via ask-codex.sh
4. REVIEW      Reviewer (Codex, session B) ⇄ Implementer, when mode/risk requires → RULES: Review convergence
5. QA          QA (Claude Sonnet) runs official checks + behavioral when required → RULES: QA gate
5b. DESIGN     Design Critic (Gemini) ⇄ Implementer, parallel, for visual-risk UI → RULES: UI visual check
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
- **ui:** Codex Implementer writes the UI + QA screenshot/behavior. Add Design Critic when composition,
  hierarchy, responsive layout, brand/taste, or neighbor regressions matter (run it in parallel).
- **production:** Full loop. Use for releases, deploys, broad refactors, high-risk user-facing work,
  or when a lighter mode finds real uncertainty.

## Per-step pointers
- **Step 3 — Implement.** The Implementer (Codex, session A) writes LOGIC and UI/CSS and applies fixes,
  all in one persistent thread resumed across review→fix — never cold `--reset` (RULES §1b).
- **Step 4 — Review.** The Reviewer (Codex, session B — separate from the Implementer) hunts bugs and
  loops with the implementer to ~zero P0/P1. It only sees diffs, so it stays independent of the author.
  Convergence rule + round cap → RULES.md.
- **Step 5 — QA.** Claude Sonnet runs *official* checks (typecheck, tests, behavioral). No test runner =
  a finding, not a pass → RULES.md.
- **Step 5b — Design.** For visual-risk UI, the Design Critic (Gemini) actually LOOKS at the screenshot
  and loops until composition converges — a fix can't silently break a neighbor. It runs in parallel
  once the shell exists; findings batch back to the Implementer (Codex) → RULES.md.
- **Step 6 — Gate.** The Orchestrator gates on milestone-scoped verdicts in `.team/verdicts/`
  (`team.sh verdict` + `team.sh gate --milestone ...`) — never its own glance (role discipline + 4c → RULES.md).

> Seats read `.team/CONTEXT.md` for project context — briefs point there, don't re-explain (RULES 6).

> Every seat must be visible in the feed pane as it works — see RULES.md "Visibility".
