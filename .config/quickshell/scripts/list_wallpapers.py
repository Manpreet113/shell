#!/usr/bin/env python3
import json
import os
import glob
import sys

DEFAULT_WALLPAPER_DIR = "~/Pictures/wallpapers"
EXTENSIONS = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]

def main():
    wallpaper_dir = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_WALLPAPER_DIR)

    if not os.path.exists(wallpaper_dir):
        print("[]")
        return

    wallpapers = []
    for ext in EXTENSIONS:
        # Check both lowercase and uppercase extensions
        for pattern in (ext, ext.upper()):
            for path in glob.glob(os.path.join(wallpaper_dir, pattern)):
                name = os.path.basename(path)
                wallpapers.append({
                    "name": name,
                    "path": path
                })

    # Sort by name
    wallpapers.sort(key=lambda x: x["name"].lower())
    
    # Output compact JSON
    print(json.dumps(wallpapers, separators=(",", ":")))

if __name__ == "__main__":
    main()
