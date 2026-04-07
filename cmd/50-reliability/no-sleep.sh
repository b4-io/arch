#!/usr/bin/env bash
set -euo pipefail

echo "🛡️  [no-sleep] Masking sleep/suspend/hibernate targets..."
sudo systemctl mask \
    sleep.target \
    suspend.target \
    hibernate.target \
    hybrid-sleep.target \
    suspend-then-hibernate.target

echo "🛡️  [no-sleep] Writing /etc/systemd/sleep.conf.d/10-no-sleep.conf..."
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/10-no-sleep.conf >/dev/null <<'EOF'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF

echo "🛡️  [no-sleep] Writing /etc/systemd/logind.conf.d/10-no-sleep.conf..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-no-sleep.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
PowerKeyIgnoreInhibited=yes
SuspendKeyIgnoreInhibited=yes
HibernateKeyIgnoreInhibited=yes
LidSwitchIgnoreInhibited=yes
EOF

sudo systemctl daemon-reload

echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "   To activate the logind changes, run the following command manually."
echo "   This WILL terminate your current login session. Run from a console or after saving work:"
echo ""
echo "       sudo systemctl restart systemd-logind"
echo ""
echo "✅ [no-sleep] Configuration applied. Reboot or restart logind to fully activate."
