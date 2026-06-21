#!/usr/bin/env bash
# ask-gemini.sh — drive ONE Antigravity (Gemini) turn, visibly + logged.
#
# The Gemini seat covers the FRONTEND DEVELOPER (UI implementation) and the
# DESIGN CRITIC (it reads screenshots — Gemini is multimodal, verified).
#
# Usage:
#   ask-gemini.sh <project-dir> <prompt-file> [role] [--reset]
#
#   <project-dir>  repo Gemini operates in (added to its workspace)
#   <prompt-file>  file containing the instruction for this turn
#   [role]         label for the log header (e.g. design-critic | frontend) default: frontend
#   --reset        start a fresh conversation instead of continuing the last one
#
# Behaviour mirrors ask-codex.sh so the orchestrator drives every seat identically:
#   - First turn for a project starts fresh:  agy -p ... --add-dir <dir>
#   - Later turns add  -c  (continue most recent conversation) to KEEP context.
#   - Streams output live AND appends to <project-dir>/logs/conversation.log
#   - Prints a <<<TURN_DONE>>> marker the orchestrator polls for.
#
# Runtime: `agy` (Antigravity CLI), OAuth'd to the Google AI Pro subscription
# (NOT a metered API key). Model is overridable via GEMINI_MODEL.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

PROJECT_DIR="${1:?usage: ask-gemini.sh <project-dir> <prompt-file> [role] [--continue]}"
PROMPT_FILE="${2:?missing <prompt-file>}"
ROLE="frontend"
CONTINUE=""
for arg in "${@:3}"; do
  case "$arg" in
    --continue) CONTINUE="1" ;;
    --reset)    : ;;            # fresh is the DEFAULT now — accepted as a no-op alias
    *)          ROLE="$arg" ;;
  esac
done

MODEL="${GEMINI_MODEL:-Gemini 3.1 Pro (High)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG="$LOG_DIR/conversation.log"
TEAM="$(cd "$(dirname "$0")" && pwd)/team.sh"   # for feed bookends + live prose stream
mkdir -p "$LOG_DIR"

# Seat isolation: each Gemini seat runs as its OWN fresh conversation by default. `agy -c`
# continues the GLOBAL most-recent conversation (not keyed to project/role), so auto-continue
# would silently bleed one seat into another (e.g. design-critic continuing frontend's chat).
# Default = fresh + full context via the brief / .team/CONTEXT.md. `--continue` opts INTO -c
# only when the caller knows this seat was the most recent agy turn.

bar() { printf '\n\033[1;36m%s\033[0m\n' "────────────────────────────────────────────────────────"; }
ROLE_UC="$(echo "$ROLE" | tr a-z A-Z)"
bar
printf '\033[1;33m▶ ORCHESTRATOR → GEMINI (%s · %s)\033[0m\n' "$ROLE_UC" "$MODEL"
cat "$PROMPT_FILE"
bar
printf '\033[1;32m◀ GEMINI is working...\033[0m\n\n'

{
  echo "### ORCHESTRATOR → GEMINI ($ROLE · $(date -u +%FT%TZ))"
  cat "$PROMPT_FILE"; echo; echo "### GEMINI:"
} >> "$LOG"

PROMPT="$(cat "$PROMPT_FILE")"
CONT_ARGS=(); [[ -n "$CONTINUE" ]] && CONT_ARGS=(-c)

# feed bookend: start. Full output → LOG (authoritative) + a copy → feedfilter (live prose in pane).
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "▶ working" 2>/dev/null || true
agy -p "$PROMPT" "${CONT_ARGS[@]}" --add-dir "$PROJECT_DIR" --dangerously-skip-permissions \
  --model "$MODEL" --print-timeout 10m 2>&1 \
  | tee -a "$LOG" | tee >(bash "$TEAM" feedfilter "$PROJECT_DIR" "$ROLE" >/dev/null 2>&1)
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "✓ done" 2>/dev/null || true

echo >> "$LOG"
bar
printf '\033[1;35m<<<TURN_DONE>>>\033[0m\n'
