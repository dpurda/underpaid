#!/usr/bin/env bash
# Underpaid: installs the /shipit Team Lead skill and its agents into the current project's .claude/.
# Usage: cd <your project> && ~/underpaid/install.sh [--uninstall]
set -euo pipefail

VERSION="1.0.0"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CLAUDE_DIR="$PROJECT_DIR/.claude"
CONF="$CLAUDE_DIR/underpaid.conf"
USER_CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- UI ------------------------------------------------------------------------
if [[ -t 1 ]]; then # cyan → violet palette, matches the logo
  R=$'\033[0m' B=$'\033[1m' DIM=$'\033[38;5;245m' LINE=$'\033[38;5;240m' ACC=$'\033[38;5;80m'
  OK=$'\033[38;5;78m' WARN=$'\033[38;5;214m' ERR=$'\033[38;5;203m'
else
  R="" B="" DIM="" LINE="" ACC="" OK="" WARN="" ERR=""
fi
W=78 SMALL=0 # the big logo needs ~81 columns; narrower terminals get a compact header
cols=$(tput cols 2>/dev/null || echo 120); (( cols < W + 3 )) && W=72 SMALL=1
BAR="  "
Q="${ACC}?${R}"; [[ -n "$R" ]] && Q=$'\033[5m'"${ACC}●${R}" # blinking dot = where you are
tilde() { printf '%s' "${1/#$HOME/~}"; }
rule()  { local s; printf -v s '%*s' "$1" ''; printf '%s' "${s// /─}"; }
# pbar pct width → [██████░░░░]
pbar()  { local f=$(( $1 * $2 / 100 )) s e; printf -v s '%*s' "$f" ''; printf -v e '%*s' $(( $2 - f )) ''; printf "${LINE}[${ACC}%s${LINE}%s]${R}" "${s// /█}" "${e// /░}"; }

