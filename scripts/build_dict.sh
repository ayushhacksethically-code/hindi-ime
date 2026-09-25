#!/bin/bash
set -e

echo "🔨 Compiling Rime Hindi Dictionary Compiler..."
nim c -d:release src/compile_rime_hindi.nim

echo "📖 Running dictionary generation..."
./src/compile_rime_hindi

echo "✅ Dictionary generated successfully."
