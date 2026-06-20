# The standard milestone loop

Every project runs the same loop. The Orchestrator drives it; teammates plug in at their step.

```
0. PLAN        Orchestrator → milestone breakdown (TaskCreate)
               Researcher (web) de-risks unknowns BEFORE code
1. ARCHITECT   (new structure only) propose file/module layout
─── per milestone ───────────────────────────────────────────
2. IMPLEMENT   Codex via ask-codex.sh, brief enriched w/ research + prior notes
3. CODE REVIEW Codex reviewer reads the diff → P0/P1 findings → Codex fixes
4. VERIFY      build green  +  QA runs ui-review.mjs (screenshot + console + download)
               Orchestrator READS the screenshot; Design Critic judges (UI milestones)
5. GATE        milestone counts ONLY when: build green + behavior observed + review clean
6. RECORD      Scribe updates CHANGELOG + decision log (who/what/why + commit hash)
7. COMMIT      Conventional Commit → push → confirm auto-deploy
─────────────────────────────────────────────────────────────
8. FINISH      final verify, README, auto-open / live URL
```

## Non-negotiable gates
- **Behavioral verification, not just builds.** Look at the running output every milestone.
- **Verify per-milestone**, not only at the end.
- **Automate the "show me"** (terminal + browser) from turn one.
- **Honor plan commitments** (e.g. tests) or announce the cut explicitly.
