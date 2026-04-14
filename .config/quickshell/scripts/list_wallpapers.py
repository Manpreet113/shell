#!/usr/bin/env python3
import json
import os
import glob

WALLPAPER_DIR = os.path.expanduser("~/Pictures/wallpapers")
EXTENSIONS = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]

def main():
    if not os.path.exists(WALLPAPER_DIR):
        print("[]")
        return

    wallpapers = []
    for ext in EXTENSIONS:
        # Check both lowercase and uppercase extensions
        for pattern in (ext, ext.upper()):
            for path in glob.glob(os.path.join(WALLPAPER_DIR, pattern)):
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
