# Plan: Arch Linux Dotfiles Refactor + Server Reliability

**Generated**: 2026-04-07
**Repo**: `/home/bruno/env` (`b4-io/arch`)
**Hardware**: AMD Ryzen 1700X, Vega 56/64, 16GB RAM, ext4 root, hostname `dezio`

## Goal

Transform `/home/bruno/env` from a 15-flat-script dotfiles repo into an ultrawork-executable "fresh install → reliable always-on server" toolkit, while adding critical reliability fixes to address a box with documented crash gaps (31 days between boots in journalctl history).

## User-Confirmed Design Decisions

1. **cmd/ layout**: Numbered subdirectories: `cmd/00-base/`, `cmd/10-wm/`, `cmd/20-dev/`, `cmd/30-apps/`, `cmd/40-net/`, `cmd/50-reliability/`
2. **Config scope**: Essential small dotfiles ONLY (dunst, tmux, opencode filtered, systemd/user, optional git/ignore) + shell dotfiles (`~/.zshrc`, `~/.gitconfig`) under top-level `home/`. NO browser profiles, NO full IDE configs, NO personal data.
3. **Sleep strategy**: Disable sleep entirely. Mask sleep/suspend/hibernate targets. Use `hypridle` for screen blanking only (no system suspend).
4. **Install scope**: Assume Arch is already installed. `install.sh` targets existing system with pacman and a regular user. Do NOT install kernel/grub/base packages.
5. **Tailscale script**: Idempotent. Installs package, enables daemon, detects if `tailscale status` shows already-up, skips `tailscale up` if so. Supports `TS_AUTHKEY` env var for non-interactive flow.

## Key Findings (Deviations from brief, with defaults)

| Finding | Impact | Default |
|---|---|---|
| `~/.config/opencode/.gitignore` upstream-ignores `package.json`, `bun.lock`, `node_modules`, `.gitignore` | Tracking causes drift | **Track only `opencode.json` + `oh-my-openagent.json`** |
| `~/.config/htop/` empty (htop writes on exit only if changed) | Nothing to track | **Skip htop** |
| `~/.config/nemo/` empty (nemo uses dconf) | Nothing to track | **Skip nemo** |
| `~/.config/uv/` only install receipt (no `uv.toml`) | Brief said "if exists" | **Skip uv** |
| `~/.config/go/` only `telemetry/` | Brief said "if exists" | **Skip go** |
| `~/.config/colima/` only `_lima/` VM state | No config file | **Skip colima** |
| `~/.config/gh/` has mode-600 `config.yml` + `hosts.yml` with auth tokens | Token leakage risk | **Skip gh entirely** |
| `~/.tmux.conf` does NOT exist as a regular file | Brief was uncertain | **Skip** |
| `~/.config/git/ignore` (31 bytes, global gitignore) | Tiny, safe, useful | **Track as bonus** |
| `/proc/cmdline` already has `idle=nomwait processor.max_cstate=5` | Zen 1 workaround partially applied | `doctor.sh` verifies; **NO GRUB edits in this refactor** |
| `/dev/watchdog` + `sp5100_tco` loaded | Hardware watchdog confirmed available | watchdog.sh will work |
| Boot history: Feb 6 → Mar 7 → Apr 7 (two 31-day gaps) | Real reliability problem | Watchdog + systemd-oomd are first fixes |
| Tailscale client 1.96.4 ≠ daemon 1.94.1 | Daemon not restarted after pkg upgrade | `update.sh` restarts `tailscaled` after upgrade |
| `~/.bash_profile` has 2× duplicates of uwsm/cargo blocks | Existing scripts use `grep -Fq` so no new dupes | **Out of scope** |
| `shellcheck` NOT installed | Needed for verification | Add to `cmd/00-base/core.sh` |
| Root FS = ext4 (not btrfs) | `fs-health.sh` btrfs branch auto-skips | Already handled |

## Clarifying Questions (defaults in bold)

1. **opencode**: OK to track only `opencode.json` + `oh-my-openagent.json` (skip `package.json` per upstream gitignore)? **YES**
2. **Empty/state-only dirs (htop, nemo, uv, go, colima)**: Confirm we skip? **YES**
3. **`gh` configs**: Confirm we skip entirely due to token risk? **YES**
4. **`.config/git/ignore`**: Include as bonus? **YES**
5. **GRUB kernel params**: Already has `processor.max_cstate=5`. Add advisory to `doctor.sh`? **YES, advisory only**
6. **`update.sh` restarts `tailscaled` after upgrade**: OK? **YES**
7. **`update.sh` running `fnm install --lts`**: Make opt-in via `UPDATE_NODE=1`? **YES, opt-in**
8. **`.config/autostart/shutter.desktop`**: Track? **NO**
9. **Existing `.bash_profile` duplicates**: Leave alone? **YES, out of scope**

---

