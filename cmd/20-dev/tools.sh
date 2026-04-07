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
    git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
    ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
    [ -f "$HOME/.tmux.conf.local" ] || cp "$HOME/.tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
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
