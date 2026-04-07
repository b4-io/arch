#!/usr/bin/env bash
#
# doctor.sh - Read-only health check for Arch Linux always-on server
#
# Reports on sleep/power config, kernel errors, GPU driver state,
# memory pressure, disk health, CPU temperature, systemd-oomd,
# hardware watchdog, kernel cmdline workarounds, failed services,
# fstrim, Tailscale, and boot history gaps.
#
# Each check emits [check-name] ... OK/WARN/FAIL/HINT.
# Exit code is non-zero if any check FAILs.

set -uo pipefail

# --- Counters ---
PASS=0
WARN=0
FAIL=0
HINT=0

# --- Logging helpers ---
ok()   { printf "  [%s] ✅ OK   %s\n" "$1" "${2:-}"; PASS=$((PASS + 1)); }
warn() { printf "  [%s] ⚠️  WARN %s\n" "$1" "${2:-}"; WARN=$((WARN + 1)); }
fail() { printf "  [%s] ❌ FAIL %s\n" "$1" "${2:-}"; FAIL=$((FAIL + 1)); }
hint() { printf "  [%s] ℹ️  HINT %s\n" "$1" "${2:-}"; HINT=$((HINT + 1)); }

section() { printf "\n━━━ %s ━━━\n" "$1"; }

# --- Checks ---

check_sleep_targets() {
    section "Sleep/Suspend Targets"
    local targets=(sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target)
    for t in "${targets[@]}"; do
        local state
        state="$(systemctl is-enabled "$t" 2>/dev/null || true)"
        state="${state:-unknown}"
        if [[ "$state" == "masked" ]]; then
            ok "sleep-targets" "$t is masked"
        else
            fail "sleep-targets" "$t is $state (expected masked - run cmd/50-reliability/no-sleep.sh)"
        fi
    done
}

check_kernel_errors() {
    section "Kernel Errors (last 24h)"
    local count
    count="$(journalctl -k -p err --since '24 hours ago' --no-pager -q 2>/dev/null | wc -l)"
    if [[ "$count" -eq 0 ]]; then
        ok "kernel-errors" "No kernel errors"
    else
        warn "kernel-errors" "$count error lines in last 24h (journalctl -k -p err --since '24 hours ago')"
    fi
}

check_suspend_resume() {
    section "Suspend/Resume/Freeze Messages (last 7 days)"
    local hits
    hits="$(journalctl --since '7 days ago' --no-pager -q 2>/dev/null | grep -ciE 'suspend|resume|freeze|hang|lockup' || true)"
    if [[ "$hits" -eq 0 ]]; then
        ok "suspend-resume" "No suspend/resume/freeze/hang messages"
    else
        warn "suspend-resume" "$hits relevant log lines in last 7 days"
    fi
}

check_gpu_driver() {
    section "GPU Driver Errors (amdgpu)"
    local count
    count="$(journalctl -b 0 -k --no-pager -q 2>/dev/null | grep -ciE 'amdgpu.*(error|fail)' || true)"
    if [[ "$count" -eq 0 ]]; then
        ok "amdgpu" "No amdgpu errors this boot"
    else
        warn "amdgpu" "$count amdgpu error/fail lines this boot"
    fi
}

check_memory() {
    section "Memory Pressure"
    local mem_used mem_total swap_used swap_total
    read -r mem_used mem_total < <(free -m | awk '/^Mem:/ {print $3, $2}')
    read -r swap_used swap_total < <(free -m | awk '/^Swap:/ {print $3, $2}')
    ok "memory" "RAM ${mem_used}MB / ${mem_total}MB"
    if [[ "$swap_total" -gt 0 ]]; then
        local pct=$((swap_used * 100 / swap_total))
        if [[ "$pct" -gt 50 ]]; then
            warn "swap" "${pct}% swap used (${swap_used}MB / ${swap_total}MB)"
        else
            ok "swap" "${pct}% swap used (${swap_used}MB / ${swap_total}MB)"
        fi
    else
        hint "swap" "No swap configured"
    fi
}