# frow "text" [end]: one line inside the banner frame, padded to the right border
frow() {
  local plain; plain=$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g')
  printf "${LINE}│${R}%s%*s${LINE}│${R}%s" "$1" $(( W + 1 - ${#plain} )) '' "${2-$'\n'}"
}
banner() {
  local c=(51 45 39 33 63 99) i=0 l p
  printf "\n${LINE}╭─${R}${B}${ACC} YOUR BEST TEAM ${R}${LINE}%s─╮${R}\n" "$(rule $((W - 17)))"
  frow ""
  if (( SMALL )); then
    frow "  ${B}${ACC}U N D E R P A I D${R}"
  else while IFS= read -r l; do
    if [[ -n "$R" ]]; then frow "     "$'\033[1;38;5;'"${c[i++]}m$l$R"; else frow "     $l"; fi
  done <<'EOF'
██╗   ██╗███╗   ██╗██████╗ ███████╗██████╗ ██████╗  █████╗ ██╗██████╗
██║   ██║████╗  ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗██║██╔══██╗
██║   ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝██████╔╝███████║██║██║  ██║
██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██╔═══╝ ██╔══██║██║██║  ██║
╚██████╔╝██║ ╚████║██████╔╝███████╗██║  ██║██║     ██║  ██║██║██████╔╝
 ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝╚═════╝
EOF
  fi
  frow ""
  frow "  ${ACC}>${R} ${B}${ACC}THE HARDEST-WORKING, LOWEST-PAID DEVS YOU WILL EVER HIRE${R}"
  frow "  ${ACC}>${R} ${DIM}ticket → plan → tests → code → QA → review${R}$(printf '%*s' $((W - 49 - ${#VERSION})) '')${DIM}v$VERSION${R}"
  local d; d=$(tilde "$PROJECT_DIR"); (( ${#d} > W - 6 )) && d="…${d: -$((W - 7))}"
  frow "  ${ACC}>${R} ${DIM}$d${R}"
  if [[ -t 1 ]]; then # boot animation
    for p in 0 10 25 40 55 70 85 100; do frow "  ${ACC}> LOADING...${R} $(pbar $p 40) ${ACC}$(printf '%3d' $p)%${R}" ""; printf '\r'; sleep 0.06; done
    echo
  fi
  printf "${LINE}╰%s╯${R}\n" "$(rule $((W + 1)))"
}
section() { # section "2/6" "Title" → "⬤ 2/6  TITLE   [████░░░░] 40%"
  local t="${1:+$1  }${2^^}" pct
  printf "\n${ACC}⬤${R}  ${B}${ACC}%s${R}" "$t"
  if [[ "$1" == */* ]]; then
    pct=$(( (${1%/*} - 1) * 100 / ${1#*/} ))
    printf "%*s%s ${ACC}%3d%%${R}" $(( W - 22 - ${#t} )) '' "$(pbar "$pct" 10)" "$pct"
  fi
  printf '\n\n'
}
endsec() { :; }
say()  { printf "${BAR}%s\n" "$*"; }
hint() { printf "${BAR}${DIM}%s${R}\n" "$*"; }
ok() { # "[✓] text ........ [OK]"
  local plain; plain=$(printf '%s' "$*" | sed 's/\x1b\[[0-9;]*m//g')
  printf "${BAR}${OK}[✓]${R} %s ${LINE}%s${R} ${OK}[OK]${R}\n" "$*" "$(d=$((W - 12 - ${#plain})); ((d < 1)) && d=1; printf '%*s' $d '' | tr ' ' '.')"
}
warn() { printf "${BAR}${WARN}[!]${R} %s\n" "$*"; }
die()  { printf "${BAR}${ERR}[✗] %s  [FAIL]${R}\n" "$*" >&2; endsec; exit 1; }
TTY=0; [[ -t 0 && -t 1 ]] && TTY=1
(( TTY )) && trap 'printf "\033[?25h"' EXIT
key() { # reads one keypress: up, down, left, right, enter or the char
  local k; IFS= read -rsn1 k
  if [[ "$k" == $'\e' ]]; then read -rsn2 -t 0.05 k || true
    case "$k" in '[A') k=up ;; '[B') k=down ;; '[C') k=right ;; '[D') k=left ;; esac
  elif [[ -z "$k" ]]; then k=enter; fi
  printf '%s' "$k"
}
# ask "question": ←/→ or y/n, Enter confirms; default No
ask() {
  if (( ! TTY )); then local a; read -r -p "${BAR}? $1 (y/N) " a; [[ "$a" =~ ^[yY]$ ]]; return; fi
  local y=0 k
  printf '\033[?25l'
  while :; do
    if (( y )); then printf "\r${BAR}${Q} %s  ${B}${ACC}❯ Yes${R}  ${DIM}No${R}\033[K" "$1"
    else printf "\r${BAR}${Q} %s  ${DIM}Yes${R}  ${B}${ACC}❯ No${R}\033[K" "$1"; fi
    k=$(key)
    case "$k" in left|right|up|down) y=$(( !y )) ;; y|Y) y=1; break ;; n|N) y=0; break ;; enter) break ;; esac
  done
  printf "\r${BAR}${OK}✓${R} %s ${DIM}%s${R}\033[K\n\033[?25h" "$1" "$( ((y)) && echo Yes || echo No)"
  (( y ))
}
# choose VAR default_index "label" "option" ...: ↑/↓ (or j/k), Enter confirms; VAR gets the index
choose() {
  local __v="$1" i="$2" label="$3" j k; shift 3
  local n=$#; local o=("$@")
  if (( ! TTY )); then printf -v "$__v" '%s' "$i"; return; fi
  printf "${BAR}${Q} %s ${DIM}(↑/↓, Enter)${R}\n\033[?25l" "$label"
  while :; do
    for ((j = 0; j < n; j++)); do
      if (( j == i )); then printf "${BAR}  ${B}${ACC}❯ %s${R}\033[K\n" "${o[j]}"
      else printf "${BAR}    ${DIM}%s${R}\033[K\n" "${o[j]}"; fi
    done
    k=$(key)
    case "$k" in up|k) i=$(( (i - 1 + n) % n )) ;; down|j) i=$(( (i + 1) % n )) ;; enter) break ;; esac
    printf '\033[%dA' "$n"
  done
  printf "\033[%dA\033[J\033[1A\r${BAR}${OK}✓${R} %s ${ACC}%s${R}\033[K\n\033[?25h" "$n" "$label" "${o[i]}"
  printf -v "$__v" '%s' "$i"
}
# prompt VAR "question" "default"
prompt() {
  local a; read -r -p "${BAR}${Q} $2${3:+ ${DIM}($3)${R}} ${ACC}›${R} " a
  printf -v "$1" '%s' "${a:-$3}"
  if (( TTY )); then printf "\033[1A\r\033[K${BAR}${OK}✓${R} %s ${ACC}%s${R}\n" "$2" "${a:-$3}"; fi
}
# box "Title" lines... (plain text only: width is counted in characters)
box() { # box "Title" lines... (lines may contain colors; width ignores them)
  local title="$1" l w=$W n; shift
  vis() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m; }
  for l in "$@"; do n=$(vis "$l"); (( n + 4 > w )) && w=$(( n + 4 )); done
  printf "\n${LINE}╭%s╮${R}\n" "$(rule "$w")"
  printf "${LINE}│${R}  ${B}${ACC}%-*s${R}${LINE}│${R}\n" $((w - 2)) "$title"
  printf "${LINE}├%s┤${R}\n" "$(rule "$w")"
  for l in "$@"; do printf "${LINE}│${R}  %s%*s${LINE}│${R}\n" "$l" $((w - 2 - $(vis "$l"))) ''; done
  printf "${LINE}╰%s╯${R}\n\n" "$(rule "$w")"
}
# project file checks: has <file> <regex>, exists <glob>...
has()   { grep -qiE "$2" "$PROJECT_DIR/$1" 2>/dev/null; }
exists(){ local f; for f in "$@"; do compgen -G "$PROJECT_DIR/$f" >/dev/null && return 0; done; return 1; }
conf_get() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -1; }

