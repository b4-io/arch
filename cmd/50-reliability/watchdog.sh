#!/usr/bin/env bash
set -euo pipefail

echo "🛡️  [watchdog] Configuring systemd hardware watchdog..."
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/10-watchdog.conf >/dev/null <<'EOF'
[Manager]
RuntimeWatchdogSec=30s
RebootWatchdogSec=10min
DefaultMemoryAccounting=yes
EOF

echo "🛡️  [watchdog] Enabling systemd-oomd..."
if sudo systemctl enable --now systemd-oomd 2>/dev/null; then
    echo "✅ [watchdog] systemd-oomd enabled"
else
    echo "⚠️  [watchdog] systemd-oomd not available on this system, skipping"
fi

sudo systemctl daemon-reload

# Report watchdog state
if [[ -c /dev/watchdog ]]; then
    echo "✅ [watchdog] /dev/watchdog present"
else
    echo "⚠️  [watchdog] /dev/watchdog not found (kernel module may need loading)"
fi

echo "✅ [watchdog] Setup complete. Reboot to activate hardware watchdog."
