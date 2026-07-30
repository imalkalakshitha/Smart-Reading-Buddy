#!/usr/bin/env python3
"""
4_build_references.py
Builds MFCC reference templates + DTW thresholds for every word folder.

For each dataset/{lang}/{grade}/{word}/ with child_01..20.wav:
  1. Extract normalized MFCC (13 coefficients)
  2. Interpolate all 20 to median length → average → reference template
  3. Compute 19 DTW distances (child_01 vs child_02..20) → threshold = mean × 1.3
  4. Save assets/audio/reference/{lang}/{grade}/{word}.json
  5. Collect all thresholds → assets/audio/reference/thresholds.json

Run from: e:/src/smart_reading_buddy/
Requires: pip install librosa soundfile numpy scipy fastdtw tqdm
"""

import json
import sys
from pathlib import Path

import numpy as np
from scipy.interpolate import interp1d
from scipy.spatial.distance import euclidean

try:
    import librosa
    import soundfile as sf
    from fastdtw import fastdtw
    from tqdm import tqdm
except ImportError:
    sys.exit(
        "Missing dependencies.  Run:\n"
        "  py -m pip install librosa soundfile numpy scipy fastdtw tqdm"
    )

# ── Constants ──────────────────────────────────────────────────────────────────
DATASET              = Path("dataset")
REF_BASE             = Path("assets/audio/reference")
TARGET_SR            = 16_000
N_MFCC               = 13
HOP                  = 160       # 10 ms at 16 kHz
N_FFT                = 512       # FFT size — MUST match Dart _nFft=512
WIN_LENGTH           = 400       # window size — MUST match Dart _winLen=400
THRESHOLD_MULTIPLIER = 1.3
N_AUGMENTED          = 20        # child_01 … child_20

# Downsample MFCC frames by this factor before DTW to speed up computation.
# 2 → keep every 2nd frame (halves length, 4× DTW speedup). 1 = no downsampling.
FRAME_STEP = 2


# ── MFCC helpers ───────────────────────────────────────────────────────────────

def extract_mfcc(path: Path) -> np.ndarray:
    """Return normalized MFCC of shape (N_MFCC, frames)."""
    audio, _ = sf.read(str(path), dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)   # stereo → mono
    mfcc = librosa.feature.mfcc(
        y=audio, sr=TARGET_SR,
        n_mfcc=N_MFCC, hop_length=HOP, n_fft=N_FFT, win_length=WIN_LENGTH,
    )
    # z-score normalization per coefficient
    mean = mfcc.mean(axis=1, keepdims=True)
    std  = mfcc.std(axis=1, keepdims=True) + 1e-8
    return ((mfcc - mean) / std).astype(np.float32)


def interpolate_to_length(mfcc: np.ndarray, target_len: int) -> np.ndarray:
    """Resize MFCC time axis to target_len using linear interpolation."""
    if mfcc.shape[1] == target_len:
        return mfcc
    t_src = np.linspace(0.0, 1.0, mfcc.shape[1])
    t_dst = np.linspace(0.0, 1.0, target_len)
    out   = np.zeros((N_MFCC, target_len), dtype=np.float32)
    for i in range(N_MFCC):
        out[i] = interp1d(t_src, mfcc[i], kind="linear")(t_dst)
    return out


def average_mfccs(mfccs: list[np.ndarray]) -> np.ndarray:
    """Interpolate all MFCCs to their median frame length, then average."""
    target_len = int(np.median([m.shape[1] for m in mfccs]))
    resized    = [interpolate_to_length(m, target_len) for m in mfccs]
    return np.mean(resized, axis=0)   # (N_MFCC, target_len)


# ── DTW helpers ────────────────────────────────────────────────────────────────

def dtw_distance_normalized(a: np.ndarray, b: np.ndarray) -> float:
    """
    FastDTW distance between two MFCC arrays (shape N_MFCC × frames).
    Downsampled by FRAME_STEP for speed. Normalized by warping-path length.
    fastdtw is O(n) vs classic DTW O(n²) — ~200× faster on typical sequences.
    """
    # Transpose to (frames, features) and optionally decimate
    sa = a.T[::FRAME_STEP]   # (frames/FRAME_STEP, N_MFCC)
    sb = b.T[::FRAME_STEP]
    dist, path = fastdtw(sa, sb, dist=euclidean)
    return float(dist) / len(path)   # normalize by warping-path length


