/// Hand-written, parent-friendly explanations for common phoneme
/// substitution patterns — reviewed and approved wording. Deliberately NOT
/// AI-generated: a small curated table so it's reliable, free, and every
/// tip has been checked for accuracy.
///
/// Covers the 13 Sinhala consonants already in cross_language_phoneme_map.dart
/// (both directions where plausible) and 10 classically-documented English
/// developmental phonological substitution patterns (gliding, fronting,
/// stopping, lisping — real speech-pathology terms). Any detected
/// substitution pair NOT in this table has no tip and is simply not shown
/// as a Practice Suggestion — no generic/fabricated tip is synthesized for
/// unlisted pairs.
class SubstitutionTip {
  final String language; // 'en' | 'si'
  final String expectedSound;
  final String producedSound;
  final String tip;

  const SubstitutionTip({
    required this.language,
    required this.expectedSound,
    required this.producedSound,
    required this.tip,
  });
}

const List<SubstitutionTip> substitutionTips = [
  // ── Sinhala ──────────────────────────────────────────────────────────────
  SubstitutionTip(
    language: 'si', expectedSound: 'r', producedSound: 'l',
    tip: "Your child may be substituting 'ල' for 'ර' — this is common when "
        "the tongue position for rolled/tapped sounds hasn't fully "
        "developed. Practicing at the start of words first, then middle, "
        "can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'l', producedSound: 'r',
    tip: "Your child may be saying 'ර' instead of 'ල' — since both sounds "
        "use a similar tongue position near the front of the mouth, mixing "
        "them up while tongue control is still developing is common. "
        "Short, slow repetition of words starting with 'ල' can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 't', producedSound: 'd',
    tip: "Your child may be saying 'ද' instead of 'ට' — both sounds are "
        "made in the same place in the mouth, but 'ට' is unvoiced while "
        "'ද' is voiced. Practicing the crisp, breathy 'ට' sound on its own "
        "before full words can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'd', producedSound: 't',
    tip: "Your child may be saying 'ට' instead of 'ද' — the opposite "
        "voicing mix-up. Gently exaggerating the vocal-cord buzz on 'ද' "
        "(a hand on the throat to feel it) can help make the difference "
        "clearer.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 's', producedSound: 'tʃ',
    tip: "Your child may be saying 'ච' instead of 'ස' — 'ස' is a smooth "
        "continuous hiss, while 'ච' is a quick stop-and-release. Slowly "
        "stretching out the 'ස' sound on its own can help separate the "
        "two.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'tʃ', producedSound: 's',
    tip: "Your child may be saying 'ස' instead of 'ච' — the reverse "
        "mix-up between a stop-release sound and a continuous hiss. "
        "Practicing the sharp, single-burst quality of 'ච' can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'n', producedSound: 'm',
    tip: "Your child may be saying 'ම' instead of 'න' — both are nasal "
        "sounds, just at different points in the mouth ('ම' at the lips, "
        "'න' behind the teeth). Practicing 'න' words with lips relaxed "
        "and open can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'm', producedSound: 'n',
    tip: "Your child may be saying 'න' instead of 'ම' — the reverse "
        "nasal mix-up. Practicing 'ම' words with lips gently closed can "
        "help highlight the difference.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'k', producedSound: 'g',
    tip: "Your child may be saying 'ග' instead of 'ක' — both are made "
        "at the back of the mouth, but 'ක' is unvoiced and 'ග' is voiced. "
        "A soft, breathy 'ක' without vocal-cord buzz can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'g', producedSound: 'k',
    tip: "Your child may be saying 'ක' instead of 'ග' — the reverse "
        "voicing mix-up at the back of the mouth. Gently voicing 'ග' "
        "(feeling the throat buzz) while keeping the same tongue position "
        "can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'p', producedSound: 'b',
    tip: "Your child may be saying 'බ' instead of 'ප' — both are lip "
        "sounds, but 'ප' is unvoiced and 'බ' is voiced. A light puff of "
        "air on 'ප' without any voice can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'b', producedSound: 'p',
    tip: "Your child may be saying 'ප' instead of 'බ' — the reverse "
        "voicing mix-up at the lips. Practicing 'බ' with a gentle throat "
        "buzz while keeping the same lip closure can help.",
  ),
  SubstitutionTip(
    language: 'si', expectedSound: 'h', producedSound: 'k',
    tip: "Your child may be replacing the soft 'හ' sound with a stronger "
        "'ක' — 'හ' is just breath with very little mouth shaping, so it's "
        "easy to substitute something that feels more definite. "
        "Practicing quiet, breathy 'හ' words can help.",
  ),

  // ── English ──────────────────────────────────────────────────────────────
  SubstitutionTip(
    language: 'en', expectedSound: 'r', producedSound: 'w',
    tip: 'Your child may be saying \'W\' instead of \'R\' (e.g. "wabbit" '
        'for "rabbit") — one of the most common early speech patterns, '
        "and it usually resolves with practice. Try words where 'R' "
        'comes right at the start first.',
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'r', producedSound: 'l',
    tip: "Your child may be saying 'L' instead of 'R' — both use the "
        "tongue near the roof of the mouth, just differently. Practicing "
        "'R' at the start of short words, tongue pulled back slightly, "
        "can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'l', producedSound: 'w',
    tip: "Your child may be saying 'W' instead of 'L' — a common early "
        "substitution since both round the lips slightly. Practicing 'L' "
        "with the tongue tip touching just behind the front teeth can "
        "help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'θ', producedSound: 'f',
    tip: 'Your child may be saying \'F\' instead of \'TH\' (as in "thumb") '
        "— very common, since both involve air through a narrow gap. "
        "Practicing with the tongue tip gently between the teeth can "
        "help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'ð', producedSound: 'd',
    tip: 'Your child may be saying \'D\' instead of the soft \'TH\' (as in '
        '"this") — a common simplification, since \'D\' skips putting the '
        "tongue between the teeth. Slow practice with the tongue tip "
        "lightly on the top teeth can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 's', producedSound: 'θ',
    tip: "Your child may be saying 'TH' instead of 'S' (a common lisp "
        "pattern) — happens when the tongue tip pushes slightly too far "
        "forward. Practicing 'S' with teeth lightly together, tongue "
        "behind them, can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'tʃ', producedSound: 't',
    tip: "Your child may be saying 'T' instead of 'CH' — 'CH' blends two "
        "sounds ('T' + 'SH'), so simplifying to just 'T' is a common step "
        "in speech development. Practicing 'SH' on its own, then "
        "blending it after 'T', can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'k', producedSound: 't',
    tip: 'Your child may be saying \'T\' instead of \'K\' — called '
        '"fronting," where back-of-mouth sounds get replaced with '
        "front-of-mouth ones. Very common early on. Practicing 'K' while "
        "gently guiding attention to the back of the tongue can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'g', producedSound: 'd',
    tip: "Your child may be saying 'D' instead of 'G' — the same "
        "fronting pattern, for the voiced version. Slow practice with the "
        "back of the tongue lifted can help.",
  ),
  SubstitutionTip(
    language: 'en', expectedSound: 'v', producedSound: 'b',
    tip: "Your child may be saying 'B' instead of 'V' — both use the "
        "lips, but 'V' needs the top teeth touching the bottom lip. "
        "Practicing in front of a mirror so your child can see the "
        "teeth-lip contact can help.",
  ),
];
