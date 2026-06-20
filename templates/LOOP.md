# The standard milestone loop

The **flow** every project runs, in order. The Orchestrator drives it; teammates plug in at their
step. This file is the sequence only — the policies that govern *how* each step behaves live in
[RULES.md](./RULES.md). Role → model mapping is in [MODELS.md](./MODELS.md).

```
0. PLAN        Orchestrator → milestone breakdown (TaskCreate)
               Researcher (web) de-risks unknowns BEFORE code
1. ARCHITECT   (new structure only) propose file/module layout
─── per milestone ───────────────────────────────────────────
2. IMPLEMENT   Implementer (Codex) via ask-codex.sh, brief enriched w/ research + prior notes
3. REVIEW      Reviewer (Codex) ⇄ Implementer, iterate until clean      → RULES: Review convergence
4. QA          QA (Sonnet) runs the official test suite + behavioral    → RULES: QA gate
4b. DESIGN     Design Critic (Opus) judges composition — UI changes ONLY → RULES: UI visual check
5. GATE        milestone counts ONLY when review converged + QA green + (UI) design PASS
6. RECORD      Scribe updates CHANGELOG + decision log (who/what/why + commit hash)
7. COMMIT      Conventional Commit → push → confirm auto-deploy (ask before push/deploy)
─────────────────────────────────────────────────────────────
8. FINISH      final verify, README, auto-open / live URL
```

## Per-step pointers
- **Step 2 — Implement.** Codex writes the code from an enriched brief. One seat = one context.
- **Step 3 — Review.** Codex reviewer hunts bugs and loops with the implementer to ~zero P0/P1.
  Convergence rule + round cap → RULES.md.
- **Step 4 — QA.** Sonnet runs *official* checks (typecheck, tests, behavioral). No test runner =
  a finding, not a pass → RULES.md.
- **Step 4b — Design.** For any UI-touching milestone, the Design Critic (Opus) actually LOOKS at
  the screenshot and judges composition. Required, not optional → RULES.md.
- **Step 5 — Gate.** The Orchestrator gates on the assigned seats' verdicts — never its own glance
  (role discipline → RULES.md).

> Every seat must be visible in the feed pane as it works — see RULES.md "Visibility".