def compute_threshold(ref_mfcc: np.ndarray, aug_mfccs: list[np.ndarray]) -> float:
    """
    Compute DTW distances from child_01 (the reference) to every augmented
    recording (child_02..20) — 19 distances instead of 190 all-pairs.
    threshold = mean_distance × THRESHOLD_MULTIPLIER
    """
    if not aug_mfccs:
        return 1.0
    distances = [dtw_distance_normalized(ref_mfcc, aug) for aug in aug_mfccs]
    return float(np.mean(distances) * THRESHOLD_MULTIPLIER)


# ── Per-word processing ────────────────────────────────────────────────────────

def process_word(word_dir: Path) -> dict | None:
    parts    = word_dir.parts    # …/dataset/en/grade3/cat
    lang     = parts[-3]
    grade    = parts[-2]
    word     = parts[-1]
    grade_no = int(grade.replace("grade", ""))

    # child_01 = original recording
    original_wav = word_dir / "child_01.wav"
    if not original_wav.exists():
        return None

    # Load original
    try:
        ref_mfcc = extract_mfcc(original_wav)
    except Exception as exc:
        tqdm.write(f"  ✗  {lang}/{grade}/{word} child_01: {exc}")
        return None

    # Load augmented (child_02..20)
    aug_mfccs: list[np.ndarray] = []
    for i in range(2, N_AUGMENTED + 1):
        wav = word_dir / f"child_{i:02d}.wav"
        if not wav.exists():
            continue
        try:
            aug_mfccs.append(extract_mfcc(wav))
        except Exception as exc:
            tqdm.write(f"  ⚠️  {lang}/{grade}/{word} child_{i:02d}: {exc}")

    # Build reference from ALL available recordings (original + augmented)
    all_mfccs = [ref_mfcc] + aug_mfccs
    reference = average_mfccs(all_mfccs)   # (N_MFCC, frames)

    # Threshold: ref (child_01) distance to each augmented file
    threshold = compute_threshold(ref_mfcc, aug_mfccs)

    return {
        "word":      word,
        "language":  lang,
        "grade":     grade_no,
        "threshold": round(threshold, 6),
        "mfcc":      reference.T.tolist(),   # (frames, N_MFCC) — easier for Dart
    }


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    if not DATASET.exists():
        sys.exit("ERROR: dataset/ not found. Run scripts 1–3 first.")

    word_dirs = sorted(
        p for p in DATASET.rglob("*")
        if p.is_dir() and p.parent.parent.parent == DATASET
    )
    if not word_dirs:
        sys.exit("ERROR: No word folders found under dataset/.")

    print(f"Processing {len(word_dirs)} word folder(s) …")
    print(f"DTW: fastdtw O(n)  |  frame step: {FRAME_STEP}  |  "
          f"threshold pairs: 19 (star from child_01)\n")

    all_thresholds: dict[str, float] = {}
    success = 0
    errors:  list[str] = []

    for word_dir in tqdm(word_dirs, desc="Building references", unit="word"):
        lang  = word_dir.parts[-3]
        grade = word_dir.parts[-2]
        word  = word_dir.parts[-1]
        label = f"{word} ({lang.upper()} {grade.replace('grade', 'Grade ')})"

        try:
            result = process_word(word_dir)
        except Exception as exc:
            errors.append(f"{label}: {exc}")
            tqdm.write(f"  ✗  {label}: {exc}")
            continue

        if result is None:
            tqdm.write(f"  ⚠️  {label}: no child_01.wav, skipped")
            continue

        # Save individual JSON
        dest_dir  = REF_BASE / lang / grade
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / f"{word}.json"
        with open(dest_file, "w", encoding="utf-8") as fh:
            json.dump(result, fh, separators=(",", ":"))

        key = f"{lang}_{grade}_{word}"
        all_thresholds[key] = result["threshold"]
        success += 1

        tqdm.write(
            f"  ✓  {label:<45}  "
            f"threshold: {result['threshold']:.4f}  "
            f"frames: {len(result['mfcc'])}"
        )

    # Save consolidated thresholds.json
    thresholds_path = REF_BASE / "thresholds.json"
    thresholds_path.parent.mkdir(parents=True, exist_ok=True)
    with open(thresholds_path, "w", encoding="utf-8") as fh:
        json.dump(all_thresholds, fh, indent=2, sort_keys=True)

    print()
    print("─" * 60)
    if errors:
        print(f"⚠️  {len(errors)} error(s):")
        for e in errors:
            print(f"     • {e}")
        print()

    print(f"✅  {success} reference JSON files created under {REF_BASE}/")
    print(f"✅  {thresholds_path}  ({len(all_thresholds)} entries)")
    print(f"\nMFCC shape: (frames, {N_MFCC})  |  z-score normalized")
    print("\nNext step:  py python_scripts/5_validate.py")


if __name__ == "__main__":
    main()
