#!/usr/bin/env bash
set -e

echo "📦 Installing docker and buildx via pacman..."
sudo pacman -Syu --needed --noconfirm docker docker-buildx

echo "📦 Setting app docker service"
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER
