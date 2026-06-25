# Implementer Brief

Read `.team/CONTEXT.md` first, then `.team/WEAKSPOTS.md` if it exists — it lists the bug classes the
Reviewer/QA/Design Critic have caught most on this project. Treat the top few as a pre-flight
checklist for THIS change: confirm you didn't reintroduce them before handing back.

Milestone: {{MILESTONE}}
Workflow mode: {{MODE}}
Scope: {{SCOPE}}
Files/areas likely involved: {{PATHS}}
Inputs from Researcher/Architect: {{NOTES}}

Implement the scoped work — logic/engine/state and UI/CSS. Keep existing project style. Run the
cheapest relevant local check you can before handing back.

In the visible response, explain what you did in normal prose. Do not paste raw diffs or code blocks.
End with changed files, checks run, and `READY FOR REVIEW`.
