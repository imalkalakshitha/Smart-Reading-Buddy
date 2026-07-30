class ReadingSentence {
  final String id;
  final String text;
  final String language;
  final String difficulty;
  final int wordCount;
  final double expectedTimeSeconds;
  final String? audioPath; // asset path to WAV file, null = use TTS

  const ReadingSentence({
    required this.id,
    required this.text,
    required this.language,
    required this.difficulty,
    required this.wordCount,
    required this.expectedTimeSeconds,
    this.audioPath,
  });

  static double calculateExpectedTime(int wordCount, String difficulty) {
    const wpm = {'short': 60.0, 'medium': 55.0, 'long': 50.0};
    return wordCount / (wpm[difficulty] ?? 55.0) * 60;
  }
}

class SentenceDatabase {
  static const String _base = 'assets/audio/sentences/';

  static const List<ReadingSentence> _all = [
    // ── English short ──────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'en_s_001', text: 'I eat rice.',
      language: 'en', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.0,
      audioPath: '${_base}I eat rice.wav',
    ),
    ReadingSentence(
      id: 'en_s_002', text: 'I drink milk.',
      language: 'en', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.0,
      audioPath: '${_base}I drink milk.wav',
    ),
    ReadingSentence(
      id: 'en_s_003', text: 'Birds fly high.',
      language: 'en', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.0,
      audioPath: '${_base}Birds fly high.wav',
    ),
    ReadingSentence(
      id: 'en_s_004', text: 'The sun shines.',
      language: 'en', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.0,
      audioPath: '${_base}The sun shines.wav',
    ),
    ReadingSentence(
      id: 'en_s_005', text: 'The cat sleeps.',
      language: 'en', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.0,
      audioPath: '${_base}The cat sleeps.wav',
    ),

