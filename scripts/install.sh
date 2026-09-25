#!/bin/bash
set -e

echo "🔧 Hindi IME installer"
echo ""

# Check dependencies
command -v nim >/dev/null 2>&1 || { echo "❌ Install Nim first"; exit 1; }
command -v fcitx5 >/dev/null 2>&1 || { echo "❌ Install Fcitx5 first"; exit 1; }

# Check for WordNet binary
echo "📚 Checking for WordNet Hindi binary..."
WORDNET_FOUND=false
for path in "$HOME/.local/share/hindi-ime/wordnet_hindi_dict.bin" \
            "./wordnet_hindi_dict.bin" \
            "./data/wordnet_hindi_dict.bin"; do
  if [ -f "$path" ]; then
    echo "   ✅ Found: $path"
    WORDNET_FOUND=true
    break
  fi
done

if [ "$WORDNET_FOUND" = false ]; then
  echo "   ⚠️  Not found. System will work with the 730-word dict only."
  echo "   ℹ️  Run ./scripts/fetch_wordnet.sh for setup instructions."
  echo ""
fi

echo "📦 Building..."
nim c -d:release src/compile_rime_hindi.nim
nim c -d:release src/build_rime_dict.nim

if [ "$WORDNET_FOUND" = true ]; then
  echo "📖 Generating full dictionary (with WordNet)..."
  ./src/compile_rime_hindi
else
  echo "📖 Generating base dictionary (730 curated words)..."
  ./src/compile_rime_hindi
fi

RIME_DIR="${HINDI_IME_RIME_DIR:-$HOME/.local/share/fcitx5/rime}"
mkdir -p "$RIME_DIR"
cp rime/*.yaml "$RIME_DIR/" 2>/dev/null || true

echo "🔄 Restarting Fcitx5..."
fcitx5 -r -d 2>/dev/null || true

echo "✅ Done! Select 'hindi_ai' in Fcitx5."
