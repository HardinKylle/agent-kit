#!/usr/bin/env bash
# ask-codex.sh — drive ONE Codex turn (implementer or reviewer), visibly + logged.
#
# Usage:
#   ask-codex.sh <project-dir> <prompt-file> [--reset] [image ...]
#
#   <project-dir>  repo Codex operates in (its session is keyed to this dir)
#   <prompt-file>  file containing the instruction for this turn
#   --reset        start a fresh Codex session instead of resuming the last one
#   [image ...]    optional screenshot paths — Codex IS multimodal (`-i`), so QA can
#                  attach shots and verify the rendered UI itself (only on a fresh turn)
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

PROJECT_DIR="${1:?usage: ask-codex.sh <project-dir> <prompt-file> [--reset] [image ...]}"
PROMPT_FILE="${2:?missing <prompt-file>}"
shift 2
RESET=""; IMAGES=()
for a in "$@"; do
  case "$a" in
    --reset) RESET="--reset" ;;
    *)       IMAGES+=("$a") ;;   # anything else = an image path to attach
  esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG="$LOG_DIR/conversation.log"
SESSION_FLAG="$PROJECT_DIR/.codex_session_started"
TEAM="$(cd "$(dirname "$0")" && pwd)/team.sh"   # for feed bookends + live prose stream
ROLE="${CODEX_ROLE:-codex}"                      # feed tag (set CODEX_ROLE=reviewer|qa-tester|…)
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
# images attach only on a fresh exec (like -C, not valid on resume). `--` ends the -i list.
IMG_ARGS=()
(( ${#IMAGES[@]} )) && IMG_ARGS=(-i "${IMAGES[@]}" --)

# feed bookend: start. Full output → LOG (authoritative) + a copy → feedfilter (live prose in pane).
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "▶ working" 2>/dev/null || true
stream() { tee -a "$LOG" | tee >(bash "$TEAM" feedfilter "$PROJECT_DIR" "$ROLE" >/dev/null 2>&1); }
if [[ -f "$SESSION_FLAG" ]]; then
  codex exec resume --last \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    "$PROMPT" 2>&1 | stream
else
  touch "$SESSION_FLAG"
  codex exec \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    -C "$PROJECT_DIR" "${IMG_ARGS[@]}" "$PROMPT" 2>&1 | stream
fi
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "✓ done" 2>/dev/null || true

echo >> "$LOG"
bar
printf '\033[1;35m<<<TURN_DONE>>>\033[0m\n'
