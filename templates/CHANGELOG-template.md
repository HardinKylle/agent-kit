# Changelog

Maintained by the Scribe. One entry per verified milestone. Format:

## <milestone> — <date>
- **What:** one line on what shipped.
- **Who:** which agent(s) — Implementer (Codex), and who reviewed/researched/critiqued.
- **Why:** the decision/driver (e.g. "Researcher flagged deprecated API"; "QA caught on/off P0").
- **Verified:** build + behavioral check result (screenshot/console/download).
- **Commit:** `<hash>`

---

## Example
## M3 Interactive grid — 2026-06-20
- **What:** grid wired to audio; ON fills cell, orange playhead, mute/solo, velocity.
- **Who:** Codex (impl); QA + Design Critic (review, 7→8); Researcher (tone.js timing).
- **Why:** Design Critic's P0 — on/off steps were indistinguishable.
- **Verified:** build green; screenshot shows clear pattern + moving playhead; no console errors.
- **Commit:** `367f294`
