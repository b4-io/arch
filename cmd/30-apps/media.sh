#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing media applications..."

echo "📦 Installing masterpdfeditor-free..."
yay -S --needed --noconfirm masterpdfeditor-free

echo "📦 Installing vlc..."
sudo pacman -S --needed --noconfirm vlc

echo "📦 Installing shotcut..."
sudo pacman -S --needed --noconfirm shotcut

echo "✅ Media setup complete"
