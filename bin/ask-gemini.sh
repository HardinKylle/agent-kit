#!/usr/bin/env bash
# ask-gemini.sh — drive ONE Antigravity (Gemini) turn, visibly + logged.
#
# The Gemini seats are the RESEARCHER (all external/net lookup) and the DESIGN
# CRITIC (reads screenshots — Gemini is multimodal, verified).
#
# Usage:
#   ask-gemini.sh <project-dir> <prompt-file> [role] [--continue]
#
#   <project-dir>  repo Gemini operates in (added to its workspace)
#   <prompt-file>  file containing the instruction for this turn
#   [role]         label for the log header (e.g. researcher | design-critic) default: design-critic
#   --continue     continue the global most-recent agy conversation when safe
#
# Behaviour mirrors ask-codex.sh so the orchestrator drives every seat identically:
#   - First turn for a project starts fresh:  agy -p ... --add-dir <dir>
#   - Later turns are fresh by default; --continue opts into agy -c.
#   - Streams output live AND appends to <project-dir>/logs/conversation.log
#   - Prints a <<<TURN_DONE>>> marker the orchestrator polls for.
#
# Runtime: `agy` (Antigravity CLI), OAuth'd to the Google AI Pro subscription
# (NOT a metered API key). Model is overridable via GEMINI_MODEL.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

PROJECT_DIR="${1:?usage: ask-gemini.sh <project-dir> <prompt-file> [role] [--continue]}"
PROMPT_FILE="${2:?missing <prompt-file>}"
ROLE="design-critic"
CONTINUE=""
RESET=""
for arg in "${@:3}"; do
  case "$arg" in
    --continue) CONTINUE="1" ;;
    --reset)    RESET="1" ;;
    *)          ROLE="$arg" ;;
  esac
done

MODEL="${GEMINI_MODEL:-Gemini 3.1 Pro (High)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG="$LOG_DIR/conversation.log"
TEAM="$(cd "$(dirname "$0")" && pwd)/team.sh"   # for feed bookends + live prose stream
TEAM_MILESTONE="${TEAM_MILESTONE:-${MILESTONE:-turn}}"
mkdir -p "$LOG_DIR"

# Seat isolation: each Gemini seat tracks its OWN conversation by ID.
# This prevents one seat bleeding into another (e.g. design-critic and researcher).
SID_FILE="$PROJECT_DIR/.gemini_session_${ROLE}.id"

[[ -n "$RESET" ]] && rm -f "$SID_FILE"

# Capture this seat's conversation id after a turn so the NEXT turn can resume it by id.
capture_sid() {
  local id
  id=$(node -e '
    const fs = require("fs");
    const path = require("path");
    const p = path.join(require("os").homedir(), ".gemini/antigravity-cli/cache/last_conversations.json");
    if (fs.existsSync(p)) {
      const data = JSON.parse(fs.readFileSync(p, "utf8"));
      console.log(data[process.argv[1]] || "");
    }
  ' "$PROJECT_DIR")
  if [[ -n "$id" ]]; then
    printf '%s' "$id" > "$SID_FILE"
  fi
}

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
GY_ARGS=()
if [[ -n "$CONTINUE" && -s "$SID_FILE" ]]; then
  GY_ARGS=(--conversation "$(cat "$SID_FILE")")
fi

# Feed bookend: show the exact prompt, then stream the filtered agent response.
bash "$TEAM" handoff "$PROJECT_DIR" orchestrator "$ROLE" "$TEAM_MILESTONE" < "$PROMPT_FILE" 2>/dev/null || true
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "▶ working" 2>/dev/null || true
agy -p "$PROMPT" "${GY_ARGS[@]}" --add-dir "$PROJECT_DIR" --dangerously-skip-permissions \
  --model "$MODEL" --print-timeout 10m 2>&1 \
  | tee -a "$LOG" | tee >(bash "$TEAM" feedfilter "$PROJECT_DIR" "$ROLE" >/dev/null 2>&1)

capture_sid

# CHANGE SUMMARY (RULES §1 visibility): post files + line-deltas to the feed, NOT raw code.
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  stat="$(git -C "$PROJECT_DIR" diff --shortstat HEAD 2>/dev/null | sed 's/^ *//')"
  files="$(git -C "$PROJECT_DIR" diff --name-status HEAD 2>/dev/null | awk '{printf "%s:%s ",$1,$2}')"
  [[ -n "$stat$files" ]] && bash "$TEAM" post "$PROJECT_DIR" "$ROLE" \
    "CHANGES vs HEAD — ${stat:-no tracked changes} | ${files:-—}" 2>/dev/null || true
fi
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "✓ done" 2>/dev/null || true

echo >> "$LOG"
bar
printf '\033[1;35m<<<TURN_DONE>>>\033[0m\n'
