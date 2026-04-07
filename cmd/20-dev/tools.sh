#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing postgresql via pacman..."
sudo pacman -Syu --needed --noconfirm postgresql

echo "📦 Installing github-cli..."
sudo pacman -Syu --needed --noconfirm github-cli

echo "📦 Installing protobuf + buf..."
sudo pacman -S --needed --noconfirm protobuf buf

echo "📦 Installing tmux..."
sudo pacman -S --needed --noconfirm tmux

if ! test -d "$HOME/.tmux"; then
    echo "📦 Installing oh-my-tmux..."
    curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash
else
    echo "✅ oh-my-tmux already present"
fi

# Go-installed tools (require languages.sh to have run first)
if command -v go &>/dev/null; then
    echo "📦 Installing air (live reload for Go)..."
    go install github.com/air-verse/air@latest
    echo "📦 Installing goose (DB migrations)..."
    go install github.com/pressly/goose/v3/cmd/goose@latest
else
    echo "⚠️  go not found; skipping air + goose (run cmd/20-dev/languages.sh first)"
fi

echo "✅ Tools setup complete"
