#!/bin/bash
set -e

if ! command -v curl >/dev/null 2>&1; then
  echo "❌ 'curl' is required but not installed. Please install curl first."
  exit 1
fi

REPO="ayushhacksethically-code/hindi-ime"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
RELEASE_BINARY_URL="https://github.com/${REPO}/releases/latest/download/compile_rime_hindi"

echo "=========================================="
echo "🇮🇳  Hindi IME Installer"
echo "=========================================="
echo ""

# 1. Check for Fcitx5 and Rime
MISSING_DEPS=()
if ! command -v fcitx5 >/dev/null 2>&1; then
  MISSING_DEPS+=("fcitx5")
fi

RIME_AVAILABLE=false
if [ -d "/usr/share/rime-data" ] || [ -f "/usr/lib/fcitx5/fcitx5-rime.so" ] || [ -f "/usr/lib64/fcitx5/fcitx5-rime.so" ] || [ -f "/usr/lib/x86_64-linux-gnu/fcitx5/fcitx5-rime.so" ] || command -v rime_deployer >/dev/null 2>&1; then
  RIME_AVAILABLE=true
fi

if [ "${#MISSING_DEPS[@]}" -gt 0 ] || [ "$RIME_AVAILABLE" = false ]; then
  echo "⚠️  Missing required dependencies: Fcitx5 and/or Rime."
  echo ""
  echo "Please install them using your package manager:"
  echo ""
  echo "  Ubuntu/Debian:  sudo apt install fcitx5 fcitx5-rime"
  echo "  Fedora:         sudo dnf install fcitx5 fcitx5-rime"
  echo "  Arch Linux:     sudo pacman -S fcitx5 fcitx5-rime"
  echo "  openSUSE:       sudo zypper install fcitx5 fcitx5-rime"
  echo ""
  echo "Once installed, rerun this installer."
  exit 1
fi

RIME_DIR="${HINDI_IME_RIME_DIR:-$HOME/.local/share/fcitx5/rime}"
TARGET_DICT="$RIME_DIR/hindi_ai.dict.yaml"
TARGET_SCHEMA="$RIME_DIR/hindi_ai.schema.yaml"

if [ "$1" = "--dry-run" ]; then
  echo "🔍 Dry run mode: showing what would be touched"
  echo "Target directory: $RIME_DIR"
  echo "Files that will be installed or updated:"
  echo "  - $TARGET_SCHEMA"
  echo "  - $TARGET_DICT"
  exit 0
fi

mkdir -p "$RIME_DIR"

if [ -e "$RIME_DIR/hindi_ai.userdb" ]; then
  echo "📦 Preserving existing Rime user dictionary (hindi_ai.userdb)."
fi

# 2. Install schema configuration
echo "📥 Installing Rime schema configuration..."
if [ -f "rime/hindi_ai.schema.yaml" ]; then
  cp "rime/hindi_ai.schema.yaml" "$TARGET_SCHEMA"
else
  curl -fsSL "${RAW_BASE}/rime/hindi_ai.schema.yaml" -o "$TARGET_SCHEMA"
fi

# 3. Generate or install dictionary
echo "📖 Setting up dictionary..."
TMP_BIN=$(mktemp /tmp/compile_rime_hindi.XXXXXX)
trap 'rm -f "$TMP_BIN"' EXIT
DOWNLOAD_SUCCESS=false

# Try downloading pre-compiled binary
echo "🔍 Attempting to fetch pre-compiled dictionary generator..."
if curl -fsSL "$RELEASE_BINARY_URL" -o "$TMP_BIN" 2>/dev/null && [ -s "$TMP_BIN" ]; then
  chmod +x "$TMP_BIN"
  echo "🚀 Running dictionary compiler..."
  if "$TMP_BIN"; then
    DOWNLOAD_SUCCESS=true
    rm -f "$TMP_BIN"
  else
    echo "⚠️  Pre-compiled binary not compatible with this CPU. Falling back..."
    DOWNLOAD_SUCCESS=false
    rm -f "$TMP_BIN"
  fi
fi

# Fallback mechanism if release binary isn't published yet or download fails
if [ "$DOWNLOAD_SUCCESS" = false ]; then
  echo "ℹ️  Downloading pre-generated dictionary from repository (fastest fallback)..."
  if curl -fsSL "${RAW_BASE}/rime/hindi_ai.dict.yaml" -o "$TARGET_DICT" 2>/dev/null && [ -s "$TARGET_DICT" ]; then
    DOWNLOAD_SUCCESS=true
    echo "✅ Pre-generated dictionary downloaded successfully."
  else
    echo "⚠️  Dictionary download failed. Trying local sources..."
    # Local Nim compile (last resort)
    if [ -f "src/compile_rime_hindi.nim" ] && command -v nim >/dev/null 2>&1; then
      echo "🔨 Compiling from local source using Nim..."
      nim c -d:release -o:"$TMP_BIN" src/compile_rime_hindi.nim
      "$TMP_BIN" || true
      rm -f "$TMP_BIN"
    elif [ -f "rime/hindi_ai.dict.yaml" ]; then
      echo "📋 Copying pre-generated local dictionary..."
      cp "rime/hindi_ai.dict.yaml" "$TARGET_DICT"
    else
      echo "❌ All fallbacks failed. Please report this issue on GitHub."
      exit 1
    fi
  fi
fi

# 4. Restart Fcitx5
echo "🔄 Restarting Fcitx5..."
fcitx5 -r -d 2>/dev/null || true

echo ""
echo "=========================================="
echo "✅ Hindi IME installed successfully!"
echo "=========================================="
echo ""
echo "Next steps to start typing in Hindi:"
echo "  1. Switch to Rime using your Fcitx5 trigger key (default: Ctrl+Space)"
echo "  2. If 'hindi_ai' schema is not active, press F4 and select 'hindi_ai'"
echo "  3. Start typing in Hinglish (e.g., 'namaste' → नमस्ते, 'kya haal hai' → क्या हाल है)"
echo ""

# 5. Open fcitx5-configtool if in GUI environment
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  if command -v fcitx5-configtool >/dev/null 2>&1; then
    echo "🖥️  Opening Fcitx5 configuration tool..."
    echo "   (Make sure 'Rime' is added under your Input Methods list)"
    (fcitx5-configtool >/dev/null 2>&1 &) || true
  fi
fi
