#!/usr/bin/env bash
set -e

echo "📦 Installing docker, postgresql via pacman..."
sudo pacman -Syu --needed --noconfirm docker postgresql

echo "📦 Setting app docker service"
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

echo "📦 Installing bun"
curl -fsSL https://bun.sh/install | bash

echo "📦 Installing air"
go install github.com/air-verse/air@latest

echo "📦 Installing goose"
go install github.com/pressly/goose/v3/cmd/goose@latest
