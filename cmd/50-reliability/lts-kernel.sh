#!/usr/bin/env bash
set -euo pipefail

# Install linux-lts as a parallel safety-net kernel.
#
# Why: this box is a one-off Zen 1 + Vega 10 combo that has historically
# bitten on freshly-released mainline kernels (notably 6.19.11 + mesa 26
# crashed Hyprland init within 3s). linux-lts gives us a known-stable
# fallback that GRUB exposes alongside the mainline kernel, so a wedged
# main kernel never leaves the box unbootable.
#
# This script does NOT replace the running linux package - both stay
# installed in parallel. To boot LTS: pick "Advanced options for Arch Linux"
# in GRUB and select the linux-lts entry.

echo "🛡️  [lts-kernel] Installing linux-lts + linux-lts-headers as fallback kernel..."
sudo pacman -S --needed --noconfirm linux-lts linux-lts-headers

# Verify the LTS kernel image landed in /boot. The pacman hook should have
# also generated the initramfs via mkinitcpio - the install fails loudly if
# either step didn't happen, so the explicit check is just belt-and-braces.
if [[ ! -f /boot/vmlinuz-linux-lts ]]; then
    echo "❌ [lts-kernel] /boot/vmlinuz-linux-lts not found after install"
    exit 1
fi
if [[ ! -f /boot/initramfs-linux-lts.img ]]; then
    echo "❌ [lts-kernel] /boot/initramfs-linux-lts.img not found after install"
    exit 1
fi
echo "✅ [lts-kernel] /boot/vmlinuz-linux-lts and initramfs-linux-lts.img present"

# Regenerate GRUB config so the new kernel shows up in the boot menu.
# os-prober is not required - grub-mkconfig picks up linux-lts via the
# 10_linux generator scanning /boot for vmlinuz-* entries.
if [[ -f /boot/grub/grub.cfg ]]; then
    echo "🛡️  [lts-kernel] Regenerating /boot/grub/grub.cfg to expose linux-lts..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    if grep -q 'vmlinuz-linux-lts' /boot/grub/grub.cfg; then
        echo "✅ [lts-kernel] linux-lts entry present in grub.cfg"
    else
        echo "⚠️  [lts-kernel] linux-lts entry NOT found in grub.cfg - check 10_linux generator"
    fi
else
    echo "⚠️  [lts-kernel] /boot/grub/grub.cfg not found - this script assumes GRUB"
fi

echo ""
echo "ℹ️  [lts-kernel] To boot the LTS kernel:"
echo "   1. Reboot"
echo "   2. At the GRUB menu, select 'Advanced options for Arch Linux'"
echo "   3. Pick the entry containing 'linux-lts'"
echo ""
echo "ℹ️  [lts-kernel] To make linux-lts the DEFAULT, edit /etc/default/grub:"
echo "   GRUB_DEFAULT='Advanced options for Arch Linux>Arch Linux, with Linux linux-lts'"
echo "   then re-run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
echo ""
echo "✅ [lts-kernel] Setup complete"
