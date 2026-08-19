#!/usr/bin/env python3
"""
EduPlay audio inventory — Smart Reading Buddy (R26-IT-069)

Read-only. Touches nothing, moves nothing, renames nothing.

The EduPlay dataset references 240 audio files that do not exist. Two audio
corpora DO exist in this project, belonging to other modules:

  dataset/          Pronunciation module word recordings
  indeepa wav/      Timed Reading module sentence recordings

This script describes what is actually on disk so the EduPlay tasks can be
remapped onto those real files. It prints a compact summary meant to be
copied into chat, and writes the full listing to a JSON file.

Usage (from project root):

  python eduplay_audio_inventory.py
  python eduplay_audio_inventory.py --words "dataset" --sent "indeepa wav"

Requires nothing beyond the Python standard library.
"""

import argparse
import json
import os
from collections import Counter, defaultdict
from pathlib import Path

AUDIO_EXTENSIONS = (".wav", ".m4a", ".mp3", ".aac", ".ogg", ".flac")


def log(msg=""):
    print(msg, flush=True)


def section(title):
    log()
    log("=" * 68)
    log(f"  {title}")
    log("=" * 68)


def walk_audio(root):
    """Yield (relative_path, filename) for every audio file under root."""
    if not os.path.isdir(root):
        log(f"  WARNING: folder not found -> {root}")
        return
    for dirpath, _dirs, files in os.walk(root):
        for name in sorted(files):
            if name.lower().endswith(AUDIO_EXTENSIONS):
                full = os.path.join(dirpath, name)
                yield os.path.relpath(full, root).replace("\\", "/"), name


def describe_words(root):
    """The Pronunciation corpus nests recordings as <lang>/<grade>/<word>/file.
    The folder immediately above each file is therefore the spoken word."""
    entries = list(walk_audio(root))
    log(f"  root            : {root}")
    log(f"  audio files     : {len(entries):,}")
    if not entries:
        return {"root": root, "files": 0, "words": {}}

    depths = Counter(rel.count("/") for rel, _ in entries)
    log(f"  folder depths   : {dict(sorted(depths.items()))}")
    log()
    log("  Example paths:")
    for rel, _ in entries[:6]:
        log(f"    {rel}")

    # Group by the parent folder, which should be the word itself.
    by_word = defaultdict(list)
    for rel, name in entries:
        parts = rel.split("/")
        word = parts[-2] if len(parts) >= 2 else "(root)"
        by_word[word].append(rel)

    # Reconstruct the language/grade prefix each word sits under.
    prefixes = Counter()
    for rel, _ in entries:
        parts = rel.split("/")
        if len(parts) >= 3:
            prefixes["/".join(parts[:-2])] += 1

    log()
    log(f"  distinct word folders : {len(by_word)}")
    log(f"  recordings per word   : min {min(len(v) for v in by_word.values())}, "
        f"max {max(len(v) for v in by_word.values())}")
    log()
    log("  Language/grade groupings:")
    for prefix, count in sorted(prefixes.items()):
        log(f"    {prefix:<40} {count:>5} files")

    log()
    log("  ALL word folder names (this is what gets text-matched):")
    for name in sorted(by_word):
        log(f"    {name}")

    return {
        "root": root,
        "files": len(entries),
        "words": {w: sorted(v) for w, v in by_word.items()},
    }


def describe_sentences(root):
    """The Timed Reading corpus is flat: one file per sentence, named after
    the sentence itself (English) or a transliteration of it (Sinhala)."""
    entries = list(walk_audio(root))
    log(f"  root            : {root}")
    log(f"  audio files     : {len(entries):,}")
    if not entries:
        return {"root": root, "files": 0, "items": []}

    extensions = Counter(Path(n).suffix.lower() for _, n in entries)
    log(f"  extensions      : {dict(extensions)}")

    subfolders = Counter(rel.rsplit("/", 1)[0] if "/" in rel else "(flat)"
                         for rel, _ in entries)
    log(f"  subfolders      : {dict(subfolders)}")

    log()
    log("  ALL sentence filenames (this is what gets text-matched):")
    for rel, _ in entries:
        log(f"    {rel}")

    return {
        "root": root,
        "files": len(entries),
        "items": [rel for rel, _ in entries],
    }


def main():
    parser = argparse.ArgumentParser(
        description="Inventory the audio corpora already in this project.")
    parser.add_argument("--words", default="dataset",
                        help="Pronunciation module word recordings")
    parser.add_argument("--sent", default="indeepa wav",
                        help="Timed Reading module sentence recordings")
    parser.add_argument("--out", default="assets/eduplay/audio_inventory.json")
    args = parser.parse_args()

    section("Word corpus")
    words = describe_words(args.words)

    section("Sentence corpus")
    sentences = describe_sentences(args.sent)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"words": words, "sentences": sentences},
                  f, ensure_ascii=False, indent=1)

    section("Done")
    log(f"  full listing written to : {out_path}")
    log(f"  word recordings         : {words['files']:,} "
        f"across {len(words.get('words', {}))} word folders")
    log(f"  sentence recordings     : {sentences['files']:,}")
    log()


if __name__ == "__main__":
    main()
