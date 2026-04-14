#!/usr/bin/env bash
# install.sh — Deploy the Quickshell/Hyprland dotfiles to your home directory.

set -euo pipefail

# ── Colors for output ────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Starting installation of Quickshell/Hyprland dotfiles...${NC}"

# ── Ensure we are in the right directory ─────────────────────────────────────
if [ ! -d ".config" ] || [ ! -d ".local" ]; then
    echo -e "${RED}Error: Could not find .config or .local directories.${NC}"
    echo "Make sure you are running this script from the root of the 'shell' project."
    exit 1
fi

# ── List of directories to copy ──────────────────────────────────────────────
# We use an array for modularity
DIRS=(".config" ".local")

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${BLUE}Deploying $dir to $HOME/$dir...${NC}"
        
        # Create parent directories if they don't exist
        mkdir -p "$HOME/$(dirname "$dir")"
        
        # Copy with -r (recursive) and -v (verbose)
        # Use -n to avoid overwriting or just overwrite if that's the goal.
        # Production scripts usually avoid 'cp -n' to ensure the latest config is applied.
        cp -rv "$dir/." "$HOME/$dir/"
    fi
done

echo -en "${YELLOW}Would you like to reload Hyprland now? (y/N): ${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Reloading Hyprland...${NC}"
    hyprctl reload || echo -e "${RED}Failed to reload Hyprland. Are you actually in a Hyprland session?${NC}"
fi

# ── Hyprland Plugin Setup ───────────────────────────────────────────────────
echo -e "\n${BLUE}Setting up Hyprland plugins...${NC}"
if command -v hyprpm &>/dev/null; then
    echo "Updating hyprpm..."
    hyprpm update
    echo "Adding hyprland-plugins repository..."
    hyprpm add https://github.com/hyprwm/hyprland-plugins.git || true
    echo "Enabling hyprscrolling..."
    hyprpm enable hyprscrolling
    echo -e "${GREEN}Hyprscrolling setup initiated.${NC}"
else
    echo -e "${YELLOW}Warning: hyprpm not found. Please install hyprland-plugins manually.${NC}"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "You can now launch the shell manually with: ${BLUE}qs -p ~/.config/quickshell/shell.qml${NC}"
echo -e "Or reload Hyprland to apply the new configuration automatically."
