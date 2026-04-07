#!/usr/bin/env bash
#
# link.sh - Symlink-based dotfiles deployer
#
# Walks the repo's tracked config trees and creates symlinks in $HOME.
# Idempotent: safe to re-run. Handles conflicts by backing up with timestamp.
#
# Trees deployed:
#   <repo>/.config/...   → $HOME/.config/...
#   <repo>/home/.foo     → $HOME/.foo
#   <repo>/.cargo/...    → $HOME/.cargo/...
#
# Conflict handling:
#   - Target is correct symlink     → SKIP (log OK)
#   - Target is wrong symlink       → REPLACE
#   - Target is regular file        → BACKUP to .bak.<epoch>, then link
#   - Target is non-symlink dir     → FAIL (refuse to clobber)
#
# Usage:
#   ./link.sh                 Deploy all trees
#   ./link.sh --dry-run       Preview, don't touch filesystem
#   ./link.sh .config/hypr    Deploy only under that prefix
#   ./link.sh --help          Show help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR

# --- Args ---
DRY_RUN=0
PREFIX=""

usage() {
    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown flag: $1" >&2
            exit 2
            ;;
        *)
            if [[ -n "$PREFIX" ]]; then
                echo "Error: multiple prefixes not supported: $PREFIX, $1" >&2
                exit 2
            fi
            PREFIX="$1"
            shift
            ;;
    esac
done

# --- Sanity checks ---
if [[ -z "${HOME:-}" ]]; then
    echo "Error: \$HOME is not set" >&2
    exit 1
fi

if [[ ! -d "$REPO_DIR" ]]; then
    echo "Error: repo dir not found: $REPO_DIR" >&2
    exit 1
fi

# --- Counters ---
LINKED=0
SKIPPED=0
BACKED_UP=0
FAILED=0

# --- Logging helpers ---
log_action() {
    local action="$1"
    local target="$2"
    local source="${3:-}"
    if [[ $DRY_RUN -eq 1 ]]; then
        printf "[DRY] %-10s %s%s\n" "$action" "$target" "${source:+ → $source}"
    else
        printf "      %-10s %s%s\n" "$action" "$target" "${source:+ → $source}"
    fi
}

# --- Core linking logic ---
# Args: <absolute source file> <absolute target path>
link_file() {
    local src="$1"
    local tgt="$2"

    # If a filter prefix was given, skip non-matching files.
    # The prefix is matched against the repo-relative path.
    if [[ -n "$PREFIX" ]]; then
        local rel="${src#"$REPO_DIR"/}"
        if [[ "$rel" != "$PREFIX"* ]]; then
            return 0
        fi
    fi

    # Ensure parent directory exists in target
    local tgt_parent
    tgt_parent="$(dirname "$tgt")"
    if [[ ! -d "$tgt_parent" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_action "MKDIR" "$tgt_parent"
        else
            mkdir -p "$tgt_parent"
        fi
    fi

    # Decide what to do based on target state
    if [[ -L "$tgt" ]]; then
        # It's a symlink - check if it already points to us
        local current
        current="$(readlink "$tgt")"
        if [[ "$current" == "$src" ]]; then
            log_action "OK" "$tgt"
            SKIPPED=$((SKIPPED + 1))
            return 0
        else
            log_action "REPLACE" "$tgt" "$src"
            if [[ $DRY_RUN -eq 0 ]]; then
                rm "$tgt"
                ln -s "$src" "$tgt"
            fi
            LINKED=$((LINKED + 1))
            return 0
        fi
    elif [[ -d "$tgt" ]]; then
        # Real directory in target where we want a file link - refuse
        log_action "FAIL-DIR" "$tgt"
        echo "Error: $tgt is a directory, refusing to clobber" >&2
        FAILED=$((FAILED + 1))
        return 1
    elif [[ -e "$tgt" ]]; then
        # Regular file - back up
        local backup
        backup="${tgt}.bak.$(date +%s)"
        log_action "BACKUP" "$tgt" "$backup"
        if [[ $DRY_RUN -eq 0 ]]; then
            mv "$tgt" "$backup"
            ln -s "$src" "$tgt"
        fi
        BACKED_UP=$((BACKED_UP + 1))
        LINKED=$((LINKED + 1))
        return 0
    else
        # Nothing there - just link
        log_action "LINK" "$tgt" "$src"
        if [[ $DRY_RUN -eq 0 ]]; then
            ln -s "$src" "$tgt"
        fi
        LINKED=$((LINKED + 1))
        return 0
    fi
}

# --- Walk a tree ---
# Args: <tree source dir> <tree target dir base>
walk_tree() {
    local src_base="$1"
    local tgt_base="$2"

    if [[ ! -d "$src_base" ]]; then
        return 0
    fi

    # Use find to enumerate regular files (not directories, not symlinks in repo)
    while IFS= read -r -d '' file; do
        local rel="${file#"$src_base"/}"
        local tgt="$tgt_base/$rel"
        link_file "$file" "$tgt" || true
    done < <(find "$src_base" -type f -print0)
}

# --- Main ---

echo "╔══════════════════════════════════════════════╗"
echo "║  link.sh - Dotfiles symlink deployer         ║"
if [[ $DRY_RUN -eq 1 ]]; then
    echo "║  MODE: DRY RUN (no filesystem changes)       ║"
fi
if [[ -n "$PREFIX" ]]; then
    echo "║  Filter: $PREFIX"
fi
echo "╚══════════════════════════════════════════════╝"
echo ""

# Tree 1: .config → ~/.config
walk_tree "$REPO_DIR/.config" "$HOME/.config"

# Tree 2: home/ → $HOME (strips home/ prefix)
walk_tree "$REPO_DIR/home" "$HOME"

# Tree 3: .cargo → ~/.cargo
walk_tree "$REPO_DIR/.cargo" "$HOME/.cargo"

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  Linked:    $LINKED"
echo "  Skipped:   $SKIPPED  (already correct)"
echo "  Backed up: $BACKED_UP"
echo "  Failed:    $FAILED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "❌ link.sh completed with errors"
    exit 1
fi

if [[ $BACKED_UP -gt 0 ]]; then
    echo "ℹ️  Review backups in their original locations (*.bak.<timestamp>)"
fi

echo "✅ link.sh complete"
