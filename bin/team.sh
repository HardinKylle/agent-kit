#!/usr/bin/env bash
# team.sh — visualize a multi-agent build: live transcript panes (#1) + roster board (#2).
#
# One dispatcher, used both by the orchestrator (to publish state) and by you (to watch).
#
# Watch:
#   team.sh view <project>          build the tmux session + 4-pane layout, print attach cmd
#
# Publish (called by orchestrator / agents as the build runs):
#   team.sh init  <project>                          seed the roster
#   team.sh set   <project> <role> <state> [task]    update one agent's row
#   team.sh say   <project> <from> <to> <message>    append a hand-off to the live feed
#   team.sh build <project> <message>                append a build/test line
#
# Render loops (these are the pane commands; you don't call them directly):
#   team.sh roster <project>   |   team.sh feed <project>   |   team.sh buildlog <project>
#
# State lives in <project>/.team/ : agents.tsv (roster), feed.log, build.log.
set -uo pipefail

CMD="${1:?usage: team.sh <view|init|set|say|build|roster|feed|buildlog> <project> ...}"
PROJECT="${2:?missing <project>}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")"
DIR="$PROJECT/.team"
ROSTER="$DIR/agents.tsv"
FEED="$DIR/feed.log"
BUILD="$DIR/build.log"
mkdir -p "$DIR"

now() { date +%s; }
ts()  { date +%H:%M:%S; }

# ── state colors ───────────────────────────────────────────────────────────
state_dot() {
  case "$1" in
    working)   printf '\033[1;32m●\033[0m' ;;   # green
    verifying) printf '\033[1;33m◐\033[0m' ;;   # yellow
    routing)   printf '\033[1;36m◆\033[0m' ;;   # cyan
    blocked)   printf '\033[1;31m■\033[0m' ;;   # red
    done)      printf '\033[1;34m✓\033[0m' ;;   # blue
    *)         printf '\033[2;37m·\033[0m' ;;   # idle/dim
  esac
}

case "$CMD" in
  init)
    : > "$FEED"; : > "$BUILD"
    # role \t model \t state \t task \t updated_epoch
    cat > "$ROSTER" <<EOF
