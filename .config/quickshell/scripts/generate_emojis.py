import json
import urllib.request
import os

def generate():
    url = "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json"
    print(f"Downloading emojis from {url}...")
    
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
        
        formatted = []
        for entry in data:
            emoji = entry.get("emoji")
            if not emoji:
                continue
                
            name = entry.get("description", "")
            aliases = entry.get("aliases", [])
            tags = entry.get("tags", [])
            
            # Combine aliases and tags for keywords
            keywords = list(set(aliases + tags))
            
            formatted.append({
                "emoji": emoji,
                "name": name,
                "keywords": keywords
            })
            
        output_path = os.path.join(os.path.dirname(__file__), "emojis.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(formatted, f, ensure_ascii=False, separators=(",", ":"))
            
        print(f"Successfully generated {output_path} with {len(formatted)} emojis.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate()
