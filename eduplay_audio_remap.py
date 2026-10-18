#!/usr/bin/env python3
"""
EduPlay audio remap — Smart Reading Buddy (R26-IT-069)

Patches assets/eduplay/eduplay_tasks.json in-place so every task points to
a real audio file that already exists in this project.

Word audio  — dataset/<lang>/<grade>/<word>/child_NN.wav
              Speaker is chosen deterministically from the task_id hash so
              the same task always plays the same child, but different tasks
              play different speakers.

Sentence audio — indeepa wav/<filename>.wav
              Mapped via normalised text matching (English) or a
              manually-verified transliteration table (Sinhala).

Tasks whose audio cannot be resolved get  audio_available: false  and are
NOT removed — the UI hides the 🔊 button for those tasks; everything else
(drag-drop, validation, buddy text) still works.

Usage (from project root):

  python eduplay_audio_remap.py
  python eduplay_audio_remap.py --tasks "assets/eduplay/eduplay_tasks.json" \\
                                 --words "dataset" \\
                                 --sent  "indeepa wav"

Requires: nothing beyond the Python standard library.
"""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path


# Force UTF-8 output so Sinhala characters don't crash on Windows cp1252
import sys as _sys, io as _io
if hasattr(_sys.stdout, 'buffer') and _sys.stdout.encoding.lower() not in ('utf-8','utf8'):
    _sys.stdout = _io.TextIOWrapper(_sys.stdout.buffer, encoding='utf-8', errors='replace')
del _sys, _io

AUDIO_EXTENSIONS = (".wav", ".m4a", ".mp3", ".aac", ".ogg")

# ------------------------------------------------------------------
# Grade folder names on disk
# ------------------------------------------------------------------
GRADE_FOLDERS = {
    "Grade 3": ["grade3"],
    "Grade 4": ["grade4"],
}
LANG_FOLDERS = {
    "English": ["en"],
    "Sinhala": ["si"],
}

# ------------------------------------------------------------------
# Sinhala word transliteration table
# Sinhala script (CSV target_text) — disk folder name
# ------------------------------------------------------------------
SI_WORD_TO_FOLDER = {
    'අත්සන': 'athsana',
    'අවධානය': 'awadhaanaya',
    'අවබෝධය': 'awabodhaya',
    'ආරක්ෂාව': 'aarakshaawa',
    'ඇස': 'asa',
    'ඊතලය': 'eethalaya',
    'උදැල්ල': 'udalla',
    'උර': 'ura',
    'එක': 'eka',
    'ඔය': 'oya',
    'කැමැත්ත': 'kemaththa',
    'කිරිබත්': 'kiribath',
    'කෙසෙල්': 'kesel',
    'ගම': 'gama',
    'ගායනය': 'gaayanaya',
    'ගැහැනිය': 'gehaniya',
    'ගුරුතුමා': 'guruthuma',
    'චීනය': 'cheenaya',
    'ජනතාව': 'janathaawa',
    'තාරාවා': 'thaaraawa',
    'තීන්ත': 'theentha',
    'තොවිලය': 'thowilaya',
    'නිගමනය': 'nigamanaya',
    'නියර': 'niyara',
    'නිර්මාණශීලී': 'nirmaanasheelee',
    'ප්‍රයත්නය': 'prayathnaya',
    'ප්‍රායෝගික': 'praayoogika',
    'පැන්සල්': 'pencil',
    'පිළිහුඩුවා': 'pilihuduwa',
    'පූජාව': 'poojaawa',
    'බෑගය': 'baegaya',
    'මුහුද': 'muhuda',
    'රූපකය': 'rupakaya',
    'වරලස': 'waralasa',
    'විචාරය': 'wichaaraya',
    'විස්තරය': 'wistharaya',
    'වේවැල': 'wewela',
    'සංකල්ප': 'sankalpa',
    'සංවාදය': 'sanwaadaya',
    'සංවිධානය': 'sanvidhaanaya',
    'සම්පූර්ණ': 'sampoorna',
    'සිංහයා': 'sinhaya',
    'සීගිරිය': 'sigiriya',
    'සෞඛ්‍යය': 'saukhya',
}

