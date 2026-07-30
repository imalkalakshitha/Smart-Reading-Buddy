#!/usr/bin/env python3
"""
analyze_wav_quality.py
Quality audit for Smart Reading Buddy reference WAV files.

Run from:  e:/src/smart_reading_buddy/
    py python_scripts/analyze_wav_quality.py

Requires:  pip install librosa soundfile numpy
"""

import sys
from pathlib import Path

# Force UTF-8 output on Windows so emoji/arrows print correctly.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

import numpy as np

try:
    import librosa
except ImportError:
    sys.exit(
        "Missing dependencies. Run:\n"
        "  py -m pip install librosa soundfile numpy"
    )

WAV_DIR = Path("wav")

# ── Thresholds ─────────────────────────────────────────────────────────────────
RMS_TOO_QUIET  = 0.01
RMS_TOO_LOUD   = 0.50
RMS_IDEAL_LO   = 0.05
RMS_IDEAL_HI   = 0.30
CLIP_THRESHOLD = 0.99     # samples at ±1.0 (or very close) count as clipped
CLIP_MAX_PCT   = 1.0      # % clipped samples allowed
SILENCE_THRESH = 0.01     # RMS per frame below this → silent frame
SILENCE_MAX    = 40.0     # % silent frames allowed
SNR_MIN_DB     = 10.0     # below this → noisy
DUR_MIN        = 0.30     # seconds
DUR_MAX        = 3.00     # seconds
TARGET_SR      = 16_000


# ── Per-file analysis ──────────────────────────────────────────────────────────