orchestrator	Opus	routing	bootstrapping	$(now)
architect	Opus	idle	—	$(now)
implementer	Codex	idle	—	$(now)
reviewer	Codex	idle	—	$(now)
qa-tester	Sonnet	idle	—	$(now)
design-critic	Opus	idle	—	$(now)
scribe	Haiku	idle	—	$(now)
EOF
    echo "[$(ts)] team initialized for $PROJECT" >> "$FEED"
    ;;

  set)
    ROLE="${3:?role}"; STATE="${4:?state}"; TASK="${5:-}"
    [[ -f "$ROSTER" ]] || { echo "no roster; run: team.sh init $PROJECT" >&2; exit 1; }
    tmp="$(mktemp)"
    found=0
    while IFS=$'\t' read -r r m s t u; do
      if [[ "$r" == "$ROLE" ]]; then
        [[ -z "$TASK" ]] && TASK="$t"
        printf '%s\t%s\t%s\t%s\t%s\n' "$r" "$m" "$STATE" "$TASK" "$(now)" >> "$tmp"
        found=1
      else
        printf '%s\t%s\t%s\t%s\t%s\n' "$r" "$m" "$s" "$t" "$u" >> "$tmp"
      fi
    done < "$ROSTER"
    (( found )) || printf '%s\t%s\t%s\t%s\t%s\n' "$ROLE" "?" "$STATE" "${TASK:-—}" "$(now)" >> "$tmp"
    mv "$tmp" "$ROSTER"
    ;;

  say)
    FROM="${3:?from}"; TO="${4:?to}"; shift 4; MSG="$*"
    printf '\033[2;37m[%s]\033[0m \033[1;33m%-13s\033[0m \033[2m→\033[0m \033[1;36m%-13s\033[0m  %s\n' \
      "$(ts)" "$FROM" "$TO" "$MSG" >> "$FEED"
    ;;

  msg)
    # Append a FULL agent reply (header + verbatim body) to the transcript.
    # Body comes from stdin:  team.sh msg <project> <role> <model> [to] <<<"$reply"
    ROLE="${3:?role}"; MODEL="${4:?model}"; TO="${5:-}"
    case "$ROLE" in
      orchestrator) c='1;37' ;; architect) c='1;35' ;; implementer) c='1;32' ;;
      reviewer) c='1;31' ;; qa-tester) c='1;33' ;; design-critic) c='1;36' ;;
      scribe) c='1;34' ;; *) c='1;37' ;;
    esac
    hdr="$(printf '\033[%sm━━━ %s' "$c" "$(echo "$ROLE" | tr a-z A-Z)")"
    [[ -n "$TO" ]] && hdr="$hdr → $(echo "$TO" | tr a-z A-Z)"
    hdr="$(printf '%s \033[2m(%s · %s)\033[0m' "$hdr" "$MODEL" "$(ts)")"
    { printf '\n%s\n' "$hdr"; cat; printf '\033[0m\n'; } >> "$FEED"
    ;;

  build)
    shift 2; MSG="$*"
    printf '[%s] %s\n' "$(ts)" "$MSG" >> "$BUILD"
    ;;

  # ── render loops (pane commands) ───────────────────────────────────────────
  roster)
    # Repaint in place (cursor-home + per-line erase). No full-screen clear → no flicker.
    printf '\033[?25l'                                   # hide cursor
    trap 'printf "\033[?25h"' EXIT INT TERM              # restore on exit
    printf '\033[2J'                                     # one clear at start only
    base="$(basename "$PROJECT")"
    while true; do
      cols=$(tput cols 2>/dev/null || echo 60)        # adapt to pane width each frame
      tmax=$(( cols - 8 )); (( tmax < 12 )) && tmax=12 # task line budget (indented)
      printf -v buf '\033[1;37m  AGENT TEAM\033[0m  \033[2m%s\033[0m\033[K\n' "$base"
      printf -v p '\033[2m  ──────────────────────────────────────────────────────────\033[0m\033[K\n'; buf+="$p"
      printf -v p '   \033[1m%-13s %-7s %-10s %5s\033[0m\033[K\n' ROLE MODEL STATE AGO; buf+="$p"
      if [[ -f "$ROSTER" ]]; then
        nowx=$(now)
        while IFS=$'\t' read -r r m s t u; do
          ago=$(( nowx - ${u:-$nowx} ))
          dot="$(state_dot "$s")"
          printf -v p '  %b \033[1m%-13s\033[0m %-7s %-10s %3ss\033[K\n' "$dot" "$r" "$m" "$s" "$ago"; buf+="$p"
          if [[ -n "$t" && "$t" != "—" ]]; then         # full task on its own line, truncated to pane
            [[ ${#t} -gt $tmax ]] && t="${t:0:$((tmax-1))}…"
            printf -v p '       \033[2m↳ %s\033[0m\033[K\n' "$t"; buf+="$p"
          fi
        done < "$ROSTER"
      fi
      printf -v p '\033[K\n\033[2m  ●working ◐verifying ◆routing ■blocked ✓done ·idle\033[0m\033[K\033[J'; buf+="$p"
      printf '\033[H%s' "$buf"                           # paint whole frame at once
      sleep 1
    done
    ;;

  feed)
    printf '\033[1;37m  FULL TRANSCRIPT — every agent reply, verbatim\033[0m\n\n'
    touch "$FEED"; tail -n 200 -F "$FEED" 2>/dev/null
    ;;

  buildlog)
    printf '\033[1;37m  BUILD / VERIFY\033[0m\n\n'
    touch "$BUILD"; tail -n 200 -F "$BUILD" 2>/dev/null
    ;;

  view)
    SES="team-$(basename "$PROJECT")"
    tmux kill-session -t "$SES" 2>/dev/null || true
    SELF="$(cd "$(dirname "$0")" && pwd)/team.sh"
    [[ -f "$ROSTER" ]] || bash "$SELF" init "$PROJECT"
    # Layout: feed (left, tall) | dev-server + build log (right column) | roster (bottom strip).
    # The dev-server pane runs the app live so you can SEE localhost, not just logs.
    tmux new-session -d -s "$SES" -x 210 -y 50 "bash '$SELF' feed '$PROJECT'"
    feed=$(tmux list-panes -t "$SES" -F '#{pane_id}' | head -1)
    # roster as a full-width bottom strip
    tmux split-window -v -l 16 -t "$feed" "bash '$SELF' roster '$PROJECT'"
    # right column off the feed pane
    right=$(tmux split-window -h -P -F '#{pane_id}' -t "$feed" "bash '$SELF' buildlog '$PROJECT'")
    # if the project has a dev script, give the right column a live dev-server pane on top
    if grep -q '"dev"' "$PROJECT/package.json" 2>/dev/null; then
      tmux split-window -v -b -l 18 -t "$right" \
        "cd '$PROJECT' && echo '── DEV SERVER ──' && exec npm run dev"
    fi
    tmux set -t "$SES" pane-border-status top 2>/dev/null || true
    tmux set -t "$SES" pane-border-format ' #{pane_title} ' 2>/dev/null || true
    echo "$SES"
    echo "attach with:  tmux attach -t $SES"
    echo "(dev server runs live in the top-right pane; read its URL there)"
    ;;

  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
