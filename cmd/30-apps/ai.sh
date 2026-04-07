#!/usr/bin/env bash
set -euo pipefail

if ! command -v opencode &>/dev/null; then
    echo "📦 Installing opencode CLI..."
    curl -fsSL https://opencode.ai/install | bash
else
    echo "✅ opencode CLI already installed"
fi

echo "📦 Installing opencode-desktop-bin..."
yay -S --needed --noconfirm opencode-desktop-bin

echo "✅ AI tools setup complete"
