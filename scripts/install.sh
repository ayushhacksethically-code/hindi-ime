#!/bin/bash
set -e

echo "🔧 Hindi IME installer"
echo ""

# Check dependencies
command -v nim >/dev/null 2>&1 || { echo "❌ Install Nim first"; exit 1; }
command -v fcitx5 >/dev/null 2>&1 || { echo "❌ Install Fcitx5 first"; exit 1; }

echo "📦 Building..."
nim c -d:release src/compile_rime_hindi.nim
nim c -d:release src/build_rime_dict.nim

RIME_DIR="${HINDI_IME_RIME_DIR:-$HOME/.local/share/fcitx5/rime}"
mkdir -p "$RIME_DIR"
TARGET_DICT="$RIME_DIR/hindi_ai.dict.yaml"

# Install schema configuration
cp rime/hindi_ai.schema.yaml "$RIME_DIR/" 2>/dev/null || true
cp rime/hindi_ai.custom.yaml "$RIME_DIR/" 2>/dev/null || true

if [ -f "$TARGET_DICT" ]; then
  echo "📖 Existing dictionary found. Skipping generation to prevent overwrite."
  echo "   To regenerate, run: ./scripts/build_dict.sh"
else
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

  if [ "$WORDNET_FOUND" = true ]; then
    echo "📖 Generating full dictionary (with WordNet)..."
    ./src/compile_rime_hindi
  else
    echo "   ⚠️  Not found. System will work with the 730-word dict only."
    echo "   ℹ️  Run ./scripts/fetch_wordnet.sh for setup instructions."
    echo ""
    echo "📖 Generating base dictionary (730 curated words)..."
    ./src/compile_rime_hindi
  fi
  cp rime/hindi_ai.dict.yaml "$RIME_DIR/" 2>/dev/null || true
fi

echo "🔄 Restarting Fcitx5..."
fcitx5 -r -d 2>/dev/null || true

echo "✅ Done! Select 'hindi_ai' in Fcitx5."
