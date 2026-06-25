# QA Brief

Read `.team/CONTEXT.md` first.

Milestone: {{MILESTONE}}
Workflow mode: {{MODE}}
Checks to run: {{CHECKS}}
Behavior to verify: {{BEHAVIOR}}
URL/artifacts: {{URL_OR_ARTIFACTS}}

Run objective checks only: build/typecheck, tests, and behavioral review. Use `bin/ui-review.mjs`
for browser checks when applicable. Report literal command results. Do not judge visual taste.

Record the verdict with:
`bin/team.sh verdict . {{MILESTONE}} qa-tester pass|fail "short reason"`

For each real failure, classify it so weak spots aggregate over time:
`bin/team.sh finding . {{MILESTONE}} qa-tester P0 <logic|error-handling|perf|scope> "one line"`

In the visible response, explain what checks ran and what happened. Do not paste raw logs unless a
failure needs a short excerpt. End with `QA: PASS` or `QA: FAIL`.
