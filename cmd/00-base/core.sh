#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(
	sudo git base-devel wget cmake mesa openssh less vi htop unzip lsof
	nano noto-fonts-cjk woff2-font-awesome
	amd-ucode linux-firmware-amdgpu linux-firmware-radeon linux-firmware-realtek linux-firmware-other
	gnome-keyring reflector ninja shellcheck lm_sensors clang
)

echo "[+] Updating system..."
sudo pacman -Syu --noconfirm

echo "[+] Checking for core packages..."

for pkg in "${PACKAGES[@]}"; do
	if ! pacman -Qi "$pkg" &>/dev/null; then
		echo "[!] Missing: $pkg - installing..."
		sudo pacman -S --noconfirm --needed "$pkg"
	else
		echo "✅ $pkg is already installed."
	fi
done

if ! command -v yay &> /dev/null; then
	TMP=$(mktemp -d)
	trap 'echo "✅ Cleaning up..."; rm -rf "$TMP"' EXIT
	cd "$TMP"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	cd "$TMP"
else
	echo "✅ yay is already installed."
fi

echo "✅ Done"
