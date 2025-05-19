#!/usr/bin/env bash
set -e

echo "📦 Installing hyprland, hyprlock, uwsm, ghostty, waybar, dunst via pacman..."
sudo pacman -Syu --needed --noconfirm hyprland hyprlock uwsm ghostty waybar dunst

echo "📦 Installing pipewire wireplumber pipewire-audio pipewire-pulse"
sudo pacman -Syu --needed --noconfirm pipewire wireplumber pipewire-audio pipewire-pulse

echo "📦 Installing qt5-wayland qt6-wayland xdg-desktop-portal-hyprland adw-gtk-theme"
sudo pacman -Syu --needed --noconfirm qt5-wayland qt6-wayland xdg-desktop-portal-hyprland adw-gtk-theme

echo "📦 Installing nemo file manager"
sudo pacman -Syu --needed --noconfirm nemo

echo "📦 Installing fonts..."
sudo pacman -Syu --needed --noconfirm ttf-font-awesome ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols

echo "📦 Installing walker-bin via yay..."
yay -S --needed --noconfirm walker-bin

echo "📦 Installing hyprpolkitagent via yay..."
yay -S --needed --noconfirm hyprpolkitagent

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
