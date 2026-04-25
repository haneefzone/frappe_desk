#!/usr/bin/env bash
# Frappe Desk — one-command installer.
#
# Run from inside the project directory:
#     bash install.sh
#
# What it does:
#   1. Installs Python venv + Flask deps for the panel itself (sudo)
#   2. Starts the panel as a background daemon
#   3. Opens http://127.0.0.1:5050/ in your default browser
#
# That's it. Everything else (MariaDB, Redis, Node, bench, etc.) installs
# from inside the web UI by clicking the Install buttons on the Requirements
# page. No more cascading bash failures.

set -euo pipefail

if [ -t 1 ]; then BOLD=$'\033[1m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RST=$'\033[0m'
else BOLD=""; GRN=""; YLW=""; RED=""; DIM=""; RST=""; fi
say()  { echo "${BOLD}$*${RST}"; }
ok()   { echo "  ${GRN}✓${RST} $*"; }
warn() { echo "  ${YLW}!${RST} $*"; }
fail() { echo "  ${RED}✗${RST} $*" >&2; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Sanity check: are we inside an actual frappe-desk project?
[ -f app.py ] || fail "install.sh must be run from the project root (where app.py lives)."
[ -f bootstrap/setup.sh ] || fail "Missing bootstrap/setup.sh — was the zip extracted fully?"

echo
say "Frappe Desk — one-command installer"
echo "${DIM}  project: $PROJECT_ROOT${RST}"
echo

# ─── Step 1: bootstrap ──────────────────────────────────────────────────────
say "Step 1/3 · System bootstrap (Python venv + panel dependencies)"
echo "${DIM}  This needs sudo for apt-get. Enter your password if prompted.${RST}"
echo
if [ "$(id -u)" -eq 0 ]; then
    bash bootstrap/setup.sh
else
    sudo bash bootstrap/setup.sh
fi
ok "Bootstrap finished"

# ─── Step 2: start panel ────────────────────────────────────────────────────
echo
say "Step 2/3 · Starting Frappe Desk in the background"
chmod +x ./frappe-desk 2>/dev/null || true
./frappe-desk start --bg

# Give the Flask server a moment to bind the port
HOST="127.0.0.1"; PORT="5050"
for i in 1 2 3 4 5; do
    if curl -sf -o /dev/null "http://$HOST:$PORT/" 2>/dev/null; then
        ok "Panel is listening on http://$HOST:$PORT/"
        break
    fi
    sleep 1
done

# ─── Step 3: open browser ───────────────────────────────────────────────────
echo
say "Step 3/3 · Opening browser"
URL="http://$HOST:$PORT/"

# Try multiple methods so it works on WSL, macOS, regular Linux
opened=0
if command -v explorer.exe >/dev/null 2>&1; then
    # WSL: opens Windows default browser
    explorer.exe "$URL" 2>/dev/null || true
    opened=1
elif command -v wslview >/dev/null 2>&1; then
    wslview "$URL" 2>/dev/null && opened=1 || true
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 && opened=1 || true
elif command -v open >/dev/null 2>&1; then
    open "$URL" >/dev/null 2>&1 && opened=1 || true
fi

if [ "$opened" -eq 1 ]; then
    ok "Opened $URL in your browser"
else
    warn "Couldn't auto-open browser. Open manually:  $URL"
fi

# ─── Done ──────────────────────────────────────────────────────────────────
echo
echo "${GRN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo "${GRN}${BOLD}  ✓ Frappe Desk is running.${RST}"
echo "${GRN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo
echo "  ${BOLD}URL:${RST}    $URL"
echo "  ${BOLD}Logs:${RST}   $PROJECT_ROOT/panel-server.log"
echo "  ${BOLD}Stop:${RST}   ./frappe-desk stop"
echo
echo "${BOLD}Next steps in the web UI:${RST}"
echo "  1. Click 'Requirements' in the sidebar"
echo "  2. Click 'Install' on each component (steps 1–9 in order)"
echo "  3. After installing MariaDB/Node/uv, restart the panel:"
echo "       ./frappe-desk stop && ./frappe-desk start"
echo "  4. Then click 'Benches' → '+ New Bench' to scaffold Frappe"
echo
