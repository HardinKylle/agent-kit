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
#   team.sh mode <project> <milestone> <tiny|logic|ui|production> [reason]
#   team.sh handoff <project> <from> <to> <milestone> [message]  log the actual task brief
#   team.sh verdict <project> <milestone> <seat> <pass|fail|converged> [summary]
#   team.sh finding <project> <milestone> <seat> <P0|P1|P2> <class> [note]  classify one caught bug
#   team.sh weakspots <project> [--top N]            ranked recurring bug classes → .team/WEAKSPOTS.md
#   team.sh outcome <project> <milestone> <kind> <clean|under|over> [note]  did the chosen mode hold?
#   team.sh routing <project>                        per-kind mode priors → .team/ROUTING.md
#   team.sh gate  <project> [--milestone M] <seat...> pass only if each seat passed
#
# Render loops (these are the pane commands; you don't call them directly):
#   team.sh roster <project>   |   team.sh feed <project>   |   team.sh buildlog <project>
#
# State lives in <project>/.team/ : agents.tsv (roster), feed.log, build.log.
set -uo pipefail

CMD="${1:?usage: team.sh <view|init|set|say|build|mode|handoff|verdict|finding|weakspots|outcome|routing|gate|roster|feed|buildlog> <project> ...}"
PROJECT="${2:?missing <project>}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")"
DIR="$PROJECT/.team"
ROSTER="$DIR/agents.tsv"
FEED="$DIR/feed.log"
BUILD="$DIR/build.log"
VERDICTS="$DIR/verdicts"
MODES="$DIR/modes.jsonl"
FINDINGS="$DIR/findings.jsonl"
WEAKSPOTS="$DIR/WEAKSPOTS.md"
ROUTINGLOG="$DIR/routing.jsonl"
ROUTINGMD="$DIR/ROUTING.md"
mkdir -p "$DIR"

now() { date +%s; }
ts()  { date +%H:%M:%S; }

norm_seat() {
  case "$1" in
    qa|tester) printf 'qa-tester' ;;
    design|critic) printf 'design-critic' ;;
    ui|frontend|frontend-developer) printf 'implementer' ;;
    review|code-reviewer) printf 'reviewer' ;;
    doc|docs) printf 'scribe' ;;
    lead) printf 'orchestrator' ;;
    finder|explore) printf 'file-finder' ;;
    codex) printf 'implementer' ;;
    *) printf '%s' "$1" ;;
  esac
}

verdict_label() {
  case "$(norm_seat "$1")" in
    qa-tester) printf 'QA' ;;
    design-critic) printf 'DESIGN-CRITIC' ;;
    reviewer) printf 'REVIEWER' ;;
    scribe) printf 'SCRIBE' ;;
    *) norm_seat "$1" | tr '[:lower:]' '[:upper:]' ;;
  esac
}

safe_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'
}

