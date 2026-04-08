# AGENTS.md

Personal Arch Linux dotfiles + install scripts for one box (`dezio`, AMD Ryzen 7
1700X / Vega 56-64 / ext4 root). `README.md` documents what each top-level
script does and the `cmd/*/` phase layout - read it first. This file documents
what `README.md` does **not**.

## Orientation

- Four top-level scripts (`install.sh`, `link.sh`, `update.sh`, `doctor.sh`)
  own all global flow. They do **not** source each other and do **not** share
  helpers.
- Phase scripts under `cmd/<NN-phase>/*.sh` are discovered by `install.sh` via
  `find -mindepth 2 -maxdepth 2 -type f -name '*.sh' | sort`. The numeric
  prefix drives ordering across phases; filename sort drives ordering within a
  phase.
- Every `cmd/*/*.sh` is **self-contained**: no `source`, no shared library, no
  helper sourcing. Add new phase scripts the same way.
- `.sisyphus/plans/dotfiles-refactor.md` is the original design rationale (831
  lines, 2026-04-07): risk register, task graph, "why is X structured this
  way?" Treat as read-only history; supersede with a new plan, do not edit in
  place.
- `README.md`'s "Repository layout" tree drifts occasionally (e.g. `services.sh`
  is now under `cmd/10-wm/`, not `cmd/00-base/`). Trust the filesystem.

## Bash conventions

- **`set` flags vary on purpose**:
  - `install.sh`, `link.sh`, most `cmd/*/*.sh` → `set -euo pipefail`.
  - `update.sh` and `doctor.sh` → `set -uo pipefail` (**no `-e`**) because they
    intentionally walk past per-section failures and aggregate results. Do
    **not** "fix" them by adding `-e`; `update.sh:18` has a comment to that
    effect.
  - `cmd/00-base/zsh.sh` uses bare `set -e`; `cmd/30-apps/browser.sh` has none.
    Trivial scripts may stay minimal; new non-trivial scripts default to
    `set -euo pipefail`.

- **Idempotency is mandatory** - re-running `install.sh` end-to-end must be a
  no-op for already-installed items. Established guards:
  - Pacman: `sudo pacman -S --needed --noconfirm <pkg>` and/or
    `pacman -Qi "$pkg" &>/dev/null` loop.
  - `curl | sh` installers: `command -v <tool> &>/dev/null` guard
    (`cmd/20-dev/languages.sh:10` is the canonical example).
  - File appends: `grep -Fq '<marker>' "$file"` before `>>` (`cmd/10-wm/hyprland.sh:48`).
  - Service restart: `systemctl is-active --quiet <unit>` first
    (`update.sh:117`, `doctor.sh:155`, `doctor.sh:243`).
  - Tailscale state: `tailscale status --peers=false --json | grep -q '"BackendState": "Running"'`
    short-circuits re-running `tailscale up` (`cmd/40-net/tailscale.sh:25`).

- **Privileged config writes use single-quoted heredocs**:
  `sudo tee /etc/<path> >/dev/null <<'EOF' ... EOF`. The single quotes are
  intentional - the file content is literal, no shell expansion. Pattern lives
  in `cmd/40-net/tailscale.sh`, `cmd/50-reliability/watchdog.sh`,
  `cmd/50-reliability/no-sleep.sh`.

- **Service activation** prefers combined `sudo systemctl enable --now <unit>`
  over separate `enable` + `start`.

- **`install.sh` refuses to run as root** (`EUID -eq 0` check, `install.sh:78`).
  Privileges happen inside individual `cmd/*/*.sh` via `sudo`. Never add `sudo`
  to `install.sh` itself.

- **Logging helpers are scoped to each top-level script**, not shared:
  - `doctor.sh` defines `ok / warn / fail / hint / section` (lines 22-27) and
    tracks `PASS/WARN/FAIL/HINT`. Reuse these names if you add a new check.
  - `link.sh` defines `log_action` (line 81) and counts
    `LINKED/SKIPPED/BACKED_UP/FAILED`.
  - `update.sh` uses a `run_section <name> <fn>` dispatcher (line 29) and an
    associative `RESULTS` array. The `# shellcheck disable=SC2317,SC2329` at
    the top is intentional - functions dispatched via `"$@"` look like dead
    code to shellcheck.
  - `install.sh` counts `SUCCEEDED/FAILED/SKIPPED` and emits
    `[install] <rel> -> START/OK/FAIL`.
  - `cmd/*/*.sh` use plain `echo "📦 ..."` / `echo "✅ ..."`. Do not
    introduce a shared helper file.

- **Argument parsing** is `case "$1" in ... esac` with `shift` / `shift 2`,
  exit code `2` for unknown or missing args
  (`install.sh:39-75`, `link.sh:38-61`). `usage()` in both top-level scripts
  re-emits the comment header via
  `sed -n '2,N p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'`. **If you add a
  flag, update the comment header - the help text is generated from it.**

- **Discovery / array idioms** worth copying:
  - `mapfile -t ARR < <(find ... | sort)`.
  - `find ... -print0 | while IFS= read -r -d '' file` for safe filenames.
  - `${path#"$BASE"/}` and `${rel%%/*}` for path slicing. No `sed`/`awk` for
    this.
  - `declare -A` for status maps (`update.sh:27`).
  - `${SUDO_USER:-$USER}` when passing user identity into a `sudo` command
    (`cmd/40-net/tailscale.sh`).

## Verification before commit

`shellcheck` is installed by `cmd/00-base/core.sh` and IS the linter. There is
no test framework, no `.github/` workflow, no pre-commit hook. The full
verification surface is:

```bash
shellcheck install.sh link.sh update.sh doctor.sh cmd/*/*.sh
bash -n     install.sh link.sh update.sh doctor.sh cmd/*/*.sh
./install.sh --dry-run
./link.sh   --dry-run
./doctor.sh                 # read-only, safe to run any time
```

`doctor.sh` exits **0 on WARN**, **1 only on FAIL** - by design, so it can be
cron'd. Don't promote WARN to FAIL casually.

## What is intentionally NOT tracked

Per `.sisyphus/plans/dotfiles-refactor.md`, the following are deliberately
excluded - do not "helpfully" start tracking them:

- `~/.config/gh/` - contains auth tokens. **Never** track.
- `~/.config/opencode/` - track **only** `opencode.json` and
  `oh-my-openagent.json`. `.gitignore` blocks `bun.lock`, `package.json`,
  `package-lock.json`, `node_modules/`, `playwright/storage-state.json`, and
  the upstream-generated `.gitignore`. Adding any of these to git is wrong.
- `~/.config/htop/`, `~/.config/nemo/`, `~/.config/uv/`, `~/.config/go/`,
  `~/.config/colima/` - empty / state-only / receipt-only directories.
- `~/.bash_profile` - has known duplicate `uwsm`/`cargo` blocks, intentionally
  out of scope. Don't touch.
- `*.bak.*` - created by `link.sh` on conflict.

Add new exclusions to `.gitignore`, not via `git update-index --skip-worktree`.

## Hardware / host assumptions baked in

This repo is shaped for one specific machine. Several files do not "just work"
elsewhere:

- **AMD-only packages** in `cmd/00-base/core.sh:7` (`amd-ucode`,
  `linux-firmware-amdgpu`, `linux-firmware-radeon`, ...). Edit before running
  on Intel/NVIDIA.
- **Zen 1 kernel cmdline** (`idle=nomwait processor.max_cstate=5`) is already
  set in `/proc/cmdline` on this box. `doctor.sh` **only verifies** it; it
  does **not** touch GRUB.
- **Hardware watchdog** (`/dev/watchdog`, `sp5100_tco`) is AMD-family-15h-plus
  specific. `watchdog.sh` config takes effect only after **reboot** - not
  after `systemctl daemon-reload`.
- **`hyprpaper.conf` pins `monitor = HDMI-A-2`** - other monitors get no
  wallpaper. The generic `monitor=,preferred,auto,auto` in `hyprland.conf` is
  the deliberate fallback.
- **`waybar/config.jsonc` clock pinned to `America/Montevideo`** - not
  auto-detected from system timezone.
- **`wireplumber/wireplumber.conf.d/51-analog-priority.conf`** routes audio by
  PCI IDs `0000:0e:00.3` (Realtek analog) and `0000:0c:00.1` (Vega HDMI).
  Different hardware = no effect.
- **Tailscale runs over `systemd-networkd` + `systemd-resolved`**, not
  NetworkManager. The common NM fix at
  `/etc/NetworkManager/conf.d/99-tailscale.conf` does **not** apply. Don't
  add it.

## Wiring gotchas

- **Editing under `~/.config/...` edits the repo.** `link.sh` symlinks; there
  is no copy step. Always `git status` after touching the deployed system.
- **`link.sh` backups**: a regular file at the target gets moved to
  `<path>.bak.$(date +%s)` before linking. After `link.sh`, run
  `find ~/.config -name '*.bak.*'` and clean up.
- **Calendar popup app-id is hardcoded across 6 places.**
  `.config/hypr/scripts/calendar-popup.py` sets
  `application_id="uy.bruno.calendar"`, and `.config/hypr/hyprland.conf` has
  five windowrules matching `^uy\.bruno\.calendar$`. Renaming the app-id
  without updating all six spots breaks the popup's float / size / position.
- **`cmd/50-reliability/no-sleep.sh` prints a manual step it deliberately does
  not run** (`sudo systemctl restart systemd-logind`) because that command
  kills the active SSH session. Leave the print-only behavior in place;
  reboot is the safe path.
- **`update.sh` restarts `tailscaled` after package upgrade** - this fixes a
  real client/daemon version mismatch this box hits. Don't remove the section.
- **Node LTS bumps are opt-in**: `update.sh` runs `fnm install --lts` only
  when `UPDATE_NODE=1` is set, to avoid breaking projects pinned to older LTS.
- **`home/.zshrc` initializes `fnm` three times** (lines 23-28, 40-45, 47-52)
  and sources `~/.local/bin/env` via the cryptic
  `. "$HOME/.local/share/../bin/env"`. Known accumulated wart. Cleanup is
  welcome but verify the resulting shell still has `fnm`, `bun`, `brew`,
  `jenv`, and the opencode PATH entry.
- **`.config/opencode/opencode.json` may have uncommitted local changes**
  rewriting the plugin entries from `<pkg>@latest` to
  `./node_modules/<pkg>`. This is in-flight experimentation - check
  `git diff .config/opencode/opencode.json` before overwriting.
- **No `services.sh` exists in `cmd/00-base/`** despite the README's repo
  layout tree implying it. The elephant.service unit is enabled by
  `cmd/10-wm/services.sh` instead.

## Commit conventions

`git log` uses Conventional Commits with scoped subjects:

```
fix(doctor): handle set -e trap on systemctl is-enabled
feat(config/zed): add AI agent settings and Catppuccin Mocha theme
feat(cmd): install pavucontrol and trayscale for desktop
```

Format: `<type>(<scope>): <imperative subject>`. Scopes seen: `cmd`, `doctor`,
`config/<subdir>`. Match this style when committing.
