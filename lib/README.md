# lib/ — folder map

Smart Reading Buddy is organised **feature-first**: each team function has
its own folder under `features/`, and code used by more than one feature
lives in `core/`.

## The one rule

- A feature may import **its own folder** and **`core/`** — never another
  feature's folder.
- `core/` doesn't import features. The only exceptions are the **app shell**
  files that navigate into features: `main.dart`,
  `core/router/app_router.dart`, `core/screens/home_screen.dart` and
  `core/screens/parent_dashboard_screen.dart`.
- If something you're adding is needed by a second feature, move it to
  `core/` instead of importing across features.
- Use `package:smart_reading_buddy/...` imports (no relative `../` imports).

## Folder map and owners

| Folder | What's in it | Owner |
|---|---|---|
| `main.dart` | App entry point (app shell) | shared |
| `config/` | `api_keys.example.dart` (tracked). Copy it to `api_keys.dart`, which is **gitignored**, and add your keys | shared |
| `core/router/` | `AppRouter` — every named route (app shell) | shared |
| `core/screens/` | Splash, language, profile select / create, child PIN, Home (app shell), Parent dashboard (parents' hub, app shell), Calibration insights (opened from Home and Parent) | shared |
| `core/models/` | `AppState`, `AppColors`, `AppText`, `LocalStorage`, `PronunciationResult`, `TimedReadingSession` | shared |
| `core/services/` | `SessionLogger` (owns `reading_buddy.db` and its migrations), `BleCommandService`, `CmuPhonemeLookup`, `PracticeSuggestionService`, `EduPlayProfileMapper` | shared |
| `core/services/speech/` | Hybrid pronunciation scorer, Gemini / Groq / DTW (`pronunciation_scorer`) / simple scorers, Timed Reading speech bridge, audio preprocessor | **Pronunciation function (Imalka)** — see note below |
| `core/services/numbers/` | Numbers level config and unlock rules shared with Parent: `LevelConfig` / `LevelRepository` (levels.json, practice_activities.json), `LevelProgressRules`, `LearnerGrade` | Numbers feature (in core because Parent analytics uses them) |
| `core/dao/` | DAOs shared by more than one feature: `EduPlayDatabase`, `FreeDrawingDao`, `TimedReadingDao`, `NumberLearningDao`, `NumberPracticeDao` | shared (each DAO's feature owns its own table) |
| `core/data/` | Shared data: word lists, substitution tips, cross-language phoneme map, Timed Reading sentences, `NumbersData` (number words, -teen/-ty pairs, Number Words levels) | shared |
| `core/widgets/` | Shared widgets: `ComingSoonPlaceholder`, `LoadingDots`, `PhonemeImageWidget` (mouth pictures — see note below) (+ unused `MascotReaction`, `SmartBuddyButton`) | shared; `PhonemeImageWidget` is **Pronunciation function (Imalka)** |
| `features/pronunciation/` | Pronunciation, calibration and Timed Reading — screens, services (calibration, coaching, phoneme substitution, word diff), data, widgets | Pronunciation function — Imalka |
| `features/eduplay_encoding/` | EduPlay (engine, RF model, task repository, screens) and Encoding (word / sentence building) | EduPlay + Encoding function — _(add name)_ |
| `features/writing/` | Free Drawing recognition, scribble guard, tracing and writing progress screens | Writing function — _(add name)_ |
| `features/reading/` | Reading module placeholder screens (still hidden in the app) and its data | Reading function — _(add name)_ |
| `features/numbers/` | Numbers hub: Number Words, Rapid Digit Naming, Number Learning (8 activity types), Spell Number Words, Number Match, Read & Answer — screens, services (question generators, checkers, RAN listener), data | shared Numbers feature — _(add name)_ |
| `features/parent/` | Parent PIN, per-feature analytics screens (incl. Numbers), Numbers summary calculations, PDF report, cross-language analyzer | Parent / analytics — _(add name)_ |

### Note: `core/services/speech/` is owned by Pronunciation

The speech engine (the hybrid scorer, the Gemini / Groq / DTW / simple
scorers, the speech bridge and the audio preprocessor) belongs to the
**Pronunciation function (Imalka)**. It lives in `core/` only because the
Numbers feature also uses it: Number Words is scored by the hybrid scorer,
and Rapid Digit Naming uses the speech bridge's STT availability check.
Changes to these files should be agreed with the Pronunciation owner.

### Note: `core/widgets/phoneme_image_widget.dart` is owned by Pronunciation

Pronunciation's mouth guide ("Watch how to say it") and its phoneme →
mouth picture mapping (`getImageForPhoneme`, pictures in
`assets/images/mouth/`). It moved here from
`features/pronunciation/widgets/` only so Number Words can show the same
mouth pictures (`features/numbers/services/number_mouth.dart` turns CMU
phonemes into IPA and asks this mapping for the picture). Changes to it
should be agreed with the Pronunciation owner.

## Inside a feature

Each feature uses only the subfolders it needs:

- `screens/` — full screens (nested by area where a feature has several,
  e.g. `features/pronunciation/screens/timed_reading/`)
- `services/` — logic, scorers, generators, helpers
- `dao/` — database access for the feature's own tables
- `data/` — static data and config (word lists, constants)
- `widgets/` — widgets used only by this feature

## Tests

`test/` mirrors this layout: `test/features/<feature>/...`.
`test/widget_test.dart` is the whole-app smoke test.

## Not referenced anywhere (kept on purpose)

These files have no importers, but were kept when the folders were
reorganised: `core/models/word_data.dart`,
`core/widgets/mascot_reaction.dart`, `core/widgets/smart_buddy_button.dart`,
`features/pronunciation/data/sinhala_syllables.dart`,
`features/pronunciation/services/stt_pronunciation_scorer.dart`,
`features/pronunciation/widgets/vmg_widget.dart`,
`features/pronunciation/widgets/vmg_mouth_widget.dart`.

## To do (needs a separate, confirmed change)

- **Pronunciation mouth pictures:** `PhonemeImageWidget.getImageForPhoneme`
  (`core/widgets/phoneme_image_widget.dart`) shows the wrong mouth shape
  for three sounds when given CMU/letter input: `AO` (as in "four") shows
  wide open instead of rounded lips; `DH` (as in "this") shows teeth
  together instead of the tongue between the teeth; `W` shows open-mid
  instead of rounded lips. Numbers works around this in
  `number_mouth.dart` (CMU → IPA, and `W` as rounded) without touching
  the shared mapping. Fixing the mapping itself changes what
  Pronunciation shows, so it should be agreed with the Pronunciation
  owner first.
- **Same mapping, IPA syllables starting with ð:** `ð` is matched only as
  a whole symbol, so a syllable such as `'ðə'` ("the") falls through to
  the open-mid picture instead of the tongue between the teeth (the
  first-character fallback has no `ð` / `θ` case). Same owner, same
  separate change as above.
