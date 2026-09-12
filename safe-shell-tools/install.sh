#!/usr/bin/env bash
#
# install.sh - safe-shell-tools için otomatik kurulum betiği.
# Bu betiği repo'nun kök dizininden çalıştır: ./install.sh

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/safe-shell-tools"
BASHRC="$HOME/.bashrc"

echo "==> Dizinler hazırlanıyor..."
mkdir -p "$BIN_DIR" "$SHARE_DIR"

echo "==> saferm ve safels kopyalanıyor..."
cp "$REPO_DIR/bin/saferm" "$BIN_DIR/saferm"
cp "$REPO_DIR/bin/safels" "$BIN_DIR/safels"
chmod +x "$BIN_DIR/saferm" "$BIN_DIR/safels"

echo "==> rm / undelete / ls sembolik bağları oluşturuluyor..."
ln -sf "$BIN_DIR/saferm" "$BIN_DIR/rm"
ln -sf "$BIN_DIR/saferm" "$BIN_DIR/undelete"
ln -sf "$BIN_DIR/safels" "$BIN_DIR/ls"

echo "==> cd/mkdir fonksiyon dosyası kopyalanıyor..."
cp "$REPO_DIR/shell/safe-shell-functions.sh" "$SHARE_DIR/safe-shell-functions.sh"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SOURCE_LINE="source \"$SHARE_DIR/safe-shell-functions.sh\""

echo "==> ~/.bashrc kontrol ediliyor..."
touch "$BASHRC"

if ! grep -qF "$PATH_LINE" "$BASHRC"; then
    {
        echo ""
        echo "# safe-shell-tools: ~/.local/bin, sistem araçlarından önce aransın"
        echo "$PATH_LINE"
    } >> "$BASHRC"
    echo "    PATH satırı eklendi."
else
    echo "    PATH satırı zaten var, atlanıyor."
fi

if ! grep -qF "$SOURCE_LINE" "$BASHRC"; then
    {
        echo ""
        echo "# safe-shell-tools: cd (geçmiş) ve mkdir (içine gir sorusu) fonksiyonları"
        echo "$SOURCE_LINE"
    } >> "$BASHRC"
    echo "    source satırı eklendi."
else
    echo "    source satırı zaten var, atlanıyor."
fi

echo
echo "Kurulum tamamlandı."
echo "Etkin olması için: source ~/.bashrc   (ya da yeni bir terminal aç)"
echo
echo "Doğrulama:"
echo "  which rm     -> ~/.local/bin/rm göstermeli"
echo "  which ls     -> ~/.local/bin/ls göstermeli"
echo "  type cd      -> \"cd is a function\" göstermeli"
echo "  type mkdir   -> \"mkdir is a function\" göstermeli"