check_disk_smart() {
    section "Disk S.M.A.R.T. Health"
    if ! command -v smartctl &>/dev/null; then
        hint "smart" "smartctl not installed (run cmd/50-reliability/fs-health.sh)"
        return
    fi
    for disk in /dev/sd[a-z]; do
        [[ -e "$disk" ]] || continue
        local out
        out="$(sudo smartctl -H "$disk" 2>/dev/null | grep -E 'PASSED|FAILED' || true)"
        if [[ "$out" == *PASSED* ]]; then
            ok "smart-$disk" "$out"
        elif [[ "$out" == *FAILED* ]]; then
            fail "smart-$disk" "$out"
        else
            hint "smart-$disk" "No S.M.A.R.T. result"
        fi
    done
}

check_nvme() {
    section "NVMe Health"
    if ! command -v nvme &>/dev/null; then
        hint "nvme" "nvme-cli not installed (run cmd/50-reliability/fs-health.sh)"
        return
    fi
    local any=0
    for nvme in /dev/nvme[0-9]n1; do
        [[ -e "$nvme" ]] || continue
        any=1
        local warning
        warning="$(sudo nvme smart-log "$nvme" 2>/dev/null | grep -i critical_warning | awk '{print $NF}' || echo unknown)"
        if [[ "$warning" == "0" || "$warning" == "0x00" ]]; then
            ok "nvme-$(basename "$nvme")" "critical_warning=$warning"
        else
            warn "nvme-$(basename "$nvme")" "critical_warning=$warning"
        fi
    done
    [[ $any -eq 0 ]] && hint "nvme" "No NVMe devices found"
}

check_cpu_temp() {
    section "CPU Temperature"
    if ! command -v sensors &>/dev/null; then
        hint "sensors" "lm_sensors not installed (run cmd/50-reliability/fs-health.sh or cmd/00-base/core.sh)"
        return
    fi
    local line
    line="$(sensors 2>/dev/null | grep -iE 'Tctl|Tdie|Package|Core 0' | head -1 || echo)"
    if [[ -n "$line" ]]; then
        ok "cpu-temp" "$line"
    else
        hint "cpu-temp" "No CPU temperature readings available"
    fi
}

check_oomd() {
    section "systemd-oomd"
    if systemctl is-active --quiet systemd-oomd 2>/dev/null; then
        ok "oomd" "systemd-oomd is active"
    else
        warn "oomd" "systemd-oomd inactive (run cmd/50-reliability/watchdog.sh)"
    fi
}

check_watchdog() {
    section "Hardware Watchdog"
    if [[ -c /dev/watchdog ]]; then
        ok "watchdog-dev" "/dev/watchdog present"
    else
        warn "watchdog-dev" "/dev/watchdog not found"
    fi
    local wd_sec
    wd_sec="$(grep -hE '^RuntimeWatchdogSec' /etc/systemd/system.conf.d/*.conf 2>/dev/null | head -1 || true)"
    if [[ -n "$wd_sec" ]]; then
        ok "watchdog-cfg" "$wd_sec"
    else
        warn "watchdog-cfg" "RuntimeWatchdogSec not configured (run cmd/50-reliability/watchdog.sh)"
    fi
}

check_kernel_cmdline() {
    section "Kernel Command Line (Zen 1 workarounds)"
    local cmdline
    cmdline="$(cat /proc/cmdline 2>/dev/null || echo)"
    if [[ "$cmdline" == *"idle=nomwait"* ]]; then
        ok "cmdline-idle" "idle=nomwait set"
    else
        hint "cmdline-idle" "idle=nomwait not set (advisory for Zen 1 stability)"
    fi
    if [[ "$cmdline" == *"processor.max_cstate"* ]]; then
        ok "cmdline-cstate" "processor.max_cstate set"
    else
        hint "cmdline-cstate" "processor.max_cstate not set (advisory for Zen 1 stability)"
    fi
}

check_btrfs() {
    section "Btrfs Status"
    local fstype
    fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || echo unknown)"
    if [[ "$fstype" == "btrfs" ]]; then
        if command -v btrfs &>/dev/null; then
            ok "btrfs" "Root is btrfs"
            sudo btrfs scrub status / 2>/dev/null | head -5 || true
        else
            warn "btrfs" "Root is btrfs but btrfs-progs not installed"
        fi
    else
        hint "btrfs" "Root is $fstype (not btrfs), skipping scrub check"
    fi
}