# ------------------------------------------------------------------
# Sinhala sentence transliteration table
# Sinhala script (CSV target_text) — disk filename (without path)
# Manually verified by reading both lists in parallel.
# ------------------------------------------------------------------
SI_SENT_TO_FILE = {
    'අක්කා පොතක් කියවයි': 'akka_pothak_kiyawayi.wav',
    'අක්කා මුදල අරගනියි': 'akka_midula_athugayi.wav',
    'අක්කාගේ දුඹුරු පාට හැට්ටය ලස්සනයි': 'akkage_dumburu_paata_haettaya_lassanai.wav',
    'අද උදේ කිරි බිව්වෙමි': 'ada_udae_kiri_beewemi.wav',
    'අපි ඉස්කෝලේ නිවාඩුවට ගමට ගියෙමු': 'api_iskole_niwaduwata_gamata_giyemu.wav',
    'අපි පරිසරය පිරිසිදුව තබා ගත යුතුය': 'api_parisaraya_pirisiduwa_thaba_gatha_yuthuya.wav',
    'අපි සෙල්ලම් කරමු': 'api_sellam_karamu.wav',
    'අපි හැමෝම එකට එකතු වී වැඩකරමු': 'api_haemoma_ekata_ekathu_wee_wadakaramu.wav',
    'අම්මා බත් උයයි': 'amma_bath_uyayi.wav',
    'අම්මා මට බත් කවයි': 'amma_mata_bath_kawayi.wav',
    'අම්මා මට ලස්සන කතන්දර කියාදෙයි': 'amma_mata_lassana_kathandara_kiyadei.wav',
    'අම්මා මට සීනි මුරුක්කු ගෙනත් දුන්නාය': 'amma_mata_sini_murukku_genath_dunnaya.wav',
    'අම්මා රසට කෑම උයයි': 'amma_rasata_kaema_uyayi.wav',
    'අයියා බයිසිකල් තරගයෙන් දිනුවේය': 'ayiya_baisikal_tharagayen_dinuweya.wav',
    'අහසේ වලාකුළු අතරින් හඳ පෙනෙයි': 'ahase_walakulu_atharin_handa_peneyi.wav',
    'ඇය ගසක් සිටුවයි': 'aya_gasak_situwai.wav',
    'ඇය වල් පැළ ගලවයි': 'aya_wal_pela_galawayi.wav',
    'ඈත අහසේ ඉර පායාගෙන එයි': 'aetha_ahase_ira_paayaagena_eyi.wav',
    'උදෑසන අවදි වී දෙමාපියන් වඳින්නෙමු': 'udaesana_awadi_wee_demapiyan_wandinemi.wav',
    'ඔවුහු ගෙදර ආවෝය': 'owuhu_gedara_awoya.wav',
    'ඔහු පාඩම් කරයි': 'ohu_paadam_karayi.wav',
    'ඔහු පොතක් කියවයි': 'ohu_pothak_kiyawayi.wav',
    'කමලා පන්තියට ආවාය': 'kamala_panthiyata_awaya.wav',
    'කළු බල්ලා බුරමින් දුවයි': 'kalu_ballaa_buramin_duwayi.wav',
    'කෑමට පෙර අත් සබන් දා සෝදන්න': 'kaemata_pera_ath_saban_daa_sodanna.wav',
    'කුඩා ළමයි මිදුලේ සතුටින් සෙල්ලම්කරති': 'kuda_lamai_midule_sathutin_sellamkarathi.wav',
    'කුරුල්ලෝ රංචුවක් සර සර ගාමින් ඉගිලී ගියෝය': 'kurullo_ranchuwak_sara_sara_gaamin_igilee_giyoya.wav',
    'ගගේ මාළුන් පිහිනමින් සිටියි': 'gange_malun_peenamin_sitiyi.wav',
    'ගමේ වැවේ ඕලු, නෙළුම්, මානෙල් පිපී බැබළෙයි': 'game_wawe_olu_nelum_maanel_pipee_hinaheyi.wav',
    'ගස උඩ සිටින කුරුල්ලා ගීත ගයයි': 'gasa_uda_sitina_kurulla_geetha_gayai.wav',
    'ගුරුතුමා කතාවක් කියවයි': 'guruthuma_kathawak_kiyawayi.wav',
    'ගුරුතුමිය අපට අලුත් පාඩම් කියාදෙයි': 'guruthumiya_apata_aluth_paadam_kiyadei.wav',
    'තාත්තා ගෙදර වැඩ කරයි': 'thaththa_gedara_wada_karayi.wav',
    'තාත්තා මට දුන් ප්‍රහේලිකාව විසඳා අවසන් කළෙමි': 'thaththa_mata_dun_prahelikawa_wisada_awasan_kalemi.wav',
    'නංගී පාට පැන්සල් වලින් ලස්සනට අඳියි': 'nangi_paata_pansal_walin_lassanata_andiyi.wav',
    'නැන්දා රෙදි සෝදයි': 'nenda_redi_sodayi.wav',
    'පිළිහුඩුවා උස අත්තක නැග වටපිට බලමින් සිටියි': 'pilihuduwa_usa_aththaka_nagee_watapita_balamIn_sitiyi.wav',
    'පොත් කියවීමෙන් අපේ දැනුම වැඩි වෙයි': 'poth_kiyawimen_ape_daenum_wadi_weyi.wav',
    'පොත් කියවීමෙන් මිනිසා සම්පූර්ණ වෙයි': 'poth_kiyawimen_minisa_sampurna_weyi.wav',
    'මම ගමට යමි': 'mama_gamata_yami.wav',
    'මම තනියම වැඩ කරමි': 'mama_thaniyama_wada_karami.wav',
    'මම පාසල් ගොස් හොඳින් ඉගෙනගනිමි': 'mama_pasal_gos_hondin_igenaganimi.wav',
    'මම පාසල් යන්න කැමතියි': 'mama_pasal_yanna_kemathiyi.wav',
    'මම මගේ පාසල් නිල ඇඳුම අඳින්නෙමි': 'mama_mage_pasal_nila_anduma_andinnemi.wav',
    'මම රස කෙසෙල් කමි': 'mama_rasa_kesel_kami.wav',
    'මල්ලි ඈතට දුවයි': 'malli_aethata_duwayi.wav',
    'මල්ලි සෙල්ලම් බඩු ගනියි': 'malli_sellam_badu_ganiyi.wav',
    'මාමා බසය පදවයි': 'maama_basaya_padawayi.wav',
    'යහළුවෝ පොහොය දිනයට පන්සල් යති': 'yahaluwo_pohoya_dinayata_pansal_yathi.wav',
    'රෑට අහසේ තරු පායයි': 'raeta_ahase_tharu_paayayi.wav',
    'වත්තේ ලස්සන රතු පාට මල් පිපෙයි': 'watthe_lassana_rathu_paata_mal_pipei.wav',
    'වැඩ අවසන් කර මම පොත් අසුරමි': 'wada_awasan_kara_mama_poth_asurami.wav',
    'වැස්ස වෙලාවට කුඩය ගනිමු': 'wessa_welawata_kudaya_ganimi.wav',
    'විමල් මලක් කැඩුවේය': 'wimal_malak_keduweya.wav',
    'වේගයෙන් එන මුහුදු රැල්ලක් ගලක හැපී විසිරි යයි': 'wegayen_ena_muhudu_raellak_galaka_haepi_wisiree_yayi.wav',
    'සඳ අහසේ තරුත් එක්ක ලස්සනට සිනාසෙයි': 'sanda_ahase_tharuth_ekka_lassanata_sinaaseyi.wav',
    'සැඩ සුළඟට ගස් වේගයෙන් සෙලවෙයි': 'seda_sulangata_gas_wegayen_selaweyi.wav',
    'සුදු පූසා කිරි බොයි': 'sudu_poosa_kiri_boyi.wav',
    'සේපාලිකා මල් රෑට පිපී සුවඳ හමයි': 'sepalika_mal_raeta_pipee_suwanda_hamayi.wav',
    'හිරු උදේට පායමින් එයි': 'hiru_udeta_paayamin_eyi.wav',
}


