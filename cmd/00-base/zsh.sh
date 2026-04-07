#!/usr/bin/env bash
set -e

echo "📦 Installing zsh via pacman..."
sudo pacman -Syu --needed --noconfirm zsh

if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "✓ oh-my-zsh already installed at $HOME/.oh-my-zsh, skipping"
else
    echo "📦 Installing ohmyzsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