## Risk Callouts

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | `git mv` commit mixed with content edits → lost history | Medium | High | T2 isolated single-agent, "no edits" instruction, verified via `git diff --stat --find-renames=100%` |
| R2 | `no-sleep.sh` restarts logind → kills user SSH session | High if literal | High | Script prints instructions only; explicit test `! grep 'systemctl restart systemd-logind'` |
| R3 | `link.sh` clobbers user's working hyprland.conf | Low | Medium | Backup mechanism + `--dry-run` first + selective `link.sh .config/hypr` |
| R4 | `install.sh` re-triggers destructive curl installers | Low | Medium | Each script uses `command -v X` guard; verified via shellcheck |
| R5 | opencode `node_modules` leaks into git | Low | Low | `.gitignore` created in T1 (before T13); explicit grep check in T22 |
| R6 | GH token in `.config/gh/` gets committed | Zero (skipped) | Critical | Default skip gh tracking |
| R7 | Agent generates non-idempotent script | Medium | Medium | Every script uses `--needed` (pacman) and `command -v` (curl) guards |
| R8 | Ryzen 1700X box crashes DURING refactor | Low | Medium | Verification + commits in small batches; T0 baseline |
| R9 | `.bash_profile` duplicates cause surprising behavior | Low | Low | Out of scope; documented |
| R10 | Tailscale version mismatch persists if update.sh isn't run | Certain (current) | Low | `update.sh` restarts tailscaled; `doctor.sh` flags mismatch |

---

## Task Dependency Graph

| # | Task | Depends On |
|---|------|-----------|
| T0 | Baseline capture (git ls-files snapshot) | None |
| T1 | Create `.gitignore` | None |
| T2 | `cmd/` reorganization via `git mv` ONLY | T0 |
| T3 | Expand `cmd/00-base/core.sh` | T2 |
| T4 | Split `cmd/20-dev/` into `languages.sh` + `tools.sh` | T2 |
| T5 | Update `cmd/10-wm/hyprland.sh` | T2 |
| T6 | Create `cmd/30-apps/editors.sh` + `media.sh`; update `ai.sh` | T2 |
| T7 | Create `cmd/40-net/tailscale.sh` + finalize `time-network.sh` | T2 |
| T8 | Create `cmd/50-reliability/*` (4 scripts) | T2 |
| T9 | Write `install.sh` | T2 |
| T10 | Write `update.sh` | None (independent) |
| T11 | Write `link.sh` | None |
| T12 | Write `doctor.sh` | None |
| T13 | Add new tracked configs (dunst, tmux, opencode filtered, elephant, git/ignore) | T1 |
| T14 | Add `home/.zshrc` + `home/.gitconfig` | T1 |
| T15 | Write `.config/hypr/hypridle.conf` + `hyprlock.conf` | T1 |
| T16 | Patch `.config/hypr/hyprland.conf` — add `exec-once = hypridle` | T15 |
| T17 | Write `README.md` | T3..T12 |
| T18 | shellcheck + `bash -n` on ALL scripts | T3..T17 |
| T19 | `install.sh --dry-run` verification | T18 |
| T20 | `link.sh --dry-run` verification | T18 |
| T21 | `doctor.sh` execution on current system | T18 |
| T22 | Personal-data scan + `git status` review | T13, T14, T15, T16 |
| T23 | Commit plan execution (atomic, awaits user) | T18..T22 + user approval |

## Parallel Execution Graph (Waves)

```
Wave 0 (Baseline - 1 task, sequential):
└── T0: Baseline snapshot

Wave 1 (Foundation - 2 tasks parallel):
├── T1: .gitignore
└── T2: git mv reorganization (ISOLATED)

Wave 2 (Content edits + new files - 13 tasks PARALLEL):
├── T3:  cmd/00-base/core.sh
├── T4:  cmd/20-dev/languages.sh + tools.sh
├── T5:  cmd/10-wm/hyprland.sh
├── T6:  cmd/30-apps/*
├── T7:  cmd/40-net/*
├── T8:  cmd/50-reliability/*
├── T9:  install.sh
├── T10: update.sh
├── T11: link.sh
├── T12: doctor.sh
├── T13: new tracked configs
├── T14: home/.zshrc + home/.gitconfig
└── T15: hypridle.conf + hyprlock.conf

Wave 3 (Hypr autostart patch + docs - 2 tasks parallel):
├── T16: patch .config/hypr/hyprland.conf
└── T17: README.md

Wave 4 (Verification - 5 tasks parallel, read-only):
├── T18: shellcheck + bash -n
├── T19: install.sh --dry-run
├── T20: link.sh --dry-run
├── T21: doctor.sh execution
└── T22: personal-data grep + git status review

Wave 5 (Final review - sequential, awaits user):
└── T23: Commit plan (apply atomic commits per strategy)
```

---

## Tasks

### T0: Baseline capture
- **What**: Snapshot of current git state — `git ls-files`, current HEAD SHA, `git status` (must be clean). Write to `/tmp/baseline_files.txt` and `/tmp/baseline_head.txt`.
- **Owner files**: read-only
- **Depends On**: None
- **Acceptance**: Snapshot artifacts captured listing all 25 tracked files + HEAD SHA
- **QA**:
  ```bash
  git -C /home/bruno/env ls-files | sort > /tmp/baseline_files.txt
  git -C /home/bruno/env log -1 --format=%H > /tmp/baseline_head.txt
  test -s /tmp/baseline_files.txt && wc -l /tmp/baseline_files.txt  # 25 lines
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T1: Create `.gitignore`
- **What**: Conservative `.gitignore` at repo root. Exclude: `node_modules/`, `*.bak.*`, `*.log`, `.DS_Store`, `.env*`, `*.swp`, `opencode/bun.lock`, `opencode/package.json`, `opencode/package-lock.json`, `opencode/node_modules/`, `opencode/playwright/storage-state.json`, `opencode/.gitignore`, `*.crt`, `*.key`, `*.pem`, `id_rsa*`, `id_ed25519*`, `.ssh/`, `/tmp_*`
- **Owner files**: `/home/bruno/env/.gitignore` (new)
- **Depends On**: None
- **Acceptance**:
  - File exists
  - `git check-ignore .config/opencode/node_modules/foo` matches
  - `git check-ignore .config/opencode/opencode.json` does NOT match
- **QA**:
  ```bash
  test -f /home/bruno/env/.gitignore
  cd /home/bruno/env && git check-ignore -v .config/opencode/node_modules/anything
  cd /home/bruno/env && ! git check-ignore .config/opencode/opencode.json
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T2: `cmd/` reorganization via pure `git mv`
- **What**: ONLY `git mv`, NO content changes. Prep step first, then renames.
- **Prep step (required because `git mv` does NOT create intermediate dirs)**:
  ```bash
  cd /home/bruno/env
  mkdir -p cmd/00-base cmd/10-wm cmd/20-dev cmd/30-apps cmd/40-net cmd/50-reliability
  ```
  Note: empty dirs are not tracked by git, so creating them doesn't affect `git status`. The `git mv` operations populate them.
