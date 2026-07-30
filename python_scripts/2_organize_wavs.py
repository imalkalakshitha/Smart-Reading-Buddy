#!/usr/bin/env python3
"""
2_organize_wavs.py
Copies uploaded WAV files from wav/ into dataset/{lang}/{grade}/{word}/child_01.wav.
Run from: e:/src/smart_reading_buddy/
Requires: pip install soundfile numpy
"""

import shutil
import sys
from pathlib import Path

import numpy as np

try:
    import soundfile as sf
except ImportError:
    sys.exit("Missing dependency.  Run:  pip install soundfile numpy")

SOURCE_DIR = Path("wav")
DATASET    = Path("dataset")
TARGET_SR  = 16_000

# ── Explicit source-filename → (lang, grade, word) mapping ────────────────────
# Keys are lowercase; matching is case-insensitive.
FILE_MAP: dict[str, tuple[str, str, str]] = {
    # ── EN Grade 3 ─────────────────────────────────────────────────────
    "cat.wav":       ("en", "grade3", "cat"),
    "dog.wav":       ("en", "grade3", "dog"),
    "pig.wav":       ("en", "grade3", "pig"),
    "sun.wav":       ("en", "grade3", "sun"),
    "pen.wav":       ("en", "grade3", "pen"),
    "fish.wav":      ("en", "grade3", "fish"),
    "jump.wav":      ("en", "grade3", "jump"),
    "rock.wav":      ("en", "grade3", "rock"),
    "rain.wav":      ("en", "grade3", "rain"),
    "ship.wav":      ("en", "grade3", "ship"),
    "eat.wav":       ("en", "grade3", "eat"),
    "ice.wav":       ("en", "grade3", "ice"),
    "open.wav":      ("en", "grade3", "open"),
    "tiger.wav":     ("en", "grade3", "tiger"),
    "pencil.wav":    ("en", "grade3", "pencil"),
    "brother.wav":   ("en", "grade3", "bother"),   # typo fix
    "table.wav":     ("en", "grade3", "table"),
    "mother.wav":    ("en", "grade3", "mother"),
    "river.wav":     ("en", "grade3", "river"),
    "weather.wav":   ("en", "grade3", "weather"),
    "paper.wav":     ("en", "grade3", "paper"),
    "window.wav":    ("en", "grade3", "window"),
    "green.wav":     ("en", "grade3", "green"),
    "beach.wav":     ("en", "grade3", "beach"),
    "plant.wav":     ("en", "grade3", "plant"),
    "bread.wav":     ("en", "grade3", "bread"),
    "light.wav":     ("en", "grade3", "light"),
    "computer.wav":  ("en", "grade3", "computer"),
    "sunshine.wav":  ("en", "grade3", "sunshine"),
    "butterfly.wav": ("en", "grade3", "butterfly"),
    # ── EN Grade 4 ─────────────────────────────────────────────────────
    # green / pencil / table: same source file → also placed in grade4
    # (handled via DUPLICATES below)
    "apple.wav":     ("en", "grade4", "apple"),
    "tasty.wav":     ("en", "grade4", "tasty"),
    "daily.wav":     ("en", "grade4", "daily"),
    "rings.wav":     ("en", "grade4", "rings"),
    "orange.wav":    ("en", "grade4", "orange"),
    "happy.wav":     ("en", "grade4", "happy"),
    "chair.wav":     ("en", "grade4", "chair"),
    "water.wav":     ("en", "grade4", "water"),
    "animal.wav":    ("en", "grade4", "animal"),
    "kite.wav":      ("en", "grade4", "kite"),
    "story.wav":     ("en", "grade4", "story"),
    "large.wav":     ("en", "grade4", "large"),
    "morning.wav":   ("en", "grade4", "morning"),
    "teacher.wav":   ("en", "grade4", "teacher"),
    "beautiful.wav": ("en", "grade4", "beautiful"),
    "bright.wav":    ("en", "grade4", "bright"),
    "everyday.wav":  ("en", "grade4", "everyday"),
    "picture.wav":   ("en", "grade4", "picture"),
    "homework.wav":  ("en", "grade4", "homework"),
    "classroom.wav": ("en", "grade4", "classroom"),
    "evening.wav":   ("en", "grade4", "evening"),
    "market.wav":    ("en", "grade4", "market"),
    "rainbow.wav":   ("en", "grade4", "rainbow"),
    "village.wav":   ("en", "grade4", "village"),
    "student.wav":   ("en", "grade4", "student"),
    "horse.wav":     ("en", "grade4", "horse"),
    "healthy.wav":   ("en", "grade4", "healthy"),
    # ── SI Grade 3 ─────────────────────────────────────────────────────
    "asa.wav":        ("si", "grade3", "asa"),
    "eka.wav":        ("si", "grade3", "eka"),
    "gama.wav":       ("si", "grade3", "gama"),
    "ura.wav":        ("si", "grade3", "ura"),
    "oya.wav":        ("si", "grade3", "oya"),
    "kesel.wav":      ("si", "grade3", "kesel"),
    "gehaniya.wav":   ("si", "grade3", "gehaniya"),
    "niyara.wav":     ("si", "grade3", "niyara"),
    "thaaraawa.wav":  ("si", "grade3", "thaaraawa"),
    "cheenaya.wav":   ("si", "grade3", "cheenaya"),
    "baegaya.wav":    ("si", "grade3", "baegaya"),
    "theentha.wav":   ("si", "grade3", "theentha"),
    "poojaawa.wav":   ("si", "grade3", "poojaawa"),
    "muhuda.wav":     ("si", "grade3", "muhuda"),
    "wewela.wav":     ("si", "grade3", "wewela"),
    "athsana.wav":    ("si", "grade3", "athsana"),
    "kemaththa.wav":  ("si", "grade3", "kemaththa"),
    "sinhaya.wav":    ("si", "grade3", "sinhaya"),
    "guruthuma.wav":  ("si", "grade3", "guruthuma"),
    "thowilaya.wav":  ("si", "grade3", "thowilaya"),
    "sigiriya.wav":   ("si", "grade3", "sigiriya"),
    "waralasa.wav":   ("si", "grade3", "waralasa"),
    "eethalaya.wav":  ("si", "grade3", "eethalaya"),
    "udalla.wav":     ("si", "grade3", "udalla"),
    "kiribath.wav":   ("si", "grade3", "kiribath"),
    "wichaaraya.wav": ("si", "grade3", "wichaaraya"),
    "rupakaya.wav":   ("si", "grade3", "rupakaya"),
    "janathaawa.wav": ("si", "grade3", "janathaawa"),
    "pohosath.wav":   ("si", "grade3", "pohosath"),
    "gaayanaya.wav":  ("si", "grade3", "gaayanaya"),
    # ── SI Grade 4 ─────────────────────────────────────────────────────
    "sampoorna.wav":       ("si", "grade4", "sampoorna"),
    "pilihuduwa.wav":      ("si", "grade4", "pilihuduwa"),
    "sanwaadaya.wav":      ("si", "grade4", "sanwaadaya"),
    "awabodhaya.wav":      ("si", "grade4", "awabodhaya"),
    "sankalpa.wav":        ("si", "grade4", "sankalpa"),
    "nirmaanasheelee.wav": ("si", "grade4", "nirmaanasheelee"),
    "saukhya.wav":         ("si", "grade4", "saukhya"),
    "sanvidhaanaya.wav":   ("si", "grade4", "sanvidhaanaya"),
    "gaurawaya.wav":       ("si", "grade4", "gaurawaya"),
    "wistharaya.wav":      ("si", "grade4", "wistharaya"),
    "nigamanaya.wav":      ("si", "grade4", "nigamanaya"),
    "aarakshaawa.wav":     ("si", "grade4", "aarakshaawa"),
    "prayathnaya.wav":     ("si", "grade4", "prayathnaya"),
    "awadhaanaya.wav":     ("si", "grade4", "awadhaanaya"),
    "praayoogika.wav":     ("si", "grade4", "praayoogika"),
}

