#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing tailscale..."
sudo pacman -S --needed --noconfirm tailscale

echo "🖥️  Installing trayscale (GTK4 tray GUI, AUR)..."
yay -S --needed --noconfirm trayscale

echo "🔧 Enabling tailscaled.service..."
sudo systemctl enable --now tailscaled

# rp_filter hardening (prevents IP spoofing on Tailscale interface)
echo "🔧 Applying rp_filter hardening..."
sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null

# Wait briefly for daemon socket
sleep 2

# Idempotent: if already running, skip tailscale up
if tailscale status --peers=false --json 2>/dev/null | grep -q '"BackendState": "Running"'; then
    echo "✅ Tailscale already running, skipping 'tailscale up'"
    tailscale status
    exit 0
fi

# Fresh install flow
if [[ -n "${TS_AUTHKEY:-}" ]]; then
    echo "🔑 Using TS_AUTHKEY for non-interactive login..."
    sudo tailscale up \
        --auth-key="$TS_AUTHKEY" \
        --hostname="${TS_HOSTNAME:-$(hostname)}" \
        --accept-dns \
        --operator="${SUDO_USER:-$USER}" \
        --ssh
else
    echo "🌐 No TS_AUTHKEY set. Starting interactive login (check terminal output for auth URL)..."
    sudo tailscale up \
        --hostname="${TS_HOSTNAME:-$(hostname)}" \
        --accept-dns \
        --operator="${SUDO_USER:-$USER}" \
        --ssh
fi

echo "✅ Tailscale setup complete"
tailscale status
