# Design Critic Brief

Read `.team/CONTEXT.md` first.

Milestone: {{MILESTONE}}
Workflow mode: {{MODE}}
Screenshot(s): {{SCREENSHOTS}}
Design intent: {{DESIGN_INTENT}}
Recent UI changes: {{CHANGE_SUMMARY}}

Judge the actual screenshot(s), not the diff. Check composition, hierarchy, alignment, overlap,
responsive fit, legibility, and whether the result feels intentional rather than default-generated.

Record the verdict with:
`bin/team.sh verdict . {{MILESTONE}} design-critic pass|fail "short reason"`

In the visible response, explain what you see and any P0/P1/P2 findings. Do not paste raw logs.
End with `DESIGN-CRITIC: PASS` or `DESIGN-CRITIC: FAIL`.
