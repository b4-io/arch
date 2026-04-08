#!/usr/bin/env bash
set -euo pipefail

# Persistent crash forensics: pstore + journald.
#
# Two layers:
#
# 1. systemd-pstore: harvests kernel oops/panic dumps from /sys/fs/pstore
#    on every boot and archives them to /var/lib/systemd/pstore. The kernel
#    writes to pstore (backed by ACPI ERST or EFI variables on this hardware)
#    in the seconds before a panic-induced reboot, so we get the stack trace
#    even when the regular journal is too late to fsync.
#
# 2. journald persistence + size limits: /var/log/journal already exists on
#    this box but no SystemMaxUse is set, which means journald defaults to
#    10% of /var. On a 250G NVMe that's 25G of journals - way too much. Cap
#    it at 2G to keep enough history for forensics without eating disk.
#    Also enable Compress + Seal for FSS (forward-secure sealing) integrity.

# --- 1. systemd-pstore --------------------------------------------------------

echo "🛡️  [persistent-crash] Checking pstore backend..."
if mountpoint -q /sys/fs/pstore; then
    echo "✅ [persistent-crash] /sys/fs/pstore mounted (kernel pstore backend present)"
else
    echo "⚠️  [persistent-crash] /sys/fs/pstore NOT mounted - kernel may lack a backend"
    echo "                       (need CONFIG_ACPI_APEI_ERST or CONFIG_EFI_VARS_PSTORE)"
fi

echo "🛡️  [persistent-crash] Enabling systemd-pstore.service..."
# systemd-pstore is a oneshot that runs on boot, harvests pstore, and exits.
# enable --now is idempotent and starts it immediately to drain anything
# already sitting in /sys/fs/pstore.
sudo systemctl enable --now systemd-pstore.service

if systemctl is-enabled --quiet systemd-pstore.service; then
    echo "✅ [persistent-crash] systemd-pstore.service enabled"
else
    echo "⚠️  [persistent-crash] systemd-pstore.service enable failed"
fi

# --- 2. journald drop-in -----------------------------------------------------

echo "🛡️  [persistent-crash] Writing /etc/systemd/journald.conf.d/10-persistent.conf..."
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/10-persistent.conf >/dev/null <<'EOF'
[Journal]
# Persist across reboots so post-crash forensics survive.
Storage=persistent

# Cap total disk usage at 2G - plenty of history for crash debugging
# without eating the root filesystem.
SystemMaxUse=2G
SystemMaxFileSize=200M
SystemKeepFree=2G

# Compression + sealing for integrity & space efficiency.
Compress=yes
Seal=yes

# This box doesn't run rsyslog and we don't want a duplicate copy of every
# log line eating CPU.
ForwardToSyslog=no
EOF

# Explicitly create /var/log/journal so Storage=persistent actually has
# a target to write to on a fresh install. On this box the directory
# already exists, but a newly-provisioned machine won't have it - and
# journald silently falls back to /run/log/journal (volatile) when the
# persistent directory is missing, which is the exact footgun we're
# trying to close.
if [[ ! -d /var/log/journal ]]; then
    echo "🛡️  [persistent-crash] Creating /var/log/journal..."
    sudo install -d -g systemd-journal -m 2755 /var/log/journal
fi

# systemd-journald handles SIGUSR1 for "rotate", but a clean restart picks
# up the new config without dropping any in-flight logs (logs are streamed
# from clients via /run/systemd/journal/socket which survives the restart).
echo "🛡️  [persistent-crash] Restarting systemd-journald to apply config..."
sudo systemctl restart systemd-journald

# Flush any volatile journal from /run/log/journal into the now-persistent
# /var/log/journal. On a box that was previously volatile-only, this is the
# step that moves existing logs over to persistent storage.
sudo journalctl --flush

# Verify the restart actually worked - if journald failed to start, the
# whole logging pipeline is dead and we want to know NOW, not after the
# next crash when there's nothing to read.
if systemctl is-active --quiet systemd-journald; then
    echo "✅ [persistent-crash] systemd-journald active"
else
    echo "❌ [persistent-crash] systemd-journald failed to restart - check journalctl -u systemd-journald"
    exit 1
fi

# --- Report current journal state -------------------------------------------

if [[ -d /var/log/journal ]]; then
    journal_size="$(sudo du -sh /var/log/journal 2>/dev/null | awk '{print $1}')"
    echo "✅ [persistent-crash] /var/log/journal present (${journal_size:-unknown})"
fi

# Show any pstore entries already harvested - if this script has been run
# before and the box has crashed since, the dumps live here.
if [[ -d /var/lib/systemd/pstore ]]; then
    pstore_count="$(sudo find /var/lib/systemd/pstore -type f 2>/dev/null | wc -l)"
    if [[ "$pstore_count" -gt 0 ]]; then
        echo "ℹ️  [persistent-crash] /var/lib/systemd/pstore has $pstore_count archived dump(s)"
        echo "   Inspect with: sudo ls -lh /var/lib/systemd/pstore"
    fi
fi

echo "✅ [persistent-crash] Setup complete"