def analyze_wav(path: Path) -> dict:
    try:
        y, _ = librosa.load(str(path), sr=TARGET_SR, mono=True)
    except Exception as exc:
        return {"file": path.name, "error": str(exc), "issues": ["❌ LOAD FAILED"]}

    duration = len(y) / TARGET_SR
    issues   = []

    # 1. RMS energy
    rms = float(np.sqrt(np.mean(y ** 2)))
    if rms < RMS_TOO_QUIET:
        issues.append(f"⚠️  TOO QUIET   RMS={rms:.4f} (min {RMS_TOO_QUIET})")
    elif rms > RMS_TOO_LOUD:
        issues.append(f"⚠️  TOO LOUD    RMS={rms:.4f} (max {RMS_TOO_LOUD})")

    # 2. Clipping
    clipped   = int(np.sum(np.abs(y) >= CLIP_THRESHOLD))
    clip_pct  = 100.0 * clipped / max(len(y), 1)
    if clip_pct > CLIP_MAX_PCT:
        issues.append(f"⚠️  CLIPPING    {clip_pct:.2f}% samples at ±1.0")

    # 3. Silence ratio (frame-based)
    hop = 256
    frame_rms     = librosa.feature.rms(y=y, frame_length=512, hop_length=hop)[0]
    silent_frames = int(np.sum(frame_rms < SILENCE_THRESH))
    silence_pct   = 100.0 * silent_frames / max(len(frame_rms), 1)
    if silence_pct > SILENCE_MAX:
        issues.append(f"⚠️  TOO SILENT  {silence_pct:.0f}% frames below threshold")

    # 4. SNR estimate (top-50% energy frames = speech, bottom-20% = noise)
    sorted_e     = np.sort(frame_rms)
    speech_e     = float(np.mean(sorted_e[len(sorted_e) // 2:]))
    noise_e      = float(np.mean(sorted_e[: max(len(sorted_e) // 5, 1)]))
    snr_db       = 10.0 * np.log10(speech_e / noise_e) if noise_e > 0 else float("inf")
    if snr_db < SNR_MIN_DB:
        issues.append(f"⚠️  NOISY       SNR={snr_db:.1f} dB (min {SNR_MIN_DB} dB)")

    # 5. Duration
    if duration < DUR_MIN:
        issues.append(f"⚠️  TOO SHORT   {duration:.2f}s (min {DUR_MIN}s)")
    elif duration > DUR_MAX:
        issues.append(f"⚠️  TOO LONG    {duration:.2f}s (max {DUR_MAX}s)")

    return {
        "file":        path.name,
        "duration":    duration,
        "rms":         rms,
        "clip_pct":    clip_pct,
        "silence_pct": silence_pct,
        "snr_db":      snr_db,
        "issues":      issues,
    }


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    if not WAV_DIR.exists():
        sys.exit(f"ERROR: '{WAV_DIR}/' not found. Run from smart_reading_buddy/ root.")

    wav_files = sorted(WAV_DIR.glob("*.wav")) + sorted(WAV_DIR.glob("*.WAV"))
    wav_files = sorted(set(wav_files))  # deduplicate

    if not wav_files:
        sys.exit(f"ERROR: No .wav files found in {WAV_DIR}/")

    print(f"Analyzing {len(wav_files)} WAV file(s)…\n")

    all_results    = []
    problem_files  = []

    for wf in wav_files:
        r = analyze_wav(wf)
        all_results.append(r)
        if r["issues"]:
            problem_files.append(r)

    clean = len(all_results) - len(problem_files)

    # ── Summary header ─────────────────────────────────────────────────────────
    print("=" * 70)
    print("QUALITY ANALYSIS  —  Smart Reading Buddy WAV files")
    print("=" * 70)
    print(f"  Total files   : {len(all_results)}")
    print(f"  Problem files : {len(problem_files)}")
    print(f"  Clean files   : {clean}")
    print()

    # ── Problem file details ───────────────────────────────────────────────────
    if problem_files:
        print("FILES WITH ISSUES")
        print("-" * 70)
        for r in problem_files:
            snr_str = f"{r['snr_db']:.1f} dB" if r["snr_db"] != float("inf") else "N/A"
            print(f"\n  {r['file']}")
            print(f"    Duration : {r['duration']:.2f} s")
            print(f"    RMS      : {r['rms']:.4f}")
            print(f"    SNR      : {snr_str}")
            print(f"    Silence  : {r['silence_pct']:.0f}%")
            print(f"    Clipping : {r['clip_pct']:.2f}%")
            for issue in r["issues"]:
                print(f"    {issue}")
    else:
        print("  ✅ All files passed quality checks!")

    # ── Statistics ─────────────────────────────────────────────────────────────
    valid = [r for r in all_results if "error" not in r]
    if valid:
        rms_vals = [r["rms"]     for r in valid]
        dur_vals = [r["duration"] for r in valid]
        snr_vals = [r["snr_db"]  for r in valid if r["snr_db"] != float("inf")]
        sil_vals = [r["silence_pct"] for r in valid]

        print()
        print("=" * 70)
        print("STATISTICS")
        print("=" * 70)
        print(f"  RMS      : min={min(rms_vals):.4f}  max={max(rms_vals):.4f}  avg={np.mean(rms_vals):.4f}")
        print(f"  Duration : min={min(dur_vals):.2f}s  max={max(dur_vals):.2f}s  avg={np.mean(dur_vals):.2f}s")
        print(f"  Silence  : min={min(sil_vals):.0f}%  max={max(sil_vals):.0f}%  avg={np.mean(sil_vals):.0f}%")
        if snr_vals:
            print(f"  SNR      : min={min(snr_vals):.1f} dB  max={max(snr_vals):.1f} dB  avg={np.mean(snr_vals):.1f} dB")

        # Ideal-range summary
        too_quiet  = sum(1 for r in valid if r["rms"] < RMS_TOO_QUIET)
        ideal_rms  = sum(1 for r in valid if RMS_IDEAL_LO <= r["rms"] <= RMS_IDEAL_HI)
        too_loud   = sum(1 for r in valid if r["rms"] > RMS_TOO_LOUD)
        print()
        print(f"  RMS buckets  →  ideal ({RMS_IDEAL_LO}–{RMS_IDEAL_HI}): {ideal_rms}  "
              f"too-quiet (<{RMS_TOO_QUIET}): {too_quiet}  "
              f"too-loud (>{RMS_TOO_LOUD}): {too_loud}")

    # ── Recommendations ────────────────────────────────────────────────────────
    print()
    print("=" * 70)
    print("RECOMMENDATIONS")
    print("=" * 70)
    if valid:
        avg_rms = float(np.mean([r["rms"] for r in valid]))
        avg_snr = float(np.mean([r["snr_db"] for r in valid if r["snr_db"] != float("inf")])) if snr_vals else None
        noisy_count = sum(1 for r in valid if r["snr_db"] < SNR_MIN_DB)

        if avg_rms < RMS_IDEAL_LO:
            print(f"  ⚠️  Average RMS {avg_rms:.4f} is below ideal ({RMS_IDEAL_LO}).")
            print("      → Re-record closer to the mic, or apply peak-normalization.")
        elif avg_rms > RMS_IDEAL_HI:
            print(f"  ⚠️  Average RMS {avg_rms:.4f} is above ideal ({RMS_IDEAL_HI}).")
            print("      → Lower recording gain or apply peak-normalization.")
        else:
            print(f"  ✅ Average RMS {avg_rms:.4f} is in the ideal range.")

        if avg_snr is not None and avg_snr < SNR_MIN_DB:
            print(f"  ⚠️  Average SNR {avg_snr:.1f} dB is below {SNR_MIN_DB} dB.")
            print("      → Record in a quieter environment or apply noise reduction.")
        elif avg_snr is not None:
            print(f"  ✅ Average SNR {avg_snr:.1f} dB is acceptable.")

        if len(problem_files) > 10:
            print(f"  ⚠️  {len(problem_files)} files have issues.")
            print("      → Consider re-recording problem words before rebuilding references.")
        elif problem_files:
            print(f"  ℹ️  {len(problem_files)} file(s) have minor issues — review individually above.")

        if noisy_count:
            print(f"  ⚠️  {noisy_count} file(s) have low SNR.")
            print("      → Run noise-reduction (e.g. noisereduce library) before rebuild.")

        if not problem_files:
            print("  ✅ All files look good. Safe to rebuild references.")

    print()


if __name__ == "__main__":
    main()
