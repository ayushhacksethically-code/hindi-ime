#!/bin/bash
set -e
echo "🔄 Updating Hindi IME..."
git pull origin main
./scripts/install.sh
echo "✅ Update complete!"
