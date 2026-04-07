#!/usr/bin/env bash
set -euo pipefail

echo "🛡️  [hyprlock-idle] Installing hypridle..."
sudo pacman -S --needed --noconfirm hypridle

echo "ℹ️  [hyprlock-idle] hyprlock is installed by cmd/10-wm/hyprland.sh"
echo "ℹ️  [hyprlock-idle] Config files (hypridle.conf, hyprlock.conf) are tracked in the repo"
echo "ℹ️  [hyprlock-idle] Run ./link.sh to deploy them to ~/.config/hypr/"
echo ""
echo "✅ [hyprlock-idle] Setup complete"
