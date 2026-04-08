#!/usr/bin/env bash
set -euo pipefail

# Panic-on-lockup kernel sysctls.
#
# Default Linux behavior on a kernel oops or hang is to PRINT a warning and
# keep limping along. On a headless / always-on box this is the worst possible
# outcome: the system silently rots until the hardware watchdog (sp5100_tco)
# notices ~60s later and force-resets, leaving zero crash evidence in the
# journal because journald never got a chance to fsync.
#
# These sysctls flip that behavior. Any of:
#   - kernel oops
#   - hardware NMI lockup
#   - software lockup (CPU stuck >20s)
# now triggers an immediate kernel panic. The panic dumps a stack trace to
# the kernel ring buffer + pstore (if mounted) and reboots after 10 seconds.
# systemd-pstore (enabled by persistent-crash.sh) then harvests the dump on
# the next boot and writes it to /var/lib/systemd/pstore for forensics.
#
# Hung-task panic is intentionally NOT enabled - normal slow I/O can hold a
# task in D-state for >120s without anything actually being broken.

echo "🛡️  [sysctl-stability] Writing /etc/sysctl.d/99-stability.conf..."
sudo tee /etc/sysctl.d/99-stability.conf >/dev/null <<'EOF'
# Reboot 10 seconds after a kernel panic (gives pstore time to flush).
kernel.panic = 10

# Convert a kernel oops into a panic so we get a stack trace + reboot
# instead of a silently corrupted kernel limping along.
kernel.panic_on_oops = 1

# Convert a hardware NMI lockup detection into a panic.
kernel.hardlockup_panic = 1

# Convert a software lockup (CPU stuck >20s in kernel) into a panic.
kernel.softlockup_panic = 1

# Do NOT panic on out-of-memory - systemd-oomd handles OOM more gracefully
# than the in-kernel killer, and a panic on OOM would reboot the box for
# something that's recoverable.
vm.panic_on_oom = 0
EOF

echo "🛡️  [sysctl-stability] Applying sysctl values to running kernel..."
# --system reads /etc/sysctl.d/, /run/sysctl.d/, /usr/lib/sysctl.d/, and
# /etc/sysctl.conf. Some keys (notably hardlockup_panic) may be missing on
# certain kernel builds - sysctl exits non-zero in that case. We capture the
# exit status explicitly so set -e doesn't abort and the verify loop below
# can report which keys actually landed.
sysctl_out=""
if ! sysctl_out="$(sudo sysctl --system 2>&1)"; then
    echo "⚠️  [sysctl-stability] sysctl --system exit non-zero (some keys may be unavailable):"
    # shellcheck disable=SC2001 # sed is clearer than ${var//$'\n'/...} for newline-prefix
    echo "$sysctl_out" | sed 's/^/    /'
else
    echo "$sysctl_out" | grep -E '99-stability\.conf|kernel\.panic|kernel\.hardlockup|kernel\.softlockup|vm\.panic_on_oom' || true
fi

# Verify each setting actually took effect. If the running kernel was built
# without CONFIG_HARDLOCKUP_DETECTOR or similar, the file simply doesn't
# exist and the value can't be set - report that as a HINT, not a failure.
echo "🛡️  [sysctl-stability] Verifying applied values..."
verify() {
    local key="$1" expected="$2" actual
    if actual="$(sysctl -n "$key" 2>/dev/null)"; then
        if [[ "$actual" == "$expected" ]]; then
            echo "✅ [sysctl-stability] $key = $actual"
        else
            echo "⚠️  [sysctl-stability] $key = $actual (expected $expected)"
        fi
    else
        echo "ℹ️  [sysctl-stability] $key not available on this kernel build"
    fi
}
verify kernel.panic 10
verify kernel.panic_on_oops 1
verify kernel.hardlockup_panic 1
verify kernel.softlockup_panic 1
verify vm.panic_on_oom 0

echo "✅ [sysctl-stability] Setup complete"