# --- Uninstall -----------------------------------------------------------------
if [[ "${1:-}" == --uninstall ]]; then
  banner
  section "" "Uninstall"
  [[ -f "$CONF" || -d "$CLAUDE_DIR/skills/shipit" ]] || die "Underpaid is not installed in $(tilde "$PROJECT_DIR")."
  SK=$(conf_get INSTALLED_SKILLS); PL=$(conf_get INSTALLED_PLUGINS)
  PATHS=(skills/shipit underpaid.conf underpaid-notes.md underpaid-screenshots shipyard.conf shipyard-notes.md shipyard-screenshots kanbandits.conf kanbandits-notes.md kanbandits-screenshots $(cd "$REPO_DIR/agents" && printf 'agents/%s ' *.md))
  for n in $SK; do PATHS+=("skills/$n"); done
  say "${B}This removes from $(tilde "$CLAUDE_DIR"):${R}"
  for f in "${PATHS[@]}"; do [[ -e "$CLAUDE_DIR/$f" ]] && hint "  • $f"; done
  [[ -n "$PL" ]] && hint "  • plugins installed for this project: $PL"
  hint "  • the Gmail send permission and the .git/info/exclude entries"
  hint "  Backups (*.bak.*) and global settings (shell rc, Slack webhook) are left alone."
  printf "\n\n"
  ask "Remove Underpaid from $(tilde "$PROJECT_DIR")?" || die "Aborted."
  for f in "${PATHS[@]}"; do [[ -e "$CLAUDE_DIR/$f" ]] && rm -rf "${CLAUDE_DIR:?}/$f" && ok "removed .claude/$f"; done
  for n in $PL; do
    (cd "$PROJECT_DIR" && claude plugin uninstall "$n@claude-plugins-official" --scope local >/dev/null 2>&1) \
      && ok "uninstalled plugin $n" || warn "Could not uninstall $n: run  claude plugin uninstall $n@claude-plugins-official --scope local"
  done
  if [[ -f "$CLAUDE_DIR/settings.local.json" ]]; then
    python3 - "$CLAUDE_DIR/settings.local.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
allow = d.get("permissions", {}).get("allow", [])
if "mcp__claude_ai_Gmail__send_message" in allow:
    allow.remove("mcp__claude_ai_Gmail__send_message"); json.dump(d, open(p, "w"), indent=2)