check_failed_services() {
    section "Failed Services"
    local failed
    failed="$(systemctl --failed --no-pager --no-legend 2>/dev/null | wc -l)"
    if [[ "$failed" -eq 0 ]]; then
        ok "failed-services" "0 failed services"
    else
        fail "failed-services" "$failed failed services (run: systemctl --failed)"
    fi
    local user_failed
    user_failed="$(systemctl --user --failed --no-pager --no-legend 2>/dev/null | wc -l)"
    if [[ "$user_failed" -eq 0 ]]; then
        ok "failed-user-services" "0 failed user services"
    else
        fail "failed-user-services" "$user_failed failed user services (run: systemctl --user --failed)"
    fi
}

check_fstrim() {
    section "fstrim.timer"
    if systemctl is-enabled --quiet fstrim.timer 2>/dev/null; then
        ok "fstrim" "fstrim.timer enabled"
    else
        warn "fstrim" "fstrim.timer not enabled (run cmd/50-reliability/fs-health.sh)"
    fi
}

check_tailscale() {
    section "Tailscale"
    if ! command -v tailscale &>/dev/null; then
        hint "tailscale" "tailscale not installed (run cmd/40-net/tailscale.sh)"
        return
    fi
    if ! systemctl is-active --quiet tailscaled 2>/dev/null; then
        warn "tailscaled" "tailscaled service not active"
        return
    fi
    if tailscale status --peers=false 2>/dev/null >/dev/null; then
        ok "tailscale-up" "Connected"
    else
        warn "tailscale-up" "Not logged in (run: sudo tailscale up)"
    fi
    # Version mismatch check
    local client_ver daemon_ver
    client_ver="$(tailscale version 2>/dev/null | head -1 || echo unknown)"
    daemon_ver="$(sudo tailscale --socket=/var/run/tailscale/tailscaled.sock version 2>/dev/null | sed -n '2p' || echo unknown)"
    if [[ -n "$client_ver" && -n "$daemon_ver" ]]; then
        if [[ "$client_ver" != "$daemon_ver" ]] && [[ "$daemon_ver" != "unknown" ]]; then
            warn "tailscale-ver" "Client/daemon version mismatch (client=$client_ver daemon=$daemon_ver). Run ./update.sh"
        else
            ok "tailscale-ver" "client=$client_ver"
        fi
    fi
}

check_boot_history() {
    section "Boot History"
    local boots
    boots="$(journalctl --list-boots --no-pager 2>/dev/null | tail -5)"
    if [[ -z "$boots" ]]; then
        hint "boot-history" "No boot history available"
        return
    fi
    while IFS= read -r line; do
        printf '    %s\n' "$line"
    done <<< "$boots"
    # Detect gaps > 7 days between consecutive boot start times
    local prev_end=""
    local gap_warn=0
    while IFS= read -r line; do
        # Parse boot end time (last field group = timestamp)
        # Format varies, try to extract ISO date
        local ts
        ts="$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || echo)"
        [[ -z "$ts" ]] && continue
        if [[ -n "$prev_end" ]]; then
            local diff_days
            diff_days=$(( ( $(date -d "$ts" +%s 2>/dev/null || echo 0) - $(date -d "$prev_end" +%s 2>/dev/null || echo 0) ) / 86400 ))
            if [[ "$diff_days" -gt 7 ]]; then
                warn "boot-gap" "Gap of ${diff_days} days between boots around $prev_end → $ts"
                gap_warn=1
            fi
        fi
        prev_end="$ts"
    done <<< "$boots"
    [[ $gap_warn -eq 0 ]] && ok "boot-gaps" "No suspicious boot gaps in recent history"
}

# --- Main ---

echo "╔══════════════════════════════════════════════╗"
echo "║  doctor.sh - System reliability health check ║"
echo "╚══════════════════════════════════════════════╝"
HOST="$(command -v hostname >/dev/null 2>&1 && hostname || cat /etc/hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)"
echo "Host: $HOST"
echo "Kernel: $(uname -r)"
echo "Date: $(date)"

check_sleep_targets
check_kernel_errors
check_suspend_resume
check_gpu_driver
check_memory
check_disk_smart
check_nvme
check_cpu_temp
check_oomd
check_watchdog
check_kernel_cmdline
check_btrfs
check_failed_services
check_fstrim
check_tailscale
check_boot_history

# --- Summary ---
echo ""
echo "━━━ Summary ━━━"
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"
echo "  HINT: $HINT"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "❌ Health check completed with $FAIL failures"
    exit 1
fi

if [[ $WARN -gt 0 ]]; then
    echo "⚠️  Health check completed with $WARN warnings"
    exit 0
fi

echo "✅ Health check complete - all systems nominal"
exit 0