read_body_or_args() {
  if [[ $# -gt 0 ]]; then
    printf '%s' "$*"
  elif [[ ! -t 0 ]]; then
    cat
  fi
}

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
researcher	Gemini	idle	—	$(now)
architect	Opus	idle	—	$(now)
implementer	Codex	idle	—	$(now)
reviewer	Codex	idle	—	$(now)
qa-tester	Sonnet	idle	—	$(now)
design-critic	Gemini	idle	—	$(now)
scribe	Haiku	idle	—	$(now)
EOF
    # Stable shared brief — seats read this instead of re-explaining context in every brief.
    if [[ ! -f "$DIR/CONTEXT.md" ]]; then
      cat > "$DIR/CONTEXT.md" <<EOF
# $(basename "$PROJECT") — shared context (read this first)

WHAT: <one sentence on what the app is / does>
STACK: <framework + key libs + build cmd>
URL: <live/preview URL, if any>
CURRENT milestone: bootstrapping

> Orchestrator keeps the CURRENT line accurate each milestone. Seat briefs point here
> instead of inlining context. Keep this under ~20 lines.
EOF
    fi
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
    { flock 9; printf '\033[2;37m[%s]\033[0m \033[1;33m%-13s\033[0m \033[2m→\033[0m \033[1;36m%-13s\033[0m  %s\n' \
      "$(ts)" "$FROM" "$TO" "$MSG" >> "$FEED"; } 9>>"$FEED.lock"
    ;;

  msg)
    # Append a FULL agent reply (header + verbatim body) to the transcript.
    # Body comes from stdin:  team.sh msg <project> <role> <model> [to] <<<"$reply"
    ROLE="${3:?role}"; MODEL="${4:?model}"; TO="${5:-}"
    case "$ROLE" in
      orchestrator) c='1;37' ;; architect) c='1;35' ;; implementer) c='1;32' ;;
      reviewer) c='1;31' ;; qa-tester) c='1;33' ;; design-critic) c='1;36' ;;
      frontend) c='1;36' ;; scribe) c='1;34' ;; *) c='1;37' ;;
    esac
    hdr="$(printf '\033[%sm━━━ %s' "$c" "$(echo "$ROLE" | tr a-z A-Z)")"
    [[ -n "$TO" ]] && hdr="$hdr → $(echo "$TO" | tr a-z A-Z)"
    hdr="$(printf '%s \033[2m(%s · %s)\033[0m' "$hdr" "$MODEL" "$(ts)")"
    { flock 9
      printf '\n%s\n' "$hdr" >> "$FEED"
      cat >> "$FEED"
      printf '\033[0m\n' >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  build)
    shift 2; MSG="$*"
    printf '[%s] %s\n' "$(ts)" "$MSG" >> "$BUILD"
    ;;

  handoff)
    # Human-readable task brief. Use this for the exact Orchestrator → seat prompt,
    # separate from noisy raw CLI logs.
    FROM="${3:?from}"; TO="${4:?to}"; MILESTONE="${5:?milestone}"; shift 5
    BODY="$(read_body_or_args "$@")"
    { flock 9
      printf '\n\033[2m[%s]\033[0m \033[1;37mHANDOFF\033[0m \033[1;33m%s\033[0m → \033[1;36m%s\033[0m \033[2m[%s]\033[0m\n' \
        "$(ts)" "$FROM" "$TO" "$MILESTONE" >> "$FEED"
      [[ -n "$BODY" ]] && printf '%s\n' "$BODY" >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  mode)
    # Record the Orchestrator's chosen workflow tier so the team knows which seats
    # are intentionally used or folded for this milestone.
    MILESTONE="${3:?milestone}"; MODE="${4:?tiny|logic|ui|production}"
    shift 4; REASON="$*"
    case "$MODE" in
      tiny|logic|ui|production) ;;
      *) echo "usage: team.sh mode <project> <milestone> <tiny|logic|ui|production> [reason]" >&2; exit 2 ;;
    esac
    TS="$(date -u +%FT%TZ)"
    { flock 9
      printf '{"ts":"%s","milestone":"%s","mode":"%s","reason":"%s"}\n' \
        "$TS" "$(json_escape "$MILESTONE")" "$MODE" "$(json_escape "$REASON")" >> "$MODES"
      printf '\033[2m[%s]\033[0m \033[1morchestrator \033[0m MODE: %s [%s] %s\n' \
        "$(ts)" "$MODE" "$MILESTONE" "$REASON" >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  verdict)
    # Structured, milestone-scoped verdict. This prevents an old "QA: PASS" line
    # from opening a later milestone's gate.
    MILESTONE="${3:?milestone}"; SEAT="$(norm_seat "${4:?seat}")"; RESULT="${5:?pass|fail|converged}"
    shift 5; SUMMARY="$*"
    case "$RESULT" in
      pass|PASS) RESULT="PASS" ;;
      fail|FAIL) RESULT="FAIL" ;;
      converged|CONVERGED) RESULT="CONVERGED" ;;
      *) echo "usage: team.sh verdict <project> <milestone> <seat> <pass|fail|converged> [summary]" >&2; exit 2 ;;
    esac
    mkdir -p "$VERDICTS"
    SAFE_MILESTONE="$(safe_name "$MILESTONE")"
    FILE="$VERDICTS/$SAFE_MILESTONE.jsonl"
    LABEL="$(verdict_label "$SEAT")"
    TS="$(date -u +%FT%TZ)"
    SUMMARY_JSON="$(json_escape "$SUMMARY")"
    { flock 9
      printf '{"ts":"%s","milestone":"%s","seat":"%s","label":"%s","result":"%s","summary":"%s"}\n' \
        "$TS" "$(json_escape "$MILESTONE")" "$SEAT" "$LABEL" "$RESULT" "$SUMMARY_JSON" >> "$FILE"
      printf '\033[2m[%s]\033[0m \033[1m%-13s\033[0m %s: %s [%s] %s\n' \
        "$(ts)" "$SEAT" "$LABEL" "$RESULT" "$MILESTONE" "$SUMMARY" >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  finding)
    # Classify ONE real bug a verifier caught, so the team can learn where the Implementer is weakest.
    # Severity weights P0=3 P1=2 P2=1; class is a free token (suggested: logic|ui|race|error-handling|
    # security|perf|scope). Aggregated by `weakspots` into a pre-flight checklist.
    MILESTONE="${3:?milestone}"; SEAT="$(norm_seat "${4:?seat}")"; SEV="${5:?P0|P1|P2}"
    CLASS="$(printf '%s' "${6:?class}" | tr '[:upper:]' '[:lower:]')"; shift 6; NOTE="$*"
    case "$SEV" in P0|P1|P2|p0|p1|p2) SEV="$(printf '%s' "$SEV" | tr '[:lower:]' '[:upper:]')" ;;
      *) echo "usage: team.sh finding <project> <milestone> <seat> <P0|P1|P2> <class> [note]" >&2; exit 2 ;; esac
    TS="$(date -u +%FT%TZ)"
    { flock 9
      printf '{"ts":"%s","milestone":"%s","seat":"%s","severity":"%s","class":"%s","note":"%s"}\n' \
        "$TS" "$(json_escape "$MILESTONE")" "$SEAT" "$SEV" "$(json_escape "$CLASS")" "$(json_escape "$NOTE")" >> "$FINDINGS"
      printf '\033[2m[%s]\033[0m \033[1m%-13s\033[0m FINDING %s [%s] %s: %s\n' \
        "$(ts)" "$SEAT" "$SEV" "$CLASS" "$MILESTONE" "$NOTE" >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  weakspots)
    # Aggregate classified findings into a ranked, severity-weighted list of recurring bug classes,
    # and write it to .team/WEAKSPOTS.md — the Implementer reads it pre-flight (self-improving briefs).
    shift 2
    TOP=8
    while [[ $# -gt 0 ]]; do case "$1" in --top) TOP="${2:-8}"; shift 2 ;; *) shift ;; esac; done
    if [[ ! -s "$FINDINGS" ]]; then
      echo "no classified findings yet ($FINDINGS) — verifiers log them with: team.sh finding ..."
      exit 0
    fi
    node -e '
      const fs = require("fs");
      const [file, topArg, out, proj] = process.argv.slice(1);
      const top = Math.max(1, parseInt(topArg, 10) || 8);
      const W = { P0: 3, P1: 2, P2: 1 };
      const byClass = {};
      for (const line of fs.readFileSync(file, "utf8").split("\n")) {
        if (!line.trim()) continue;
        let r; try { r = JSON.parse(line); } catch { continue; }
        const c = (r.class || "other").trim() || "other";
        const sev = (r.severity || "P2").toUpperCase();
        const e = byClass[c] || (byClass[c] = { score: 0, P0: 0, P1: 0, P2: 0, total: 0, last: "" });
        e.score += W[sev] || 1; e[sev] = (e[sev] || 0) + 1; e.total++;
        if (r.note) e.last = r.note;
      }
      const ranked = Object.entries(byClass).sort((a, b) => b[1].score - a[1].score).slice(0, top);
      const lines = ranked.map(([c, e], i) =>
        `${i + 1}. **${c}** — weight ${e.score} (P0×${e.P0} P1×${e.P1} P2×${e.P2}, ${e.total} total)` +
        (e.last ? `\n   e.g. ${e.last}` : ""));
      const md = `# Implementer pre-flight — recurring weak spots (auto-generated)\n\n` +
        `> Bug classes the Reviewer/QA/Design Critic catch most on ${proj}. Treat the top few as a\n` +
        `> checklist BEFORE handing back: did this change avoid these? Regenerated by \`team.sh weakspots\`.\n\n` +
        (lines.length ? lines.join("\n") : "_No findings recorded yet._") + "\n";
      fs.writeFileSync(out, md);
      process.stdout.write(md);
    ' "$FINDINGS" "$TOP" "$WEAKSPOTS" "$(basename "$PROJECT")"
    ;;

  outcome)
    # Close the loop on a mode choice: did the mode the Orchestrator picked for this milestone HOLD?
    #   clean = right call (gates passed without escalation)
    #   under = too light (had to escalate / add seats mid-milestone)
    #   over  = too heavy (every seat trivially passed; could have been lighter)
    # The chosen mode is looked up from modes.jsonl so you don't retype it. kind is a free token
    # (suggested: logic|ui|docs|refactor|mixed). Aggregated by `routing` into ROUTING.md.
    MILESTONE="${3:?milestone}"; KIND="$(printf '%s' "${4:?kind}" | tr '[:upper:]' '[:lower:]')"
    RESULT="$(printf '%s' "${5:?clean|under|over}" | tr '[:upper:]' '[:lower:]')"; shift 5; NOTE="$*"
    case "$RESULT" in clean|under|over) ;;
      *) echo "usage: team.sh outcome <project> <milestone> <kind> <clean|under|over> [note]" >&2; exit 2 ;; esac
    CHOSEN="unknown"
    if [[ -f "$MODES" ]]; then
      m="$(grep -F "\"milestone\":\"$(json_escape "$MILESTONE")\"" "$MODES" | tail -n 1 | sed -n 's/.*"mode":"\([^"]*\)".*/\1/p')"
      [[ -n "$m" ]] && CHOSEN="$m"
    fi
    TS="$(date -u +%FT%TZ)"
    { flock 9
      printf '{"ts":"%s","milestone":"%s","mode":"%s","kind":"%s","result":"%s","note":"%s"}\n' \
        "$TS" "$(json_escape "$MILESTONE")" "$CHOSEN" "$(json_escape "$KIND")" "$RESULT" "$(json_escape "$NOTE")" >> "$ROUTINGLOG"
      printf '\033[2m[%s]\033[0m \033[1morchestrator \033[0m ROUTE-OUTCOME %s mode=%s kind=%s [%s] %s\n' \
        "$(ts)" "$RESULT" "$CHOSEN" "$KIND" "$MILESTONE" "$NOTE" >> "$FEED"
    } 9>>"$FEED.lock"
    ;;

  routing)
    # Aggregate mode outcomes into a per-kind prior: for each change kind, which mode tends to HOLD,
    # and which keeps coming up under/over. Writes .team/ROUTING.md — the Orchestrator reads it BEFORE
    # picking a mode (self-improving routing; no ML, just the project's own history).
    if [[ ! -s "$ROUTINGLOG" ]]; then
      echo "no routing outcomes yet ($ROUTINGLOG) — close milestones with: team.sh outcome ..."
      exit 0
    fi
    node -e '
      const fs = require("fs");
      const [file, out, proj] = process.argv.slice(1);
      const ORDER = { tiny: 0, logic: 1, ui: 2, production: 3, unknown: 9 };
      const byKind = {};
      for (const line of fs.readFileSync(file, "utf8").split("\n")) {
        if (!line.trim()) continue;
        let r; try { r = JSON.parse(line); } catch { continue; }
        const k = (r.kind || "mixed").trim() || "mixed";
        const mode = r.mode || "unknown";
        const res = (r.result || "").toLowerCase();
        const e = byKind[k] || (byKind[k] = {});
        const m = e[mode] || (e[mode] = { clean: 0, under: 0, over: 0, total: 0 });
        if (res in m) m[res]++; m.total++;
      }
      function recommend(modes) {
        // pick the mode with the most CLEAN holds; tie → the lighter one.
        const entries = Object.entries(modes).filter(([mo]) => mo !== "unknown");
        if (!entries.length) return null;
        entries.sort((a, b) => (b[1].clean - a[1].clean) || (ORDER[a[0]] - ORDER[b[0]]));
        return entries[0];
      }
      const kinds = Object.keys(byKind).sort();
      let body = "";
      for (const k of kinds) {
        const modes = byKind[k];
        body += `\n### ${k}\n`;
        for (const [mo, m] of Object.entries(modes).sort((a, b) => ORDER[a[0]] - ORDER[b[0]])) {
          body += `- \`${mo}\`: ${m.clean} clean / ${m.under} under / ${m.over} over (${m.total})\n`;
        }
        const rec = recommend(modes);
        if (rec) {
          const [mo, m] = rec;
          let tip = `default \`${mo}\``;
          // flag chronic under/over patterns
          const under = Object.entries(modes).filter(([, x]) => x.under > x.clean && x.under >= 2);
          const over = Object.entries(modes).filter(([, x]) => x.over > x.clean && x.over >= 2);
          if (under.length) tip += ` — ${under.map(([mm]) => `\`${mm}\``).join(", ")} keeps going UNDER, stop defaulting there`;
          if (over.length) tip += ` — ${over.map(([mm]) => `\`${mm}\``).join(", ")} is usually OVERKILL here`;
          body += `  → **${tip}**\n`;
        }
      }
      const md = `# Routing priors — which mode holds, by change kind (auto-generated)\n\n` +
        `> The Orchestrator reads this BEFORE \`team.sh mode\` on ${proj}. Counts: clean = mode held,\n` +
        `> under = had to escalate, over = could have been lighter. Regenerated by \`team.sh routing\`.\n` +
        (body || "\n_No outcomes recorded yet._\n");
      fs.writeFileSync(out, md);
      process.stdout.write(md);
    ' "$ROUTINGLOG" "$ROUTINGMD" "$(basename "$PROJECT")"
    ;;

  post)
    # Locked, uniformly-formatted feed append. ALL feed writes should route through here so
    # concurrent writers (multiple seats + orchestrator) can't tear each other's lines (flock),
    # and the feed reads in one consistent style.
    #   team.sh post <project> <role> <message...>
    ROLE="${3:?role}"; shift 3; MSG="$*"
    { flock 9; printf '\033[2m[%s]\033[0m \033[1m%-13s\033[0m %s\n' "$(ts)" "$ROLE" "$MSG" >> "$FEED"; } 9>>"$FEED.lock"
    ;;

  feedfilter)
    # Stream a seat's raw stdout, DROP code/diff/command/metadata noise, and forward the PROSE
    # (what the agent is thinking/saying) to the feed live — tagged by seat, lock-appended.
    # Pipe a seat's output into it:   <codex/agy ...> | team.sh feedfilter <project> <role>
    ROLE="${3:?role}"
    awk '
      { gsub(/\033\[[0-9;?]*[a-zA-Z]/, "") }                 # strip ANSI
      /^OpenAI Codex/ { meta=1; next }                       # codex banner block
      meta==1 { if ($0 ~ /^-+$/ && ++d>=2){meta=0;d=0} next }
      /^user$/ { ep=1; next }                                # skip echoed prompt …
      ep==1 { if ($0 ~ /^codex$/) ep=0; next }               # … until the assistant turn
      /^### / { next }                                        # our brief headers
      /^(codex|agy|exec|tokens used|thinking)$/ { next }      # turn/section markers
      /^\/bin\/bash/ { next }                                 # command echoes
      /^ *(succeeded|failed) in/ { next }                     # command results
      /^\?\? / { next }                                        # git status noise
      /rmcp::transport|AuthorizationRequired/ { next }         # known MCP warning
      /^(diff --git|index |@@|\+\+\+|--- )/ { next }           # diff headers
      /^\+/ { next }                                            # diff/code added line
      /^-[^ ]/ { next }                                         # diff removed line (keep "- " bullets)
      /^total [0-9]/ { next }                                  # ls -l total
      /^[dlbcps-][rwxsStT-]{9}/ { next }                       # ls -l permission rows
      /^(apply patch|patch:|new file mode|deleted file|old mode|new mode|rename (from|to)|Binary files)/ { next }
      /[{};(,][[:space:]]*$/ { next }                          # code: lines ending in { } ; ( ,
      /^[[:space:]]*(import|export|const|let|var|function|class|return|@media|@import|@keyframes|\.[A-Za-z])/ { next }  # JS/CSS code
      /^[[:space:]]*[.#&][A-Za-z][A-Za-z0-9 ._:#>~,()%*-]*$/ { next }                       # bare CSS selector
      length($0) > 400 { next }                                # very long = code, drop
      /^[[:space:]]*$/ { next }                                # blanks
      ($0 ~ /[A-Za-z]/ && $0 ~ / /) { print }                 # keep: prose (has words)
    ' | while IFS= read -r l; do
      { flock 9; printf '   \033[2m%-12s│\033[0m %s\n' "$ROLE" "$l" >> "$FEED"; } 9>>"$FEED.lock"
    done
    ;;

  gate)
    # Mechanical milestone gate (RULES 4c). With --milestone it reads structured
    # .team/verdicts/<milestone>.jsonl; without it, it falls back to legacy feed grep.
    #   team.sh gate <project> --milestone M3 qa design-critic
    #   team.sh gate <project> qa design-critic      # legacy/global feed fallback
    shift 2
    MILESTONE=""; SEATS=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --milestone|-m) MILESTONE="${2:?missing milestone}"; shift 2 ;;
        *) SEATS+=("$1"); shift ;;
      esac
    done
    [[ ${#SEATS[@]} -gt 0 ]] || { echo "usage: team.sh gate <project> [--milestone M] <seat...>" >&2; exit 2; }
    touch "$FEED"; missing=0
    for raw_seat in "${SEATS[@]}"; do
      seat="$(norm_seat "$raw_seat")"
      label="$(verdict_label "$seat")"
      if [[ -n "$MILESTONE" ]]; then
        file="$VERDICTS/$(safe_name "$MILESTONE").jsonl"
        line=""
        [[ -f "$file" ]] && line="$(grep -E "\"seat\":\"$seat\"" "$file" | tail -n 1 || true)"
        if [[ "$line" =~ \"result\":\"(PASS|CONVERGED)\" ]]; then
          printf '\033[1;32m✓ GATE  %-14s PASS  (%s)\033[0m\n' "$seat" "$MILESTONE"
        else
          printf '\033[1;31m■ GATE  %-14s MISSING — latest %s verdict is not PASS for %s\033[0m\n' "$seat" "$label" "$MILESTONE"
          missing=1
        fi
      elif grep -Eq "${label}:[[:space:]]*(PASS|CONVERGED)" "$FEED"; then
        printf '\033[1;32m✓ GATE  %-14s PASS\033[0m\n' "$seat"
      else
        printf '\033[1;31m■ GATE  %-14s MISSING — no "%s: PASS" in feed.log\033[0m\n' "$seat" "$label"
        missing=1
      fi
    done
    (( missing == 0 )) || { echo "── milestone BLOCKED: a seat verdict is missing ──" >&2; exit 1; }
    echo "── milestone GATE OPEN: all seat verdicts present ──"
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
    roster=$(tmux split-window -v -l 16 -P -F '#{pane_id}' -t "$feed" "bash '$SELF' roster '$PROJECT'")
    # right column off the feed pane
    right=$(tmux split-window -h -P -F '#{pane_id}' -t "$feed" "bash '$SELF' buildlog '$PROJECT'")
    # if the project has a dev script, give the right column a live dev-server pane on top
    dev=""
    if grep -q '"dev"' "$PROJECT/package.json" 2>/dev/null; then
      dev=$(tmux split-window -v -b -l 18 -P -F '#{pane_id}' -t "$right" \
        "cd '$PROJECT' && echo '── DEV SERVER ──' && exec npm run dev")
    fi
    # label every pane so they don't all read "Honeydew" and blur together
    tmux select-pane -t "$feed"   -T ' ① CONVERSATION — agent transcript ' 2>/dev/null || true
    tmux select-pane -t "$right"  -T ' ② BUILD / VERIFY ' 2>/dev/null || true
    [[ -n "$dev" ]] && tmux select-pane -t "$dev" -T ' ③ DEV SERVER — localhost ' 2>/dev/null || true
    tmux select-pane -t "$roster" -T ' ROSTER ' 2>/dev/null || true
    tmux set -t "$SES" pane-border-status top 2>/dev/null || true
    tmux set -t "$SES" pane-border-format ' #{pane_title} ' 2>/dev/null || true
    echo "$SES"
    echo "attach with:  tmux attach -t $SES"
    echo "(dev server runs live in the top-right pane; read its URL there)"
    ;;

  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
