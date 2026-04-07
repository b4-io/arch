#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing language toolchains..."

# Go
sudo pacman -S --needed --noconfirm go

# Rust (via rustup, with command -v guard for idempotency)
if ! command -v rustup &>/dev/null; then
    echo "📦 Installing rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
else
    echo "✅ rustup already installed"
fi

# Append rust env to shell profiles (idempotent via grep -Fq)
# shellcheck disable=SC2016  # literal $HOME is intentional for deferred eval in profile
START_BLOCK='. "$HOME/.cargo/env"'
PROFILE_FILES=("$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.profile")
for PROFILE in "${PROFILE_FILES[@]}"; do
    if [ ! -f "$PROFILE" ]; then
        echo "⚠️  Skipping $PROFILE (does not exist)"
        continue
    fi
    # shellcheck disable=SC2016  # literal $HOME is intentional for deferred eval
    if grep -Fq '. "$HOME/.cargo/env"' "$PROFILE"; then
        echo "ℹ️  Cargo env block already present in $PROFILE"
    else
        echo -e "\n$START_BLOCK" >> "$PROFILE"
        echo "✅ Appended cargo env block to $PROFILE"
    fi
done

# mold linker (faster rust linking)
echo "📦 Installing mold..."
yay -S --needed --noconfirm mold

# Cargo tools (command -v guards for idempotency)
if command -v cargo &>/dev/null; then
    if ! command -v cargo-watch &>/dev/null; then
        echo "📦 Installing cargo-watch..."
        cargo install cargo-watch
    else
        echo "✅ cargo-watch already installed"
    fi
    if ! command -v wasm-pack &>/dev/null; then
        echo "📦 Installing wasm-pack..."
        curl https://drager.github.io/wasm-pack/installer/init.sh -sSf | sh
    else
        echo "✅ wasm-pack already installed"
    fi
fi

# fnm (Node version manager)
if ! command -v fnm &>/dev/null; then
    echo "📦 Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
else
    echo "✅ fnm already installed"
fi

# bun (JS runtime)
if ! command -v bun &>/dev/null; then
    echo "📦 Installing bun..."
    curl -fsSL https://bun.sh/install | bash
else
    echo "✅ bun already installed"
fi

# uv (Python package manager)
if ! command -v uv &>/dev/null; then
    echo "📦 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "✅ uv already installed"
fi

# JDK + jenv
echo "📦 Installing jdk-openjdk..."
sudo pacman -S --needed --noconfirm jdk-openjdk
echo "📦 Installing jenv (AUR)..."
yay -S --needed --noconfirm jenv

echo "✅ Languages setup complete"
