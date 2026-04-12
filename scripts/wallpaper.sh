#!/usr/bin/env bash
# wallpaper.sh — Set wallpaper and regenerate color theme via matugen
#
# Usage:
#   ./wallpaper.sh /path/to/image.jpg   — set a specific image
#   ./wallpaper.sh                      — open a file picker (requires zenity)
#
# Hyprland bind: bind = SUPER, W, exec, ~/dev/shell/scripts/wallpaper.sh
#
# What this does:
#   1. Lets you pick or specify a wallpaper image
#   2. Sets it with swww (animated transition)
#   3. Runs matugen to generate Material You colors from the image
#   4. Writes ~/.config/shell/colors.json
#   5. shell.qml's FileView detects the change and recolors everything live

set -euo pipefail

COLORS_DIR="$HOME/.config/shell"
COLORS_FILE="$COLORS_DIR/colors.json"

# ── Step 1: Determine wallpaper path ─────────────────────────────────────────
if [ -n "${1:-}" ]; then
    IMAGE="$1"
else
    # Open a GUI file picker
    if command -v zenity &>/dev/null; then
        IMAGE=$(zenity \
            --file-selection \
            --title="Select Wallpaper" \
            --file-filter="Images | *.jpg *.jpeg *.png *.webp *.bmp *.tiff" \
            2>/dev/null) || { echo "No image selected."; exit 0; }
    else
        echo "Error: no image path given and zenity is not installed."
        echo "Usage: $0 /path/to/image.jpg"
        exit 1
    fi
fi

if [ ! -f "$IMAGE" ]; then
    echo "Error: file not found: $IMAGE"
    exit 1
fi

echo "Setting wallpaper: $IMAGE"

# ── Step 2: Set the wallpaper ─────────────────────────────────────────────────
if command -v swww &>/dev/null; then
    # Initialize swww daemon if not running
    swww init 2>/dev/null || true
    swww img "$IMAGE" \
        --transition-type  grow \
        --transition-pos   center \
        --transition-duration 1.2 \
        --transition-fps   60 \
    && echo "Wallpaper set via swww."
elif command -v hyprpaper &>/dev/null; then
    hyprctl hyprpaper wallpaper ",$IMAGE" 2>/dev/null \
    && echo "Wallpaper set via hyprpaper."
elif command -v swaybg &>/dev/null; then
    pkill swaybg 2>/dev/null || true
    swaybg -i "$IMAGE" &
    echo "Wallpaper set via swaybg."
else
    echo "Warning: no wallpaper setter found."
    echo "Install swww (recommended):  sudo dnf install swww  or  yay -S swww"
fi

# ── Step 3: Generate colors with matugen ─────────────────────────────────────
mkdir -p "$COLORS_DIR"

if command -v matugen &>/dev/null; then
    matugen image "$IMAGE" --json hex > "$COLORS_FILE"
    echo "Colors written to $COLORS_FILE"
    echo "The shell will reload its theme automatically."
else
    echo ""
    echo "matugen not found — colors will not be updated."
    echo "Install it with:  cargo install matugen"
    echo "(requires Rust: sudo dnf install rust cargo)"
fi
