#!/usr/bin/env bash
#
# install.sh - Orchestrator for Arch Linux dotfiles setup
#
# Runs all cmd/*/*.sh scripts in lexicographic (numbered) order.
# Each subdirectory represents a logical phase:
#   00-base/    - core pacman packages + yay + zsh
#   10-wm/      - Hyprland compositor + desktop stack
#   20-dev/     - language toolchains + dev tools
#   30-apps/    - browsers, editors, media, AI tools
#   40-net/     - network services (time, tailscale)
#   50-reliability/ - server hardening (watchdog, no-sleep, fs-health)
#
# Usage:
#   ./install.sh                      Run everything
#   ./install.sh --dry-run            Preview what would run
#   ./install.sh --only 50-reliability  Run only matching subdir
#   ./install.sh --skip 30-apps       Skip matching subdir
#   ./install.sh --continue-on-error  Don't halt on first failure
#   ./install.sh --help               Show this help

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CMD_DIR="$SCRIPT_DIR/cmd"

# --- Arg parsing ---
DRY_RUN=0
ONLY_PATTERN=""
SKIP_PATTERN=""
CONTINUE_ON_ERROR=0

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --only)
            ONLY_PATTERN="${2:-}"
            if [[ -z "$ONLY_PATTERN" ]]; then
                echo "Error: --only requires a pattern argument" >&2
                exit 2
            fi
            shift 2
            ;;
        --skip)
            SKIP_PATTERN="${2:-}"
            if [[ -z "$SKIP_PATTERN" ]]; then
                echo "Error: --skip requires a pattern argument" >&2
                exit 2
            fi
            shift 2
            ;;
        --continue-on-error)
            CONTINUE_ON_ERROR=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# --- Safety: refuse to run as root ---
if [[ $EUID -eq 0 ]]; then
    echo "Error: do not run install.sh as root" >&2
    echo "  The individual cmd scripts use sudo internally where needed." >&2
    exit 1
fi

# --- Sanity: cmd/ must exist ---
if [[ ! -d "$CMD_DIR" ]]; then
    echo "Error: $CMD_DIR not found" >&2
    exit 1
fi

# --- Discover scripts ---
# Use find + sort to get lexicographic order across subdirs.
# cmd/00-base/core.sh sorts before cmd/10-wm/hyprland.sh etc.
mapfile -t ALL_SCRIPTS < <(find "$CMD_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.sh' | sort)

if [[ ${#ALL_SCRIPTS[@]} -eq 0 ]]; then
    echo "Warning: no scripts found under $CMD_DIR" >&2
    exit 0
fi

# --- Filter ---
SCRIPTS=()
for script in "${ALL_SCRIPTS[@]}"; do
    rel="${script#"$CMD_DIR"/}"     # e.g. "00-base/core.sh"
    subdir="${rel%%/*}"            # e.g. "00-base"

    if [[ -n "$ONLY_PATTERN" ]] && ! [[ "$subdir" =~ $ONLY_PATTERN ]]; then
        continue
    fi
    if [[ -n "$SKIP_PATTERN" ]] && [[ "$subdir" =~ $SKIP_PATTERN ]]; then
        continue
    fi
    SCRIPTS+=("$script")
done

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo "No scripts match filter criteria" >&2
    exit 0
fi

# --- Dry-run mode ---
if [[ $DRY_RUN -eq 1 ]]; then
    echo "[install] Dry run - would execute:"
    for script in "${SCRIPTS[@]}"; do
        echo "  ${script#"$SCRIPT_DIR"/}"
    done
    echo "[install] Total: ${#SCRIPTS[@]} scripts"
    exit 0
fi

# --- Execute ---
SUCCEEDED=0
FAILED=0
SKIPPED=0

for script in "${SCRIPTS[@]}"; do
    rel="${script#"$SCRIPT_DIR"/}"
    echo "[install] $rel -> START"
    if bash "$script"; then
        echo "[install] $rel -> OK"
        SUCCEEDED=$((SUCCEEDED + 1))
    else
        exit_code=$?
        echo "[install] $rel -> FAIL (exit $exit_code)" >&2
        FAILED=$((FAILED + 1))
        if [[ $CONTINUE_ON_ERROR -eq 0 ]]; then
            echo "[install] Halting due to failure. Use --continue-on-error to proceed past failures." >&2
            break
        fi
    fi
done

# --- Summary ---
echo ""
echo "[install] Summary:"
echo "  Succeeded: $SUCCEEDED"
echo "  Failed:    $FAILED"
echo "  Skipped:   $SKIPPED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "[install] ❌ Installation had failures"
    exit 1
fi

echo "[install] ✅ Installation complete"
echo "[install] Next: run ./link.sh to deploy configs to \$HOME"
