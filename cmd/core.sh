#!/usr/bin/env bash
set -e

PACKAGES=(sudo git base-devel wget cmake mesa openssh)

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
	trap "echo '✅ Cleaning up...'; rm -rf $TMP" EXIT
	cd "$TMP"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	cd "$TMP"
else
	echo "✅ yay is already installed."
fi

echo "✅ Done"
