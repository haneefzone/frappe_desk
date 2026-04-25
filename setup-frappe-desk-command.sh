#!/usr/bin/env bash
# Creates a symlink so you can run `frappe-desk` from anywhere.
# Usage:  bash setup-frappe-desk-command.sh
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET="$SCRIPT_DIR/frappe-desk"

# Prefer /usr/local/bin, fall back to ~/.local/bin (no sudo)
if [ -w "/usr/local/bin" ]; then
  LINK="/usr/local/bin/frappe-desk"
else
  mkdir -p "$HOME/.local/bin"
  LINK="$HOME/.local/bin/frappe-desk"
fi

ln -sf "$TARGET" "$LINK"
chmod +x "$TARGET"
echo "Installed: $LINK -> $TARGET"
echo "You may need to restart your shell if 'frappe-desk' isn't on PATH."
