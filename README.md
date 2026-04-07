# env

Arch Linux dotfiles + install scripts for an always-on personal server.

## What

This is the setup configuration for a specific Arch Linux box used as a development machine and a "kind of server" that's meant to stay reachable and reliable at all times.

It contains:

- **`cmd/`** - Install scripts organized into numbered subdirectories, each representing a phase
- **`.config/`** - Configs deployed via symlink to `~/.config/`
- **`home/`** - Shell dotfiles (`.zshrc`, `.gitconfig`) deployed to `$HOME`
- **`.cargo/`** - Cargo config
- **Top-level scripts** - `install.sh`, `update.sh`, `link.sh`, `doctor.sh`

## Hardware context

- **CPU**: AMD Ryzen 7 1700X (Zen 1, 8C/16T)
- **GPU**: AMD Radeon RX Vega 56/64
- **RAM**: 16GB
- **Root FS**: ext4
- **Hostname**: dezio
- **OS**: Arch Linux, kernel 6.18+
- **DE**: Hyprland (Wayland) via uwsm

Some decisions in this repo (e.g. `amd-ucode`, `linux-firmware-amdgpu`, specific kernel workarounds in `doctor.sh`) are tied to this hardware.

## Quickstart

Assumes Arch Linux is already installed and you have a regular user with sudo access.

```bash
git clone git@github.com:b4-io/arch.git ~/env
cd ~/env

# Phase 1: Install packages and tools
./install.sh

# Phase 2: Deploy configs via symlinks
./link.sh

# Phase 3: Verify system health
./doctor.sh
```

## `install.sh` - Orchestrator

Runs every `cmd/*/*.sh` script in lexicographic (numbered) order. Each subdirectory is a phase:

```
cmd/
├── 00-base/           pacman + base packages + yay bootstrap + zsh
├── 10-wm/             Hyprland + waybar + dunst + ghostty + elephant
├── 20-dev/            Go, Rust, Node (fnm), Bun, uv, JDK, Postgres, Docker, tmux
├── 30-apps/           Chrome, editors (zed/vscode/datagrip/kiro/gh-desktop), AI, media
├── 40-net/            Time sync + Tailscale
└── 50-reliability/    Sleep disabling, watchdog, fs health, hyprlock idle
```

### Usage

```bash
./install.sh                           # Run everything
./install.sh --dry-run                 # Preview what would run
./install.sh --only 50-reliability     # Run only the reliability phase
./install.sh --only '(00|10)'          # Run base + wm phases (regex)
./install.sh --skip 30-apps            # Run everything except apps
./install.sh --continue-on-error       # Don't halt on first failure
./install.sh --help                    # Show usage
```

`install.sh` refuses to run as root - the individual scripts use `sudo` internally where needed.

## `update.sh` - Updater

Updates all installed package managers, language toolchains, and dev tools. Each section is guarded by `command -v` so missing tools are skipped gracefully.

```bash
./update.sh                # Update everything (except Node LTS - see below)
./update.sh --dry-run      # Preview
UPDATE_NODE=1 ./update.sh  # Also bump Node to latest LTS via fnm
```

Sections: `pacman`, `yay`, `rustup`, `fnm-node` (gated), `bun`, `uv`, `cargo-tools`, `go-tools`, `opencode`, `oh-my-zsh`, `tailscaled` (restart after pkg upgrade to fix client/daemon version mismatches).

The `UPDATE_NODE=1` gate exists because bumping Node LTS can break projects pinned to an older version.

## `link.sh` - Config deployer

Pure-bash symlink deployer. Walks `.config/`, `home/`, and `.cargo/` in the repo and creates corresponding symlinks in `$HOME`.

```bash
./link.sh                    # Deploy everything
./link.sh --dry-run          # Preview
./link.sh .config/hypr       # Only deploy hypr configs
./link.sh --help             # Usage
```

### Conflict handling

- **Target is correct symlink** → skip (`OK`)
- **Target is wrong symlink** → replace
- **Target is regular file** → back up to `<path>.bak.<timestamp>`, then link
- **Target is non-symlink directory** → fail (refuses to clobber)

After running, look for `~/.config/**/*.bak.*` files to review backups.

## `doctor.sh` - Health check

Read-only system health report with 16 checks:

