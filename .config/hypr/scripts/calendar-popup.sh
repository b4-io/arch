#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if pkill -f "calendar-popup\.py" 2>/dev/null; then
    exit 0
fi

exec python3 "${SCRIPT_DIR}/calendar-popup.py"