- **Mapping**:
  ```
  cmd/core.sh         → cmd/00-base/core.sh
  cmd/zsh.sh          → cmd/00-base/zsh.sh
  cmd/services.sh     → cmd/10-wm/services.sh        (one-line elephant enable; lives with elephant install)
  cmd/wm.sh           → cmd/10-wm/hyprland.sh        (renamed)
  cmd/screenshot.sh   → cmd/10-wm/screenshot.sh
  cmd/dev.sh          → cmd/20-dev/tools.sh          (will be edited in T4)
  cmd/go.sh           → cmd/20-dev/go.sh             (will be deleted by T4 after merge into languages.sh)
  cmd/rust.sh         → cmd/20-dev/rust.sh           (will be deleted by T4 after merge into languages.sh)
  cmd/docker.sh       → cmd/20-dev/docker.sh
  cmd/browser.sh      → cmd/30-apps/browser.sh
  cmd/ai.sh           → cmd/30-apps/ai.sh
  cmd/zed.sh          → cmd/30-apps/zed.sh           (will be deleted by T6 after merge into editors.sh)
  cmd/vscode.sh       → cmd/30-apps/vscode.sh        (will be deleted by T6)
  cmd/pdf.sh          → cmd/30-apps/pdf.sh           (will be deleted by T6 after merge into media.sh)
  cmd/time_network.sh → cmd/40-net/time-network.sh   (renamed underscore→dash)
  ```
- **⚠️ CRITICAL**: Single atomic isolated task. Use only `git mv`. NO content edits. Commit message: `refactor(cmd): reorganize scripts into numbered subdirs`.
- **Owner files**: all `cmd/*.sh` (moved only)
- **Depends On**: T0
- **Acceptance**:
  - `git status` shows 15 renames (R), 0 modifications (M)
  - `git diff --stat --find-renames=100%` shows ≥90% similarity for each
  - `git log --follow cmd/00-base/core.sh` traces back to original
- **QA**:
  ```bash
  cd /home/bruno/env
  test $(git status --porcelain | grep -c '^R') -eq 15
  test $(git status --porcelain | grep -c '^M') -eq 0
  ```
- **Delegation**: `category=unspecified-low`, `load_skills=["git-master"]`

---

### T3: Expand `cmd/00-base/core.sh`
- **What**: Add to PACKAGES array: `nano`, `noto-fonts-cjk`, `woff2-font-awesome`, `amd-ucode`, `linux-firmware-amdgpu`, `linux-firmware-radeon`, `linux-firmware-realtek`, `linux-firmware-other`, `gnome-keyring`, `reflector`, `ninja`, `shellcheck`, `lm_sensors`, `clang`. Upgrade `set -e` → `set -euo pipefail`. Preserve yay bootstrap. Match emoji log style.
- **Owner files**: `cmd/00-base/core.sh`
- **Depends On**: T2
- **Acceptance**: All pre-existing pkgs still present; new pkgs added; `bash -n` + `shellcheck` pass
- **QA**:
  ```bash
  bash -n /home/bruno/env/cmd/00-base/core.sh
  shellcheck /home/bruno/env/cmd/00-base/core.sh
  grep -q 'shellcheck' /home/bruno/env/cmd/00-base/core.sh
  grep -q 'amd-ucode' /home/bruno/env/cmd/00-base/core.sh
  ```
- **Delegation**: `category=unspecified-low`, `load_skills=[]`

---

### T4: Split `cmd/20-dev/` into `languages.sh` + `tools.sh`
- **What**:
  - Create `cmd/20-dev/languages.sh`: consolidates rust (from `rust.sh` including mold + cargo-watch + wasm-pack + shell profile block via grep -Fq idempotency), go, fnm, bun, uv, jdk-openjdk, jenv. Use `--needed` for pacman, `command -v` guards for curl installers.
  - Update `cmd/20-dev/tools.sh` (was `dev.sh` per T2): remove rust/go/fnm/bun/uv (now in languages.sh). Keep: postgresql, github-cli, protobuf, buf, tmux, oh-my-tmux, air (`go install`), goose (`go install`).
  - `git rm cmd/20-dev/go.sh cmd/20-dev/rust.sh`
