#!/usr/bin/env bash

sudo pacman -S --needed --noconfirm vulkan-icd-loader vulkan-tools
sudo pacman -S --needed --noconfirm vulkan-radeon
curl -f https://zed.dev/install.sh | sh
