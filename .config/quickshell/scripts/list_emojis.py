#!/usr/bin/env python3
import json
import os
import sys

def main():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    json_path = os.path.join(script_dir, "emojis.json")
    
    if not os.path.exists(json_path):
        # Fallback to an empty list if JSON doesn't exist
        print("[]")
        return

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            # We just print the content directly since it's already JSON
            sys.stdout.write(f.read())
    except Exception as e:
        print("[]", file=sys.stderr)
        print(f"Error reading emojis.json: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()

