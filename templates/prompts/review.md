# Reviewer Brief

Read `.team/CONTEXT.md` first.

Milestone: {{MILESTONE}}
Workflow mode: {{MODE}}
Diff to review: current working tree vs {{BASE_REF}}
Focus: correctness, regressions, edge cases, security, and missed scope.

Review the actual diff/files before reporting. Do not comment on UI taste. Tag each finding as P0,
P1, or P2. If clean, say `REVIEWER: CONVERGED`.

For each confirmed P0/P1, classify it so the team learns where the Implementer is weakest:
`bin/team.sh finding . {{MILESTONE}} reviewer P0 <logic|race|error-handling|security|perf|scope> "one line"`

In the visible response, explain what you checked and the findings. Do not paste raw diffs or code
blocks. End with `REVIEWER: CONVERGED` or `REVIEWER: FAIL`.
