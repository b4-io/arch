#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing editors and IDEs..."

# Vulkan stack (needed by zed on AMD)
sudo pacman -S --needed --noconfirm vulkan-icd-loader vulkan-tools vulkan-radeon

# Zed (idempotent via command -v guard)
if ! command -v zed &>/dev/null; then
    echo "📦 Installing zed..."
    curl -f https://zed.dev/install.sh | sh
else
    echo "✅ zed already installed"
fi

# VS Code (AUR binary)
echo "📦 Installing visual-studio-code-bin..."
yay -S --needed --noconfirm visual-studio-code-bin

# DataGrip (AUR)
echo "📦 Installing datagrip..."
yay -S --needed --noconfirm datagrip

# Kiro IDE (AUR)
echo "📦 Installing kiro-ide..."
yay -S --needed --noconfirm kiro-ide

# GitHub Desktop (AUR binary)
echo "📦 Installing github-desktop-bin..."
yay -S --needed --noconfirm github-desktop-bin

echo "✅ Editors setup complete"
