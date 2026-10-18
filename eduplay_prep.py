#!/usr/bin/env python3
"""
EduPlay preparation script — Smart Reading Buddy (R26-IT-069)

Runs ONCE on the developer machine. Produces three Flutter assets:

  assets/eduplay/rf_model.json        pruned Random Forest, ready for Dart
  assets/eduplay/eduplay_tasks.json   875 unique content tasks (seed data)
  assets/eduplay/audio_audit.json     which referenced audio files exist

Usage (from project root):

  python eduplay_prep.py \
      --pkl   "dataset/final_next_lesson_model_1_.pkl" \
      --csv   "dataset/final_ml_recommendation_dataset_corrected.csv" \
      --words "dataset" \
      --sent  "indeepa wav" \
      --out   "assets/eduplay"

All arguments have defaults; run with no arguments to use them.
Requires: pandas, scikit-learn, numpy, joblib
"""

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import joblib
from sklearn.base import clone
from sklearn.model_selection import train_test_split


# --------------------------------------------------------------------------
# Configuration — the pruned forest. 30 trees at depth 8 scores within
# 0.7pp of the original 200x12 forest while being ~18x smaller on disk.
# --------------------------------------------------------------------------
PRUNED_N_ESTIMATORS = 30
PRUNED_MAX_DEPTH = 8
LABEL_COLUMN = "next_recommended_activity"

# Columns copied verbatim into the task seed. Everything the child-side
# activity screens need in order to render a task.
TASK_COLUMNS = [
    "task_id", "activity_type", "lesson_number", "lesson_name",
    "language", "grade", "level", "difficulty",
    "target_text", "prompt_text",
    "audio_type", "audio_asset_folder", "audio_filename",
    "tile_items", "scrambled_items", "decoy_items", "options",
    "correct_answer", "correct_order",
    "blank_text", "missing_answer", "missing_position",
    "question_text", "question_type",
    "semantic_subject", "semantic_action", "semantic_object",
    "skill_area", "target_error_type", "category",
    "buddy_positive", "buddy_corrective",
]

# Columns stored as JSON lists rather than raw strings.
LIST_COLUMNS = ["tile_items", "scrambled_items", "decoy_items",
                "options", "correct_order"]


def log(msg=""):
    print(msg, flush=True)


def section(title):
    log()
    log("=" * 68)
    log(f"  {title}")
    log("=" * 68)


# --------------------------------------------------------------------------
# 1. Train the pruned forest
# --------------------------------------------------------------------------
def train_pruned(pipeline, df):
    numeric_cols = list(pipeline.named_steps["preprocessor"].transformers_[0][2])
    categorical_cols = list(pipeline.named_steps["preprocessor"].transformers_[1][2])
    feature_cols = numeric_cols + categorical_cols

    missing = [c for c in feature_cols + [LABEL_COLUMN] if c not in df.columns]
    if missing:
        raise SystemExit(f"CSV is missing required columns: {missing}")

    X = df[feature_cols]
    y = df[LABEL_COLUMN]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # The shipped .pkl was fitted on rows that fall inside our test split,
    # so scoring it here flatters it. Retrain at the original settings on
    # our own split to get an honest like-for-like baseline.
    shipped_acc = float((pipeline.predict(X_test) == y_test).mean())

    baseline = clone(pipeline)
    baseline.fit(X_train, y_train)
    original_acc = float((baseline.predict(X_test) == y_test).mean())

    pruned = clone(pipeline)
    pruned.set_params(
        classifier__n_estimators=PRUNED_N_ESTIMATORS,
        classifier__max_depth=PRUNED_MAX_DEPTH,
    )
    pruned.fit(X_train, y_train)
    holdout_acc = float((pruned.predict(X_test) == y_test).mean())

    # Refit on everything for the model we actually ship.
    shipped = clone(pruned)
    shipped.fit(X, y)

    nodes = sum(t.tree_.node_count
                for t in shipped.named_steps["classifier"].estimators_)

    log(f"  supplied .pkl on our split (leaky) : {shipped_acc:.4f}  <- not comparable")
    log(f"  baseline 200 x 12, same split      : {original_acc:.4f}")
    log(f"  pruned {PRUNED_N_ESTIMATORS} x {PRUNED_MAX_DEPTH}, same split         : {holdout_acc:.4f}")
    log(f"  accuracy given up by pruning       : {(original_acc - holdout_acc) * 100:.2f} pp")
    log(f"  shipped model total tree nodes     : {nodes:,}")

    return shipped, numeric_cols, categorical_cols, {
        "supplied_pkl_accuracy_leaky": round(shipped_acc, 4),
        "baseline_holdout_accuracy": round(original_acc, 4),
        "pruned_holdout_accuracy": round(holdout_acc, 4),
        "n_estimators": PRUNED_N_ESTIMATORS,
        "max_depth": PRUNED_MAX_DEPTH,
        "total_nodes": nodes,
    }


