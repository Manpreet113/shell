import sys
import json
import urllib.request
import re
import os
import subprocess
from datetime import datetime

CACHE_FILE = os.path.expanduser("~/.cache/quickshell/github.json")

def get_github_user():
    """Try git config keys commonly used for GitHub username."""
    for key in ["user.github", "github.user"]:
        try:
            res = subprocess.check_output(
                ["git", "config", "--global", "--get", key],
                stderr=subprocess.DEVNULL
            )
            name = res.decode().strip()
            if name:
                return name
        except Exception:
            pass
    return "manpreet113"


def fetch():
    user = sys.argv[1] if len(sys.argv) > 1 else get_github_user()
    cache_path = CACHE_FILE

    try:
        url = f"https://github.com/users/{user}/contributions"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as response:
            html = response.read().decode()

        # --- Extract actual contribution total from page text ---
        total_match = re.search(r"([\d,]+)\s+contributions?\s+in\s+the\s+last\s+year", html)
        total = int(total_match.group(1).replace(",", "")) if total_match else 0

        # --- Extract per-day levels from <td> elements only ---
        # Each contribution day is a <td> with data-date and data-level.
        entries = re.findall(
            r'<td[^>]*data-date="([^"]+)"[^>]*data-level="(\d+)"', html
        )
        if not entries:
            return  # keep existing cache

        # Build a dict of date -> level
        day_levels = [(date, int(level)) for date, level in entries]

        # Group into weeks (GitHub starts weeks on Sunday).
        # The entries are already ordered Sun-Sat per week in the HTML table.
        weeks = []
        week = []
        for _, level in day_levels:
            week.append(level)
            if len(week) == 7:
                weeks.append(week)
                week = []
        if week:
            # pad incomplete last week
            while len(week) < 7:
                week.append(0)
            weeks.append(week)

        data = {
            "user": user,
            "contributions": weeks,
            "total": total,
            "updated": datetime.now().isoformat(),
        }

        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
        with open(cache_path, "w") as f:
            json.dump(data, f)

    except Exception as e:
        # Silently fail — the dashboard will use the existing cache
        print(f"fetch_github: {e}", file=sys.stderr)


if __name__ == "__main__":
    fetch()
