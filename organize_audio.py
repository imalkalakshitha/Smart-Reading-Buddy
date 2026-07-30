#!/usr/bin/env python3
"""
organize_audio.py
Organizes WAV files from wav/ into the Flutter assets/audio/words/ structure.
Run from the Flutter project root:  python organize_audio.py
"""

import shutil
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────────

SOURCE_DIR = Path("wav")
DEST_BASE  = Path("assets/audio/words")

# Each entry: (source_filename_case_insensitive, dest_relative_path)
# Destination paths are already lowercase.
FILE_MAP = [
    # ── ENGLISH GRADE 3 ───────────────────────────────────────────────────────
    ("Cat.wav",       "en/grade3/cat.wav"),
    ("Dog.wav",       "en/grade3/dog.wav"),
    ("Pig.wav",       "en/grade3/pig.wav"),
    ("Sun.wav",       "en/grade3/sun.wav"),
    ("Pen.wav",       "en/grade3/pen.wav"),
    ("Fish.wav",      "en/grade3/fish.wav"),
    ("Jump.wav",      "en/grade3/jump.wav"),
    ("Rock.wav",      "en/grade3/rock.wav"),
    ("Rain.wav",      "en/grade3/rain.wav"),
    ("Ship.wav",      "en/grade3/ship.wav"),
    ("Eat.wav",       "en/grade3/eat.wav"),
    ("Ice.wav",       "en/grade3/ice.wav"),
    ("Open.wav",      "en/grade3/open.wav"),
    ("Tiger.wav",     "en/grade3/tiger.wav"),
    ("Pencil.wav",    "en/grade3/pencil.wav"),
    ("Brother.wav",   "en/grade3/bother.wav"),   # RENAME
    ("Table.wav",     "en/grade3/table.wav"),
    ("Mother.wav",    "en/grade3/mother.wav"),
    ("River.wav",     "en/grade3/river.wav"),
    ("Weather.wav",   "en/grade3/weather.wav"),
    ("Paper.wav",     "en/grade3/paper.wav"),
    ("Window.wav",    "en/grade3/window.wav"),
    ("Green.wav",     "en/grade3/green.wav"),
    ("Beach.wav",     "en/grade3/beach.wav"),
    ("Plant.wav",     "en/grade3/plant.wav"),
    ("Bread.wav",     "en/grade3/bread.wav"),
    ("Light.wav",     "en/grade3/light.wav"),
    ("Computer.wav",  "en/grade3/computer.wav"),
    ("Sunshine.wav",  "en/grade3/sunshine.wav"),
    ("Butterfly.wav", "en/grade3/butterfly.wav"),

    # ── ENGLISH GRADE 4 ───────────────────────────────────────────────────────
    ("Green.wav",     "en/grade4/green.wav"),      # duplicate → both grades
    ("apple.wav",     "en/grade4/apple.wav"),
    ("tasty.wav",     "en/grade4/tasty.wav"),
    ("daily.wav",     "en/grade4/daily.wav"),
    ("rings.wav",     "en/grade4/rings.wav"),
    ("orange.wav",    "en/grade4/orange.wav"),
    ("happy.wav",     "en/grade4/happy.wav"),
    ("chair.wav",     "en/grade4/chair.wav"),
    ("Pencil.wav",    "en/grade4/pencil.wav"),     # duplicate → both grades
    ("water.wav",     "en/grade4/water.wav"),
    ("animal.wav",    "en/grade4/animal.wav"),
    ("Table.wav",     "en/grade4/table.wav"),      # duplicate → both grades
    ("kite.wav",      "en/grade4/kite.wav"),
    ("story.wav",     "en/grade4/story.wav"),
    ("large.wav",     "en/grade4/large.wav"),
    ("Morning.wav",   "en/grade4/morning.wav"),
    ("teacher.wav",   "en/grade4/teacher.wav"),
    ("beautiful.wav", "en/grade4/beautiful.wav"),
    ("bright.wav",    "en/grade4/bright.wav"),
    ("everyday.wav",  "en/grade4/everyday.wav"),
    ("picture.wav",   "en/grade4/picture.wav"),
    ("homework.wav",  "en/grade4/homework.wav"),
    ("classroom.wav", "en/grade4/classroom.wav"),
    ("evening.wav",   "en/grade4/evening.wav"),
    ("market.wav",    "en/grade4/market.wav"),
    ("rainbow.wav",   "en/grade4/rainbow.wav"),
    ("village.wav",   "en/grade4/village.wav"),
    ("student.wav",   "en/grade4/student.wav"),
    ("horse.wav",     "en/grade4/horse.wav"),
    ("healthy.wav",   "en/grade4/healthy.wav"),

    # ── SINHALA GRADE 3 ───────────────────────────────────────────────────────
    ("asa.wav",          "si/grade3/asa.wav"),
    ("eka.wav",          "si/grade3/eka.wav"),
    ("gama.wav",         "si/grade3/gama.wav"),
    ("ura.wav",          "si/grade3/ura.wav"),
    ("oya.wav",          "si/grade3/oya.wav"),
    ("kesel.wav",        "si/grade3/kesel.wav"),
    ("gehaniya.wav",     "si/grade3/gehaniya.wav"),
    ("niyara.wav",       "si/grade3/niyara.wav"),
    ("thaaraawa.wav",    "si/grade3/thaaraawa.wav"),
    ("cheenaya.wav",     "si/grade3/cheenaya.wav"),
    ("baegaya.wav",      "si/grade3/baegaya.wav"),
    ("theentha.wav",     "si/grade3/theentha.wav"),
    ("poojaawa.wav",     "si/grade3/poojaawa.wav"),
    ("muhuda.wav",       "si/grade3/muhuda.wav"),
    ("wewela.wav",       "si/grade3/wewela.wav"),
    ("athsana.wav",      "si/grade3/athsana.wav"),
    ("kemaththa.wav",    "si/grade3/kemaththa.wav"),
    ("sinhaya.wav",      "si/grade3/sinhaya.wav"),
    ("guruthuma.wav",    "si/grade3/guruthuma.wav"),
    ("thowilaya.wav",    "si/grade3/thowilaya.wav"),
    ("sigiriya.wav",     "si/grade3/sigiriya.wav"),
    ("waralasa.wav",     "si/grade3/waralasa.wav"),
    ("eethalaya.wav",    "si/grade3/eethalaya.wav"),
    ("udalla.wav",       "si/grade3/udalla.wav"),
    ("kiribath.wav",     "si/grade3/kiribath.wav"),
    ("wichaaraya.wav",   "si/grade3/wichaaraya.wav"),
    ("rupakaya.wav",     "si/grade3/rupakaya.wav"),
    ("janathaawa.wav",   "si/grade3/janathaawa.wav"),
    ("pohosath.wav",     "si/grade3/pohosath.wav"),
    ("gaayanaya.wav",    "si/grade3/gaayanaya.wav"),

    # ── SINHALA GRADE 4 ───────────────────────────────────────────────────────
    ("sampoorna.wav",        "si/grade4/sampoorna.wav"),
    ("pilihuduwa.wav",       "si/grade4/pilihuduwa.wav"),
    ("sanwaadaya.wav",       "si/grade4/sanwaadaya.wav"),
    ("awabodhaya.wav",       "si/grade4/awabodhaya.wav"),
    ("sankalpa.wav",         "si/grade4/sankalpa.wav"),
    ("nirmaanasheelee.wav",  "si/grade4/nirmaanasheelee.wav"),
    ("saukhya.wav",          "si/grade4/saukhya.wav"),
    ("sanvidhaanaya.wav",    "si/grade4/sanvidhaanaya.wav"),
    ("Gaurawaya.wav",        "si/grade4/gaurawaya.wav"),
    ("wistharaya.wav",       "si/grade4/wistharaya.wav"),
    ("nigamanaya.wav",       "si/grade4/nigamanaya.wav"),
    ("aarakshaawa.wav",      "si/grade4/aarakshaawa.wav"),
    ("prayathnaya.wav",      "si/grade4/prayathnaya.wav"),
    ("awadhaanaya.wav",      "si/grade4/awadhaanaya.wav"),
    ("praayoogika.wav",      "si/grade4/praayoogika.wav"),
]