PY
  fi
  if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    EXCLUDE="$(git -C "$PROJECT_DIR" rev-parse --git-path info/exclude)"
    [[ "$EXCLUDE" = /* ]] || EXCLUDE="$PROJECT_DIR/$EXCLUDE"
    for f in "${PATHS[@]}"; do
      [[ -f "$EXCLUDE" ]] && { grep -vxF -e "/.claude/$f" -e "/.claude/$f/" "$EXCLUDE" > "$EXCLUDE.tmp" || true; mv "$EXCLUDE.tmp" "$EXCLUDE"; }
    done
    [[ -f "$EXCLUDE" ]] && { grep -vxF "/.claude/**/*.bak.*" "$EXCLUDE" > "$EXCLUDE.tmp" || true; mv "$EXCLUDE.tmp" "$EXCLUDE"; }
    ok "cleaned .git/info/exclude"
  fi
  rmdir "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills" 2>/dev/null || true
  endsec
  t="REMOVED"; printf "\n${OK}⬤${R}  ${B}${OK}%s${R}%*s%s ${ACC}100%%${R}\n\n" "$t" $(( W - 22 - ${#t} )) '' "$(pbar 100 10)"
  exit 0
fi

# --- Welcome -------------------------------------------------------------------
banner
section "" "Setup"
say "${B}What Underpaid does${R}"
hint "  You give /shipit a ticket; a crew of agents ships it:"
say "    ${ACC}Captain Kanban${R}    ${DIM}plans + coordinates${R}"
say "    ${ACC}Codey McCodeface${R}  ${DIM}writes the code${R}"
say "    ${ACC}Bugsy Malone${R}      ${DIM}writes the tests first, then runs the suite${R}"
say "    ${ACC}Pixel Pete${R}        ${DIM}checks the UI in a real browser${R}"
say "    ${ACC}Lockdown Larry${R}    ${DIM}security review, when the change is sensitive${R}"
say "    ${ACC}Nitpick Nick${R}      ${DIM}reviews; real bugs go back for one fix round${R}"
hint "  Everything stays uncommitted on your machine, ready for you to review."
echo
say "${B}Setup${R} ${DIM}· optional connections, I'll help you authenticate each one${R}"
hint "  • a ticketing system: Notion, Linear, Jira or GitHub Issues"
hint "  • Slack, via an incoming webhook, to ping you when work is ready"
[[ "$PROJECT_DIR" == "$REPO_DIR" ]] && die "Run this from the target project's folder, not from underpaid."
printf "\n\n"
ask "Install Underpaid into $(tilde "$PROJECT_DIR")?" || die "Aborted."
endsec

# --- Claude Code ---------------------------------------------------------------
section "1/6" "Claude Code"
command -v claude >/dev/null || die "claude is not installed: https://docs.claude.com/en/docs/claude-code"
ok "$(claude --version)"
# Projects installed under an old name (Shipyard, Kanbandits): move their files to the new names.
for old in {shipyard,kanbandits}.conf {shipyard,kanbandits}-notes.md {shipyard,kanbandits}-screenshots; do
  new="underpaid${old#shipyard}"; new="${new/underpaidkanbandits/underpaid}"
  [[ -e "$CLAUDE_DIR/$old" && ! -e "$CLAUDE_DIR/$new" ]] && mv "$CLAUDE_DIR/$old" "$CLAUDE_DIR/$new" && ok "Renamed .claude/$old → $new"
done
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  EX="$(git -C "$PROJECT_DIR" rev-parse --git-path info/exclude)"; [[ "$EX" = /* ]] || EX="$PROJECT_DIR/$EX"
  [[ -f "$EX" ]] && sed -i -E '/^\/\.claude\/(shipyard|kanbandits)/d' "$EX"
fi
REUSE=0
if [[ -f "$CONF" ]] && ask "Existing config found ($(tilde "$CONF")). Keep it?"; then
  REUSE=1
  TICKETS="$(conf_get TICKETS)"; NOTIFY="$(conf_get NOTIFY)"; NOTIFY_TO="$(conf_get NOTIFY_TO)"
  ok "Keeping existing config"
fi
endsec

# --- Ticketing -----------------------------------------------------------------
section "2/6" "Ticketing system"
if (( ! REUSE )); then
  choose choice 4 "Where do your tickets live?" \
    "Notion" "Linear" "Jira" "GitHub Issues" "None (/shipit takes a plain description)"
  TICKETS=$(t=(notion linear jira github none); echo "${t[choice]}")
fi

mcp_connected() { claude mcp list 2>/dev/null | grep -i "$1" | grep -q '✔'; }
# require_mcp <label> <grep pattern> <server name> <mcp url>
require_mcp() {
  hint "Checking $1 connection…"
  until mcp_connected "$2"; do
    warn "$1 is not connected in Claude Code."
    if ! claude mcp list 2>/dev/null | grep -qi "$2" && ask "Add the $1 MCP server ($4)?"; then
      claude mcp add --scope user --transport http "$3" "$4" >/dev/null && ok "$1 MCP server added"
    fi
    say "Authenticate in one of these ways:"
    hint "  a) claude.ai → Settings → Connectors → $1 → Connect"
    hint "  b) another terminal: claude → /mcp → $3 → Authenticate"
    local a; read -r -p "${BAR}${Q} Press Enter once authenticated ${DIM}(s = skip ticketing)${R} " a
    if [[ "$a" == s ]]; then TICKETS=none; warn "Continuing without ticketing."; return; fi
  done
  ok "$1 connected"
}

case "$TICKETS" in
  notion) require_mcp Notion notion notion https://mcp.notion.com/mcp ;;
  linear) require_mcp Linear linear linear https://mcp.linear.app/mcp ;;
  jira)   require_mcp "Jira (Atlassian)" atlassian atlassian https://mcp.atlassian.com/v2/mcp ;;
  github)
    command -v gh >/dev/null || die "Install the GitHub CLI: https://cli.github.com"
    until gh auth status >/dev/null 2>&1; do
      warn "gh is not authenticated."
      ask "Run gh auth login now?" && gh auth login || { TICKETS=none; warn "Continuing without ticketing."; break; }
    done
    [[ "$TICKETS" == github ]] && ok "GitHub authenticated" ;;
  *) ok "No ticketing" ;;
esac

if (( ! REUSE )); then
  BOARD="" STATUS_IN_PROGRESS="" STATUS_DONE="" PR_FIELD="" NOTES_FIELD=""
  case "$TICKETS" in
    notion)
      prompt BOARD "Tickets database URL or ID" ""
      prompt STATUS_IN_PROGRESS "Status for 'in progress'" "In progress"
      prompt STATUS_DONE "Status for 'done'" "Done"
      prompt PR_FIELD "Property for the PR link (- = none)" "PR"
      prompt NOTES_FIELD "Property for the result note (- = none)" "-" ;;
    linear)
      prompt BOARD "Team key, e.g. ENG (- = all teams)" "-"
      prompt STATUS_IN_PROGRESS "State for 'in progress'" "In Progress"
      prompt STATUS_DONE "State for 'done'" "Done" ;;
    jira)
      prompt BOARD "Project key, e.g. PROJ" ""
      prompt STATUS_IN_PROGRESS "Status for 'in progress'" "In Progress"
      prompt STATUS_DONE "Status for 'done'" "Done" ;;
    github)
      prompt BOARD "Issues repo (owner/repo)" \
        "$(cd "$PROJECT_DIR" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)" ;;
  esac
  # "-" means "explicitly none"
  for v in BOARD PR_FIELD NOTES_FIELD; do [[ "${!v}" == "-" ]] && printf -v "$v" '%s' ""; done
fi
endsec

# --- Slack ---------------------------------------------------------------------
section "3/6" "Notifications"
if (( ! REUSE )); then
  hint "Get the report on your phone when work is ready, even away from the PC."
  choose choice 2 "Notify me via" "Slack (incoming webhook)" "Gmail (Claude's Gmail connector, email to yourself)" "None (report in the terminal only)"
  NOTIFY=$(t=(slack gmail none); echo "${t[choice]}")
fi
if [[ "$NOTIFY" == gmail ]]; then
  hint "Checking Gmail connection…"
  until mcp_connected gmail; do
    warn "Gmail is not connected in Claude Code."
    hint "  claude.ai → Settings → Connectors → Gmail → Connect, then restart claude"
    read -r -p "${BAR}${Q} Press Enter once connected ${DIM}(s = no notifications)${R} " a
    if [[ "$a" == s ]]; then NOTIFY=none; warn "Continuing without notifications."; break; fi
  done
fi
if [[ "$NOTIFY" == gmail ]]; then
  ok "Gmail connected"
  (( REUSE )) || prompt NOTIFY_TO "Send the report to" "$(git config user.email 2>/dev/null || true)"
  # Without this, the send waits for a permission prompt, so you'd get nothing while away from the PC.
  if ask "Allow /shipit to send that email without asking each time?"; then
    python3 - "$CLAUDE_DIR/settings.local.json" <<'PY'
import json, os, sys
p = sys.argv[1]; os.makedirs(os.path.dirname(p), exist_ok=True)
d = json.load(open(p)) if os.path.exists(p) else {}
allow = d.setdefault("permissions", {}).setdefault("allow", [])
rule = "mcp__claude_ai_Gmail__send_message"
if rule not in allow: allow.append(rule)
json.dump(d, open(p, "w"), indent=2)
PY
    ok "Allowed in .claude/settings.local.json"
  else
    warn "Claude will ask before each email; the run waits for you."
  fi
fi
if [[ "$NOTIFY" == slack ]]; then
  # Claude Code injects the "env" block of its settings into every session, so a webhook there is enough.
  if [[ -z "${SLACK_WEBHOOK_URL:-}" && -f "$USER_CLAUDE_DIR/settings.json" ]]; then
    SLACK_WEBHOOK_URL="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("env",{}).get("SLACK_WEBHOOK_URL",""))' \
      "$USER_CLAUDE_DIR/settings.json" 2>/dev/null || true)"
    [[ -n "$SLACK_WEBHOOK_URL" ]] && ok "Webhook found in $(tilde "$USER_CLAUDE_DIR")/settings.json"
  fi
  if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
    warn "SLACK_WEBHOOK_URL is not set."
    hint "Get one: api.slack.com/apps → your app → Incoming Webhooks → Add New Webhook"
    while :; do
      read -r -s -p "${BAR}${Q} Paste the webhook URL ${DIM}(hidden · s = no Slack)${R} ${ACC}›${R} " SLACK_WEBHOOK_URL; echo
      if [[ "$SLACK_WEBHOOK_URL" == s ]]; then NOTIFY=none; break; fi
      [[ "$SLACK_WEBHOOK_URL" == https://hooks.slack.com/* ]] && break
      warn "That doesn't look like a Slack webhook (must start with https://hooks.slack.com/)."
    done
    if [[ "$NOTIFY" == slack ]]; then
      case "${SHELL##*/}" in zsh) RC="$HOME/.zshrc" ;; *) RC="$HOME/.bashrc" ;; esac
      if ask "Save it to $(tilde "$RC")?"; then
        printf "\nexport SLACK_WEBHOOK_URL='%s'\n" "$SLACK_WEBHOOK_URL" >> "$RC"
        ok "Saved to $(tilde "$RC") ${DIM}(open a new terminal or: source $(tilde "$RC"))${R}"
      else
        warn "Not saved. Export it yourself before starting claude."
      fi
    fi
  fi
  if [[ "$NOTIFY" == slack ]] && ask "Send a test message to Slack?"; then
    resp=$(curl -s -X POST -H 'Content-type: application/json' \
      --data '{"text":"💸 Underpaid: connection test ✔"}' "$SLACK_WEBHOOK_URL" || true)
    [[ "$resp" == ok ]] && ok "Test message delivered" || die "Webhook replied: '$resp'"
  fi
fi
case "$NOTIFY" in
  slack) ok "Slack on" ;; gmail) ok "Gmail on ${DIM}(to ${NOTIFY_TO:-$(conf_get NOTIFY_TO)})${R}" ;;
  *) ok "Notifications off ${DIM}(report shows in the terminal only)${R}" ;;
esac
endsec

# --- Project settings ----------------------------------------------------------
section "4/6" "Project settings"
if (( ! REUSE )); then
  default_test=""
  if   [[ -x "$PROJECT_DIR/bin/rspec" ]]; then default_test="bin/rspec"
  elif [[ -f "$PROJECT_DIR/Gemfile" || -f "$PROJECT_DIR/gems.rb" ]]; then default_test="bundle exec rspec"
  elif [[ -f "$PROJECT_DIR/mix.exs" ]]; then default_test="mix test"
  elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then default_test="cargo test"
  elif [[ -f "$PROJECT_DIR/go.mod" ]]; then default_test="go test ./..."
  elif [[ -x "$PROJECT_DIR/mvnw" ]]; then default_test="./mvnw test"
  elif [[ -f "$PROJECT_DIR/pom.xml" ]]; then default_test="mvn test"
  elif [[ -x "$PROJECT_DIR/gradlew" ]]; then default_test="./gradlew test"
  elif compgen -G "$PROJECT_DIR/build.gradle*" >/dev/null; then default_test="gradle test"
  elif compgen -G "$PROJECT_DIR/*.sln" >/dev/null || compgen -G "$PROJECT_DIR/*.csproj" >/dev/null; then default_test="dotnet test"
  elif [[ -f "$PROJECT_DIR/Package.swift" ]]; then default_test="swift test"
  elif [[ -f "$PROJECT_DIR/artisan" ]]; then default_test="php artisan test"
  elif [[ -f "$PROJECT_DIR/composer.json" ]]; then default_test="vendor/bin/phpunit"
  elif [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/pytest.ini" || -f "$PROJECT_DIR/requirements.txt" ]]; then default_test="pytest"
  elif [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then default_test="pnpm test"
  elif [[ -f "$PROJECT_DIR/yarn.lock" ]]; then default_test="yarn test"
  elif [[ -f "$PROJECT_DIR/bun.lockb" || -f "$PROJECT_DIR/bun.lock" ]]; then default_test="bun test"
  elif [[ -f "$PROJECT_DIR/package.json" ]]; then default_test="npm test"
  fi
  prompt TEST_CMD "Full test suite command" "$default_test"
  prompt LINT_CMD "Lint command (- = let QA find it)" "-"
  [[ "$LINT_CMD" == "-" ]] && LINT_CMD=""
  prompt BASE_BRANCH "Base branch" \
    "$(git -C "$PROJECT_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo main)"
  choose choice 0 "Show me the plan for approval before coding" \
    "Only for large changes (migrations, many files, public APIs)" "Always" "Never, run straight through"
  PLAN_APPROVAL=$(t=(large always never); echo "${t[choice]}")
  hint "A git worktree lets the crew work in a separate folder while you keep working in yours."
  hint "Say No if your app or tests only run from this folder (e.g. a Docker setup tied to it)."
  ask "Work in a separate git worktree?" && WORKTREE=yes || WORKTREE=no
  default_app=""
  if   [[ -x "$PROJECT_DIR/bin/dev" ]]; then default_app="bin/dev"
  elif [[ -f "$PROJECT_DIR/mix.exs" ]]; then default_app="mix phx.server"
  elif [[ -x "$PROJECT_DIR/bin/rails" ]]; then default_app="bin/rails server"
  elif [[ -f "$PROJECT_DIR/artisan" ]]; then default_app="php artisan serve"
  elif has package.json '"dev"[[:space:]]*:'; then default_app="npm run dev"
  elif has package.json '"start"[[:space:]]*:'; then default_app="npm start"
  fi
  hint "UI QA (Pixel Pete) starts your app and checks changed pages in a browser."
  prompt APP_CMD "Command that starts the app (- = no UI QA)" "${default_app:--}"
  [[ "$APP_CMD" == "-" ]] && APP_CMD=""
  APP_URL=""
  if [[ -n "$APP_CMD" ]]; then
    case "$APP_CMD" in *phx*|*rails*|bin/dev) u=http://localhost:3000 ;; *artisan*) u=http://localhost:8000 ;; *) u=http://localhost:3000 ;; esac
    [[ "$APP_CMD" == *phx* ]] && u=http://localhost:4000
    has package.json '"vite"' && [[ "$APP_CMD" == npm* ]] && u=http://localhost:5173
    prompt APP_URL "App URL" "$u"
  fi
  mkdir -p "$CLAUDE_DIR"
  cat > "$CONF" <<EOF
# Underpaid config, read by /shipit. Re-run install.sh to regenerate, or edit by hand.
TICKETS=$TICKETS
BOARD=$BOARD
STATUS_IN_PROGRESS=$STATUS_IN_PROGRESS
STATUS_DONE=$STATUS_DONE
PR_FIELD=$PR_FIELD
NOTES_FIELD=$NOTES_FIELD
NOTIFY=$NOTIFY
NOTIFY_TO=${NOTIFY_TO:-}
BASE_BRANCH=${BASE_BRANCH:-main}
TEST_CMD=$TEST_CMD
LINT_CMD=$LINT_CMD
PLAN_APPROVAL=$PLAN_APPROVAL
WORKTREE=$WORKTREE
APP_CMD=$APP_CMD
APP_URL=$APP_URL
EOF
  ok "Config written to $(tilde "$CONF")"
else
  # Connection steps may have fallen back to none; keep the file in sync.
  sed -i "s/^TICKETS=.*/TICKETS=$TICKETS/; s/^NOTIFY=.*/NOTIFY=$NOTIFY/" "$CONF"
  ok "Config kept"
fi
endsec

# --- Stack skills --------------------------------------------------------------
section "5/6" "Stack skills"
# Detect the stack and offer what makes Codey and Nick better at it:
#   skill  = expert skill bundled in underpaid/stack-skills, copied into .claude/skills
#   plugin = official Claude plugin (LSP = real code intelligence), installed for this project only
SUGGEST=()   # "kind|name|why|what|binary the plugin needs"
add() { [[ " ${SUGGEST[*]} " == *"|$2|"* ]] || SUGGEST+=("$1|$2|$3|$4|${5:-}"); }
FRONTEND=0
if has Gemfile '^\s*gem .rails.' || has gems.rb '^\s*gem .rails.'; then
  add skill  rails-expert "Rails" "ActiveRecord, N+1, callbacks, security, testing"
  add plugin ruby-lsp "Ruby" "code intelligence for Ruby" ruby-lsp
  [[ -d "$PROJECT_DIR/app/views" ]] && FRONTEND=1
elif exists Gemfile gems.rb; then
  add plugin ruby-lsp "Ruby" "code intelligence for Ruby" ruby-lsp
fi
if exists mix.exs; then
  add skill elixir-expert "Elixir" "Phoenix, Ecto, OTP, LiveView"
  exists 'lib/*_web' && FRONTEND=1
fi
if exists Cargo.toml; then
  add skill  rust-expert "Rust" "ownership, errors, async, unsafe"
  add plugin rust-analyzer-lsp "Rust" "code intelligence for Rust" rust-analyzer
fi
if exists pom.xml 'build.gradle*'; then
  add skill  java-expert "Java/Kotlin" "Spring Boot, JPA, Maven/Gradle"
  add plugin jdtls-lsp "Java" "code intelligence for Java" jdtls
  exists 'build.gradle.kts' 'src/main/kotlin' && add plugin kotlin-lsp "Kotlin" "code intelligence for Kotlin" kotlin-lsp
fi
if exists go.mod; then add plugin gopls-lsp "Go" "code intelligence for Go" gopls; fi
if exists pyproject.toml requirements.txt setup.py; then add plugin pyright-lsp "Python" "code intelligence for Python" pyright; fi
if exists composer.json; then add plugin php-lsp "PHP" "code intelligence for PHP" intelephense; exists resources/views && FRONTEND=1; fi
if exists '*.sln' '*.csproj'; then add plugin csharp-lsp "C#" "code intelligence for C#" csharp-ls; fi
if exists Package.swift '*.xcodeproj'; then add plugin swift-lsp "Swift" "code intelligence for Swift" sourcekit-lsp; fi
if exists package.json; then
  add skill  typescript-expert "JavaScript/TypeScript" "types, async, Node, ESM/CJS"
  add plugin typescript-lsp "JavaScript/TypeScript" "code intelligence for JS/TS" typescript-language-server
  has package.json '"(react|next)"'      && add skill react-expert   "React" "hooks, effects, rendering, Next.js"
  has package.json '"(vue|nuxt)"'        && add skill vue-expert     "Vue" "Composition API, reactivity, Pinia, Nuxt"
  has package.json '"@angular/core"'     && add skill angular-expert "Angular" "signals, RxJS, change detection, DI"
  has package.json '"(react|next|vue|nuxt|svelte|@sveltejs/kit|@angular/core|solid-js|astro)"' && FRONTEND=1
fi
exists templates 'app/templates' && FRONTEND=1
if (( FRONTEND )); then
  add plugin frontend-design "Frontend" "UI/UX expert: layout, typography, visual design"
  add plugin playwright "Frontend" "real browser for Pixel Pete's UI QA (screenshots, clicks)" npx
fi

plugin_installed() { claude plugin list 2>/dev/null | grep -q "❯ $1@"; }
INSTALL_SKILLS=() NEW_PLUGINS=()
for e in ${SUGGEST[@]+"${SUGGEST[@]}"}; do
  IFS='|' read -r kind name why what bin <<<"$e"
  if [[ "$kind" == skill ]]; then
    [[ -f "$REPO_DIR/stack-skills/$name/SKILL.md" ]] || continue
    if [[ -d "$USER_CLAUDE_DIR/skills/$name" ]]; then ok "$name ${DIM}(already installed globally)${R}"; continue; fi
    say "${ACC}$why${R} ${DIM}→${R} ${B}$name${R} ${DIM}· $what${R}"
    ask "Install the $name skill?" && INSTALL_SKILLS+=("$name")
  else
    if plugin_installed "$name"; then ok "$name ${DIM}(plugin already installed)${R}"; continue; fi
    say "${ACC}$why${R} ${DIM}→${R} ${B}$name${R} ${DIM}· $what${R}"
    [[ -n "$bin" ]] && ! command -v "$bin" >/dev/null && hint "  needs $bin on your PATH to work; install it before using the plugin"
    if ask "Install the $name plugin for this project?"; then
      claude plugin install "$name@claude-plugins-official" --scope local >/dev/null 2>&1 \
        && { ok "$name plugin installed"; NEW_PLUGINS+=("$name"); } || warn "Could not install $name: run  claude plugin install $name@claude-plugins-official"
    fi
  fi
done
(( ${#SUGGEST[@]} )) || ok "No stack-specific skills to suggest"
endsec

# --- Install -------------------------------------------------------------------
section "6/6" "Install"
install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    hint "backed up previous $(basename "$dst")"
  fi
  cp "$src" "$dst"
  ok ".claude/${dst#"$CLAUDE_DIR"/}"
}
install_file "$REPO_DIR/skills/shipit/SKILL.md" "$CLAUDE_DIR/skills/shipit/SKILL.md"
for f in "$REPO_DIR"/agents/*.md; do
  install_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done
for name in ${INSTALL_SKILLS[@]+"${INSTALL_SKILLS[@]}"}; do
  install_file "$REPO_DIR/stack-skills/$name/SKILL.md" "$CLAUDE_DIR/skills/$name/SKILL.md"
done

# Keep it out of the project's git without touching its .gitignore (local-only exclude).
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  EXCLUDE="$(git -C "$PROJECT_DIR" rev-parse --git-path info/exclude)"
  [[ "$EXCLUDE" = /* ]] || EXCLUDE="$PROJECT_DIR/$EXCLUDE"
  mkdir -p "$(dirname "$EXCLUDE")"
  for p in "/.claude/**/*.bak.*" /.claude/skills/shipit/ /.claude/underpaid.conf /.claude/underpaid-notes.md /.claude/underpaid-screenshots/ $(cd "$REPO_DIR/agents" && printf '/.claude/agents/%s ' *.md) \
           ${INSTALL_SKILLS[@]+$(printf '/.claude/skills/%s/ ' "${INSTALL_SKILLS[@]}")}; do
    grep -qxF "$p" "$EXCLUDE" 2>/dev/null || echo "$p" >> "$EXCLUDE"
  done
  ok "Git-ignored locally ${DIM}(.git/info/exclude · never committed)${R}"
fi

# A global `shipit` would override the project one; a global `ticket-to-pr` is the old pre-Underpaid version.
for name in shipit ticket-to-pr; do
  GLOBAL_SKILL="$USER_CLAUDE_DIR/skills/$name"
  [[ -d "$GLOBAL_SKILL" ]] || continue
  warn "Global skill /$name found: it is an old version or overrides the project's /shipit."
  if ask "Move it to $(tilde "$USER_CLAUDE_DIR")/$name.global-backup?"; then
    mv "$GLOBAL_SKILL" "$USER_CLAUDE_DIR/$name.global-backup.$(date +%Y%m%d%H%M%S)"
    ok "Moved /$name out of the way"
  else
    warn "Left in place: /$name stays available globally."
  fi
done

# Remember what was installed, so --uninstall can remove exactly that.
uniq_words() { tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'; }
SK=$(echo "$(conf_get INSTALLED_SKILLS) ${INSTALL_SKILLS[*]-}" | uniq_words)
PL=$(echo "$(conf_get INSTALLED_PLUGINS) ${NEW_PLUGINS[*]-}" | uniq_words)
sed -i '/^INSTALLED_/d' "$CONF"
printf 'INSTALLED_SKILLS=%s\nINSTALLED_PLUGINS=%s\n' "$SK" "$PL" >> "$CONF"

# Optional dependencies: the agents degrade gracefully without them.
compgen -G "$USER_CLAUDE_DIR/plugins/cache/*/ponytail*" >/dev/null \
  || warn "ponytail plugin not found; Nitpick Nick will skip ponytail-review."
endsec

# --- Summary -------------------------------------------------------------------
if [[ "$TICKETS" == none ]]; then ARG="<description of the work>"; else ARG="<ticket title or ID>"; fi
TICKETS_LABEL="$TICKETS"; [[ "$TICKETS" == none ]] && TICKETS_LABEL="none (plain descriptions)"
t="DONE"; printf "\n${OK}⬤${R}  ${B}${OK}%s${R}%*s%s ${ACC}100%%${R}\n" "$t" $(( W - 22 - ${#t} )) '' "$(pbar 100 10)"
box "SYSTEM STATUS: READY TO SHIP" \
  "${ACC}Tickets${R}   $TICKETS_LABEL" \
  "${ACC}Notify${R}    $NOTIFY" \
  "${ACC}Tests${R}     $(conf_get TEST_CMD)" \
  "${ACC}Config${R}    .claude/underpaid.conf" \
  "" \
  "${B}${ACC}Run it${R}" \
  "  1  cd $(tilde "$PROJECT_DIR")" \
  "  2  claude" \
  "  3  /model opus  +  /effort high  ${DIM}(recommended for the Lead)${R}" \
  "  4  /shipit $ARG" \
  "" \
  "${B}${ACC}The crew${R}" \
  "  ${ACC}Captain Kanban${R}    Lead      plans and coordinates" \
  "  ${ACC}Codey McCodeface${R}  Sonnet    writes the code (high effort)" \
  "  ${ACC}Bugsy Malone${R}      Opus      tests first, then the full suite" \
  "  ${ACC}Pixel Pete${R}        Opus      UI QA in a browser (UI changes)" \
  "  ${ACC}Lockdown Larry${R}    Opus      security review (sensitive changes)" \
  "  ${ACC}Nitpick Nick${R}      Opus      reviews (high effort, + ponytail)" \
  "" \
  "Everything stays uncommitted for review; the crew fixes what review finds." \
  "After deploy, tell the Lead: \"<ticket> is in production, PR <link>\"."