    // ── English medium ─────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'en_m_001', text: 'The cat sat on mat.',
      language: 'en', difficulty: 'medium', wordCount: 5, expectedTimeSeconds: 5.5,
      audioPath: '${_base}The cat sat on mat.wav',
    ),
    ReadingSentence(
      id: 'en_m_002', text: 'She does her homework daily.',
      language: 'en', difficulty: 'medium', wordCount: 5, expectedTimeSeconds: 5.5,
      audioPath: '${_base}She does her homework daily.wav',
    ),
    ReadingSentence(
      id: 'en_m_003', text: 'Mom cooks tasty rice today.',
      language: 'en', difficulty: 'medium', wordCount: 5, expectedTimeSeconds: 5.5,
      audioPath: '${_base}Mom cooks tasty rice today.wav',
    ),
    ReadingSentence(
      id: 'en_m_004', text: 'I read my book everyday.',
      language: 'en', difficulty: 'medium', wordCount: 5, expectedTimeSeconds: 5.5,
      audioPath: '${_base}I read my book everyday.wav',
    ),
    ReadingSentence(
      id: 'en_m_005', text: 'We play in the garden.',
      language: 'en', difficulty: 'medium', wordCount: 5, expectedTimeSeconds: 5.5,
      audioPath: '${_base}We play in the garden.wav',
    ),

    // ── English long ───────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'en_l_001', text: 'The red apple is very sweet.',
      language: 'en', difficulty: 'long', wordCount: 6, expectedTimeSeconds: 7.2,
      audioPath: '${_base}The red apple is very sweet.wav',
    ),
    ReadingSentence(
      id: 'en_l_002', text: 'The sky is so clear today.',
      language: 'en', difficulty: 'long', wordCount: 6, expectedTimeSeconds: 7.2,
      audioPath: '${_base}The sky is so clear today.wav',
    ),
    ReadingSentence(
      id: 'en_l_003', text: 'I like fresh green apples.',
      language: 'en', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 6.0,
      audioPath: '${_base}I like fresh green apples.wav',
    ),
    ReadingSentence(
      id: 'en_l_004', text: 'She paints a beautiful picture.',
      language: 'en', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 6.0,
      audioPath: '${_base}She paints a beautiful picture.wav',
    ),
    ReadingSentence(
      id: 'en_l_005', text: 'He reads an interesting storybook.',
      language: 'en', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 6.0,
      audioPath: '${_base}He reads an interesting storybook.wav',
    ),

    // ── Sinhala short ──────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'si_s_001', text: 'මම ගමට යමි.',
      language: 'si', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.5,
      audioPath: '${_base}mama_gamata_yami.wav',
    ),
    ReadingSentence(
      id: 'si_s_002', text: 'අම්මා බත් උයාය.',
      language: 'si', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.5,
      audioPath: '${_base}amma_bath_uyayi.wav',
    ),
    ReadingSentence(
      id: 'si_s_003', text: 'ඔහු පාඩම් කරයි.',
      language: 'si', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.5,
      audioPath: '${_base}ohu_paadam_karayi.wav',
    ),
    ReadingSentence(
      id: 'si_s_004', text: 'අපි සෙල්ලම් කරමු.',
      language: 'si', difficulty: 'short', wordCount: 3, expectedTimeSeconds: 3.5,
      audioPath: '${_base}api_sellam_karamu.wav',
    ),
    ReadingSentence(
      id: 'si_s_005', text: 'මම රස කෙසෙල් කමි.',
      language: 'si', difficulty: 'short', wordCount: 4, expectedTimeSeconds: 4.5,
      audioPath: '${_base}mama_rasa_kesel_kami.wav',
    ),

    // ── Sinhala medium ─────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'si_m_001', text: 'අක්කා පොතක් කියෑව්වාය.',
      language: 'si', difficulty: 'medium', wordCount: 3, expectedTimeSeconds: 5.0,
      audioPath: '${_base}akka_pothak_kiyawayi.wav',
    ),
    ReadingSentence(
      id: 'si_m_002', text: 'ගඟේ මළුන් පිනාමින් සිටියි.',
      language: 'si', difficulty: 'medium', wordCount: 4, expectedTimeSeconds: 6.0,
      audioPath: '${_base}gange_malun_peenamin_sitiyi.wav',
    ),
    ReadingSentence(
      id: 'si_m_003', text: 'හිරු උදෙට පායාමින් යයි.',
      language: 'si', difficulty: 'medium', wordCount: 4, expectedTimeSeconds: 6.0,
      audioPath: '${_base}hiru_udeta_paayamin_eyi.wav',
    ),
    ReadingSentence(
      id: 'si_m_004', text: 'අම්මා මට බත් කෑව්වාය.',
      language: 'si', difficulty: 'medium', wordCount: 4, expectedTimeSeconds: 6.0,
      audioPath: '${_base}amma_mata_bath_kawayi.wav',
    ),
    ReadingSentence(
      id: 'si_m_005', text: 'තාත්තා ගෙදර වැඩ කරයි.',
      language: 'si', difficulty: 'medium', wordCount: 4, expectedTimeSeconds: 6.0,
      audioPath: '${_base}thaththa_gedara_wada_karayi.wav',
    ),

    // ── Sinhala long ───────────────────────────────────────────────────────────
    ReadingSentence(
      id: 'si_l_001', text: 'ගුරුතුමිය අපට අලුත් පාඩම් කියාදෙයි.',
      language: 'si', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 8.0,
      audioPath: '${_base}guruthumiya_apata_aluth_paadam_kiyadei.wav',
    ),
    ReadingSentence(
      id: 'si_l_002', text: 'අම්මා මට ලස්සන කතන්දර කියාදෙයි.',
      language: 'si', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 8.0,
      audioPath: '${_base}amma_mata_lassana_kathandara_kiyadei.wav',
    ),
    ReadingSentence(
      id: 'si_l_003', text: 'පොත් කියවීමෙන් අපේ දැනුම වැඩි වෙයි.',
      language: 'si', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 8.0,
      audioPath: '${_base}poth_kiyawimen_ape_daenum_wadi_weyi.wav',
    ),
    ReadingSentence(
      id: 'si_l_004', text: 'යාළුවෝ පෝය දිනයට පන්සල් යති.',
      language: 'si', difficulty: 'long', wordCount: 5, expectedTimeSeconds: 8.0,
      audioPath: '${_base}yahaluwo_pohoya_dinayata_pansal_yathi.wav',
    ),
    ReadingSentence(
      id: 'si_l_005', text: 'ගමේ වැවේ නෙළුම් මල් පිපී හිනාහෙයි.',
      language: 'si', difficulty: 'long', wordCount: 6, expectedTimeSeconds: 9.0,
      audioPath: '${_base}game_wawe_olu_nelum_maanel_pipee_hinaheyi.wav',
    ),
  ];

  static List<ReadingSentence> getByLanguageAndDifficulty(
    String language,
    String difficulty,
  ) =>
      _all.where((s) => s.language == language && s.difficulty == difficulty).toList();
}
