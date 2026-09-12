```bash
#!/usr/bin/env bash
#
# install.sh - automatic installer for safe-shell-tools.
# Run this script from the repository root: ./install.sh

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/safe-shell-tools"
BASHRC="$HOME/.bashrc"

echo "==> Preparing directories..."
mkdir -p "$BIN_DIR" "$SHARE_DIR"

echo "==> Copying saferm and safels..."
cp "$REPO_DIR/bin/saferm" "$BIN_DIR/saferm"
cp "$REPO_DIR/bin/safels" "$BIN_DIR/safels"
chmod +x "$BIN_DIR/saferm" "$BIN_DIR/safels"

echo "==> Creating symbolic links for rm / undelete / ls..."
ln -sf "$BIN_DIR/saferm" "$BIN_DIR/rm"
ln -sf "$BIN_DIR/saferm" "$BIN_DIR/undelete"
ln -sf "$BIN_DIR/safels" "$BIN_DIR/ls"

echo "==> Copying the cd/mkdir function file..."
cp "$REPO_DIR/shell/safe-shell-functions.sh" "$SHARE_DIR/safe-shell-functions.sh"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SOURCE_LINE="source \"$SHARE_DIR/safe-shell-functions.sh\""

echo "==> Checking ~/.bashrc..."
touch "$BASHRC"

if ! grep -qF "$PATH_LINE" "$BASHRC"; then
    {
        echo ""
        echo "# safe-shell-tools: search ~/.local/bin before system tools"
        echo "$PATH_LINE"
    } >> "$BASHRC"
    echo "    PATH entry added."
else
    echo "    PATH entry already exists, skipping."
fi

if ! grep -qF "$SOURCE_LINE" "$BASHRC"; then
    {
        echo ""
        echo "# safe-shell-tools: cd (history) and mkdir (enter-directory prompt) functions"
        echo "$SOURCE_LINE"
    } >> "$BASHRC"
    echo "    source entry added."
else
    echo "    source entry already exists, skipping."
fi

echo
echo "Installation completed successfully."
echo "To activate it: source ~/.bashrc   (or open a new terminal)"
echo
echo "Verification:"
echo "  which rm     -> should show ~/.local/bin/rm"
echo "  which ls     -> should show ~/.local/bin/ls"
echo "  type cd      -> should show \"cd is a function\""
echo "  type mkdir   -> should show \"mkdir is a function\""
```