# --------------------------------------------------------------------------
# 2. Serialise the model to JSON
# --------------------------------------------------------------------------
def export_model_json(pipeline, numeric_cols, categorical_cols, metrics):
    pre = pipeline.named_steps["preprocessor"]
    clf = pipeline.named_steps["classifier"]

    num_imputer = pre.named_transformers_["numeric"].named_steps["imputer"]
    cat_pipe = pre.named_transformers_["categorical"]
    cat_imputer = cat_pipe.named_steps["imputer"]
    onehot = cat_pipe.named_steps["onehot"]

    # Feature layout: all numeric columns in order, then every one-hot
    # column in categorical-column order. Dart must build the vector
    # exactly this way.
    layout = [f"num:{c}" for c in numeric_cols]
    categories = {}
    for col, cats in zip(categorical_cols, onehot.categories_):
        values = [str(v) for v in cats]
        categories[col] = values
        layout.extend(f"cat:{col}={v}" for v in values)

    trees = []
    for est in clf.estimators_:
        t = est.tree_
        # Leaf rows hold class weights; normalise so trees vote evenly.
        value = t.value.reshape(t.node_count, -1)
        totals = value.sum(axis=1, keepdims=True)
        totals[totals == 0] = 1.0
        proba = value / totals
        # Thresholds are NOT rounded. Rounding to a few decimals can send a
        # sample down the opposite branch and silently change predictions.
        trees.append({
            "l": t.children_left.astype(int).tolist(),
            "r": t.children_right.astype(int).tolist(),
            "f": t.feature.astype(int).tolist(),
            "t": [float(x) for x in t.threshold],
            "v": [[float(x) for x in row] for row in proba],
        })

    model = {
        "format_version": 1,
        "model_type": "RandomForestClassifier",
        "classes": [str(c) for c in clf.classes_],
        "numeric_columns": numeric_cols,
        "categorical_columns": categorical_cols,
        "numeric_medians": {
            c: round(float(v), 6)
            for c, v in zip(numeric_cols, num_imputer.statistics_)
        },
        "categorical_defaults": {
            c: str(v)
            for c, v in zip(categorical_cols, cat_imputer.statistics_)
        },
        "categories": categories,
        "feature_layout": layout,
        "n_features": len(layout),
        "trees": trees,
        "metrics": metrics,
    }
    return model


# --------------------------------------------------------------------------
# 3. Pure-Python inference — mirrors what Dart will do, so we can prove
#    the exported JSON reproduces scikit-learn exactly.
# --------------------------------------------------------------------------
def f32(x):
    """scikit-learn casts inputs to float32 before walking a tree, so the
    comparison `value <= threshold` happens at float32 precision. Dart uses
    64-bit doubles throughout, so we must round the same way or a handful of
    samples sitting exactly on a split boundary take the opposite branch."""
    return float(np.float32(x))


def build_vector(model, row):
    vec = []
    for col in model["numeric_columns"]:
        raw = row.get(col, None)
        if raw is None or (isinstance(raw, float) and np.isnan(raw)):
            vec.append(f32(model["numeric_medians"][col]))
        else:
            vec.append(f32(raw))

    for col in model["categorical_columns"]:
        raw = row.get(col, None)
        if raw is None or (isinstance(raw, float) and pd.isna(raw)):
            raw = model["categorical_defaults"][col]
        raw = str(raw)
        for value in model["categories"][col]:
            # Unknown values leave every slot at 0 — matches
            # OneHotEncoder(handle_unknown="ignore").
            vec.append(1.0 if raw == value else 0.0)
    return vec


def predict(model, row):
    vec = build_vector(model, row)
    n_classes = len(model["classes"])
    totals = [0.0] * n_classes

    for tree in model["trees"]:
        node = 0
        while tree["l"][node] != -1:
            if vec[tree["f"][node]] <= tree["t"][node]:
                node = tree["l"][node]
            else:
                node = tree["r"][node]
        for i, p in enumerate(tree["v"][node]):
            totals[i] += p

    n_trees = len(model["trees"])
    proba = [t / n_trees for t in totals]
    best = max(range(n_classes), key=lambda i: proba[i])
    return model["classes"][best], proba[best], proba


