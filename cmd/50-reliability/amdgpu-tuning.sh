#!/usr/bin/env bash
set -euo pipefail

# Vega 10 / GFX9 hang-recovery hardening for amdgpu.
#
# Background: kernel 6.19's amdgpu defaults `gpu_recovery=-1` which evaluates
# to DISABLED on bare metal (only enabled under SR-IOV virtualization). That
# means a GPU-side hang on Vega 10 deadlocks the entire kernel until the
# sp5100_tco hardware watchdog notices ~60s later and force-resets the box.
# This was the exact failure mode observed on 2026-04-07: the kernel hung
# 3s into Hyprland startup with no diagnostic output anywhere.
#
# Two knobs, both load-time module options:
#
#   gpu_recovery=1
#     Forces GPU reset on hang detection instead of letting the wait queue
#     deadlock the kernel. The driver tears down the GFX/Compute/SDMA/Video
#     rings, replays in-flight submissions where possible, and lets userspace
#     keep going. The display might flicker - the box stays alive.
#
#   lockup_timeout=5000,5000,5000,5000
#     Per-queue lockup detection timeout in ms (GFX, Compute, SDMA, Video).
#     Default is 2000ms which is too aggressive for Vega 10 - complex Wayland
#     compositor frames can legitimately take 3-4s during init. 5000ms is the
#     production-recommended value (NixOS, Arch wiki).
#
# Source: https://www.kernel.org/doc/html/next/gpu/amdgpu/module-parameters.html
#
# These take effect on next reboot OR on `modprobe -r amdgpu && modprobe amdgpu`.
# Reloading amdgpu while a Wayland session is running will tear down the display
# and is NOT safe - this script does NOT attempt a hot-reload. Reboot required.

# Use a dedicated drop-in filename so this script can never clobber a
# pre-existing /etc/modprobe.d/amdgpu.conf that another package or admin
# may own. The 99- prefix ensures our options are loaded LAST and win any
# conflicts with lower-numbered drop-ins.
CONF=/etc/modprobe.d/99-amdgpu-stability.conf

echo "🛡️  [amdgpu-tuning] Writing $CONF..."
sudo tee "$CONF" >/dev/null <<'EOF'
options amdgpu gpu_recovery=1
options amdgpu lockup_timeout=5000,5000,5000,5000
EOF

echo "✅ [amdgpu-tuning] $CONF written"

# Show the current (running) values for comparison so the user can see
# what's about to change on next boot. /sys/module/amdgpu/parameters/* are
# the live values - if they don't match the file we just wrote, that's
# expected and reflects the fact that module options bind at modprobe time.
echo ""
echo "🛡️  [amdgpu-tuning] Current (live) amdgpu parameters:"
for param in gpu_recovery lockup_timeout; do
    if [[ -r "/sys/module/amdgpu/parameters/$param" ]]; then
        printf "   %-20s = %s\n" "$param" "$(cat "/sys/module/amdgpu/parameters/$param")"
    else
        printf "   %-20s = (not present in this kernel build)\n" "$param"
    fi
done
echo ""
echo "🛡️  [amdgpu-tuning] Expected (post-reboot) values:"
echo "   gpu_recovery         = 1"
echo "   lockup_timeout       = 5000, 5000, 5000, 5000"

# Regenerate initramfs so the new modprobe.d entries are baked in early.
# This matters because amdgpu can be pulled in by the initramfs (KMS)
# before /etc/modprobe.d/ is even readable from the root filesystem.
if command -v mkinitcpio &>/dev/null; then
    echo ""
    echo "🛡️  [amdgpu-tuning] Regenerating initramfs (mkinitcpio -P)..."
    sudo mkinitcpio -P
    echo "✅ [amdgpu-tuning] initramfs regenerated"
else
    echo "⚠️  [amdgpu-tuning] mkinitcpio not found - cannot regenerate initramfs"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ⚠️  REBOOT REQUIRED                                          ║"
echo "║                                                              ║"
echo "║  amdgpu module options only bind at modprobe time. Hot       ║"
echo "║  reloading amdgpu while a Wayland session is running is NOT  ║"
echo "║  safe - it will tear down the display. REBOOT to activate.   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "✅ [amdgpu-tuning] Setup complete"
