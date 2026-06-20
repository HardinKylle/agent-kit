#!/usr/bin/env bash
# ask-codex.sh — drive ONE Codex turn (implementer or reviewer), visibly + logged.
#
# Usage:
#   ask-codex.sh <project-dir> <prompt-file> [--reset]
#
#   <project-dir>  repo Codex operates in (its session is keyed to this dir)
#   <prompt-file>  file containing the instruction for this turn
#   --reset        start a fresh Codex session instead of resuming the last one
#
# Behaviour:
#   - First turn for a project starts a fresh `codex exec` (with -C <dir>).
#   - Later turns `codex exec resume --last` to KEEP context (note: -C is NOT
#     valid on resume; resume reuses the original session cwd).
#   - Streams Codex output live AND appends to <project-dir>/logs/conversation.log
#   - Prints a <<<TURN_DONE>>> marker the orchestrator polls for.
#
# Why a script: one agreed, reusable way to invoke the implementer/reviewer so
# every project behaves identically and the orchestrator can watch + detect done.
set -uo pipefail

PROJECT_DIR="${1:?usage: ask-codex.sh <project-dir> <prompt-file> [--reset]}"
PROMPT_FILE="${2:?missing <prompt-file>}"
RESET="${3:-}"

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG="$LOG_DIR/conversation.log"
SESSION_FLAG="$PROJECT_DIR/.codex_session_started"
mkdir -p "$LOG_DIR"

[[ "$RESET" == "--reset" ]] && rm -f "$SESSION_FLAG"

bar() { printf '\n\033[1;36m%s\033[0m\n' "────────────────────────────────────────────────────────"; }
bar
printf '\033[1;33m▶ ORCHESTRATOR → CODEX (implementer)\033[0m\n'
cat "$PROMPT_FILE"
bar
printf '\033[1;32m◀ CODEX is working...\033[0m\n\n'

{
  echo "### ORCHESTRATOR → CODEX  ($(date -u +%FT%TZ))"
  cat "$PROMPT_FILE"; echo; echo "### CODEX:"
} >> "$LOG"

PROMPT="$(cat "$PROMPT_FILE")"
if [[ -f "$SESSION_FLAG" ]]; then
  codex exec resume --last \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    "$PROMPT" 2>&1 | tee -a "$LOG"
else
  touch "$SESSION_FLAG"
  codex exec \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    -C "$PROJECT_DIR" "$PROMPT" 2>&1 | tee -a "$LOG"
fi

echo >> "$LOG"
bar
printf '\033[1;35m<<<TURN_DONE>>>\033[0m\n'
