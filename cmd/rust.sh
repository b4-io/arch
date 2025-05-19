#!/usr/bin/env bash

echo "📦 Installing rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Block to append
START_BLOCK='. "$HOME/.cargo/env"'

# Shell profiles to target
PROFILE_FILES=("$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.profile")

echo "📝 Updating shell profiles..."

for PROFILE in "${PROFILE_FILES[@]}"; do
    if [ ! -f "$PROFILE" ]; then
        echo "⚠️  Skipping $PROFILE (does not exist)"
        continue
    fi

    if grep -Fq '. "$HOME/.cargo/env"' "$PROFILE"; then
        echo "ℹ️  Block already present in $PROFILE"
    else
        echo -e "\n$START_BLOCK" >> "$PROFILE"
        source "$PROFILE"
        echo "✅ Appended block to $PROFILE"
    fi
done

echo "📦 Installing mold"
yay -S --needed --noconfirm mold

echo "📦 Installing cargo-watch"
cargo install cargo-watch
