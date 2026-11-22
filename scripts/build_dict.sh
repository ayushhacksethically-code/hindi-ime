#!/bin/bash
set -e

echo "🔨 Compiling Rime Hindi Dictionary Compiler..."
nim c -d:release src/compile_rime_hindi.nim

echo "📖 Running dictionary generation..."
./src/compile_rime_hindi

echo "🚀 Deploying and compiling Rime binary tables..."
if command -v rime_deployer >/dev/null 2>&1; then
  rime_deployer --build "${HINDI_IME_RIME_DIR:-$HOME/.local/share/fcitx5/rime}"
fi

echo "✅ Dictionary generated and deployed to Rime successfully."