def verify_parity(model, pipeline, df, numeric_cols, categorical_cols):
    feature_cols = numeric_cols + categorical_cols
    X = df[feature_cols]
    sk_pred = pipeline.predict(X)
    sk_proba = pipeline.predict_proba(X)

    rows = X.to_dict(orient="records")
    mismatch_label = 0
    max_proba_delta = 0.0

    for i, row in enumerate(rows):
        label, _, proba = predict(model, row)
        if label != sk_pred[i]:
            mismatch_label += 1
        delta = float(np.max(np.abs(np.array(proba) - sk_proba[i])))
        max_proba_delta = max(max_proba_delta, delta)

    log(f"  rows checked                : {len(rows):,}")
    log(f"  label mismatches            : {mismatch_label}")
    log(f"  max probability difference  : {max_proba_delta:.2e}")

    if mismatch_label == 0 and max_proba_delta < 1e-6:
        log("  PARITY OK — the JSON reproduces scikit-learn exactly.")
        return True

    log("  PARITY FAILED — do not ship this model.")
    return False


# --------------------------------------------------------------------------
# 4. Extract the content bank
# --------------------------------------------------------------------------
def split_list(raw):
    if raw is None or (isinstance(raw, float) and pd.isna(raw)):
        return None
    text = str(raw).strip()
    if not text:
        return None
    for sep in ["|", ";", ","]:
        if sep in text:
            parts = [p.strip() for p in text.split(sep)]
            return [p for p in parts if p]
    return [text]


def extract_tasks(df):
    available = [c for c in TASK_COLUMNS if c in df.columns]
    tasks_df = df.drop_duplicates("task_id")[available].copy()

    tasks = []
    for record in tasks_df.to_dict(orient="records"):
        task = {}
        for key, value in record.items():
            if isinstance(value, float) and pd.isna(value):
                value = None
            elif isinstance(value, (np.integer,)):
                value = int(value)
            elif key == "missing_position" and isinstance(value, float):
                value = int(value)
            elif isinstance(value, (np.floating,)):
                value = float(value)

            if key in LIST_COLUMNS:
                task[key] = split_list(value)
            else:
                task[key] = value
        tasks.append(task)

    counts = (tasks_df.groupby(["activity_type", "language", "grade"])
              .size().reset_index(name="n"))
    log(f"  unique tasks extracted : {len(tasks)}")
    log()
    log(counts.to_string(index=False))
    return tasks


# --------------------------------------------------------------------------
# 5. Audit audio files
# --------------------------------------------------------------------------
def index_folder(folder, by_name, by_stem):
    """Index a folder recursively, both by full filename and by stem."""
    if not folder or not os.path.isdir(folder):
        log(f"  WARNING: folder not found -> {folder}")
        return 0
    count = 0
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if not name.lower().endswith((".wav", ".m4a", ".mp3", ".aac", ".ogg")):
                continue
            path = os.path.join(root, name)
            by_name.setdefault(name.lower(), path)
            by_stem.setdefault(Path(name).stem.lower(), path)
            count += 1
    return count