| Check | What it verifies |
|---|---|
| `sleep-targets` | sleep/suspend/hibernate targets are `masked` |
| `kernel-errors` | No kernel errors in last 24h |
| `suspend-resume` | No freeze/hang messages in last 7 days |
| `amdgpu` | No GPU driver errors this boot |
| `memory`, `swap` | RAM + swap usage |
| `smart-*` | S.M.A.R.T. health per disk |
| `nvme-*` | NVMe `critical_warning` status |
| `cpu-temp` | Temperature readings |
| `oomd` | `systemd-oomd` is active |
| `watchdog-*` | Hardware watchdog is configured + device present |
| `cmdline-*` | Zen 1 kernel params (`idle=nomwait`, `processor.max_cstate`) advisory |
| `btrfs` | Scrub status (skipped if root isn't btrfs) |
| `failed-services` | `systemctl --failed` is empty |
| `fstrim` | `fstrim.timer` enabled |
| `tailscale-*` | Connection + client/daemon version match |
| `boot-gaps` | Detects >7-day gaps in boot history (reliability signal) |

Exit code: `0` if all checks pass or only WARN, `1` if any FAIL.

```bash
./doctor.sh            # Run all checks
./doctor.sh || true    # For cron (don't fail the cron job)
```

## Design decisions

### Never sleep, never crash on wake

This box is intended to be always reachable. Sleep and suspend are **masked** at the systemd level (`cmd/50-reliability/no-sleep.sh`). `hypridle` handles user-level screen blanking (DPMS off after 15min) but never triggers a system suspend. There is no wake path, so there is no wake-crash.

### Hardware watchdog

`cmd/50-reliability/watchdog.sh` configures `RuntimeWatchdogSec=30s`. If the kernel hangs for more than 30 seconds, the hardware watchdog (`/dev/watchdog`, `sp5100_tco`) force-reboots the box. This addresses the "31-day gap between boots" symptom observed in `journalctl --list-boots`.

### Symlinked configs, not copies

`link.sh` is pure bash and uses symlinks exclusively. Editing a file in the deployed target is the same as editing the tracked file in the repo. No `stow` dependency.

### Idempotent everything

Every cmd script uses `pacman -S --needed`, `command -v` guards for curl-based installers, and `grep -Fq` guards for shell profile modifications. Re-running `install.sh` should be safe and a no-op for already-installed items.

### Tailscale without NetworkManager

This box uses `systemd-networkd` + `systemd-resolved`, not NetworkManager. Tailscale works with both but the common NetworkManager fix (`/etc/NetworkManager/conf.d/99-tailscale.conf`) is not needed here.

## Warnings

### `cmd/50-reliability/no-sleep.sh` prints a manual step

After the script applies the sleep.conf.d and logind.conf.d changes, it prints:

```
sudo systemctl restart systemd-logind
```

as an instruction. **It does not run this command automatically** because restarting `systemd-logind` ends the current login session. Run it yourself from a console or after saving work, or simply reboot.

### `link.sh` may back up existing files

If you have existing configs at `~/.config/...` that conflict with the tracked ones, `link.sh` will back them up with a `.bak.<timestamp>` suffix and symlink the repo version. Review the backups (search: `find ~/.config -name '*.bak.*'`) and delete them once you've verified nothing important was clobbered.

### Tailscale already installed on this box

This repo includes `cmd/40-net/tailscale.sh` but Tailscale is already running on the target box. The script is **idempotent**: it detects a running tailscaled and skips the `tailscale up` step. Safe to run anyway for reproducibility.

### Your `~/.zshrc` and `~/.gitconfig` become symlinks

After running `link.sh`, `~/.zshrc` and `~/.gitconfig` will be symlinks into `~/env/home/`. Edit them via the repo path if you want the changes tracked in git.

## Repository layout

```
env/
├── install.sh              # Orchestrator
├── update.sh               # Updater
├── link.sh                 # Symlink deployer
├── doctor.sh               # Health check
├── README.md               # This file
├── .gitignore              # Conservative: no secrets, no node_modules
├── cmd/
│   ├── 00-base/
│   │   ├── core.sh
│   │   ├── services.sh
│   │   └── zsh.sh
│   ├── 10-wm/
│   │   ├── hyprland.sh
│   │   ├── screenshot.sh
│   │   └── services.sh
│   ├── 20-dev/
│   │   ├── docker.sh
│   │   ├── languages.sh
│   │   └── tools.sh
│   ├── 30-apps/
│   │   ├── ai.sh
│   │   ├── browser.sh
│   │   ├── editors.sh
│   │   └── media.sh
│   ├── 40-net/
│   │   ├── tailscale.sh
│   │   └── time-network.sh
│   └── 50-reliability/
│       ├── fs-health.sh
│       ├── hyprlock-idle.sh
│       ├── no-sleep.sh
│       └── watchdog.sh
├── .config/
│   ├── dunst/
│   ├── ghostty/
│   ├── git/
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── hypr/
│   │   ├── hypridle.conf
│   │   ├── hyprland.conf
│   │   ├── hyprlock.conf
│   │   ├── hyprpaper.conf
│   │   └── wallpapers/
│   ├── opencode/
│   ├── systemd/user/
│   ├── tmux/
│   ├── waybar/
│   └── zed/
├── home/
│   ├── .gitconfig
│   └── .zshrc
└── .cargo/
    └── config.toml
```

## License

Personal configuration - use at your own risk.
