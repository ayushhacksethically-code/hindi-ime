#!/bin/bash
set -e

RIME_DIR="${HINDI_IME_RIME_DIR:-$HOME/.local/share/fcitx5/rime}"

echo "=========================================="
echo "🗑️  Hindi IME Uninstaller"
echo "=========================================="
echo ""

echo "Removing Hindi IME files from $RIME_DIR..."
rm -f "$RIME_DIR/hindi_ai.schema.yaml"
rm -f "$RIME_DIR/hindi_ai.dict.yaml"

echo "🔄 Restarting Fcitx5..."
fcitx5 -r -d 2>/dev/null || true

echo ""
echo "✅ Hindi IME uninstalled successfully."
