#!/usr/bin/env bash
set -e

echo "📦 Installing zsh via pacman..."
sudo pacman -Syu --needed --noconfirm zsh

echo "📦 Installing ohmyzsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
