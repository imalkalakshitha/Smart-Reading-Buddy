#!/usr/bin/env python3
"""
3_augment_voices.py
For each dataset/{lang}/{grade}/{word}/child_01.wav, generates 19 augmented
copies (child_02.wav … child_20.wav) using pitch-shift, time-stretch and noise.
Run from: e:/src/smart_reading_buddy/
Requires: pip install librosa soundfile numpy tqdm
"""

import sys
from pathlib import Path

import numpy as np

try:
    import librosa
    import soundfile as sf
    from tqdm import tqdm
except ImportError:
    sys.exit("Missing dependencies.  Run:  pip install librosa soundfile numpy tqdm")

DATASET   = Path("dataset")
TARGET_SR = 16_000
RNG       = np.random.default_rng(42)   # reproducible noise

# ── 19 augmentation recipes ────────────────────────────────────────────────────
# (pitch_semitones, speed_factor, noise_scale)
# child_01 = original; child_02..20 = these 19 variants
AUGMENTATIONS: list[tuple[float, float, float]] = [
    # pitch-only shifts
    (-3.0, 1.00, 0.0005),
    (-2.0, 1.00, 0.0005),
    (-1.0, 1.00, 0.0005),
    (+1.0, 1.00, 0.0005),
    (+2.0, 1.00, 0.0005),
    (+3.0, 1.00, 0.0005),
    # speed-only changes
    ( 0.0, 0.90, 0.0005),
    ( 0.0, 0.95, 0.0005),
    ( 0.0, 1.05, 0.0005),
    ( 0.0, 1.10, 0.0005),
    # combined pitch + speed
    (-2.0, 0.95, 0.001),
    (-1.0, 0.90, 0.001),
    (+1.0, 1.05, 0.001),
    (+2.0, 1.10, 0.001),
    (-1.0, 1.05, 0.001),
    (+1.0, 0.95, 0.001),
    (-2.0, 1.10, 0.001),
    (+2.0, 0.90, 0.001),
    # original + noise only (rounds out to 20 total files)
    ( 0.0, 1.00, 0.002),
]

assert len(AUGMENTATIONS) == 19, "Must be exactly 19 augmentation entries"


def augment(audio: np.ndarray, pitch: float, speed: float, noise: float) -> np.ndarray:
    y = audio.copy()

    if speed != 1.0:
        y = librosa.effects.time_stretch(y, rate=speed)

    if pitch != 0.0:
        y = librosa.effects.pitch_shift(y, sr=TARGET_SR, n_steps=pitch)

    if noise > 0.0:
        y = y + RNG.normal(0, noise, size=y.shape).astype(np.float32)

    # Clip to [-1, 1] to avoid clipping artefacts on save
    y = np.clip(y, -1.0, 1.0)
    return y


def collect_word_dirs() -> list[Path]:
    return sorted(
        p for p in DATASET.rglob("child_01.wav")
        if p.is_file()
    )


def main() -> None:
    if not DATASET.exists():
        sys.exit("ERROR: dataset/ not found. Run 1_setup_folders.py and 2_organize_wavs.py first.")

    originals = collect_word_dirs()
    if not originals:
        sys.exit("ERROR: No child_01.wav files found in dataset/. Run 2_organize_wavs.py first.")

    print(f"Found {len(originals)} word folder(s) with child_01.wav\n")
    print(f"Generating {len(AUGMENTATIONS)} augmented versions per word …\n")

    total_generated = 0
    errors: list[str] = []

    for original_path in tqdm(originals, desc="Augmenting", unit="word"):
        word_dir = original_path.parent
        label    = "/".join(word_dir.parts[-3:])   # e.g. en/grade3/cat

        try:
            audio, sr = librosa.load(str(original_path), sr=TARGET_SR, mono=True)
        except Exception as exc:
            errors.append(f"{label}: {exc}")
            tqdm.write(f"  ✗  {label}  — load failed: {exc}")
            continue

        for idx, (pitch, speed, noise) in enumerate(AUGMENTATIONS, start=2):
            dest = word_dir / f"child_{idx:02d}.wav"
            try:
                y_aug = augment(audio, pitch, speed, noise)
                sf.write(str(dest), y_aug, TARGET_SR, subtype="PCM_16")
                total_generated += 1
            except Exception as exc:
                errors.append(f"{label}/child_{idx:02d}: {exc}")
                tqdm.write(f"  ✗  {label}/child_{idx:02d} — {exc}")

    print()
    print("─" * 60)
    if errors:
        print(f"⚠️  {len(errors)} error(s):")
        for e in errors:
            print(f"     • {e}")
        print()

    words_done = len(originals) - len(
        [e for e in errors if "load failed" in e]
    )
    total_files = words_done + total_generated
    print(f"✅  {words_done} words × 20 = {total_files} WAV files total")
    print(f"   ({words_done} original  +  {total_generated} augmented)")
    print("\nNext step:  python python_scripts/4_build_references.py")


if __name__ == "__main__":
    main()
