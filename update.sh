#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2329
# Rationale: SC2317/SC2329 fire because functions are invoked indirectly via
# `"$@"` inside the run_section dispatcher. The linter cannot statically
# track that pattern, so these warnings are false positives.
#
# update.sh - Update all installed packages and dev tools
#
# Each section is guarded by `command -v`, so missing tools are skipped.
# The fnm LTS bump is opt-in via UPDATE_NODE=1 to avoid breaking projects
# pinned to older LTS versions.
#
# Usage:
#   ./update.sh              Run all updaters
#   ./update.sh --dry-run    Preview what would run
#   UPDATE_NODE=1 ./update.sh  Also bump Node to latest LTS

set -uo pipefail
# Note: NOT using -e here because we want to continue past per-section failures.

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

# Track section results
declare -A RESULTS

run_section() {
    local name="$1"
    shift
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[$name] (dry-run) Would execute: $*"
        RESULTS["$name"]="DRY"
        return 0
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$name] Starting..."
    if "$@"; then
        echo "[$name] ✅ OK"
        RESULTS["$name"]="OK"
    else
        echo "[$name] ❌ FAIL" >&2
        RESULTS["$name"]="FAIL"
    fi
}

# --- Section implementations ---

update_pacman() {
    command -v pacman &>/dev/null || { echo "pacman not found"; return 1; }
    sudo pacman -Syu --noconfirm
}

update_yay() {
    command -v yay &>/dev/null || { echo "yay not found"; return 1; }
    yay -Syu --noconfirm
}

update_rustup() {
    command -v rustup &>/dev/null || { echo "rustup not found"; return 1; }
    rustup update
}

update_fnm_node() {
    if [[ "${UPDATE_NODE:-0}" != "1" ]]; then
        echo "UPDATE_NODE not set to 1, skipping Node LTS bump (safety)"
        echo "   Run with: UPDATE_NODE=1 ./update.sh"
        return 0
    fi
    command -v fnm &>/dev/null || { echo "fnm not found"; return 1; }
    fnm install --lts
    fnm use lts-latest
}

update_bun() {
    command -v bun &>/dev/null || { echo "bun not found"; return 1; }
    bun upgrade
}

update_uv() {
    command -v uv &>/dev/null || { echo "uv not found"; return 1; }
    uv self update
}

update_cargo_tools() {
    command -v cargo &>/dev/null || { echo "cargo not found"; return 1; }
    # Re-install = update for cargo-installed binaries
    cargo install cargo-watch --force
    cargo install wasm-pack --force
}

update_go_tools() {
    command -v go &>/dev/null || { echo "go not found"; return 1; }
    go install github.com/air-verse/air@latest
    go install github.com/pressly/goose/v3/cmd/goose@latest
}

update_opencode() {
    if ! command -v opencode &>/dev/null; then
        echo "opencode not found, skipping"
        return 1
    fi
    curl -fsSL https://opencode.ai/install | bash
}

update_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "oh-my-zsh not found at ~/.oh-my-zsh, skipping"
        return 1
    fi
    "$HOME/.oh-my-zsh/tools/upgrade.sh" || return 1
}

restart_tailscaled() {
    command -v tailscale &>/dev/null || { echo "tailscale not found"; return 1; }
    if systemctl is-active --quiet tailscaled; then
        echo "Restarting tailscaled to sync with updated client..."
        sudo systemctl restart tailscaled
        sleep 1
        tailscale status --peers=false 2>/dev/null || echo "(status check skipped)"
    else
        echo "tailscaled not active, skipping restart"
        return 0
    fi
}

# --- Main ---

echo "╔══════════════════════════════════════════════╗"
echo "║  update.sh - Arch dotfiles updater           ║"
if [[ $DRY_RUN -eq 1 ]]; then
    echo "║  MODE: DRY RUN (no changes)                  ║"
fi
echo "╚══════════════════════════════════════════════╝"
echo ""

run_section "pacman"       update_pacman
run_section "yay"          update_yay
run_section "rustup"       update_rustup
run_section "fnm-node"     update_fnm_node
run_section "bun"          update_bun
run_section "uv"           update_uv
run_section "cargo-tools"  update_cargo_tools
run_section "go-tools"     update_go_tools
run_section "opencode"     update_opencode
run_section "oh-my-zsh"    update_oh_my_zsh
run_section "tailscaled"   restart_tailscaled

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
printf "  %-15s %s\n" "Section" "Status"
printf "  %-15s %s\n" "-------" "------"
for name in pacman yay rustup fnm-node bun uv cargo-tools go-tools opencode oh-my-zsh tailscaled; do
    printf "  %-15s %s\n" "$name" "${RESULTS[$name]:-SKIP}"
done
echo ""

# Exit non-zero if any section failed
for status in "${RESULTS[@]}"; do
    if [[ "$status" == "FAIL" ]]; then
        exit 1
    fi
done
exit 0
