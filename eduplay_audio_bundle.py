#!/usr/bin/env python3
"""
EduPlay audio bundle — Smart Reading Buddy (R26-IT-069)

Fixes two confirmed Flutter asset-loading bugs:
  1. "indeepa wav/" has a space in the folder name. The Flutter build tool
     percent-encodes the space when zipping the APK, but the engine's
     runtime asset lookup does not apply the same encoding — so
     rootBundle.load() fails even though the file is physically present.
  2. "dataset/" as a single pubspec folder entry does NOT recursively pick
     up files nested three levels down (dataset/<lang>/<grade>/<word>/*.wav).
     Flutter only bundles files directly inside a declared folder.

Fix: copy (never move/rename) every audio file actually used by a task
into a flat, EduPlay-controlled folder with no spaces and no nesting:

  assets/eduplay/audio/words/<sanitised-name>.wav
  assets/eduplay/audio/sentences/<sanitised-name>.wav

Then patch eduplay_tasks.json so audio_path points at the new location.
Original dataset/ and "indeepa wav/" folders are left completely untouched.

Multiple tasks can share the same source recording (deterministic speaker
picking). Each unique source file is copied exactly once.

Usage (from project root, after eduplay_audio_remap.py has already run):

  python eduplay_audio_bundle.py
  python eduplay_audio_bundle.py --tasks "assets/eduplay/eduplay_tasks.json" \\
                                  --out   "assets/eduplay/audio"

Requires: nothing beyond the Python standard library.
"""

import argparse
import json
import os
import re
import shutil
from pathlib import Path


def log(msg=""):
    print(msg, flush=True)


def section(title):
    log()
    log("=" * 68)
    log(f"  {title}")
    log("=" * 68)


def sanitise(path_str):
    """Turn a source path into a safe, unique, flat filename.
    Keeps it human-readable for debugging while guaranteeing no spaces,
    no slashes, no characters that upset any platform or the Flutter
    asset system."""
    stem = Path(path_str).stem
    ext = Path(path_str).suffix.lower()
    # Fold the parent folder in too, so two different "child_01.wav" files
    # under different word folders don't collide.
    parent = Path(path_str).parent.name
    raw = f"{parent}_{stem}"
    safe = re.sub(r"[^A-Za-z0-9_\-]", "_", raw)
    safe = re.sub(r"_+", "_", safe).strip("_")
    return f"{safe}{ext}"


def main():
    parser = argparse.ArgumentParser(
        description="Bundle EduPlay audio into a flat, space-free asset folder.")
    parser.add_argument("--tasks", default="assets/eduplay/eduplay_tasks.json")
    parser.add_argument("--out", default="assets/eduplay/audio")
    args = parser.parse_args()

    if not os.path.isfile(args.tasks):
        raise SystemExit(f"ERROR: tasks file not found -> {args.tasks}")

    words_dir = Path(args.out) / "words"
    sentences_dir = Path(args.out) / "sentences"
    words_dir.mkdir(parents=True, exist_ok=True)
    sentences_dir.mkdir(parents=True, exist_ok=True)

    section("Loading tasks")
    with open(args.tasks, encoding="utf-8") as f:
        tasks = json.load(f)
    log(f"  {len(tasks)} tasks loaded")

    with_audio = [t for t in tasks if t.get("audio_available") and t.get("audio_path")]
    log(f"  {len(with_audio)} tasks have a resolved source audio_path")

    section("Copying (deduplicated by source file)")
    # source_path -> new relative audio_path (without "assets/" prefix,
    # matching how audioplayers' AssetSource already expects paths in
    # this codebase — it prepends "assets/" itself).
    copied = {}
    n_copied = n_reused = n_missing = 0

    for task in with_audio:
        src = task["audio_path"]
        if src in copied:
            task["audio_path"] = copied[src]
            n_reused += 1
            continue

        if not os.path.isfile(src):
            log(f"  MISSING on disk (was resolved earlier but now absent): {src}")
            task["audio_available"] = False
            task["audio_path"] = None
            n_missing += 1
            continue

        is_sentence = task.get("audio_type") == "sentence"
        dest_dir = sentences_dir if is_sentence else words_dir
        dest_name = sanitise(src)
        dest_path = dest_dir / dest_name

        # Guard against a sanitised-name collision between two different
        # source files (rare, but check rather than silently overwrite).
        suffix = 1
        base_stem = dest_path.stem
        while dest_path.exists():
            # Only a real problem if it's not the exact same source we
            # already copied under this name.
            existing_src = next((s for s, d in copied.items()
                                if Path(d).name == dest_path.name), None)
            if existing_src == src:
                break
            suffix += 1
            dest_path = dest_dir / f"{base_stem}_{suffix}{dest_path.suffix}"

        shutil.copy2(src, dest_path)

        rel = f"eduplay/audio/{'sentences' if is_sentence else 'words'}/{dest_path.name}"
        copied[src] = rel
        task["audio_path"] = rel
        n_copied += 1

    log(f"  new files copied   : {n_copied}")
    log(f"  reused (dedup)     : {n_reused}")
    log(f"  missing on disk    : {n_missing}")

    section("Writing patched tasks")
    with open(args.tasks, "w", encoding="utf-8") as f:
        json.dump(tasks, f, ensure_ascii=False, indent=1)
    size_kb = Path(args.tasks).stat().st_size / 1024
    log(f"  written: {args.tasks}  ({size_kb:,.0f} KB)")

    words_count = len(list(words_dir.glob("*")))
    sentences_count = len(list(sentences_dir.glob("*")))
    words_size = sum(f.stat().st_size for f in words_dir.glob("*")) / (1024 * 1024)
    sentences_size = sum(f.stat().st_size for f in sentences_dir.glob("*")) / (1024 * 1024)

    section("Done")
    log(f"  {words_dir}/  : {words_count} files, {words_size:.1f} MB")
    log(f"  {sentences_dir}/  : {sentences_count} files, {sentences_size:.1f} MB")
    log()
    log("  pubspec.yaml — replace the 'dataset/' and 'indeepa wav/' lines with:")
    log("    - assets/eduplay/audio/words/")
    log("    - assets/eduplay/audio/sentences/")
    log()
    log("  Do NOT remove the original 'dataset/' or 'indeepa wav/' entries if")
    log("  Pronunciation or Timed Reading still reference them directly — check")
    log("  before deleting those two pubspec lines.")
    log()


if __name__ == "__main__":
    main()