- **Owner files**: `cmd/20-dev/languages.sh` (new), `cmd/20-dev/tools.sh` (edit), `cmd/20-dev/go.sh` (delete), `cmd/20-dev/rust.sh` (delete)
- **Depends On**: T2
- **Acceptance**: `go.sh` and `rust.sh` removed; `languages.sh` has rust+go+fnm+bun+uv; `tools.sh` has postgresql+air+goose
- **QA**:
  ```bash
  bash -n /home/bruno/env/cmd/20-dev/languages.sh
  bash -n /home/bruno/env/cmd/20-dev/tools.sh
  shellcheck /home/bruno/env/cmd/20-dev/*.sh
  ! test -e /home/bruno/env/cmd/20-dev/go.sh
  ! test -e /home/bruno/env/cmd/20-dev/rust.sh
  grep -q 'rustup' /home/bruno/env/cmd/20-dev/languages.sh
  grep -q 'fnm.vercel.app' /home/bruno/env/cmd/20-dev/languages.sh
  grep -q 'go install.*air' /home/bruno/env/cmd/20-dev/tools.sh
  ```
- **Delegation**: `category=unspecified-high`, `load_skills=[]`

---

### T5: Update `cmd/10-wm/hyprland.sh`
- **What**: Add to first pacman line: `aquamarine`, `hypridle`, `hyprpaper`, `brightnessctl`, `playerctl`. Replace `ttf-font-awesome` with `woff2-font-awesome`. Upgrade to `set -euo pipefail`. Preserve uwsm shell profile autostart block unchanged.
- **Owner files**: `cmd/10-wm/hyprland.sh`
- **Depends On**: T2
- **Acceptance**: New pkgs present; uwsm autostart block unchanged
- **QA**:
  ```bash
  bash -n /home/bruno/env/cmd/10-wm/hyprland.sh
  shellcheck /home/bruno/env/cmd/10-wm/hyprland.sh
  grep -q 'hypridle' /home/bruno/env/cmd/10-wm/hyprland.sh
  grep -q 'aquamarine' /home/bruno/env/cmd/10-wm/hyprland.sh
  grep -q 'exec uwsm start hyprland.desktop' /home/bruno/env/cmd/10-wm/hyprland.sh
  ```
- **Delegation**: `category=unspecified-low`, `load_skills=[]`

---

### T6: Create `cmd/30-apps/editors.sh` + `media.sh`; update `ai.sh`
- **What**:
  - Create `editors.sh`: zed (curl, with `command -v zed` guard) + vulkan deps + visual-studio-code-bin (yay) + datagrip (yay) + kiro-ide (yay) + github-desktop-bin (yay)
  - Create `media.sh`: masterpdfeditor-free (yay) + vlc (pacman) + shotcut (pacman)
  - Update `ai.sh`: keep opencode curl with `command -v opencode` guard, add `yay -S --needed --noconfirm opencode-desktop-bin`
  - `git rm cmd/30-apps/{zed.sh, vscode.sh, pdf.sh}`
- **Owner files**: `cmd/30-apps/editors.sh` (new), `cmd/30-apps/media.sh` (new), `cmd/30-apps/ai.sh` (edit), zed.sh/vscode.sh/pdf.sh (delete)
- **Depends On**: T2
- **Acceptance**: Three source files absent; consolidated files exist; `bash -n` + `shellcheck` pass
- **QA**:
  ```bash
  bash -n /home/bruno/env/cmd/30-apps/*.sh
  shellcheck /home/bruno/env/cmd/30-apps/*.sh
  ! test -e /home/bruno/env/cmd/30-apps/zed.sh
  grep -q 'visual-studio-code-bin' /home/bruno/env/cmd/30-apps/editors.sh
  grep -q 'datagrip' /home/bruno/env/cmd/30-apps/editors.sh
  grep -q 'opencode-desktop-bin' /home/bruno/env/cmd/30-apps/ai.sh
  ```
- **Delegation**: `category=unspecified-low`, `load_skills=[]`

---

