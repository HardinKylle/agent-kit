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
#   - Later turns resume this role's captured session id to KEEP context.
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
TEAM="$(cd "$(dirname "$0")" && pwd)/team.sh"   # for feed bookends + live prose stream
ROLE="${CODEX_ROLE:-codex}"                      # feed tag (set CODEX_ROLE=reviewer|qa-tester|…)
TEAM_MILESTONE="${TEAM_MILESTONE:-${MILESTONE:-turn}}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
# Per-ROLE session id: the implementer can resume its OWN thread across review→fix→re-review even
# when reviewer/QA turns interleave (global `resume --last` would grab the wrong seat). Each seat
# keeps an independent thread, so the reviewer never inherits the writer's context (role discipline).
SID_FILE="$PROJECT_DIR/.codex_session_${ROLE}.id"
mkdir -p "$LOG_DIR"

[[ "$RESET" == "--reset" ]] && rm -f "$SID_FILE"   # --reset/--fresh starts this seat's thread over

# Capture this seat's session id after a FRESH turn so the NEXT turn can resume it by id.
capture_sid() {
  local start="$1" newest cwd id
  while IFS= read -r p; do
    cwd="$(head -1 "$p" 2>/dev/null | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)"
    if [[ "$cwd" == "$PROJECT_DIR" ]]; then newest="$p"; break; fi
  done < <(find "$CODEX_HOME/sessions" -name '*.jsonl' -newermt "@$start" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2)
  [[ -n "${newest:-}" ]] && id="$(head -1 "$newest" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  [[ -n "${id:-}" ]] && printf '%s' "$id" > "$SID_FILE"
}

bar() { printf '\n\033[1;36m%s\033[0m\n' "────────────────────────────────────────────────────────"; }
ROLE_UC="$(echo "$ROLE" | tr a-z A-Z)"
bar
printf '\033[1;33m▶ ORCHESTRATOR → CODEX (%s)\033[0m\n' "$ROLE_UC"
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

# Feed bookend: show the exact prompt, then stream the filtered agent response.
bash "$TEAM" handoff "$PROJECT_DIR" orchestrator "$ROLE" "$TEAM_MILESTONE" < "$PROMPT_FILE" 2>/dev/null || true
bash "$TEAM" post "$PROJECT_DIR" "$ROLE" "▶ working" 2>/dev/null || true
stream() { tee -a "$LOG" | tee >(bash "$TEAM" feedfilter "$PROJECT_DIR" "$ROLE" >/dev/null 2>&1); }
START=$(date +%s)
if [[ -s "$SID_FILE" ]]; then
  # Resume THIS seat's own thread by id (keeps context across review→fix; no cold re-read).
  codex exec resume \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    "$(cat "$SID_FILE")" "$PROMPT" 2>&1 | stream
else
  codex exec \
    --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
    -C "$PROJECT_DIR" "${IMG_ARGS[@]}" "$PROMPT" 2>&1 | stream
  capture_sid "$START"
fi

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
