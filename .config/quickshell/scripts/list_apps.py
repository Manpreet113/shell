#!/usr/bin/env python3
"""list_apps.py — Scan .desktop files and output a JSON array of apps.

Output format (single compact line):
  [{"name": "Firefox", "exec": "firefox"}, ...]

Called by Launcher.qml via Process each time the launcher opens.
"""
import json
import os
import glob
import re
import shlex

SEARCH_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    os.path.expanduser("~/.local/share/applications"),
]

def parse_desktop_file(path: str) -> dict | None:
    """Return {name, exec} for a .desktop file, or None if it should be skipped."""
    name = None
    exec_cmd = None
    no_display = False
    in_desktop = False

    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for raw_line in f:
                line = raw_line.strip()

                # Track which section we're in
                if line == "[Desktop Entry]":
                    in_desktop = True
                    continue
                if line.startswith("[") and line != "[Desktop Entry]":
                    if in_desktop:
                        break   # Past the Desktop Entry section
                    continue

                if not in_desktop:
                    continue

                # Skip localized keys (Name[fr]=…)
                if line.startswith("Name="):
                    name = line[5:].strip()
                elif line.startswith("Exec="):
                    exec_cmd = line[5:].strip()
                elif line in ("NoDisplay=true", "Hidden=true"):
                    no_display = True
    except (OSError, PermissionError):
        return None

    if not name or not exec_cmd or no_display:
        return None

    exec_cmd = normalize_exec(exec_cmd)

    return {"name": name, "exec": exec_cmd} if exec_cmd else None


def normalize_exec(exec_cmd: str) -> str:
    """Convert Exec= into a safely re-quoted shell command."""
    exec_cmd = re.sub(r"(?<!%)%%", "%", exec_cmd).strip()

    try:
        tokens = shlex.split(exec_cmd, posix=True)
    except ValueError:
        tokens = exec_cmd.split()

    cleaned: list[str] = []
    for token in tokens:
        if re.fullmatch(r"%[a-zA-Z]", token):
            continue

        token = re.sub(r"(?<!%)%[a-zA-Z]", "", token)
        token = token.replace("%%", "%").strip()
        if token:
            cleaned.append(token)

    if not cleaned:
        return ""

    return shlex.join(cleaned)


def main():
    apps: list[dict] = []
    seen_names: set[str] = set()

    for directory in SEARCH_DIRS:
        for desktop_path in glob.glob(os.path.join(directory, "*.desktop")):
            app = parse_desktop_file(desktop_path)
            if app and app["name"] not in seen_names:
                seen_names.add(app["name"])
                apps.append(app)

    # Sort alphabetically by name (case-insensitive)
    apps.sort(key=lambda a: a["name"].lower())

    # Output compact JSON — one line so SplitParser gets it in a single read
    print(json.dumps(apps, separators=(",", ":")))


if __name__ == "__main__":
    main()