# ── Helpers ────────────────────────────────────────────────────────────────────

def find_source(filename: str) -> Path | None:
    """Case-insensitive lookup inside SOURCE_DIR."""
    target = filename.lower()
    for p in SOURCE_DIR.iterdir():
        if p.name.lower() == target:
            return p
    return None

# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    if not SOURCE_DIR.exists():
        print(f"ERROR: Source folder '{SOURCE_DIR}' not found.")
        print("Run this script from your Flutter project root, next to the wav/ folder.")
        raise SystemExit(1)

    # Build a case-insensitive index of what's actually in wav/
    available = {p.name.lower(): p for p in SOURCE_DIR.iterdir() if p.suffix.lower() == ".wav"}
    print(f"Found {len(available)} WAV file(s) in {SOURCE_DIR}/\n")

    copied   = 0
    skipped  = 0
    missing  = []

    # Track which destination paths have already been written this run
    # so we don't double-count duplicates in the summary.
    written_dests: set[str] = set()

    for src_name, dest_rel in FILE_MAP:
        src_path = available.get(src_name.lower())
        dest_path = DEST_BASE / dest_rel

        if src_path is None:
            print(f"  MISSING  {src_name}")
            missing.append(src_name)
            continue

        dest_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dest_path)

        # Detect rename for display
        display_src  = src_path.name
        display_dest = f"assets/audio/words/{dest_rel}"
        flag = " (renamed)" if src_path.name.lower() != dest_path.name.lower() else ""
        print(f"  ✓  {display_src:<28} →  {display_dest}{flag}")

        if dest_rel not in written_dests:
            written_dests.add(dest_rel)
            copied += 1
        else:
            skipped += 1   # shouldn't happen, but guard anyway

    # ── Summary ───────────────────────────────────────────────────────────────
    print()
    print("─" * 60)
    if missing:
        print(f"⚠️  {len(missing)} source file(s) not found in {SOURCE_DIR}/:")
        for m in missing:
            print(f"     • {m}")
        print()

    total_entries = len(FILE_MAP)
    print(f"✅  Copied {copied} unique WAV file(s) to assets/  "
          f"({total_entries - len(missing)} entries processed, "
          f"{len(missing)} missing)")

    # List any wav/ files that weren't referenced in the map
    mapped_lower = {n.lower() for n, _ in FILE_MAP}
    unreferenced = [p.name for p in SOURCE_DIR.iterdir()
                    if p.suffix.lower() == ".wav" and p.name.lower() not in mapped_lower]
    if unreferenced:
        print()
        print(f"ℹ️  {len(unreferenced)} file(s) in wav/ were NOT in the map (not copied):")
        for u in sorted(unreferenced):
            print(f"     • {u}")


if __name__ == "__main__":
    main()