def log(msg=""):
    print(msg, flush=True)


def section(title):
    log()
    log("=" * 68)
    log(f"  {title}")
    log("=" * 68)


# ------------------------------------------------------------------
# Build word index: {(lang_folder, grade_folder, word_folder): [paths]}
# ------------------------------------------------------------------
def index_words(root):
    index = {}
    if not os.path.isdir(root):
        log(f"  WARNING: words folder not found -> {root}")
        return index
    for lang_dir in sorted(os.listdir(root)):
        lang_path = os.path.join(root, lang_dir)
        if not os.path.isdir(lang_path):
            continue
        for grade_dir in sorted(os.listdir(lang_path)):
            grade_path = os.path.join(lang_path, grade_dir)
            if not os.path.isdir(grade_path):
                continue
            for word_dir in sorted(os.listdir(grade_path)):
                word_path = os.path.join(grade_path, word_dir)
                if not os.path.isdir(word_path):
                    continue
                files = sorted(
                    f for f in os.listdir(word_path)
                    if f.lower().endswith(AUDIO_EXTENSIONS)
                )
                if files:
                    key = (lang_dir.lower(), grade_dir.lower(),
                           word_dir.lower())
                    index[key] = [
                        os.path.join(word_path, f).replace("\\", "/")
                        for f in files
                    ]
    log(f"  word index: {len(index)} (lang, grade, word) entries, "
        f"{sum(len(v) for v in index.values())} files")
    return index


# ------------------------------------------------------------------
# Build sentence index: {stem_normalised: path}
# ------------------------------------------------------------------
def _norm(s):
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def index_sentences(root):
    index = {}
    if not os.path.isdir(root):
        log(f"  WARNING: sentences folder not found -> {root}")
        return index
    for dirpath, _dirs, files in os.walk(root):
        for name in sorted(files):
            if name.lower().endswith(AUDIO_EXTENSIONS):
                stem = Path(name).stem
                path = os.path.join(dirpath, name).replace("\\", "/")
                index[name.lower()] = path
                index[_norm(stem)] = path
    log(f"  sentence index: {len(index) // 2} files (indexed by name + normalised stem)")
    return index


