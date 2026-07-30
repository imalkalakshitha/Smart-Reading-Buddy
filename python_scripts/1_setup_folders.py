#!/usr/bin/env python3
"""
1_setup_folders.py
Creates the dataset/ folder structure for all words across all languages and grades.
Run from: e:/src/smart_reading_buddy/
"""

from pathlib import Path

# ── Word lists ─────────────────────────────────────────────────────────────────

WORDS = {
    "en": {
        "grade3": [
            "cat", "dog", "pig", "sun", "pen", "fish", "jump", "rock",
            "rain", "ship", "eat", "ice", "open", "tiger", "pencil",
            "bother", "table", "mother", "river", "weather", "paper",
            "window", "green", "beach", "plant", "bread", "light",
            "computer", "sunshine", "butterfly",
        ],
        "grade4": [
            "green", "apple", "tasty", "daily", "rings", "orange", "happy",
            "chair", "pencil", "water", "animal", "table", "kite", "story",
            "large", "morning", "teacher", "beautiful", "bright", "everyday",
            "picture", "homework", "classroom", "evening", "market",
            "rainbow", "village", "student", "horse", "healthy",
        ],
    },
    "si": {
        "grade3": [
            "asa", "eka", "gama", "ura", "oya", "kesel", "gehaniya",
            "niyara", "thaaraawa", "cheenaya", "baegaya", "theentha",
            "poojaawa", "muhuda", "wewela", "athsana", "kemaththa",
            "sinhaya", "guruthuma", "thowilaya", "sigiriya", "waralasa",
            "eethalaya", "udalla", "kiribath", "wichaaraya", "rupakaya",
            "janathaawa", "pohosath", "gaayanaya",
        ],
        "grade4": [
            "sampoorna", "pilihuduwa", "sanwaadaya", "awabodhaya",
            "sankalpa", "nirmaanasheelee", "saukhya", "sanvidhaanaya",
            "gaurawaya", "wistharaya", "nigamanaya", "aarakshaawa",
            "prayathnaya", "awadhaanaya", "praayoogika",
        ],
    },
}

BASE = Path("dataset")


def main() -> None:
    created = 0

    for lang, grades in WORDS.items():
        for grade, words in grades.items():
            for word in words:
                folder = BASE / lang / grade / word
                folder.mkdir(parents=True, exist_ok=True)
                created += 1

    print(f"✅  Created {created} word folders under dataset/")
    print()

    # Summary table
    for lang, grades in WORDS.items():
        for grade, words in grades.items():
            path = BASE / lang / grade
            print(f"  {lang}/{grade}:  {len(words)} folders  →  {path}")

    print()
    print("Next step:  python python_scripts/2_organize_wavs.py")


if __name__ == "__main__":
    main()
