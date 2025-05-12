#!/usr/bin/env bash
set -e

echo "📦 Installing hyprland, hyprlock, uwsm, ghostty and waybar via pacman..."
sudo pacman -Syu --needed --noconfirm hyprland hyprlock uwsm ghostty waybar

echo "📦 Installing fonts..."
sudo pacman -Syu --needed --noconfirm ttf-font-awesome ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols

echo "📦 Installing walker-bin via yay..."
yay -S --needed --noconfirm walker-bin

# Block to append
START_BLOCK='if uwsm check may-start; then
    exec uwsm start hyprland.desktop
fi'

# Shell profiles to target
PROFILE_FILES=("$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.profile")

echo "📝 Updating shell profiles..."

for PROFILE in "${PROFILE_FILES[@]}"; do
    if [ ! -f "$PROFILE" ]; then
        echo "⚠️  Skipping $PROFILE (does not exist)"
        continue
    fi

    if grep -Fq 'exec uwsm start hyprland.desktop' "$PROFILE"; then
        echo "ℹ️  Block already present in $PROFILE"
    else
        echo -e "\n$START_BLOCK" >> "$PROFILE"
        echo "✅ Appended block to $PROFILE"
    fi
done

echo "✅ Setup complete. Restart your session to launch Hyprland via uwsm."
