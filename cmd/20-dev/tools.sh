#!/usr/bin/env bash
set -e

echo "📦 Installing postgresql via pacman..."
sudo pacman -Syu --needed --noconfirm postgresql

echo "📦 Installing fnm"
curl -fsSL https://fnm.vercel.app/install | bash

echo "📦 Installing bun"
curl -fsSL https://bun.sh/install | bash

echo "📦 Installing air"
go install github.com/air-verse/air@latest

echo "📦 Installing goose"
go install github.com/pressly/goose/v3/cmd/goose@latest

echo "Installing github-cli"
sudo pacman -Syu --needed --noconfirm github-cli

echo "Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing protobuf"
sudo pacman -S --noconfirm protobuf buf

echo "Installing tmux"
sudo pacman -S --noconfirm tmux

echo "Installing oh-my-tmux"
curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash
