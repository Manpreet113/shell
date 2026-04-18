"""Read the cached GitHub contribution data. No network calls here."""
import json
import os
import subprocess
import sys

CACHE_FILE = os.path.expanduser("~/.cache/quickshell/github.json")


def get_github_user():
    for key in ["user.github", "github.user"]:
        try:
            res = subprocess.check_output(
                ["git", "config", "--global", "--get", key],
                stderr=subprocess.DEVNULL,
            )
            name = res.decode().strip()
            if name:
                return name
        except Exception:
            pass
    return "manpreet113"


def empty_data(user):
    return {
        "user": user,
        "contributions": [[0] * 7 for _ in range(52)],
        "total": 0,
    }


def get_data():
    user = get_github_user()

    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                data = json.load(f)
            # Ensure user field is up-to-date
            data["user"] = user
            return data
        except Exception:
            pass

    return empty_data(user)


if __name__ == "__main__":
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    print(json.dumps(get_data()))
