#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing docker and buildx via pacman..."
sudo pacman -Syu --needed --noconfirm docker docker-buildx

echo "📦 Enabling docker service"
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker "$USER"
