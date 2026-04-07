#!/usr/bin/env bash
# Power menu via walker dmenu.
# Suspend omitted: suspend.target is masked on this box.
set -euo pipefail

choice=$(printf '  Lock\n  Logout\n  Reboot\n  Shutdown' \
    | walker -d -p ' Power' 2>/dev/null) || exit 0

case "$choice" in
    *Lock*)     hyprlock & disown ;;
    *Logout*)   hyprctl dispatch exit ;;
    *Reboot*)   systemctl reboot ;;
    *Shutdown*) systemctl poweroff ;;
esac
