#!/usr/bin/env bash
set -euo pipefail

echo "🛡️  [fs-health] Installing monitoring tools..."
sudo pacman -S --needed --noconfirm smartmontools nvme-cli lm_sensors

echo "🛡️  [fs-health] Enabling fstrim.timer (weekly SSD TRIM)..."
sudo systemctl enable --now fstrim.timer

ROOTFS=$(findmnt -n -o FSTYPE /)
echo "🛡️  [fs-health] Root filesystem: $ROOTFS"

if [[ "$ROOTFS" == "btrfs" ]]; then
    echo "🛡️  [fs-health] Enabling btrfs-scrub@-.timer for root..."
    if sudo systemctl enable --now btrfs-scrub@-.timer 2>/dev/null; then
        echo "✅ [fs-health] btrfs scrub timer enabled"
    else
        echo "⚠️  [fs-health] btrfs-scrub@-.timer not available; install btrfs-progs"
    fi
else
    echo "ℹ️  [fs-health] Root is $ROOTFS (not btrfs), skipping btrfs scrub timer"
fi

echo "✅ [fs-health] Setup complete"