# Files that must be copied to more than one destination
DUPLICATES: list[tuple[str, str, str, str]] = [
    # (source_key_in_FILE_MAP,  lang,  grade,   word)
    ("green.wav",  "en", "grade4", "green"),
    ("pencil.wav", "en", "grade4", "pencil"),
    ("table.wav",  "en", "grade4", "table"),
]


def load_and_verify(path: Path) -> tuple[np.ndarray, int]:
    """Load WAV and verify it is mono / 16 kHz."""
    audio, sr = sf.read(str(path), dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)              # stereo → mono
    if sr != TARGET_SR:
        print(f"  ⚠️  {path.name}: sample rate is {sr} Hz (expected {TARGET_SR})")
    return audio, sr


def copy_to_dataset(src: Path, lang: str, grade: str, word: str) -> Path:
    dest_dir  = DATASET / lang / grade / word
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_file = dest_dir / "child_01.wav"
    shutil.copy2(src, dest_file)
    return dest_file


def main() -> None:
    if not SOURCE_DIR.exists():
        sys.exit(f"ERROR: '{SOURCE_DIR}' folder not found. "
                 "Run from the Flutter project root.")

    # Build case-insensitive index of what's actually in wav/
    available: dict[str, Path] = {
        p.name.lower(): p
        for p in SOURCE_DIR.iterdir()
        if p.suffix.lower() == ".wav"
    }

    print(f"Found {len(available)} WAV file(s) in {SOURCE_DIR}/\n")

    copied  = 0
    missing = []

    # ── Primary mapping ────────────────────────────────────────────────────────
    for src_name_lower, (lang, grade, word) in FILE_MAP.items():
        src = available.get(src_name_lower)
        if src is None:
            missing.append(src_name_lower)
            print(f"  MISSING  {src_name_lower}")
            continue

        dest = copy_to_dataset(src, lang, grade, word)
        renamed = (src.stem.lower() != word)
        flag    = f"  (→ {word})" if renamed else ""
        print(f"  ✓  {src.name:<30} →  {dest}{flag}")
        copied += 1

    # ── Duplicate mappings ─────────────────────────────────────────────────────
    print("\n  [Duplicates — same audio used in multiple grades]")
    for src_key, lang, grade, word in DUPLICATES:
        src = available.get(src_key)
        if src is None:
            print(f"  MISSING (dup)  {src_key}")
            continue
        dest = copy_to_dataset(src, lang, grade, word)
        print(f"  ✓  {src.name:<30} →  {dest}  (dup)")
        copied += 1

    # ── Summary ────────────────────────────────────────────────────────────────
    print()
    print("─" * 65)
    if missing:
        print(f"⚠️  {len(missing)} file(s) not found:")
        for m in missing:
            print(f"     • {m}")
        print()

    unreferenced = [
        p.name for p in SOURCE_DIR.iterdir()
        if p.suffix.lower() == ".wav"
        and p.name.lower() not in FILE_MAP
        and p.name.lower() not in {s for s, *_ in DUPLICATES}
    ]
    if unreferenced:
        print(f"ℹ️  {len(unreferenced)} file(s) in wav/ were not mapped (skipped):")
        for u in sorted(unreferenced):
            print(f"     • {u}")
        print()

    print(f"✅  Copied {copied} WAV files → dataset/  "
          f"({len(missing)} missing)")
    print("\nNext step:  python python_scripts/3_augment_voices.py")


if __name__ == "__main__":
    main()
