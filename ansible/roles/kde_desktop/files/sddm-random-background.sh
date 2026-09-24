#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="/usr/share/wallpapers/sddm"
THEMES=(
    "/usr/share/sddm/themes/WhiteSur-dark"
    "/usr/share/sddm/themes/WhiteSur-light"
)

if [ ! -d "$WALLPAPER_DIR" ]; then
    exit 0
fi

# Find all valid image files
mapfile -t ALL_IMAGES < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

TOTAL=${#ALL_IMAGES[@]}
if [ "$TOTAL" -eq 0 ]; then
    exit 0
elif [ "$TOTAL" -eq 1 ]; then
    SELECTED="${ALL_IMAGES[0]}"
else
    # Determine the currently linked image if any
    CURRENT=""
    if [ -L "${THEMES[0]}/background.jpeg" ]; then
        CURRENT=$(readlink -f "${THEMES[0]}/background.jpeg" || true)
    fi

    # Filter out current image to avoid picking the same one consecutively
    CANDIDATES=()
    for img in "${ALL_IMAGES[@]}"; do
        if [ "$img" != "$CURRENT" ]; then
            CANDIDATES+=("$img")
        fi
    done

    # If all were somehow filtered out, fall back to ALL_IMAGES
    if [ ${#CANDIDATES[@]} -eq 0 ]; then
        CANDIDATES=("${ALL_IMAGES[@]}")
    fi

    # Pick a random candidate
    SELECTED=$(printf "%s\n" "${CANDIDATES[@]}" | shuf -n 1)
fi

if [ -n "$SELECTED" ] && [ -f "$SELECTED" ]; then
    for theme_dir in "${THEMES[@]}"; do
        if [ -d "$theme_dir" ]; then
            ln -sf "$SELECTED" "$theme_dir/background.jpeg"
        fi
    done
fi
