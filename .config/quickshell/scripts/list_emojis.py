#!/usr/bin/env python3
import json

EMOJIS = [
    {"emoji": "😀", "name": "grinning face", "keywords": ["happy", "smile", "joy"]},
    {"emoji": "😂", "name": "face with tears of joy", "keywords": ["laugh", "funny", "cry"]},
    {"emoji": "🙂", "name": "slightly smiling face", "keywords": ["smile", "calm", "friendly"]},
    {"emoji": "😉", "name": "winking face", "keywords": ["wink", "playful"]},
    {"emoji": "😍", "name": "smiling face with heart eyes", "keywords": ["love", "heart", "crush"]},
    {"emoji": "🥲", "name": "smiling face with tear", "keywords": ["emotional", "proud", "soft"]},
    {"emoji": "😎", "name": "smiling face with sunglasses", "keywords": ["cool", "chill"]},
    {"emoji": "🤔", "name": "thinking face", "keywords": ["think", "hmm", "question"]},
    {"emoji": "🫡", "name": "saluting face", "keywords": ["salute", "respect", "yes"]},
    {"emoji": "😭", "name": "loudly crying face", "keywords": ["sad", "cry", "tears"]},
    {"emoji": "😴", "name": "sleeping face", "keywords": ["sleep", "tired", "zzz"]},
    {"emoji": "🤯", "name": "exploding head", "keywords": ["mind blown", "shock"]},
    {"emoji": "🥳", "name": "partying face", "keywords": ["party", "celebrate"]},
    {"emoji": "😤", "name": "face with steam from nose", "keywords": ["frustrated", "angry"]},
    {"emoji": "🙏", "name": "folded hands", "keywords": ["thanks", "pray", "please"]},
    {"emoji": "👍", "name": "thumbs up", "keywords": ["yes", "approve", "like"]},
    {"emoji": "👎", "name": "thumbs down", "keywords": ["no", "dislike"]},
    {"emoji": "👏", "name": "clapping hands", "keywords": ["applause", "good job"]},
    {"emoji": "🙌", "name": "raising hands", "keywords": ["celebrate", "praise"]},
    {"emoji": "🤝", "name": "handshake", "keywords": ["deal", "agreement"]},
    {"emoji": "💀", "name": "skull", "keywords": ["dead", "lol", "funny"]},
    {"emoji": "🔥", "name": "fire", "keywords": ["lit", "hot", "great"]},
    {"emoji": "✨", "name": "sparkles", "keywords": ["magic", "shine", "pretty"]},
    {"emoji": "⭐", "name": "star", "keywords": ["favorite", "highlight"]},
    {"emoji": "🌙", "name": "crescent moon", "keywords": ["night", "sleep"]},
    {"emoji": "☀️", "name": "sun", "keywords": ["day", "bright", "warm"]},
    {"emoji": "🌧️", "name": "cloud with rain", "keywords": ["rain", "weather"]},
    {"emoji": "❄️", "name": "snowflake", "keywords": ["winter", "cold"]},
    {"emoji": "❤️", "name": "red heart", "keywords": ["love", "heart"]},
    {"emoji": "💔", "name": "broken heart", "keywords": ["sad", "heartbreak"]},
    {"emoji": "💯", "name": "hundred points", "keywords": ["perfect", "agree"]},
    {"emoji": "✅", "name": "check mark", "keywords": ["done", "yes", "complete"]},
    {"emoji": "❌", "name": "cross mark", "keywords": ["no", "wrong", "error"]},
    {"emoji": "⚠️", "name": "warning", "keywords": ["alert", "careful"]},
    {"emoji": "🚀", "name": "rocket", "keywords": ["launch", "ship", "fast"]},
    {"emoji": "🧠", "name": "brain", "keywords": ["smart", "mind", "think"]},
    {"emoji": "🎉", "name": "party popper", "keywords": ["celebrate", "party"]},
    {"emoji": "🎵", "name": "music note", "keywords": ["song", "audio"]},
    {"emoji": "📌", "name": "pushpin", "keywords": ["pin", "note"]},
    {"emoji": "📎", "name": "paperclip", "keywords": ["attach", "file"]},
    {"emoji": "💡", "name": "light bulb", "keywords": ["idea", "inspiration"]},
    {"emoji": "🔒", "name": "locked", "keywords": ["lock", "secure"]},
    {"emoji": "🔋", "name": "battery", "keywords": ["power", "charge"]},
    {"emoji": "📶", "name": "signal strength", "keywords": ["wifi", "network"]},
    {"emoji": "🖥️", "name": "desktop computer", "keywords": ["computer", "desktop"]},
    {"emoji": "💻", "name": "laptop", "keywords": ["computer", "work"]},
    {"emoji": "⌨️", "name": "keyboard", "keywords": ["type", "keys"]},
    {"emoji": "🖱️", "name": "computer mouse", "keywords": ["mouse"]},
    {"emoji": "📁", "name": "file folder", "keywords": ["folder", "files"]},
    {"emoji": "📝", "name": "memo", "keywords": ["note", "write"]},
]


def main():
    print(json.dumps(EMOJIS, separators=(",", ":")))


if __name__ == "__main__":
    main()