# ------------------------------------------------------------------
# Speaker selection: deterministic from task_id
# ------------------------------------------------------------------
def pick_speaker(task_id, files):
    digest = int(hashlib.md5(task_id.encode()).hexdigest(), 16)
    return files[digest % len(files)]


# ------------------------------------------------------------------
# Resolve a single task to an audio path
# ------------------------------------------------------------------
def resolve_word(task, word_index):
    lang = task.get("language", "")
    grade = task.get("grade", "")
    text = (task.get("target_text") or "").strip().lower()

    lang_folders = LANG_FOLDERS.get(lang, [lang.lower()])
    grade_folders = GRADE_FOLDERS.get(grade, [grade.lower().replace(" ", "")])

    # English: folder name = lowercased word
    # Sinhala: look up transliteration table first, fallback to lowercase
    if lang == "Sinhala":
        folder = SI_WORD_TO_FOLDER.get(task.get("target_text", "").strip(), text)
    else:
        folder = text

    for lf in lang_folders:
        for gf in grade_folders:
            key = (lf, gf, folder)
            files = word_index.get(key)
            if files:
                return pick_speaker(task["task_id"], files), None

    # Cross-language fallback: some Sinhala words map to a folder that only
    # exists under the English subtree (e.g. පැන්සල් -> pencil).
    # If the primary search failed, try every lang folder we have.
    all_lang_folders = list({lf for langs in LANG_FOLDERS.values() for lf in langs})
    for lf in all_lang_folders:
        for gf in grade_folders:
            key = (lf, gf, folder)
            files = word_index.get(key)
            if files:
                return pick_speaker(task["task_id"], files), None

    return None, f"word folder not found: lang={lang} grade={grade} word={folder}"


def resolve_sentence(task, sent_index):
    lang = task.get("language", "")
    text = (task.get("target_text") or "").strip()

    if lang == "Sinhala":
        fname = SI_SENT_TO_FILE.get(text)
        if fname:
            path = sent_index.get(fname.lower())
            if path:
                return path, None
        return None, f"Sinhala sentence not in table: {text[:40]}"

    # English: normalised text match
    key = _norm(text)
    path = sent_index.get(key)
    if path:
        return path, None

    # Fuzzy fallback via difflib
    import difflib
    close = difflib.get_close_matches(key, sent_index.keys(), n=1, cutoff=0.82)
    if close:
        return sent_index[close[0]], f"fuzzy match: [{text}] -> [{close[0]}]"

    return None, f"sentence not found: {text[:60]}"


def resolve(task, word_index, sent_index):
    atype = task.get("audio_type", "")
    if atype == "word":
        return resolve_word(task, word_index)
    if atype == "sentence":
        return resolve_sentence(task, sent_index)
    return None, f"unknown audio_type: {atype}"


# ------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Patch eduplay_tasks.json with real audio paths.")
    parser.add_argument("--tasks", default="assets/eduplay/eduplay_tasks.json")
    parser.add_argument("--words", default="dataset")
    parser.add_argument("--sent", default="indeepa wav")
    args = parser.parse_args()

    if not os.path.isfile(args.tasks):
        raise SystemExit(f"ERROR: tasks file not found -> {args.tasks}")

    section("Indexing audio corpora")
    word_index = index_words(args.words)
    sent_index = index_sentences(args.sent)

    section("Loading tasks")
    with open(args.tasks, encoding="utf-8") as f:
        tasks = json.load(f)
    log(f"  {len(tasks)} tasks loaded")

    section("Resolving audio paths")
    resolved = skipped = 0
    warnings = []

    for task in tasks:
        path, warn = resolve(task, word_index, sent_index)
        if path:
            task["audio_path"] = path
            task["audio_available"] = True
            resolved += 1
        else:
            task["audio_path"] = None
            task["audio_available"] = False
            skipped += 1
            if warn:
                warnings.append(f"  {task['task_id']:30s} {warn}")

    log(f"  resolved        : {resolved}")
    log(f"  audio_available=false : {skipped}")

    if warnings:
        log()
        log("  Warnings (tasks with no audio — 🔊 button will be hidden):")
        for w in warnings:
            log(w)

    section("Writing patched tasks")
    with open(args.tasks, "w", encoding="utf-8") as f:
        json.dump(tasks, f, ensure_ascii=False, indent=1)
    size_kb = Path(args.tasks).stat().st_size / 1024
    log(f"  written: {args.tasks}  ({size_kb:,.0f} KB)")

    section("Done")
    log(f"  {resolved}/{len(tasks)} tasks have real audio paths.")
    log(f"  {skipped} tasks will hide the 🔊 button (no matching file found).")
    log()


if __name__ == "__main__":
    main()