### T7: Create `cmd/40-net/tailscale.sh` + finalize `time-network.sh`
- **What**:
  - Write `tailscale.sh`:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    echo "[tailscale] Installing..."
    sudo pacman -S --needed --noconfirm tailscale
    echo "[tailscale] Enabling tailscaled.service..."
    sudo systemctl enable --now tailscaled

    sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<EOF
    net.ipv4.conf.default.rp_filter = 1
    net.ipv4.conf.all.rp_filter = 1
    EOF
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

    sleep 2
    if tailscale status --peers=false --json 2>/dev/null | grep -q '"BackendState": "Running"'; then
      echo "[tailscale] Already running, skipping tailscale up"
      tailscale status
      exit 0
    fi

    if [[ -n "${TS_AUTHKEY:-}" ]]; then
      sudo tailscale up \
        --auth-key="$TS_AUTHKEY" \
        --hostname="${TS_HOSTNAME:-$(hostname)}" \
        --accept-dns \
        --operator="${SUDO_USER:-$USER}" \
        --ssh
    else
      echo "[tailscale] No TS_AUTHKEY set. Running interactive login..."
      sudo tailscale up \
        --hostname="${TS_HOSTNAME:-$(hostname)}" \
        --accept-dns \
        --operator="${SUDO_USER:-$USER}" \
        --ssh
    fi
    tailscale status
    ```
  - `time-network.sh`: add `set -euo pipefail` to existing content. Keep `timedatectl set-ntp true`.
- **Owner files**: `cmd/40-net/tailscale.sh` (new), `cmd/40-net/time-network.sh` (edit)
- **Depends On**: T2
- **Acceptance**: Idempotency check present; `TS_AUTHKEY` env var supported
- **QA**:
  ```bash
  bash -n /home/bruno/env/cmd/40-net/tailscale.sh
  shellcheck /home/bruno/env/cmd/40-net/tailscale.sh
  grep -q 'TS_AUTHKEY' /home/bruno/env/cmd/40-net/tailscale.sh
  grep -q 'BackendState' /home/bruno/env/cmd/40-net/tailscale.sh
  ```
- **Delegation**: `category=unspecified-low`, `load_skills=[]`

---

### T8: Create `cmd/50-reliability/*` (4 scripts)

#### no-sleep.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[no-sleep] Masking sleep/suspend/hibernate targets..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d

sudo tee /etc/systemd/sleep.conf.d/10-no-sleep.conf >/dev/null <<EOF
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF

sudo tee /etc/systemd/logind.conf.d/10-no-sleep.conf >/dev/null <<EOF
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
echo "[no-sleep] To activate logind changes, run (will end current session):"
echo "  sudo systemctl restart systemd-logind"
echo "[no-sleep] Done"
```
**⚠️ CRITICAL**: MUST NOT auto-restart systemd-logind. Only print instructions.

#### watchdog.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[watchdog] Enabling systemd hardware watchdog..."
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/10-watchdog.conf >/dev/null <<EOF
[Manager]
RuntimeWatchdogSec=30s
RebootWatchdogSec=10min
DefaultMemoryAccounting=yes
EOF

echo "[watchdog] Enabling systemd-oomd..."
sudo systemctl enable --now systemd-oomd || echo "[watchdog] systemd-oomd not available, skipping"

sudo systemctl daemon-reload
echo "[watchdog] Done"
```

#### fs-health.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[fs-health] Installing monitoring tools..."
sudo pacman -S --needed --noconfirm smartmontools nvme-cli lm_sensors

echo "[fs-health] Enabling fstrim.timer..."
sudo systemctl enable --now fstrim.timer

ROOTFS=$(findmnt -n -o FSTYPE /)
if [[ "$ROOTFS" == "btrfs" ]]; then
  echo "[fs-health] Root is btrfs, enabling btrfs-scrub@-.timer"
  sudo systemctl enable --now btrfs-scrub@-.timer 2>/dev/null || echo "[fs-health] btrfs-scrub timer not available"
else
  echo "[fs-health] Root is $ROOTFS (not btrfs), skipping btrfs scrub"
fi
echo "[fs-health] Done"
```

#### hyprlock-idle.sh
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[hyprlock-idle] Installing hypridle..."
sudo pacman -S --needed --noconfirm hypridle
echo "[hyprlock-idle] hyprlock already installed via cmd/10-wm/hyprland.sh"
echo "[hyprlock-idle] Run ./link.sh to deploy hypridle.conf and hyprlock.conf"
echo "[hyprlock-idle] Done"
```

- **Owner files**: 4 new scripts under `cmd/50-reliability/`
- **Depends On**: T2
- **QA**:
  ```bash
  for f in /home/bruno/env/cmd/50-reliability/*.sh; do bash -n "$f" && shellcheck "$f"; done
  # Positive: the restart instruction MUST appear as an echo (so user sees it printed)
  grep -q 'echo.*systemctl restart systemd-logind' /home/bruno/env/cmd/50-reliability/no-sleep.sh
  # Negative: the restart command MUST NOT be executed directly (no bare shell line starting with `sudo systemctl restart systemd-logind`)
  ! grep -E '^[[:space:]]*sudo systemctl restart systemd-logind' /home/bruno/env/cmd/50-reliability/no-sleep.sh
  grep -q 'RuntimeWatchdogSec=30s' /home/bruno/env/cmd/50-reliability/watchdog.sh
  grep -q 'hypridle' /home/bruno/env/cmd/50-reliability/hyprlock-idle.sh
  ```
- **Delegation**: `category=unspecified-high`, `load_skills=[]`

---

### T9: Write `install.sh` orchestrator
- **What**: Iterates `cmd/*/*.sh` in lexicographic order. Flags:
  - `--dry-run`: list, don't execute
  - `--only <pattern>`: regex match on subdir
  - `--skip <pattern>`: regex match
  - `--continue-on-error`: don't halt on first failure
  - `--help|-h`
- Logs: `[install] 00-base/core.sh -> START / OK / FAIL`
- Summary: `N succeeded, M failed, K skipped`
- Refuses to run as root (`[[ $EUID -eq 0 ]]`)
- Final hint: `Next: run ./link.sh to deploy configs`
- **Owner files**: `install.sh` (new)
- **Depends On**: T2
- **QA**:
  ```bash
  bash -n /home/bruno/env/install.sh
  shellcheck /home/bruno/env/install.sh
  /home/bruno/env/install.sh --help
  /home/bruno/env/install.sh --dry-run | grep -c '00-base/core.sh'  # 1
  /home/bruno/env/install.sh --only 50-reliability --dry-run | grep -c '00-base'  # 0
  ```
- **Delegation**: `category=unspecified-high`, `load_skills=[]`

---

### T10: Write `update.sh`
- **What**: Sections, each gated by `command -v X`:
  - `[pacman]` `sudo pacman -Syu --noconfirm`
  - `[yay]` `yay -Syu --noconfirm`
  - `[rustup]` `rustup update`
  - `[fnm]` gated behind `UPDATE_NODE=1` (safety)
  - `[bun]` `bun upgrade`
  - `[uv]` `uv self update`
  - `[cargo]` re-install cargo-watch, wasm-pack
  - `[go]` re-install air + goose
  - `[opencode]` re-run installer
  - `[oh-my-zsh]` `omz update --unattended`
  - `[tailscale-daemon]` `sudo systemctl restart tailscaled` if active (fixes client/daemon mismatch)
- Print summary table at end. Support `--dry-run`.
- **Owner files**: `update.sh` (new)
- **QA**:
  ```bash
  bash -n /home/bruno/env/update.sh
  shellcheck /home/bruno/env/update.sh
  grep -q 'UPDATE_NODE' /home/bruno/env/update.sh
  grep -q 'tailscaled' /home/bruno/env/update.sh
  /home/bruno/env/update.sh --dry-run
  ```
- **Delegation**: `category=unspecified-high`, `load_skills=[]`

---

### T11: Write `link.sh` (pure-bash symlink deployer)
- **What**: Walks `<repo>/.config/`, `<repo>/home/`, `<repo>/.cargo/`. For every regular file:
  - For `.config/X` → symlink at `$HOME/.config/X`
  - For `home/.X` → symlink at `$HOME/.X` (strips `home/` prefix)
  - For `.cargo/X` → symlink at `$HOME/.cargo/X`
- Conflict handling:
  - Target exists as regular file → backup `<path>.bak.$(date +%s)`, log `BACKED UP`
  - Target is correct symlink → skip, log `OK (existing)`
  - Target is wrong symlink → replace
  - Target is non-symlink directory → FAIL (don't clobber)
- `--dry-run`: print plan, don't execute
- Selective: `./link.sh .config/hypr` restricts to files under that prefix
- Refuses if `$HOME` unset
- `set -euo pipefail`
- **Owner files**: `link.sh` (new)
- **QA**:
  ```bash
  bash -n /home/bruno/env/link.sh
  shellcheck /home/bruno/env/link.sh
  /home/bruno/env/link.sh --help
  /home/bruno/env/link.sh --dry-run | head -20
  ```
- **Delegation**: `category=unspecified-high`, `load_skills=[]`

---

### T12: Write `doctor.sh` (read-only health check)
- **What**: 16 checks, each `[check-name] ... OK/WARN/FAIL`:
  1. Sleep targets masked
  2. Kernel errors last 24h
  3. Suspend/resume messages last 7 days
  4. GPU driver errors (amdgpu)
  5. Memory pressure (`free -h`, swap > 50% = WARN)
  6. Disk S.M.A.R.T. health (smartctl, all sd*)
  7. NVMe health (nvme smart-log)
  8. CPU temperature (sensors)
  9. systemd-oomd active
  10. Watchdog (`/proc/sys/kernel/watchdog`, `/dev/watchdog`, `RuntimeWatchdogSec`)
  11. Kernel cmdline (verify Zen 1 workarounds: `idle=nomwait processor.max_cstate`)
  12. Btrfs status (only if root is btrfs)
  13. Failed services (`systemctl --failed`)
  14. fstrim.timer enabled
  15. Tailscale status + version mismatch detection
  16. Boot history gaps (>7 days = WARN)
- Each check wrapped (per-check errors non-fatal). Exit non-zero if any FAIL.
- All external tools gated by `command -v`.
- **Owner files**: `doctor.sh` (new)
- **QA**:
  ```bash
  bash -n /home/bruno/env/doctor.sh
  shellcheck /home/bruno/env/doctor.sh
  /home/bruno/env/doctor.sh || echo "FAILs detected (expected on current box)"
  /home/bruno/env/doctor.sh 2>&1 | grep -q 'Sleep targets'
  /home/bruno/env/doctor.sh 2>&1 | grep -q 'Tailscale'
  /home/bruno/env/doctor.sh 2>&1 | grep -q 'Summary'
  ```
- **Delegation**: `category=deep`, `load_skills=[]`

---

### T13: Add new tracked configs
- **What**: Copy from `$HOME` into repo:
  - `cp ~/.config/dunst/dunstrc /home/bruno/env/.config/dunst/dunstrc`
  - `cp ~/.config/tmux/tmux.conf.local /home/bruno/env/.config/tmux/tmux.conf.local`
  - `cp ~/.config/opencode/opencode.json /home/bruno/env/.config/opencode/opencode.json`
  - `cp ~/.config/opencode/oh-my-openagent.json /home/bruno/env/.config/opencode/oh-my-openagent.json`
  - `cp ~/.config/systemd/user/elephant.service /home/bruno/env/.config/systemd/user/elephant.service && chmod -x ...` (remove executable bit)
  - `mkdir -p .config/git && cp ~/.config/git/ignore .config/git/ignore` (bonus)
- Scrub checks:
  - `grep -rEn '"token"|"secret"|"password"|sk-|ghp_|github_pat' .config/opencode/` must be clean
  - `! test -x .config/systemd/user/elephant.service`
- **Owner files**: 6 new tracked files
- **Depends On**: T1
- **QA**:
  ```bash
  test -f /home/bruno/env/.config/dunst/dunstrc
  test -f /home/bruno/env/.config/tmux/tmux.conf.local
  test -f /home/bruno/env/.config/opencode/opencode.json
  ! test -x /home/bruno/env/.config/systemd/user/elephant.service
  # Proper absence check: find + grep -q (find alone always returns 0)
  ! find /home/bruno/env/.config/opencode -name node_modules -print 2>/dev/null | grep -q .
  grep -rEn '"token"|"secret"|"password"|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]' /home/bruno/env/.config/opencode/ || echo clean
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T14: Add `home/.zshrc` + `home/.gitconfig`
- **What**:
  - `mkdir -p /home/bruno/env/home`
  - `cp /home/bruno/.zshrc /home/bruno/env/home/.zshrc`
  - `cp /home/bruno/.gitconfig /home/bruno/env/home/.gitconfig`
  - Scrub: `! grep -iE 'token|secret|password|api[_-]?key|sk-|ghp_' home/.zshrc home/.gitconfig`