def audit_audio(df, words_dir, sentences_dir):
    by_name, by_stem = {}, {}
    n_words = index_folder(words_dir, by_name, by_stem)
    n_sent = index_folder(sentences_dir, by_name, by_stem)
    log(f"  audio files on disk : {n_words} in words folder, {n_sent} in sentence folder")

    referenced = (df.drop_duplicates("audio_filename")
                    [["audio_filename", "audio_asset_folder"]]
                    .dropna(subset=["audio_filename"]))

    exact, by_extension, missing = [], [], []
    for record in referenced.to_dict(orient="records"):
        name = str(record["audio_filename"])
        entry = {
            "audio_filename": name,
            "audio_asset_folder": record["audio_asset_folder"],
        }
        source = by_name.get(name.lower())
        if source:
            entry["source_path"] = source
            entry["match"] = "exact"
            exact.append(entry)
            continue
        # The dataset may reference .m4a while the recordings on disk are
        # .wav (or vice versa). Fall back to matching on the stem only.
        source = by_stem.get(Path(name).stem.lower())
        if source:
            entry["source_path"] = source
            entry["match"] = "extension_differs"
            entry["actual_filename"] = os.path.basename(source)
            by_extension.append(entry)
        else:
            entry["source_path"] = None
            entry["match"] = "missing"
            missing.append(entry)

    log(f"  referenced by tasks : {len(referenced)}")
    log(f"  matched exactly     : {len(exact)}")
    log(f"  matched by stem     : {len(by_extension)}   (extension differs)")
    log(f"  MISSING             : {len(missing)}")

    if by_extension:
        log()
        log("  Extension mismatches (dataset name -> file on disk):")
        for entry in by_extension[:5]:
            log(f"    {entry['audio_filename']} -> {entry['actual_filename']}")
        if len(by_extension) > 5:
            log(f"    ... and {len(by_extension) - 5} more")

    if missing:
        log()
        log("  Missing files:")
        for entry in missing[:15]:
            log(f"    - {entry['audio_asset_folder']}/{entry['audio_filename']}")
        if len(missing) > 15:
            log(f"    ... and {len(missing) - 15} more")

    return {
        "summary": {
            "referenced": len(referenced),
            "exact": len(exact),
            "extension_differs": len(by_extension),
            "missing": len(missing),
        },
        "exact": exact,
        "extension_differs": by_extension,
        "missing": missing,
    }


# --------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Prepare EduPlay model and content assets.")
    parser.add_argument("--pkl", default="dataset/final_next_lesson_model_1_.pkl")
    parser.add_argument("--csv", default="dataset/final_ml_recommendation_dataset_corrected.csv")
    parser.add_argument("--words", default="dataset",
                        help="Folder containing the word .wav recordings")
    parser.add_argument("--sent", default="indeepa wav",
                        help="Folder containing the sentence .m4a recordings")
    parser.add_argument("--out", default="assets/eduplay")
    parser.add_argument("--skip-audio", action="store_true")
    args = parser.parse_args()

    for path, label in [(args.pkl, "model .pkl"), (args.csv, "dataset .csv")]:
        if not os.path.isfile(path):
            raise SystemExit(f"ERROR: {label} not found at: {path}")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    section("Loading inputs")
    pipeline = joblib.load(args.pkl)
    df = pd.read_csv(args.csv)
    log(f"  dataset rows    : {len(df):,}")
    log(f"  dataset columns : {len(df.columns)}")

    section("Training pruned forest")
    shipped, numeric_cols, categorical_cols, metrics = train_pruned(pipeline, df)

    section("Exporting model to JSON")
    model = export_model_json(shipped, numeric_cols, categorical_cols, metrics)
    model_path = out_dir / "rf_model.json"
    with open(model_path, "w", encoding="utf-8") as f:
        json.dump(model, f, separators=(",", ":"))
    size_kb = model_path.stat().st_size / 1024
    log(f"  input columns   : {len(numeric_cols)} numeric + {len(categorical_cols)} categorical")
    log(f"  feature vector  : {model['n_features']} values")
    log(f"  classes         : {', '.join(model['classes'])}")
    log(f"  written         : {model_path}  ({size_kb:,.0f} KB)")

    section("Verifying JSON matches scikit-learn")
    if not verify_parity(model, shipped, df, numeric_cols, categorical_cols):
        raise SystemExit("Aborting: exported model does not match scikit-learn.")

    section("Extracting content bank")
    tasks = extract_tasks(df)
    tasks_path = out_dir / "eduplay_tasks.json"
    with open(tasks_path, "w", encoding="utf-8") as f:
        json.dump(tasks, f, ensure_ascii=False, indent=1)
    log()
    log(f"  written : {tasks_path}  ({tasks_path.stat().st_size / 1024:,.0f} KB)")

    if not args.skip_audio:
        section("Auditing audio files")
        audit = audit_audio(df, args.words, args.sent)
        audit_path = out_dir / "audio_audit.json"
        with open(audit_path, "w", encoding="utf-8") as f:
            json.dump(audit, f, ensure_ascii=False, indent=1)
        log(f"  written : {audit_path}")

    section("Done")
    log(f"  {out_dir}/rf_model.json")
    log(f"  {out_dir}/eduplay_tasks.json")
    if not args.skip_audio:
        log(f"  {out_dir}/audio_audit.json")
    log()
    log("  Next: add the assets to pubspec.yaml and build the Dart loader.")
    log()


if __name__ == "__main__":
    main()
