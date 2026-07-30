#!/usr/bin/env python3
"""
5_validate.py
80 / 20 split validation of the DTW reference templates.

  Train set  — child_01 … child_16  (used when building references)
  Test set   — child_17 … child_20  (held-out, never seen by model)

For every test recording, load the saved reference JSON, compute the
normalized FastDTW distance against the stored template, compare with
the threshold and score it. Ground truth: same word → PASS is correct.

Run from: e:/src/smart_reading_buddy/
Requires: pip install librosa soundfile numpy scipy fastdtw tqdm
"""

import json
import sys
from pathlib import Path

import numpy as np
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

DATASET    = Path("dataset")
REF_BASE   = Path("assets/audio/reference")
TARGET_SR  = 16_000
N_MFCC     = 13
HOP        = 160
N_FFT      = 512             # must match Dart _nFft=512
WIN_LENGTH = 400             # must match Dart _winLen=400
TEST_RANGE = range(17, 21)   # child_17 … child_20
FRAME_STEP = 2               # must match 4_build_references.py


# ── MFCC helpers ───────────────────────────────────────────────────────────────

def extract_mfcc(path: Path) -> np.ndarray:
    """Return normalized MFCC, shape (N_MFCC, frames)."""
    audio, _ = sf.read(str(path), dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)   # stereo → mono
    mfcc = librosa.feature.mfcc(
        y=audio, sr=TARGET_SR,
        n_mfcc=N_MFCC, hop_length=HOP, n_fft=N_FFT, win_length=WIN_LENGTH,
    )
    mean = mfcc.mean(axis=1, keepdims=True)
    std  = mfcc.std(axis=1, keepdims=True) + 1e-8
    return ((mfcc - mean) / std).astype(np.float32)


def dtw_distance_normalized(query: np.ndarray, reference: np.ndarray) -> float:
    """FastDTW distance, decimated and normalized by warping-path length."""
    sq = query.T[::FRAME_STEP]
    sr = reference.T[::FRAME_STEP]
    dist, path = fastdtw(sq, sr, dist=euclidean)
    return float(dist) / len(path)


def load_reference(lang: str, grade: str, word: str) -> dict | None:
    ref_path = REF_BASE / lang / grade / f"{word}.json"
    if not ref_path.exists():
        return None
    with open(ref_path, encoding="utf-8") as fh:
        data = json.load(fh)
    # stored as (frames, N_MFCC) → convert back to (N_MFCC, frames) for DTW
    data["mfcc_array"] = np.array(data["mfcc"], dtype=np.float32).T
    return data


# ── Stats helper ───────────────────────────────────────────────────────────────

class Stats:
    def __init__(self) -> None:
        self.correct = 0
        self.total   = 0

    def update(self, passed: bool) -> None:
        self.total   += 1
        self.correct += int(passed)

    @property
    def accuracy(self) -> float:
        return 100.0 * self.correct / self.total if self.total else 0.0

    def __str__(self) -> str:
        return f"{self.accuracy:.1f}%  ({self.correct}/{self.total})"


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    if not DATASET.exists():
        sys.exit("ERROR: dataset/ not found.")
    if not REF_BASE.exists():
        sys.exit("ERROR: assets/audio/reference/ not found. "
                 "Run 4_build_references.py first.")

    word_dirs = sorted(
        p for p in DATASET.rglob("*")
        if p.is_dir() and p.parent.parent.parent == DATASET
    )
    if not word_dirs:
        sys.exit("ERROR: No word folders found under dataset/.")

    print(f"Validating {len(word_dirs)} word(s) with test files child_17…20\n")

    overall                     = Stats()
    by_group: dict[str, Stats]  = {}
    per_word: dict[str, dict]   = {}
    skipped:  list[str]         = []

    for word_dir in tqdm(word_dirs, desc="Validating", unit="word"):
        lang  = word_dir.parts[-3]
        grade = word_dir.parts[-2]
        word  = word_dir.parts[-1]
        group = f"{lang}_{grade}"
        label = f"{word} ({lang.upper()} {grade.replace('grade', 'Grade ')})"

        ref = load_reference(lang, grade, word)
        if ref is None:
            tqdm.write(f"  ⚠️  No reference JSON for {label} — skipped")
            skipped.append(label)
            continue

        ref_mfcc  = ref["mfcc_array"]
        threshold = ref["threshold"]

        if group not in by_group:
            by_group[group] = Stats()

        word_stats = Stats()

        for child_no in TEST_RANGE:
            test_file = word_dir / f"child_{child_no:02d}.wav"
            if not test_file.exists():
                continue

            try:
                query_mfcc = extract_mfcc(test_file)
            except Exception as exc:
                tqdm.write(f"  ✗  {label}/child_{child_no:02d}: {exc}")
                continue

            dist   = dtw_distance_normalized(query_mfcc, ref_mfcc)
            passed = dist <= threshold

            word_stats.update(passed)
            by_group[group].update(passed)
            overall.update(passed)

            if not passed:
                tqdm.write(
                    f"  ✗  {label}  child_{child_no:02d}  "
                    f"dist={dist:.4f}  threshold={threshold:.4f}"
                )

        per_word[label] = {
            "correct":  word_stats.correct,
            "total":    word_stats.total,
            "accuracy": round(word_stats.accuracy, 1),
        }

    # ── Report ─────────────────────────────────────────────────────────────────
    lines: list[str] = []

    def pr(line: str = "") -> None:
        print(line)
        lines.append(line)

    pr()
    pr("=" * 60)
    pr("VALIDATION REPORT — Smart Reading Buddy DTW References")
    pr("=" * 60)
    pr()

    GROUP_LABELS = {
        "en_grade3": "EN Grade 3",
        "en_grade4": "EN Grade 4",
        "si_grade3": "SI Grade 3",
        "si_grade4": "SI Grade 4",
    }
    for key in ["en_grade3", "en_grade4", "si_grade3", "si_grade4"]:
        s = by_group.get(key)
        if s and s.total:
            pr(f"  {GROUP_LABELS[key]:<15}  {s}")

    pr()
    pr(f"  {'Overall':<15}  {overall}")
    pr()
    pr("─" * 60)
    pr(f"  Test split:   child_17 … child_20 per word")
    pr(f"  Words tested: {len(per_word)}")
    if skipped:
        pr(f"  Words skipped (no reference): {len(skipped)}")
    pr()

    # Words below 75 %
    weak = {
        lbl: info for lbl, info in per_word.items()
        if info["total"] > 0 and info["accuracy"] < 75.0
    }
    if weak:
        pr("  Words below 75% accuracy:")
        for lbl, info in sorted(weak.items(), key=lambda x: x[1]["accuracy"]):
            pr(f"    • {lbl:<45} {info['accuracy']:.1f}%")
        pr()

    pr("=" * 60)

    report_path = Path("validation_report.txt")
    report_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n✅  Report saved → {report_path}")

    if overall.total == 0:
        print("\n⚠️  No test files found (child_17…20). "
              "Run 3_augment_voices.py first.")


if __name__ == "__main__":
    main()