- We do NOT clean up duplicate fnm blocks (out of scope per Q9 default)
- **Owner files**: `home/.zshrc`, `home/.gitconfig`
- **Depends On**: T1
- **QA**:
  ```bash
  test -f /home/bruno/env/home/.zshrc
  test -f /home/bruno/env/home/.gitconfig
  ! grep -iE 'token|secret|password|api[_-]?key|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]' /home/bruno/env/home/.zshrc /home/bruno/env/home/.gitconfig
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T15: Write `.config/hypr/hypridle.conf` + `hyprlock.conf`
- **What**:
  - `hypridle.conf`:
    ```
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }
    listener {
        timeout = 600
        on-timeout = loginctl lock-session
    }
    listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
    # NO suspend listener - system never sleeps (per server reliability requirements)
    ```
  - `hyprlock.conf`: minimal functional config — background color, single input field, show username, no external image dependencies
- **Owner files**: `.config/hypr/hypridle.conf`, `.config/hypr/hyprlock.conf`
- **Depends On**: T1
- **QA**:
  ```bash
  test -f /home/bruno/env/.config/hypr/hypridle.conf
  test -f /home/bruno/env/.config/hypr/hyprlock.conf
  ! grep -i 'systemctl suspend\|suspend-then-hibernate\|hibernate' /home/bruno/env/.config/hypr/hypridle.conf
  test $(grep -c 'listener' /home/bruno/env/.config/hypr/hypridle.conf) -eq 2
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T16: Patch `.config/hypr/hyprland.conf` — add `exec-once = hypridle`
- **What**: Add single line `exec-once = hypridle` after line 46 (`exec-once = systemctl --user start hyprpolkitagent`). Preserve all other content byte-identical.
- **Owner files**: `.config/hypr/hyprland.conf` (edit)
- **Depends On**: T15
- **QA**:
  ```bash
  test $(grep -c '^exec-once = hypridle$' /home/bruno/env/.config/hypr/hyprland.conf) -eq 1
  cd /home/bruno/env && git diff .config/hypr/hyprland.conf | grep -c '^+'  # ~2 (header + line)
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T17: Write `README.md`
- **What**: Sections:
  - **What**: "Arch Linux dotfiles + install scripts for an always-on server"
  - **Hardware context**: brief
  - **Quickstart**:
    ```bash
    git clone git@github.com:b4-io/arch.git ~/env
    cd ~/env
    ./install.sh
    ./link.sh
    ./doctor.sh
    ```
  - **Install groups**: `--only`, `--skip`, `--dry-run` examples
  - **Update**: `./update.sh` and `UPDATE_NODE=1 ./update.sh`
  - **Deploy configs**: `./link.sh`
  - **Health check**: `./doctor.sh`
  - **Layout**: tree of cmd/, .config/, home/
  - **Design decisions**: never sleep, hardware watchdog, Tailscale
  - **Warnings**: no-sleep.sh prints manual logind restart instructions; review `~/.config/**/*.bak.*` after link.sh
- **Owner files**: `README.md`
- **Depends On**: T3..T12
- **QA**:
  ```bash
  test -f /home/bruno/env/README.md
  grep -q 'install.sh' /home/bruno/env/README.md
  grep -q 'link.sh' /home/bruno/env/README.md
  grep -q 'doctor.sh' /home/bruno/env/README.md
  ```
- **Delegation**: `category=writing`, `load_skills=[]`

---

### T18: shellcheck + bash -n verification
- **What**: Run `bash -n` and `shellcheck` on every `.sh` file. Acceptable suppressions: `SC1090/SC1091` (not following source), `SC2034` if intentional.
- **Owner files**: read-only audit (may trigger fix PRs back into T3..T12)
- **Depends On**: T3..T17
- **QA**:
  ```bash
  cd /home/bruno/env
  find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 bash -n
  find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck -e SC1090,SC1091
  ```
- **Delegation**: `category=quick`, `load_skills=["ai-slop-remover"]`

---

### T19: `install.sh --dry-run` verification
- **What**: Verify orchestrator lists all scripts in correct numeric order.
- **Depends On**: T18
- **QA**:
  ```bash
  /home/bruno/env/install.sh --dry-run > /tmp/install_dryrun.log 2>&1
  test $? -eq 0
  grep -c '00-base/' /tmp/install_dryrun.log    # >=2
  grep -c '50-reliability/' /tmp/install_dryrun.log  # >=4
  awk '/00-base/{a=NR} /50-reliability/{b=NR} END{exit !(a<b)}' /tmp/install_dryrun.log
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T20: `link.sh --dry-run` verification
- **What**: Verify symlink deployer lists planned links matching expected set.
- **Depends On**: T18
- **QA**:
  ```bash
  /home/bruno/env/link.sh --dry-run > /tmp/link_dryrun.log 2>&1
  grep -q 'dunstrc' /tmp/link_dryrun.log
  grep -q 'tmux.conf.local' /tmp/link_dryrun.log
  grep -q 'hyprland.conf' /tmp/link_dryrun.log
  grep -q 'hypridle.conf' /tmp/link_dryrun.log
  grep -q '.zshrc' /tmp/link_dryrun.log
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T21: `doctor.sh` execution on current system
- **What**: Run on current box. Expected FAILs (current state pre-fix): sleep targets `static`, systemd-oomd inactive, fstrim.timer disabled, smartmontools missing, watchdog not configured. Expected WARN: tailscale version mismatch, boot history gaps.
- **Acceptance**: Script doesn't crash mid-run; tailscale version mismatch detected; boot gap detected
- **QA**:
  ```bash
  /home/bruno/env/doctor.sh 2>&1 | tee /tmp/doctor_out.log
  grep -E 'Sleep targets.*FAIL' /tmp/doctor_out.log
  grep -E 'Tailscale' /tmp/doctor_out.log
  grep -q 'Summary' /tmp/doctor_out.log
  ```
- **Delegation**: `category=quick`, `load_skills=[]`

---

### T22: Personal-data scan + git status review
- **What**:
  - Secrets grep (excluding `.git`, `.bak`, doc occurrences)
  - `git status` shows only expected paths
  - No `.bak` files
  - No `node_modules/` staged
- **Depends On**: T13, T14, T15, T16
- **QA**:
  ```bash
  cd /home/bruno/env
  grep -rEn "(token|secret|password|api[_-]?key)\s*[=:]\s*['\"][^'\"]+['\"]" \
    --include='*.sh' --include='*.conf' --include='*.json' --include='*.toml' --include='.gitconfig' --include='.zshrc' \
    . || echo "clean"
  grep -rEn 'sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{16,}' . || echo "clean"
  ! git ls-files | grep -q node_modules
  ! find . -path './.git' -prune -o -name '*.bak*' -print | grep -q .
  ```
- **Delegation**: `category=quick`, `load_skills=["git-master"]`

---

### T23: Commit plan execution (atomic, awaits user)
- **What**: After all verification passes AND user explicitly says "yes commit", apply 17 atomic commits per the sequence below. **Do not commit without approval.**
- **Atomic commit sequence**:
  ```
  C1  chore: add .gitignore                                            (T1)
  C2  refactor(cmd): reorganize scripts into numbered subdirs          (T2 — pure git mv)
  C3  feat(cmd/00-base): expand core.sh with base pkgs + shellcheck    (T3)
  C4  refactor(cmd/20-dev): split dev into languages.sh + tools.sh     (T4)
  C5  feat(cmd/10-wm): rename wm→hyprland; add aquamarine, hypridle    (T5)
  C6  feat(cmd/30-apps): consolidate editors + media; add opencode-desktop (T6)
  C7  feat(cmd/40-net): add tailscale.sh; rename time_network.sh       (T7)
  C8  feat(cmd/50-reliability): no-sleep, watchdog, fs-health, hyprlock-idle (T8)
  C9  feat: add install.sh orchestrator                                (T9)
  C10 feat: add update.sh                                              (T10)
  C11 feat: add link.sh symlink deployer                               (T11)
  C12 feat: add doctor.sh health check                                 (T12)
  C13 feat(config): track dunst, tmux, opencode, elephant, git/ignore  (T13)
  C14 feat(home): add .zshrc + .gitconfig                              (T14)
  C15 feat(config/hypr): add hypridle.conf + hyprlock.conf             (T15)
  C16 feat(config/hypr): autostart hypridle                            (T16)
  C17 docs: add README                                                 (T17)
  ```
- **⚠️ C2 is the critical one** — must be `git mv` only, zero content changes.
- **Depends On**: T18..T22 + user approval
- **Delegation**: `category=unspecified-high`, `load_skills=["git-master"]`

---

## Commit Strategy

Key principles:

1. **C1 first**: `.gitignore` before any config tracking prevents accidental leakage
2. **C2 isolated**: Pure `git mv` with 100% rename detection — no content drift
3. **C3–C8**: Each cmd/ subdir gets its own commit so bisecting is easy
4. **C9–C12**: Top-level scripts, one per commit
5. **C13–C16**: Config tracking split by domain
6. **C17 last**: README depends on knowing the final state

**DO NOT commit anything** until the user explicitly approves after Wave 4 verification.

---

## Success Criteria

1. `git status` shows 0 unstaged changes (all deliverables committed OR staged awaiting approval)
2. `./install.sh --dry-run` succeeds, lists all 6 subdir groups in order
3. `./link.sh --dry-run` succeeds, lists planned symlinks with backup behavior
4. `./doctor.sh` runs end-to-end without crashing
5. All `.sh` files pass `bash -n` + `shellcheck` (with documented exceptions only)
6. No secrets/tokens found in any tracked file (grep scan clean)
7. Git history preserved for all renamed cmd/ scripts (`git log --follow` works)
8. Zero files deleted that weren't intended
9. README documents the quickstart flow
10. User can proceed with execution after answering clarifying questions
