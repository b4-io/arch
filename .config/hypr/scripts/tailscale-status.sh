#!/usr/bin/env bash
set -euo pipefail

mode="${1:-status}"

if ! command -v tailscale >/dev/null 2>&1; then
    printf '{"text":"","tooltip":"","class":"missing"}\n'
    exit 0
fi

python3 - "$mode" <<'PYSUB'
import json, sys, subprocess

mode = sys.argv[1]

try:
    raw = subprocess.run(
        ["tailscale", "status", "--json"],
        capture_output=True, text=True, timeout=3
    ).stdout
    d = json.loads(raw)
except Exception:
    print(json.dumps({"text": "\uf00d", "tooltip": "Tailscale: unreachable", "class": "error"}))
    sys.exit(0)

state = d.get("BackendState", "Unknown")
self_node = d.get("Self") or {}
host = self_node.get("HostName", "?")
ips = self_node.get("TailscaleIPs") or []
ip4 = next((ip for ip in ips if ":" not in ip), "?")
peers = list((d.get("Peer") or {}).values())
online = [p for p in peers if p.get("Online")]
total = len(peers)
online_count = len(online)

ICON_ON   = "\uf0ac"
ICON_OFF  = "\uf127"
ICON_AUTH = "\uf023"

if state == "Running":
    text, cls = ICON_ON, "connected"
    tooltip = f"Tailscale  Running\nHost: {host}\nIP: {ip4}\nPeers online: {online_count}/{total}"
elif state == "Stopped":
    text, cls = ICON_OFF, "disconnected"
    tooltip = "Tailscale  Stopped"
elif state == "NeedsLogin":
    text, cls = ICON_AUTH, "needs-login"
    tooltip = "Tailscale  Needs login"
else:
    text, cls = ICON_OFF, "unknown"
    tooltip = f"Tailscale  {state}"

if mode == "--notify":
    body_lines = [tooltip, ""]
    for p in online[:8]:
        name = p.get("HostName", "?")
        ip = next((ip for ip in (p.get("TailscaleIPs") or []) if ":" not in ip), "?")
        body_lines.append(f"  - {name}  {ip}")
    if len(online) > 8:
        body_lines.append(f"  ... +{len(online) - 8} more")
    body = "\n".join(body_lines)
    subprocess.run(["dunstify", "-t", "8000", "-a", "tailscale", "Tailscale", body], check=False)
else:
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
PYSUB
