# frozen_string_literal: true

require_relative 'transliterator'

module SanskritGrammarEngine
  VOWELS = %w[अ आ इ ई उ ऊ ऋ ॠ ऌ ॡ ए ऐ ओ औ].freeze
  SHORT_VOWELS = %w[अ इ उ ऋ ऌ].freeze
  LONG_VOWELS = %w[आ ई ऊ ॠ ॡ ए ऐ ओ औ].freeze

  MATRA_TO_VOWEL = {
    'ा' => 'आ', 'ि' => 'इ', 'ी' => 'ई', 'ु' => 'उ', 'ू' => 'ऊ',
    'ृ' => 'ऋ', 'ॄ' => 'ॠ', 'ॢ' => 'ऌ', 'ॣ' => 'ॡ',
    'े' => 'ए', 'ै' => 'ऐ', 'ो' => 'ओ', 'ौ' => 'औ'
  }.freeze

  VOWEL_TO_MATRA = MATRA_TO_VOWEL.invert.merge('अ' => '').freeze

  CONSONANTS = %w[
    क ख ग घ ङ
    च छ ज झ ञ
    ट ठ ड ढ ण
    त थ द ध न
    प फ ब भ म
    य र ल व
    श ष स ह ळ
  ].freeze

  GANA_MAP = {
    '।ऽऽ' => { name: 'य-गणः (Ya)', symbol: 'Y', example: 'यमाता', deity: 'जलम् (Water)' },
    'ऽऽऽ' => { name: 'म-गणः (Ma)', symbol: 'M', example: 'मातारा', deity: 'पृथिवी (Earth)' },
    'ऽऽ।' => { name: 'त-गणः (Ta)', symbol: 'T', example: 'ताराज', deity: 'आकाशः (Ether)' },
    'ऽ।ऽ' => { name: 'र-गणः (Ra)', symbol: 'R', example: 'राजभा', deity: 'अग्निः (Fire)' },
    '।ऽ।' => { name: 'ज-गणः (Ja)', symbol: 'J', example: 'जभान', deity: 'सूर्यः (Sun)' },
    'ऽ।।' => { name: 'भ-गणः (Bha)', symbol: 'Bh', example: 'भानस', deity: 'चन्द्रः (Moon)' },
    '।।।' => { name: 'न-गणः (Na)', symbol: 'N', example: 'नसल', deity: 'स्वर्गः (Heaven)' },
    '।।ऽ' => { name: 'स-गणः (Sa)', symbol: 'S', example: 'सलगाः', deity: 'वायुः (Wind)' }
  }.freeze

  METERS = [
    {
      name_sa: 'इन्द्रवज्रा', name_en: 'Indravajrā', syllables: 11,
      pattern: 'ऽऽ।ऽऽ।।ऽ।ऽऽ', ganas: 'त, त, ज, ग, ग', yati: '5 किंवा 11',
      lakshana: 'स्यादिन्द्रवज्रा यदि तौ जगौ गः ।'
    },
    {
      name_sa: 'उपेन्द्रवज्रा', name_en: 'Upendravajrā', syllables: 11,
      pattern: '।ऽ।ऽऽ।।ऽ।ऽऽ', ganas: 'ज, त, ज, ग, ग', yati: '5 किंवा 11',
      lakshana: 'उपेन्द्रवज्रा जतजास्ततो गौ ।'
    },
    {
      name_sa: 'शालिनी', name_en: 'Śālinī', syllables: 11,
      pattern: 'ऽऽऽऽऽ।ऽऽ।ऽऽ', ganas: 'म, त, त, ग, ग', yati: '4, 7',
      lakshana: 'मात्तौ गौ चेच्छालिनी वेदलोकैः ।'
    },
    {
      name_sa: 'रथोद्धता', name_en: 'Rathoddhatā', syllables: 11,
      pattern: 'ऽ।ऽ।।।ऽ।ऽ।ऽ', ganas: 'र, न, र, ल, ग', yati: '11',
      lakshana: 'रात्परैर्नरलगै रथोद्धता ।'
    },
    {
      name_sa: 'स्वागता', name_en: 'Svāgatā', syllables: 11,
      pattern: 'ऽ।ऽ।।।ऽ।।ऽऽ', ganas: 'र, न, भ, ग, ग', yati: '11',
      lakshana: 'स्वागता रनभगैर्गुरुणा च ।'
    },
    {
      name_sa: 'वंशस्थम्', name_en: 'Vaṃśastha', syllables: 12,
      pattern: '।ऽ।ऽऽ।।ऽ।ऽ।ऽ', ganas: 'ज, त, ज, र', yati: '12 (किंवा 5, 7)',
      lakshana: 'जतौ तु वंशस्थमुदीरितं जरौ ।'
    },
    {
      name_sa: 'इन्द्रवंशा', name_en: 'Indravaṃśā', syllables: 12,
      pattern: 'ऽऽ।ऽऽ।।ऽ।ऽ।ऽ', ganas: 'त, त, ज, र', yati: '12',
      lakshana: 'ततौ जराविन्द्रवंशा प्रकीर्तिता ।'
    },
    {
      name_sa: 'द्रुतविलम्बितम्', name_en: 'Drutavilambita', syllables: 12,
      pattern: '।।।ऽ।।ऽ।।ऽ।ऽ', ganas: 'न, भ, भ, र', yati: '12',
      lakshana: 'द्रुतविलम्बितमाह नभौ भरौ ।'
    },
    {
      name_sa: 'भुजङ्गप्रयातम्', name_en: 'Bhujaṅgaprayāta', syllables: 12,
      pattern: '।ऽऽ।ऽऽ।ऽऽ।ऽऽ', ganas: 'य, य, य, य', yati: '6, 6',
      lakshana: 'भुजङ्गप्रयातं चतुर्भिर्यकारैः ।'
    },
    {
      name_sa: 'तोटकम्', name_en: 'Toṭaka', syllables: 12,
      pattern: '।।ऽ।।ऽ।।ऽ।।ऽ', ganas: 'स, स, स, स', yati: '12',
      lakshana: 'वद तोटकमब्धिसकारयुतम् ।'
    },
    {
      name_sa: 'प्रहर्षिणी', name_en: 'Praharṣiṇī', syllables: 13,
      pattern: 'ऽऽऽ।।।।ऽ।ऽ।ऽऽ', ganas: 'म, न, ज, र, ग', yati: '3, 10',
      lakshana: 'त्र्याशाभिर्मनजरगाः प्रहर्षिणीयम् ।'
    },
    {
      name_sa: 'वसन्ततिलका', name_en: 'Vasantatilakā', syllables: 14,
      pattern: 'ऽऽ।ऽ।।।ऽ।।ऽ।ऽऽ', ganas: 'त, भ, ज, ज, ग, ग', yati: '8, 6 (किंवा 14)',
      lakshana: 'उक्ता वसन्ततिलका तभजा जगौ गः ।'
    },
    {
      name_sa: 'मालिनी', name_en: 'Mālinī', syllables: 15,
      pattern: '।।।।।।ऽऽऽ।ऽऽ।ऽऽ', ganas: 'न, न, म, य, य', yati: '8, 7',
      lakshana: 'ननमयययुतेयं मालिनी भोगिलोकैः ।'
    },
    {
      name_sa: 'पञ्चचामरम्', name_en: 'Pañcacāmara', syllables: 16,
      pattern: '।ऽ।ऽ।ऽ।ऽ।ऽ।ऽ।ऽ।ऽ', ganas: 'ज, र, ज, र, ज, ग', yati: '8, 8',
      lakshana: 'जरौ जरौ ततो जगाविदं तु पञ्चचामरम् ।'
    },
    {
      name_sa: 'मन्दाक्रान्ता', name_en: 'Mandākrāntā', syllables: 17,
      pattern: 'ऽऽऽऽ।।।।।ऽऽ।ऽऽ।ऽऽ', ganas: 'म, भ, न, त, त, ग, ग', yati: '4, 6, 7',
      lakshana: 'मन्दाक्रान्ताम्बुधिरसनगैर्मो भनौ तौ गयुग्मम् ।'
    },
    {
      name_sa: 'शिखरिणी', name_en: 'Śikhariṇī', syllables: 17,
      pattern: '।ऽऽऽऽऽ।।।।।ऽऽ।।।ऽ', ganas: 'य, म, न, स, भ, ल, ग', yati: '6, 11',
      lakshana: 'रसैरुद्रैश्छिन्ना यमनसभलागः शिखरिणी ।'
    },
    {
      name_sa: 'हरिणी', name_en: 'Hariṇī', syllables: 17,
      pattern: '।।।।।ऽऽऽऽऽ।ऽ।।ऽ।ऽ', ganas: 'न, स, म, र, स, ल, ग', yati: '6, 4, 7',
      lakshana: 'नसमरसलागः षड्वेदैर्हयैर्हरिणी मता ।'
    },
    {
      name_sa: 'पृथ्वी', name_en: 'Pṛthvī', syllables: 17,
      pattern: '।ऽ।।।ऽ।ऽ।।।ऽ।ऽऽ।ऽ', ganas: 'ज, स, ज, स, य, ल, ग', yati: '8, 9',
      lakshana: 'जसौ जसयला वसुग्रहयतिश्च पृथ्वी गुरुः ।'
    },
    {
      name_sa: 'शार्दूलविक्रीडितम्', name_en: 'Śārdūlavikrīḍita', syllables: 19,
      pattern: 'ऽऽऽ।।ऽ।ऽ।।।ऽऽऽ।ऽऽ।ऽ', ganas: 'म, स, ज, स, त, त, ग', yati: '12, 7',
      lakshana: 'सूर्याश्वैर्यदि मः सजौ सततगाः शार्दूलविक्रीडितम् ।'
    },
    {
      name_sa: 'स्रग्धरा', name_en: 'Sragdharā', syllables: 21,
      pattern: 'ऽऽऽऽ।ऽऽ।।।।।।ऽऽ।ऽऽ।ऽऽ', ganas: 'म, र, भ, न, य, य, य', yati: '7, 7, 7',
      lakshana: 'म्रभ्नैर्याणां त्रयेण त्रिमुनियतियुता स्रग्धरा कीर्तितेयम् ।'
    }
  ].freeze

  module_function

  # ==========================================================================
  # 1. SANDHI JOINER & SPLITTER ENGINE (Paninian Rules)
  # ==========================================================================

  def extract_ending(word)
    chars = word.strip.chars
    return [word, '', :none] if chars.empty?

    last = chars.last
    if last == '्' && chars.size >= 2
      cons = chars[-2]
      prefix = chars[0...-2].join
      [prefix, "#{cons}्", :hal]
    elsif last == 'ः'
      # Find preceding vowel
      prev_word = chars[0...-1].join
      base, v, _ = extract_ending(prev_word)
      [base, "#{v}ः", :visarga]
    elsif last == 'ं'
      [chars[0...-1].join, 'म्', :hal]
    elsif MATRA_TO_VOWEL.key?(last)
      [chars[0...-1].join + '्', MATRA_TO_VOWEL[last], :ac]
    elsif VOWELS.include?(last)
      [chars[0...-1].join, last, :ac]
    elsif CONSONANTS.include?(last)
      [chars[0...-1].join + last + '्', 'अ', :ac]
    else
      [word, '', :none]
    end
  end

  def extract_beginning(word)
    chars = word.strip.chars
    return ['', '', :none] if chars.empty?

    first = chars.first
    if VOWELS.include?(first)
      [first, chars[1..-1].join, :ac]
    elsif CONSONANTS.include?(first)
      [first, chars.join, :hal]
    else
      [first, chars[1..-1].join, :other]
    end
  end

  def attach_vowel(stem_with_halant_or_base, vowel)
    return stem_with_halant_or_base + vowel if stem_with_halant_or_base.empty?
    if stem_with_halant_or_base.end_with?('्')
      base_cons = stem_with_halant_or_base.sub(/्$/, '')
      matra = VOWEL_TO_MATRA[vowel]
      matra ? (base_cons + matra) : (base_cons + vowel)
    else
      matra = VOWEL_TO_MATRA[vowel]
      if CONSONANTS.include?(stem_with_halant_or_base[-1]) && matra
        stem_with_halant_or_base + matra
      else
        stem_with_halant_or_base + vowel
      end
    end
  end

  def join_sandhi(p1_raw, p2_raw)
    p1 = SanskritTransliterator.ensure_utf8(p1_raw).strip
    p2 = SanskritTransliterator.ensure_utf8(p2_raw).strip
    return [] if p1.empty? || p2.empty?

    # Convert Telugu to Devanagari if input is in Telugu
    p1 = SanskritTransliterator.telugu_to_dev(p1) if p1.match?(/[\u0C00-\u0C7F]/)
    p2 = SanskritTransliterator.telugu_to_dev(p2) if p2.match?(/[\u0C00-\u0C7F]/)

    results = []
    base1, end1, type1 = extract_ending(p1)
    beg2, rest2, type2 = extract_beginning(p2)

    # --- A. AC SANDHI (Vowel + Vowel) ---
    if type1 == :ac && type2 == :ac
      v1 = end1
      v2 = beg2

      # 1. Savarna Dirgha (अकः सवर्णे दीर्घः 6.1.101)
      savarna = {
        %w[अ अ] => 'आ', %w[अ आ] => 'आ', %w[आ अ] => 'आ', %w[आ आ] => 'आ',
        %w[इ इ] => 'ई', %w[इ ई] => 'ई', %w[ई इ] => 'ई', %w[ई ई] => 'ई',
        %w[उ उ] => 'ऊ', %w[उ ऊ] => 'ऊ', %w[ऊ उ] => 'ऊ', %w[ऊ ऊ] => 'ऊ',
        %w[ऋ ऋ] => 'ॠ', %w[ऋ ॠ] => 'ॠ', %w[ॠ ऋ] => 'ॠ', %w[ॠ ॠ] => 'ॠ'
      }
      if savarna[[v1, v2]]
        v_new = savarna[[v1, v2]]
        joined = attach_vowel(base1, v_new) + rest2
        results << {
          result: joined,
          sandhi_name: 'सवर्णदीर्घसन्धिः (Savarṇa Dīrgha Sandhi)',
          sutra: 'अकः सवर्णे दीर्घः (6.1.101)',
          rule: "#{v1} + #{v2} → #{v_new}",
          explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)'
        }
      end

      # 2. Guna Sandhi (आद्गुणः 6.1.87 + उरण् रपरः 1.1.51)
      if %w[अ आ].include?(v1)
        if %w[इ ई].include?(v2)
          joined = attach_vowel(base1, 'ए') + rest2
          results << {
            result: joined,
            sandhi_name: 'गुणसन्धिः (Guṇa Sandhi)',
            sutra: 'आद्गुणः (6.1.87)',
            rule: "#{v1} + #{v2} → ए",
            explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter. (Pāṇini 6.1.87)'
          }
        elsif %w[उ ऊ].include?(v2)
          joined = attach_vowel(base1, 'ओ') + rest2
          results << {
            result: joined,
            sandhi_name: 'गुणसन्धिः (Guṇa Sandhi)',
            sutra: 'आद्गुणः (6.1.87)',
            rule: "#{v1} + #{v2} → ओ",
            explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter. (Pāṇini 6.1.87)'
          }
        elsif %w[ऋ ॠ].include?(v2)
          joined = attach_vowel(base1, 'अ') + 'र्' + rest2
          # Better orthographic rendering of र् before consonant
          results << {
            result: joined,
            sandhi_name: 'गुणसन्धिः (Guṇa Sandhi)',
            sutra: 'आद्गुणः (6.1.87) / उरण् रपरः (1.1.51)',
            rule: "#{v1} + #{v2} → अर्",
            explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter (followed by र् by उरण् रपरः 1.1.51).'
          }
        elsif %w[ऌ ॡ].include?(v2)
          joined = attach_vowel(base1, 'अ') + 'ल्' + rest2
          results << {
            result: joined,
            sandhi_name: 'गुणसन्धिः (Guṇa Sandhi)',
            sutra: 'आद्गुणः (6.1.87) / उरण् रपरः (1.1.51)',
            rule: "#{v1} + #{v2} → अल्",
            explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter (followed by ल् by उरण् रपरः 1.1.51).'
          }
        end
      end

      # 3. Vriddhi Sandhi (वृद्धिरेचि 6.1.88)
      if %w[अ आ].include?(v1)
        if %w[ए ऐ].include?(v2)
          joined = attach_vowel(base1, 'ऐ') + rest2
          results << {
            result: joined,
            sandhi_name: 'वृद्धिसन्धिः (Vṛddhi Sandhi)',
            sutra: 'वृद्धिरेचि (6.1.88)',
            rule: "#{v1} + #{v2} → ऐ",
            explanation: 'When an अवर्ण is followed by an एच् letter in the context of संहिता, both of them are replaced by a single वृद्धि letter. (Pāṇini 6.1.88)'
          }
        elsif %w[ओ औ].include?(v2)
          joined = attach_vowel(base1, 'औ') + rest2
          results << {
            result: joined,
            sandhi_name: 'वृद्धिसन्धिः (Vṛddhi Sandhi)',
            sutra: 'वृद्धिरेचि (6.1.88)',
            rule: "#{v1} + #{v2} → औ",
            explanation: 'When an अवर्ण is followed by an एच् letter in the context of संहिता, both of them are replaced by a single वृद्धि letter. (Pāṇini 6.1.88)'
          }
        end
      end

      # 4. Yan Sandhi (इको यणचि 6.1.77)
      yan_map = {
        'इ' => 'य्', 'ई' => 'य्',
        'उ' => 'व्', 'ऊ' => 'व्',
        'ऋ' => 'र्', 'ॠ' => 'र्',
        'ऌ' => 'ल्', 'ॡ' => 'ल्'
      }
      if yan_map.key?(v1) && !savarna[[v1, v2]]
        semi = yan_map[v1]
        joined = base1 + attach_vowel(semi, v2) + rest2
        results << {
          result: joined,
          sandhi_name: 'यण्सन्धिः (Yaṇ Sandhi)',
          sutra: 'इको यणचि (6.1.77)',
          rule: "#{v1} + #{v2} → #{attach_vowel(semi, v2)}",
          explanation: 'An इक् letter which is followed by a स्वर is converted to a corresponding यण् letter in the context of संहिता. (Pāṇini 6.1.77)'
        }
      end

      # 5. Purvarupa Sandhi (एङः पदान्तादति 6.1.109)
      if %w[ए ओ].include?(v1) && v2 == 'अ'
        joined = p1 + 'ऽ' + rest2
        results << {
          result: joined,
          sandhi_name: 'पूर्वरूपसन्धिः (Pūrvarūpa Sandhi)',
          sutra: 'एङः पदान्तादति (6.1.109)',
          rule: "#{v1} + अ → #{v1}ऽ",
          explanation: 'If a पदान्त ए / ओ letter is followed by a ह्रस्व अकार, then both of them combine to form a पूर्वरूप एकादेश. (Pāṇini 6.1.109)'
        }
      end

      # 6. Ayavayava Sandhi (एचोऽयवायावः 6.1.78)
      ayadi_map = { 'ए' => 'अय्', 'ऐ' => 'आय्', 'ओ' => 'अव्', 'औ' => 'आव्' }
      if ayadi_map.key?(v1) && !(%w[ए ओ].include?(v1) && v2 == 'अ')
        rep = ayadi_map[v1]
        rep_base = rep[0...-2] # अ or आ
        rep_cons = rep[-2..-1] # य् or व्
        joined = attach_vowel(base1, rep_base) + attach_vowel(rep_cons, v2) + rest2
        results << {
          result: joined,
          sandhi_name: 'अयादिसन्धिः (Ayavāyāva Sandhi)',
          sutra: 'एचोऽयवायावः (6.1.78)',
          rule: "#{v1} + #{v2} → #{rep} + #{v2}",
          explanation: 'When followed by a स्वर, the letters of the एच् प्रत्याहार are respectively converted to अय्, अव्, आय् and आव् in the context of संहिता. (Pāṇini 6.1.78)'
        }
      end
    end

    # --- B. VISARGA SANDHI ---
    if type1 == :visarga
      v_before = end1.sub(/ः$/, '')
      first_c = beg2
      voiced_cons = %w[ग घ ङ ज झ ञ ड ढ ण द ध न ब भ म य र ल व ह]

      # 1. अः + अ -> ओऽ (अतो रोरप्लुतादप्लुते 6.1.113 + एङः पदान्तादति 6.1.109)
      if v_before == 'अ' && beg2 == 'अ'
        joined = attach_vowel(base1, 'ओ') + 'ऽ' + rest2
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-उत्व-पूर्वरूपसन्धिः (Visarga Utva + Pūrvarūpa)',
          sutra: 'अतो रोरप्लुतादप्लुते (6.1.113) / एङः पदान्तादति (6.1.109)',
          rule: 'अः + अ → ओऽ',
          explanation: 'A रुँ letter that is sandwiched between an अप्लुत-ह्रस्व-अकार from each side is converted to an उकार (6.1.113), then पूर्वरूप एकादेश (6.1.109).'
        }
      elsif v_before == 'अ' && type2 == :ac && beg2 != 'अ'
        # अः + अन्यस्वरः -> अ + स्वरः (भोभगोअघोअपूर्वस्य योऽशि 8.3.17, लोपः शाकल्यस्य 8.3.19)
        joined = attach_vowel(base1, 'अ') + ' ' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्गलोपसन्धिः (Visarga Lopa)',
          sutra: 'लोपः शाकल्यस्य (8.3.19)',
          rule: "अः + #{beg2} → अ #{beg2}",
          explanation: 'According to Shakalya, a वकार/यकार present at end of a पद and situated after अ/आ gets removed when it is followed by a letter from अश् प्रत्याहार in the context of संहिता. (Pāṇini 8.3.19)'
        }
      elsif v_before == 'अ' && voiced_cons.include?(first_c)
        # अः + हश् (voiced consonant) -> ओ (हशि च 6.1.114)
        joined = attach_vowel(base1, 'ओ') + ' ' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-उत्वसन्धिः (Visarga Utva)',
          sutra: 'हशि च (6.1.114) / आद्गुणः (6.1.87)',
          rule: "अः + #{first_c} → ओ #{first_c}",
          explanation: 'A रुँ letter that follows an अप्लुत-ह्रस्व-अकार and is followed by a हश् letter is converted to an उकार. (Pāṇini 6.1.114)'
        }
      elsif v_before == 'आ' && (type2 == :ac || voiced_cons.include?(first_c))
        joined = attach_vowel(base1, 'आ') + ' ' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्गलोपसन्धिः (Visarga Lopa after आ)',
          sutra: 'भोभगोअघोअपूर्वस्य योऽशि (8.3.17) / लोपः शाकल्यस्य (8.3.19)',
          rule: "आः + #{first_c} → आ #{first_c}",
          explanation: 'In the context of संहिता, a पदान्त रुँ after अ/आ is converted to यकार when followed by अश् (8.3.17) and removed by लोपः शाकल्यस्य (8.3.19).'
        }
      elsif !%w[अ आ].include?(v_before) && (type2 == :ac || voiced_cons.include?(first_c))
        # इः/उः etc. + vowel/voiced consonant -> र (ससजुषो रुः 8.2.66)
        if type2 == :ac
          joined = attach_vowel(base1, v_before) + attach_vowel('र्', beg2) + rest2
        else
          joined = attach_vowel(base1, v_before) + 'र्' + p2
        end
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-रुत्वसन्धिः (Visarga Rutva)',
          sutra: 'ससजुषो रुः (8.2.66)',
          rule: "#{v_before}ः + #{first_c} → #{v_before}र्...",
          explanation: 'The सकार at end of a पद, and the षकार at end of the सजुष् पद get a रुँ-आदेश. (Pāṇini 8.2.66)'
        }
      elsif %w[च छ श].include?(first_c)
        joined = attach_vowel(base1, v_before) + 'श्' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-सत्व-श्चुत्वसन्धिः (Visarga → श्)',
          sutra: 'विसर्जनीयस्य सः (8.3.34) / स्तोः श्चुना श्चुः (8.4.40)',
          rule: "ः + #{first_c} → श्#{first_c}",
          explanation: 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by खर् (8.3.34), then to शकार by स्तोः श्चुना श्चुः (8.4.40).'
        }
      elsif %w[ट ठ ष].include?(first_c)
        joined = attach_vowel(base1, v_before) + 'ष्' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-सत्व-ष्टुत्वसन्धिः (Visarga → ष्)',
          sutra: 'विसर्जनीयस्य सः (8.3.34) / ष्टुना ष्टुः (8.4.41)',
          rule: "ः + #{first_c} → ष्#{first_c}",
          explanation: 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by खर् (8.3.34), then to षकार by ष्टुना ष्टुः (8.4.41).'
        }
      elsif %w[त थ स].include?(first_c)
        joined = attach_vowel(base1, v_before) + 'स्' + p2
        results << {
          result: joined,
          sandhi_name: 'विसर्ग-सत्वसन्धिः (Visarga → स्)',
          sutra: 'विसर्जनीयस्य सः (8.3.34)',
          rule: "ः + #{first_c} → स्#{first_c}",
          explanation: 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by a letter from the खर् प्रत्याहार. (Pāṇini 8.3.34)'
        }
      end
    end

    # --- C. HAL SANDHI (Consonant + Vowel/Consonant) ---
    if type1 == :hal
      c1 = end1 # e.g., 'त्', 'म्', 'क्'
      first_c = beg2

      # 1. Consonant + Vowel -> join directly (or Jashva first if unvoiced stop)
      jash_map = { 'क्' => 'ग्', 'ख्' => 'ग्', 'ग्' => 'ग्', 'घ्' => 'ग्',
                   'च्' => 'ज्', 'छ्' => 'ज्', 'ज्' => 'ज्', 'झ्' => 'ज्',
                   'ट्' => 'ड्', 'ठ्' => 'ड्', 'ड्' => 'ड्', 'ढ्' => 'ड्',
                   'त्' => 'द्', 'थ्' => 'द्', 'द्' => 'द्', 'ध्' => 'द्',
                   'प्' => 'ब्', 'फ्' => 'ब्', 'ब्' => 'ब्', 'भ्' => 'ब्' }

      if type2 == :ac
        if jash_map.key?(c1)
          voiced_c = jash_map[c1]
          joined = base1 + attach_vowel(voiced_c, beg2) + rest2
          results << {
            result: joined,
            sandhi_name: 'जश्त्वसन्धिः (Jaśtva Sandhi)',
            sutra: 'झलां जशोऽन्ते (8.2.39)',
            rule: "#{c1} + #{beg2} → #{attach_vowel(voiced_c, beg2)}",
            explanation: 'A झल् letter occurring at end of a पद is converted to the corresponding जश् letter. (Pāṇini 8.2.39)'
          }
        else
          joined = base1 + attach_vowel(c1, beg2) + rest2
          results << {
            result: joined,
            sandhi_name: 'वर्णसम्मेलनम् (Consonant-Vowel Join)',
            sutra: 'अज्झीनं परेण संयोज्यम्',
            rule: "#{c1} + #{beg2} → #{attach_vowel(c1, beg2)}",
            explanation: 'अज्झीनं परेण संयोज्यम् — A vowelless consonant joins with the following vowel.'
          }
        end
      elsif type2 == :hal
        # 2. त्/द् rules (Scutva, Stutva, Torli, Jashva, Anunasika)
        if %w[त् द्].include?(c1)
          if %w[च छ].include?(first_c)
            joined = base1 + 'च्' + p2
            results << {
              result: joined,
              sandhi_name: 'श्चुत्वसन्धिः (Ścutva Sandhi)',
              sutra: 'स्तोः श्चुना श्चुः (8.4.40)',
              rule: "#{c1} + #{first_c} → च्#{first_c}",
              explanation: 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a शकार and चवर्ग letter when associated with a शकार or a चवर्ग letter. (Pāṇini 8.4.40)'
            }
          elsif %w[ज झ].include?(first_c)
            joined = base1 + 'ज्' + p2
            results << {
              result: joined,
              sandhi_name: 'श्चुत्व-जश्त्वसन्धिः (Ścutva Sandhi)',
              sutra: 'स्तोः श्चुना श्चुः (8.4.40)',
              rule: "#{c1} + #{first_c} → ज्#{first_c}",
              explanation: 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a शकार and चवर्ग letter when associated with a शकार or a चवर्ग letter. (Pāṇini 8.4.40)'
            }
          elsif first_c == 'श'
            joined = base1 + 'च्' + rest2.sub(/^श/, 'छ')
            results << {
              result: joined,
              sandhi_name: 'छत्वसन्धिः (Chatva Sandhi)',
              sutra: 'शश्छोऽटि (8.4.63) / स्तोः श्चुना श्चुः (8.4.40)',
              rule: "#{c1} + श → च्छ",
              explanation: 'A शकार sandwiched between a झय् letter on the left and an अट् letter on the right is optionally converted to a छकार. (Pāṇini 8.4.63)'
            }
          elsif %w[ट ठ].include?(first_c)
            joined = base1 + 'ट्' + p2
            results << {
              result: joined,
              sandhi_name: 'ष्टुत्वसन्धिः (Ṣṭutva Sandhi)',
              sutra: 'ष्टुना ष्टुः (8.4.41)',
              rule: "#{c1} + #{first_c} → ट्#{first_c}",
              explanation: 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a षकार and टवर्ग letter when associated with a षकार or a टवर्ग letter. (Pāṇini 8.4.41)'
            }
          elsif %w[ड ढ].include?(first_c)
            joined = base1 + 'ड्' + p2
            results << {
              result: joined,
              sandhi_name: 'ष्टुत्वसन्धिः (Ṣṭutva Sandhi)',
              sutra: 'ष्टुना ष्टुः (8.4.41)',
              rule: "#{c1} + #{first_c} → ड्#{first_c}",
              explanation: 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a षकार and टवर्ग letter when associated with a षकार or a टवर्ग letter. (Pāṇini 8.4.41)'
            }
          elsif first_c == 'ल'
            joined = base1 + 'ल्ँ' + p2
            results << {
              result: base1 + 'ल्' + p2,
              sandhi_name: 'परसवर्णसन्धिः (Torli Sandhi)',
              sutra: 'तोर्लि (8.4.60)',
              rule: "#{c1} + ल → ल्ल",
              explanation: 'A letter of तवर्ग is converted to a परसवर्ण when followed by a लकार. (Pāṇini 8.4.60)'
            }
          elsif first_c == 'ह'
            joined = base1 + 'द्ध' + p2.chars[1..-1].join
            results << {
              result: joined,
              sandhi_name: 'पूर्वसवर्णसन्धिः (Pūrvasavarṇa Sandhi)',
              sutra: 'झयो होऽन्यतरस्याम् (8.4.62)',
              rule: "#{c1} + ह → द्ध",
              explanation: 'A हकार following a झय् letter is optionally converted to the पूर्वसवर्ण (i.e. वर्गचतुर्थ). (Pāṇini 8.4.62)'
            }
          end
        end

        # 3. Anunasika Sandhi (यरोऽनुनासिकेऽनुनासिको वा 8.4.45)
        nasal_map = { 'क्' => 'ङ्', 'ग्' => 'ङ्', 'च्' => 'ञ्', 'ज्' => 'ञ्',
                      'ट्' => 'ण्', 'ड्' => 'ण्', 'त्' => 'न्', 'द्' => 'न्',
                      'प्' => 'म्', 'ब्' => 'म्' }
        if nasal_map.key?(c1) && %w[न म].include?(first_c)
          n_rep = nasal_map[c1]
          results << {
            result: base1 + n_rep + p2,
            sandhi_name: 'अनुनासिकसन्धिः (Anunāsika Sandhi)',
            sutra: 'यरोऽनुनासिकेऽनुनासिको वा (8.4.45)',
            rule: "#{c1} + #{first_c} → #{n_rep}#{first_c}",
            explanation: 'A यर् letter occurring at end of a पद is optionally converted to an अनुनासिक when it is followed by an अनुनासिक. (Pāṇini 8.4.45)'
          }
        end

        # 4. म् + Consonant -> Anusvara (मोऽनुस्वारः 8.3.23)
        if c1 == 'म्'
          results << {
            result: base1 + 'ं' + p2,
            sandhi_name: 'अनुस्वारसन्धिः (Anusvāra Sandhi)',
            sutra: 'मोऽनुस्वारः (8.3.23)',
            rule: "म् + #{first_c} → ं#{first_c}",
            explanation: 'In the context of संहिता, the मकार at the end of a पद is converted to अनुस्वार when it is followed by a हल् वर्ण. (Pāṇini 8.3.23)'
          }
        end

        # 5. General Jashva before voiced consonants (झलां जशोऽन्ते 8.2.39)
        voiced_cons = %w[ग घ ज झ ड ढ द ध ब भ य र ल व ह]
        if jash_map.key?(c1) && voiced_cons.include?(first_c) && results.empty?
          voiced_c = jash_map[c1]
          results << {
            result: base1 + voiced_c + p2,
            sandhi_name: 'जश्त्वसन्धिः (Jaśtva Sandhi)',
            sutra: 'झलां जशोऽन्ते (8.2.39)',
            rule: "#{c1} + #{first_c} → #{voiced_c}#{first_c}",
            explanation: 'A झल् letter occurring at end of a पद is converted to the corresponding जश् letter. (Pāṇini 8.2.39)'
          }
        end
      end
    end

    if results.empty?
      results << {
        result: "#{p1} #{p2}",
        sandhi_name: 'संहिताभावः / प्रकृतिभावः (No Sandhi Change)',
        sutra: 'संहितैकपदे नित्या',
        rule: "#{p1} + #{p2} → #{p1} #{p2}",
        explanation: 'संहितैकपदे नित्या नित्या धातूपसर्गयोः । नित्या समासे वाक्ये तु सा विवक्षामपेक्षते ॥ (Kāśikā / Siddhāntakaumudī)'
      }
    end

    results.map do |r|
      r.merge(
        result_te: SanskritTransliterator.dev_to_telugu(r[:result]),
        result_iast: SanskritTransliterator.dev_to_iast(r[:result])
      )
    end
  end

  def split_sandhi(word_raw)
    w = SanskritTransliterator.ensure_utf8(word_raw).strip
    return [] if w.empty?
    w = SanskritTransliterator.telugu_to_dev(w) if w.match?(/[\u0C00-\u0C7F]/)

    splits = []

    # 1. Purvarupa avagraha: ओऽ -> अः + अ OR ओ + अ; एऽ -> ए + अ
    if w.include?('ोऽ')
      left, right = w.split('ोऽ', 2)
      splits << {
        pada1: "#{left}ः", pada2: "अ#{right}",
        sandhi_name: 'विसर्ग-उत्व-पूर्वरूपसन्धिः',
        sutra: 'अतो रोरप्लुतादप्लुते (6.1.113) / एङः पदान्तादति (6.1.109)',
        explanation: 'A रुँ letter that is sandwiched between an अप्लुत-ह्रस्व-अकार from each side is converted to an उकार (6.1.113), then पूर्वरूप एकादेश (6.1.109).'
      }
      splits << {
        pada1: "#{left}ो", pada2: "अ#{right}",
        sandhi_name: 'पूर्वरूपसन्धिः',
        sutra: 'एङः पदान्तादति (6.1.109)',
        explanation: 'If a पदान्त ए / ओ letter is followed by a ह्रस्व अकार, then both of them combine to form a पूर्वरूप एकादेश. (Pāṇini 6.1.109)'
      }
    end
    if w.include?('ेऽ')
      left, right = w.split('ेऽ', 2)
      splits << {
        pada1: "#{left}े", pada2: "अ#{right}",
        sandhi_name: 'पूर्वरूपसन्धिः',
        sutra: 'एङः पदान्तादति (6.1.109)',
        explanation: 'If a पदान्त ए / ओ letter is followed by a ह्रस्व अकार, then both of them combine to form a पूर्वरूप एकादेश. (Pāṇini 6.1.109)'
      }
    end

    # 2. Scan internal matras & clusters for Savarna Dirgha, Guna, Vriddhi, Yan, Ayadi, Hal, Visarga
    chars = w.chars
    chars.each_with_index do |ch, idx|
      next if idx == 0 || idx >= chars.size - 1
      left_prefix = chars[0...idx].join
      right_suffix = chars[(idx + 1)..-1].join

      case ch
      when 'ा'
        splits << { pada1: left_prefix, pada2: "आ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
        splits << { pada1: left_prefix, pada2: "अ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
        splits << { pada1: "#{left_prefix}ा", pada2: "आ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
        splits << { pada1: "#{left_prefix}ा", pada2: "अ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
      when 'ी'
        splits << { pada1: "#{left_prefix}ि", pada2: "इ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
        splits << { pada1: "#{left_prefix}ी", pada2: "ई#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
      when 'ू'
        splits << { pada1: "#{left_prefix}ु", pada2: "उ#{right_suffix}", sandhi_name: 'सवर्णदीर्घसन्धिः', sutra: 'अकः सवर्णे दीर्घः (6.1.101)', explanation: 'In the context of संहिता, when an अक् letter is followed by a सवर्ण अच् letter, both of them are replaced by a दीर्घ-एकादेश. (Pāṇini 6.1.101)' }
      when 'े'
        splits << { pada1: left_prefix, pada2: "इ#{right_suffix}", sandhi_name: 'गुणसन्धिः', sutra: 'आद्गुणः (6.1.87)', explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter. (Pāṇini 6.1.87)' }
        splits << { pada1: left_prefix, pada2: "ई#{right_suffix}", sandhi_name: 'गुणसन्धिः', sutra: 'आद्गुणः (6.1.87)', explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter. (Pāṇini 6.1.87)' }
      when 'ो'
        splits << { pada1: left_prefix, pada2: "उ#{right_suffix}", sandhi_name: 'गुणसन्धिः', sutra: 'आद्गुणः (6.1.87)', explanation: 'When an अवर्ण is followed by an अच् letter in the context of संहिता, both of them are replaced by a single गुण letter. (Pāṇini 6.1.87)' }
        splits << { pada1: "#{left_prefix}ः", pada2: right_suffix, sandhi_name: 'विसर्ग-उत्वसन्धिः', sutra: 'हशि च (6.1.114)', explanation: 'A रुँ letter that follows an अप्लुत-ह्रस्व-अकार and is followed by a हश् letter is converted to an उकार. (Pāṇini 6.1.114)' }
      when 'ै'
        splits << { pada1: left_prefix, pada2: "ए#{right_suffix}", sandhi_name: 'वृद्धिसन्धिः', sutra: 'वृद्धिरेचि (6.1.88)', explanation: 'When an अवर्ण is followed by an एच् letter in the context of संहिता, both of them are replaced by a single वृद्धि letter. (Pāṇini 6.1.88)' }
      when 'ौ'
        splits << { pada1: left_prefix, pada2: "ओ#{right_suffix}", sandhi_name: 'वृद्धिसन्धिः', sutra: 'वृद्धिरेचि (6.1.88)', explanation: 'When an अवर्ण is followed by an एच् letter in the context of संहिता, both of them are replaced by a single वृद्धि letter. (Pāṇini 6.1.88)' }
      end

      # Yan Sandhi: ् + य / व
      if ch == '्' && idx + 1 < chars.size
        nxt = chars[idx + 1]
        after_nxt = chars[(idx + 2)..-1].join
        v_following = 'अ'
        rest_after = after_nxt
        if !after_nxt.empty? && MATRA_TO_VOWEL.key?(after_nxt[0])
          v_following = MATRA_TO_VOWEL[after_nxt[0]]
          rest_after = after_nxt[1..-1]
        end

        if nxt == 'य'
          splits << {
            pada1: "#{left_prefix}ि", pada2: "#{v_following}#{rest_after}",
            sandhi_name: 'यण्सन्धिः', sutra: 'इको यणचि (6.1.77)',
            explanation: 'An इक् letter which is followed by a स्वर is converted to a corresponding यण् letter in the context of संहिता. (Pāṇini 6.1.77)'
          }
        elsif nxt == 'व'
          splits << {
            pada1: "#{left_prefix}ु", pada2: "#{v_following}#{rest_after}",
            sandhi_name: 'यण्सन्धिः', sutra: 'इको यणचि (6.1.77)',
            explanation: 'An इक् letter which is followed by a स्वर is converted to a corresponding यण् letter in the context of संहिता. (Pāṇini 6.1.77)'
          }
        end
      end
    end

    # Check common Hal/Visarga clusters
    cluster_rules = [
      ['च्च', 'त्', 'च', 'स्तोः श्चुना श्चुः (8.4.40)', 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a शकार and चवर्ग letter when associated with a शकार or a चवर्ग letter. (Pāṇini 8.4.40)'],
      ['च्छ', 'त्', 'श', 'शश्छोऽटि (8.4.63)', 'A शकार sandwiched between a झय् letter on the left and an अट् letter on the right is optionally converted to a छकार. (Pāṇini 8.4.63)'],
      ['ज्ज', 'त्', 'ज', 'स्तोः श्चुना श्चुः (8.4.40)', 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a शकार and चवर्ग letter when associated with a शकार or a चवर्ग letter. (Pāṇini 8.4.40)'],
      ['ट्ट', 'त्', 'ट', 'ष्टुना ष्टुः (8.4.41)', 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a षकार and टवर्ग letter when associated with a षकार or a टवर्ग letter. (Pāṇini 8.4.41)'],
      ['ड्ड', 'त्', 'ड', 'ष्टुना ष्टुः (8.4.41)', 'In the context of संहिता, a सकार and a तवर्ग letter are converted (respectively) to a षकार and टवर्ग letter when associated with a षकार or a टवर्ग letter. (Pāṇini 8.4.41)'],
      ['ल्ल', 'त्', 'ल', 'तोर्लि (8.4.60)', 'A letter of तवर्ग is converted to a परसवर्ण when followed by a लकार. (Pāṇini 8.4.60)'],
      ['द्ध', 'त्', 'ह', 'झयो होऽन्यतरस्याम् (8.4.62)', 'A हकार following a झय् letter is optionally converted to the पूर्वसवर्ण (i.e. वर्गचतुर्थ). (Pāṇini 8.4.62)'],
      ['श्च', 'ः', 'च', 'विसर्जनीयस्य सः (8.3.34) / स्तोः श्चुना श्चुः (8.4.40)', 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by खर् (8.3.34), then to शकार by स्तोः श्चुना श्चुः (8.4.40).'],
      ['ष्ट', 'ः', 'ट', 'विसर्जनीयस्य सः (8.3.34) / ष्टुना ष्टुः (8.4.41)', 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by खर् (8.3.34), then to षकार by ष्टुना ष्टुः (8.4.41).'],
      ['स्त', 'ः', 'त', 'विसर्जनीयस्य सः (8.3.34)', 'A विसर्ग occurring at end of a पद is converted to a सकार when followed by a letter from the खर् प्रत्याहार. (Pāṇini 8.3.34)'],
      ['न्न', 'त्', 'न', 'यरोऽनुनासिकेऽनुनासिको वा (8.4.45)', 'A यर् letter occurring at end of a पद is optionally converted to an अनुनासिक when it is followed by an अनुनासिक. (Pāṇini 8.4.45)'],
      ['न्म', 'त्', 'म', 'यरोऽनुनासिकेऽनुनासिको वा (8.4.45)', 'A यर् letter occurring at end of a पद is optionally converted to an अनुनासिक when it is followed by an अनुनासिक. (Pāṇini 8.4.45)'],
      ['ङ्म', 'क्', 'म', 'यरोऽनुनासिकेऽनुनासिको वा (8.4.45)', 'A यर् letter occurring at end of a पद is optionally converted to an अनुनासिक when it is followed by an अनुनासिक. (Pāṇini 8.4.45)']
    ]

    cluster_rules.each do |cluster, rep1, rep2, sutra_ref, expl|
      if w.include?(cluster)
        l, r = w.split(cluster, 2)
        splits << {
          pada1: "#{l}#{rep1}", pada2: "#{rep2}#{r}",
          sandhi_name: 'व्यञ्जन/विसर्गसन्धिः',
          sutra: sutra_ref,
          explanation: expl
        }
      end
    end

    unique_splits = splits.uniq { |s| [s[:pada1], s[:pada2]] }
    # Sort balanced splits (where both pada1 and pada2 have at least 2 characters) first
    sorted_splits = unique_splits.sort_by do |s|
      min_len = [s[:pada1].length, s[:pada2].length].min
      [min_len >= 2 ? 0 : 1, (s[:pada1].length - s[:pada2].length).abs]
    end

    sorted_splits.first(12).map do |s|
      s.merge(
        pada1_te: SanskritTransliterator.dev_to_telugu(s[:pada1]),
        pada2_te: SanskritTransliterator.dev_to_telugu(s[:pada2]),
        pada1_iast: SanskritTransliterator.dev_to_iast(s[:pada1]),
        pada2_iast: SanskritTransliterator.dev_to_iast(s[:pada2])
      )
    end
  end

  # ==========================================================================
  # 2. ALGORITHMIC SHABDA VIBHAKTI GENERATOR (Paninian Declension Engine)
  # ==========================================================================

  # Check if Paninian Natva (8.4.2 अट्कुप्वाङ्नुम्व्यवायेऽपि) applies to transform न -> ण
  def apply_natva(stem_Part, suffix)
    return stem_Part + suffix unless suffix.include?('न')
    # Check if stem_Part contains र, ष, ऋ, ॠ, ृ, ॄ and after its last occurrence only at/ku/pu/ang/num intervene
    allowed_intervening = /^[अआइईउऊऋॠऌएऐओऔािीुूृॄेैोौकखगघङपफबभमयरवहंँ्]*$/
    last_trigger = stem_Part.rindex(/[रषऋॠृॄ]/)
    if last_trigger
      intervening = stem_Part[(last_trigger + 1)..-1]
      if intervening.match?(allowed_intervening)
        # Replace first न in suffix (unless न is at word end like रामान्)
        new_suffix = suffix.sub(/न(?!्$)/, 'ण')
        return stem_Part + new_suffix
      end
    end
    stem_Part + suffix
  end

  def generate_declension(stem_raw, linga_raw = 'P')
    stem = SanskritTransliterator.ensure_utf8(stem_raw).strip
    return nil if stem.empty?
    stem = SanskritTransliterator.telugu_to_dev(stem) if stem.match?(/[\u0C00-\u0C7F]/)
    # Strip trailing visarga/am if user entered प्रथमा एकवचनम् like रामः or फलम्
    stem = stem.sub(/ः$/, '')
    linga = linga_raw.to_s.strip.upcase
    linga = 'P' unless %w[P S N].include?(linga)

    anta = 'अकारान्तः'
    forms = []

    if stem.end_with?('्')
      if stem.end_with?('न्') && !stem.end_with?('इन्')
        # नकारान्त (e.g. राजन्, आत्मन्, नामन्, कर्मन्)
        anta = 'नकारान्तः'
        base = stem.sub(/अ?न्$/, '').sub(/न्$/, '')
        # By न संयोगाद्वमन्तात् (6.4.137), अ is NOT elided if base ends in a conjunct ending with व or म (e.g. आत्मन्, कर्मन्, ब्रह्मन्, अध्वन्)
        conjunct_vm = base.match?(/्[वम]$/)
        bha_stem = if conjunct_vm
                     base
                   elsif base.end_with?('ज')
                     # अल्लोपोऽनः (6.4.134) + स्तोः श्चुना श्चुः (8.4.40): राज् + न -> राज्ञ
                     "#{base}्"
                   else
                     "#{base}्"
                   end

        join_bha = lambda do |suf|
          if conjunct_vm
            apply_natva(base, suf)
          elsif base.end_with?('ज')
            "#{base}्" + suf.sub(/^न/, 'ञ')
          else
            apply_natva("#{base}्", suf)
          end
        end

        if linga == 'N'
          du_nom = conjunct_vm ? apply_natva(base, 'नी') : "#{join_bha.call('नी')} / #{apply_natva(base, 'नी')}"
          loc_sg = conjunct_vm ? apply_natva(base, 'नि') : "#{join_bha.call('नि')} / #{apply_natva(base, 'नि')}"
          pl_nom = apply_natva("#{base}ा", 'नि')
          forms = [
            [base, du_nom, pl_nom, 'प्रथमा'],
            [base, du_nom, pl_nom, 'द्वितीया'],
            [join_bha.call('ना'), "#{base}भ्याम्", "#{base}भिः", 'तृतीया'],
            [join_bha.call('ने'), "#{base}भ्याम्", "#{base}भ्यः", 'चतुर्थी'],
            [join_bha.call('नः'), "#{base}भ्याम्", "#{base}भ्यः", 'पञ्चमी'],
            [join_bha.call('नः'), join_bha.call('नोः'), join_bha.call('नाम्'), 'षष्ठी'],
            [loc_sg, join_bha.call('नोः'), "#{base}सु", 'सप्तमी'],
            ["हे #{base}न् / हे #{base}", "हे #{du_nom}", "हे #{pl_nom}", 'सम्बोधनम्']
          ]
        else
          loc_sg = conjunct_vm ? apply_natva(base, 'नि') : "#{join_bha.call('नि')} / #{apply_natva(base, 'नि')}"
          forms = [
            ["#{base}ा", "#{base}ानौ", "#{base}ानः", 'प्रथमा'],
            ["#{base}ानम्", "#{base}ानौ", join_bha.call('नः'), 'द्वितीया'],
            [join_bha.call('ना'), "#{base}भ्याम्", "#{base}भिः", 'तृतीया'],
            [join_bha.call('ने'), "#{base}भ्याम्", "#{base}भ्यः", 'चतुर्थी'],
            [join_bha.call('नः'), "#{base}भ्याम्", "#{base}भ्यः", 'पञ्चमी'],
            [join_bha.call('नः'), join_bha.call('नोः'), join_bha.call('नाम्'), 'षष्ठी'],
            [loc_sg, join_bha.call('नोः'), "#{base}सु", 'सप्तमी'],
            ["हे #{base}न्", "हे #{base}ानौ", "हे #{base}ानः", 'सम्बोधनम्']
          ]
        end
      elsif stem.end_with?('इन्')
        # इन्-अन्त (e.g. ज्ञानिन्, गुणिन्, योगिन्)
        anta = 'इन्नन्तः (नकारान्तः)'
        base = stem.sub(/इन्$/, '').sub(/िन्$/, '') # e.g. ज्ञान
        forms = [
          ["#{base}ी", "#{base}िनौ", "#{base}िनः", 'प्रथमा'],
          ["#{base}िनम्", "#{base}िनौ", "#{base}िनः", 'द्वितीया'],
          [apply_natva("#{base}ि", 'ना'), "#{base}िभ्याम्", "#{base}िभिः", 'तृतीया'],
          ["#{base}िने", "#{base}िभ्याम्", "#{base}िभ्यः", 'चतुर्थी'],
          ["#{base}िनः", "#{base}िभ्याम्", "#{base}िभ्यः", 'पञ्चमी'],
          ["#{base}िनः", "#{base}िनोः", apply_natva("#{base}ि", 'नाम्'), 'षष्ठी'],
          ["#{base}िनि", "#{base}िनोः", "#{base}िषु", 'सप्तमी'],
          ["हे #{base}िन्", "हे #{base}िनौ", "हे #{base}िनः", 'सम्बोधनम्']
        ]
      elsif stem.end_with?('त्')
        # तकारान्त / वतुप् / मतुप् (e.g. भवत्, भगवत्, श्रीमत्, जगत्, मरुत्)
        anta = 'तकारान्तः'
        base = stem.sub(/त्$/, '')
        if linga == 'N'
          forms = [
            ["#{base}त्", "#{base}ती", "#{base}न्ति", 'प्रथमा'],
            ["#{base}त्", "#{base}ती", "#{base}न्ति", 'द्वितीया'],
            ["#{base}ता", "#{base}द्भ्याम्", "#{base}द्भिः", 'तृतीया'],
            ["#{base}ते", "#{base}द्भ्याम्", "#{base}द्भ्यः", 'चतुर्थी'],
            ["#{base}तः", "#{base}द्भ्याम्", "#{base}द्भ्यः", 'पञ्चमी'],
            ["#{base}तः", "#{base}तोः", "#{base}ताम्", 'षष्ठी'],
            ["#{base}ति", "#{base}तोः", "#{base}त्सु", 'सप्तमी'],
            ["हे #{base}त्", "हे #{base}ती", "हे #{base}न्ति", 'सम्बोधनम्']
          ]
        else
          nom_sg = base.end_with?('व', 'म') ? "#{base}ान्" : "#{base}न् / #{base}त्"
          nom_du = base.end_with?('व', 'म') ? "#{base}न्तौ" : "#{base}तौ"
          nom_pl = base.end_with?('व', 'म') ? "#{base}न्तः" : "#{base}तः"
          acc_sg = base.end_with?('व', 'म') ? "#{base}न्तम्" : "#{base}तम्"
          forms = [
            [nom_sg, nom_du, nom_pl, 'प्रथमा'],
            [acc_sg, nom_du, "#{base}तः", 'द्वितीया'],
            ["#{base}ता", "#{base}द्भ्याम्", "#{base}द्भिः", 'तृतीया'],
            ["#{base}ते", "#{base}द्भ्याम्", "#{base}द्भ्यः", 'चतुर्थी'],
            ["#{base}तः", "#{base}द्भ्याम्", "#{base}द्भ्यः", 'पञ्चमी'],
            ["#{base}तः", "#{base}तोः", "#{base}ताम्", 'षष्ठी'],
            ["#{base}ति", "#{base}तोः", "#{base}त्सु", 'सप्तमी'],
            ["हे #{base}न् / हे #{base}त्", "हे #{nom_du}", "हे #{nom_pl}", 'सम्बोधनम्']
          ]
        end
      elsif stem.end_with?('स्')
        # सकारान्त (e.g. मनस्, यशस्, चन्द्रमस्)
        anta = 'सकारान्तः'
        base = stem.sub(/स्$/, '')
        if linga == 'N'
          forms = [
            ["#{base}ः", "#{base}सी", "#{base}ांसि", 'प्रथमा'],
            ["#{base}ः", "#{base}सी", "#{base}ांसि", 'द्वितीया'],
            ["#{base}सा", "#{base}ोभ्याम्", "#{base}ोभिः", 'तृतीया'],
            ["#{base}से", "#{base}ोभ्याम्", "#{base}ोभ्यः", 'चतुर्थी'],
            ["#{base}सः", "#{base}ोभ्याम्", "#{base}ोभ्यः", 'पञ्चमी'],
            ["#{base}सः", "#{base}सोः", "#{base}साम्", 'षष्ठी'],
            ["#{base}सि", "#{base}सोः", "#{base}ःसु / #{base}स्सु", 'सप्तमी'],
            ["हे #{base}ः", "हे #{base}सी", "हे #{base}ांसि", 'सम्बोधनम्']
          ]
        else
          forms = [
            ["#{base}ाः", "#{base}सौ", "#{base}सः", 'प्रथमा'],
            ["#{base}सम्", "#{base}सौ", "#{base}सः", 'द्वितीया'],
            ["#{base}सा", "#{base}ोभ्याम्", "#{base}ोभिः", 'तृतीया'],
            ["#{base}से", "#{base}ोभ्याम्", "#{base}ोभ्यः", 'चतुर्थी'],
            ["#{base}सः", "#{base}ोभ्याम्", "#{base}ोभ्यः", 'पञ्चमी'],
            ["#{base}सः", "#{base}सोः", "#{base}साम्", 'षष्ठी'],
            ["#{base}सि", "#{base}सोः", "#{base}ःसु / #{base}स्सु", 'सप्तमी'],
            ["हे #{base}ः", "हे #{base}सौ", "हे #{base}सः", 'सम्बोधनम्']
          ]
        end
      end
    elsif stem.end_with?('ा')
      # आकारान्त स्त्रीलिङ्गः (e.g. रमा, लता, विद्या)
      anta = 'आकारान्तः'
      base = stem.sub(/ा$/, '')
      forms = [
        ["#{base}ा", "#{base}े", "#{base}ाः", 'प्रथमा'],
        ["#{base}ाम्", "#{base}े", "#{base}ाः", 'द्वितीया'],
        ["#{base}या", "#{base}ाभ्याम्", "#{base}ाभिः", 'तृतीया'],
        ["#{base}ायै", "#{base}ाभ्याम्", "#{base}ाभ्यः", 'चतुर्थी'],
        ["#{base}ायाः", "#{base}ाभ्याम्", "#{base}ाभ्यः", 'पञ्चमी'],
        ["#{base}ायाः", "#{base}योः", apply_natva("#{base}ा", 'नाम्'), 'षष्ठी'],
        ["#{base}ायाम्", "#{base}योः", "#{base}ासु", 'सप्तमी'],
        ["हे #{base}े", "हे #{base}े", "हे #{base}ाः", 'सम्बोधनम्']
      ]
    elsif stem.end_with?('ि')
      # इकारान्तः (e.g. हरि, कवि, मति, वारि)
      anta = 'इकारान्तः'
      base = stem.sub(/ि$/, '')
      if linga == 'S'
        forms = [
          ["#{base}िः", "#{base}ी", "#{base}यः", 'प्रथमा'],
          ["#{base}िम्", "#{base}ी", "#{base}ीः", 'द्वितीया'],
          ["#{base}्या", "#{base}िभ्याम्", "#{base}िभिः", 'तृतीया'],
          ["#{base}ये / #{base}्यै", "#{base}िभ्याम्", "#{base}िभ्यः", 'चतुर्थी'],
          ["#{base}ेः / #{base}्याः", "#{base}िभ्याम्", "#{base}िभ्यः", 'पञ्चमी'],
          ["#{base}ेः / #{base}्याः", "#{base}्योः", apply_natva("#{base}ी", 'नाम्'), 'षष्ठी'],
          ["#{base}ौ / #{base}्याम्", "#{base}्योः", "#{base}िषु", 'सप्तमी'],
          ["हे #{base}े", "हे #{base}ी", "हे #{base}यः", 'सम्बोधनम्']
        ]
      elsif linga == 'N'
        forms = [
          ["#{base}ि", apply_natva("#{base}ि", 'नी'), apply_natva("#{base}ी", 'नि'), 'प्रथमा'],
          ["#{base}ि", apply_natva("#{base}ि", 'नी'), apply_natva("#{base}ी", 'नि'), 'द्वितीया'],
          [apply_natva("#{base}ि", 'ना'), "#{base}िभ्याम्", "#{base}िभिः", 'तृतीया'],
          [apply_natva("#{base}ि", 'ने'), "#{base}िभ्याम्", "#{base}िभ्यः", 'चतुर्थी'],
          [apply_natva("#{base}ि", 'नः'), "#{base}िभ्याम्", "#{base}िभ्यः", 'पञ्चमी'],
          [apply_natva("#{base}ि", 'नः'), apply_natva("#{base}ि", 'नोः'), apply_natva("#{base}ी", 'नाम्'), 'षष्ठी'],
          [apply_natva("#{base}ि", 'नि'), apply_natva("#{base}ि", 'नोः'), "#{base}िषु", 'सप्तमी'],
          ["हे #{base}े / हे #{base}ि", "हे #{apply_natva("#{base}ि", 'नी')}", "हे #{apply_natva("#{base}ी", 'नि')}", 'सम्बोधनम्']
        ]
      else
        forms = [
          ["#{base}िः", "#{base}ी", "#{base}यः", 'प्रथमा'],
          ["#{base}िम्", "#{base}ी", "#{base}ीन्", 'द्वितीया'],
          [apply_natva("#{base}ि", 'ना'), "#{base}िभ्याम्", "#{base}िभिः", 'तृतीया'],
          ["#{base}ये", "#{base}िभ्याम्", "#{base}िभ्यः", 'चतुर्थी'],
          ["#{base}ेः", "#{base}िभ्याम्", "#{base}िभ्यः", 'पञ्चमी'],
          ["#{base}ेः", "#{base}्योः", apply_natva("#{base}ी", 'नाम्'), 'षष्ठी'],
          ["#{base}ौ", "#{base}्योः", "#{base}िषु", 'सप्तमी'],
          ["हे #{base}े", "हे #{base}ी", "हे #{base}यः", 'सम्बोधनम्']
        ]
      end
    elsif stem.end_with?('ी')
      # ईकारान्तः (e.g. नदी, देवी, गौरी)
      anta = 'ईकारान्तः'
      base = stem.sub(/ी$/, '')
      forms = [
        ["#{base}ी", "#{base}्यौ", "#{base}्यः", 'प्रथमा'],
        ["#{base}ीम्", "#{base}्यौ", "#{base}ीः", 'द्वितीया'],
        ["#{base}्या", "#{base}ीभ्याम्", "#{base}ीभिः", 'तृतीया'],
        ["#{base}्यै", "#{base}ीभ्याम्", "#{base}ीभ्यः", 'चतुर्थी'],
        ["#{base}्याः", "#{base}ीभ्याम्", "#{base}ीभ्यः", 'पञ्चमी'],
        ["#{base}्याः", "#{base}्योः", apply_natva("#{base}ी", 'नाम्'), 'षष्ठी'],
        ["#{base}्याम्", "#{base}्योः", "#{base}ीषु", 'सप्तमी'],
        ["हे #{base}ि", "हे #{base}्यौ", "हे #{base}्यः", 'सम्बोधनम्']
      ]
    elsif stem.end_with?('ु')
      # उकारान्तः (e.g. गुरु, भानु, धेनु, मधु)
      anta = 'उकारान्तः'
      base = stem.sub(/ु$/, '')
      if linga == 'S'
        forms = [
          ["#{base}ुः", "#{base}ू", "#{base}वः", 'प्रथमा'],
          ["#{base}ुम्", "#{base}ू", "#{base}ूः", 'द्वितीया'],
          ["#{base}्वा", "#{base}ुभ्याम्", "#{base}ुभिः", 'तृतीया'],
          ["#{base}वे / #{base}्वै", "#{base}ुभ्याम्", "#{base}ुभ्यः", 'चतुर्थी'],
          ["#{base}ोः / #{base}्वाः", "#{base}ुभ्याम्", "#{base}ुभ्यः", 'पञ्चमी'],
          ["#{base}ोः / #{base}्वाः", "#{base}्वोः", apply_natva("#{base}ू", 'नाम्'), 'षष्ठी'],
          ["#{base}ौ / #{base}्वाम्", "#{base}्वोः", "#{base}ुषु", 'सप्तमी'],
          ["हे #{base}ो", "हे #{base}ू", "हे #{base}वः", 'सम्बोधनम्']
        ]
      elsif linga == 'N'
        forms = [
          ["#{base}ु", apply_natva("#{base}ु", 'नी'), apply_natva("#{base}ू", 'नि'), 'प्रथमा'],
          ["#{base}ु", apply_natva("#{base}ु", 'नी'), apply_natva("#{base}ू", 'नि'), 'द्वितीया'],
          [apply_natva("#{base}ु", 'ना'), "#{base}ुभ्याम्", "#{base}ुभिः", 'तृतीया'],
          [apply_natva("#{base}ु", 'ने'), "#{base}ुभ्याम्", "#{base}ुभ्यः", 'चतुर्थी'],
          [apply_natva("#{base}ु", 'नः'), "#{base}ुभ्याम्", "#{base}ुभ्यः", 'पञ्चमी'],
          [apply_natva("#{base}ु", 'नः'), apply_natva("#{base}ु", 'नोः'), apply_natva("#{base}ू", 'नाम्'), 'षष्ठी'],
          [apply_natva("#{base}ु", 'नि'), apply_natva("#{base}ु", 'नोः'), "#{base}ुषु", 'सप्तमी'],
          ["हे #{base}ो / हे #{base}ु", "हे #{apply_natva("#{base}ु", 'नी')}", "हे #{apply_natva("#{base}ू", 'नि')}", 'सम्बोधनम्']
        ]
      else
        forms = [
          ["#{base}ुः", "#{base}ू", "#{base}वः", 'प्रथमा'],
          ["#{base}ुम्", "#{base}ू", "#{base}ून्", 'द्वितीया'],
          [apply_natva("#{base}ु", 'ना'), "#{base}ुभ्याम्", "#{base}ुभिः", 'तृतीया'],
          ["#{base}वे", "#{base}ुभ्याम्", "#{base}ुभ्यः", 'चतुर्थी'],
          ["#{base}ोः", "#{base}ुभ्याम्", "#{base}ुभ्यः", 'पञ्चमी'],
          ["#{base}ोः", "#{base}्वोः", apply_natva("#{base}ू", 'नाम्'), 'षष्ठी'],
          ["#{base}ौ", "#{base}्वोः", "#{base}ुषु", 'सप्तमी'],
          ["हे #{base}ो", "हे #{base}ू", "हे #{base}वः", 'सम्बोधनम्']
        ]
      end
    elsif stem.end_with?('ू')
      # ऊकारान्तः (e.g. वधू, चमू)
      anta = 'ऊकारान्तः'
      base = stem.sub(/ू$/, '')
      forms = [
        ["#{base}ूः", "#{base}्वौ", "#{base}्वः", 'प्रथमा'],
        ["#{base}ूम्", "#{base}्वौ", "#{base}ूः", 'द्वितीया'],
        ["#{base}्वा", "#{base}ूभ्याम्", "#{base}ूभिः", 'तृतीया'],
        ["#{base}्वै", "#{base}ूभ्याम्", "#{base}ूभ्यः", 'चतुर्थी'],
        ["#{base}्वाः", "#{base}ूभ्याम्", "#{base}ूभ्यः", 'पञ्चमी'],
        ["#{base}्वाः", "#{base}्वोः", apply_natva("#{base}ू", 'नाम्'), 'षष्ठी'],
        ["#{base}्वाम्", "#{base}्वोः", "#{base}ूषु", 'सप्तमी'],
        ["हे #{base}ु", "हे #{base}्वौ", "हे #{base}्वः", 'सम्बोधनम्']
      ]
    elsif stem.end_with?('ृ')
      # ऋकारान्तः (e.g. पितृ, भ्रातृ, मातृ, दातृ, कर्तृ)
      anta = 'ऋकारान्तः'
      base = stem.sub(/ृ$/, '')
      is_naptr = %w[पितृ भ्रातृ जामातृ देवृ नृ सव्येष्ठृ मातृ दुहितृ ननान्दृ यातृ].include?(stem)
      du_pl_stem = is_naptr ? "#{base}र" : "#{base}ार"
      acc_pl = linga == 'S' ? "#{base}ॄः" : "#{base}ॄन्"
      forms = [
        ["#{base}ा", "#{du_pl_stem}ौ", "#{du_pl_stem}ः", 'प्रथमा'],
        ["#{du_pl_stem}म्", "#{du_pl_stem}ौ", acc_pl, 'द्वितीया'],
        ["#{base}्रा", "#{base}ृभ्याम्", "#{base}ृभिः", 'तृतीया'],
        ["#{base}्रे", "#{base}ृभ्याम्", "#{base}ृभ्यः", 'चतुर्थी'],
        ["#{base}ुः", "#{base}ृभ्याम्", "#{base}ृभ्यः", 'पञ्चमी'],
        ["#{base}ुः", "#{base}्रोः", "#{base}ॄणाम्", 'षष्ठी'],
        ["#{base}रि", "#{base}्रोः", "#{base}ृषु", 'सप्तमी'],
        ["हे #{base}र्", "हे #{du_pl_stem}ौ", "हे #{du_pl_stem}ः", 'सम्बोधनम्']
      ]
    end

    # Default: अकारान्तः (e.g. राम, देव, बालक, फल, वन, ज्ञान)
    if forms.empty?
      anta = 'अकारान्तः'
      base = stem
      if linga == 'N'
        forms = [
          ["#{base}म्", "#{base}े", apply_natva("#{base}ा", 'नि'), 'प्रथमा'],
          ["#{base}म्", "#{base}े", apply_natva("#{base}ा", 'नि'), 'द्वितीया'],
          [apply_natva("#{base}े", 'न'), "#{base}ाभ्याम्", "#{base}ैः", 'तृतीया'],
          ["#{base}ाय", "#{base}ाभ्याम्", "#{base}ेभ्यः", 'चतुर्थी'],
          ["#{base}ात्", "#{base}ाभ्याम्", "#{base}ेभ्यः", 'पञ्चमी'],
          ["#{base}स्य", "#{base}योः", apply_natva("#{base}ा", 'नाम्'), 'षष्ठी'],
          ["#{base}े", "#{base}योः", "#{base}ेषु", 'सप्तमी'],
          ["हे #{base}", "हे #{base}े", "हे #{apply_natva("#{base}ा", 'नि')}", 'सम्बोधनम्']
        ]
      else
        forms = [
          ["#{base}ः", "#{base}ौ", "#{base}ाः", 'प्रथमा'],
          ["#{base}म्", "#{base}ौ", "#{base}ान्", 'द्वितीया'],
          [apply_natva("#{base}े", 'न'), "#{base}ाभ्याम्", "#{base}ैः", 'तृतीया'],
          ["#{base}ाय", "#{base}ाभ्याम्", "#{base}ेभ्यः", 'चतुर्थी'],
          ["#{base}ात्", "#{base}ाभ्याम्", "#{base}ेभ्यः", 'पञ्चमी'],
          ["#{base}स्य", "#{base}योः", apply_natva("#{base}ा", 'नाम्'), 'षष्ठी'],
          ["#{base}े", "#{base}योः", "#{base}ेषु", 'सप्तमी'],
          ["हे #{base}", "हे #{base}ौ", "हे #{base}ाः", 'सम्बोधनम्']
        ]
      end
    end

    flat_forms = forms.flat_map { |r| r[0..2] }.join(';')
    table = forms.map do |ek, dv, ba, vib|
      {
        vibhakti: vib,
        ekavachana: ek,
        dvivachana: dv,
        bahuvachana: ba,
        ekavachana_te: SanskritTransliterator.dev_to_telugu(ek),
        dvivachana_te: SanskritTransliterator.dev_to_telugu(dv),
        bahuvachana_te: SanskritTransliterator.dev_to_telugu(ba),
        ekavachana_iast: SanskritTransliterator.dev_to_iast(ek),
        dvivachana_iast: SanskritTransliterator.dev_to_iast(dv),
        bahuvachana_iast: SanskritTransliterator.dev_to_iast(ba)
      }
    end

    {
      word: stem,
      word_te: SanskritTransliterator.dev_to_telugu(stem),
      word_iast: SanskritTransliterator.dev_to_iast(stem),
      linga: linga,
      anta: anta,
      forms: flat_forms,
      table: table
    }
  end

  # ==========================================================================
  # 3. CHANDAS (PROSODY / METER) ANALYZER
  # ==========================================================================

  def split_aksharas(line_raw)
    line = line_raw.to_s.strip
    line = SanskritTransliterator.telugu_to_dev(line) if line.match?(/[\u0C00-\u0C7F]/)
    line = SanskritTransliterator.roman_to_dev(line) if line.match?(/[A-Za-zāīūṛṝḷḹṅñṭḍṇśṣṃḥĀĪŪṚṜḶḸṄÑṬḌṆŚṢṂḤ]/)
    # Strip punctuation and numbers
    clean = line.gsub(/[।॥0-9०-९,\.\-\!\?\(\)\[\]\"\'ऽ\s]+/, '')
    chars = clean.chars
    aksharas = []
    current = +''
    i = 0
    n = chars.size

    while i < n
      ch = chars[i]
      if CONSONANTS.include?(ch)
        current << ch
        if i + 1 < n && chars[i + 1] == '्'
          current << '्'
          i += 2
          next
        elsif i + 1 < n && MATRA_TO_VOWEL.key?(chars[i + 1])
          current << chars[i + 1]
          i += 2
        else
          i += 1
        end
        # Attach trailing anusvara / visarga / chandrabindu
        while i < n && %w[ं ः ँ].include?(chars[i])
          current << chars[i]
          i += 1
        end
        aksharas << current
        current = +''
      elsif VOWELS.include?(ch)
        current << ch
        i += 1
        while i < n && %w[ं ः ँ].include?(chars[i])
          current << chars[i]
          i += 1
        end
        aksharas << current
        current = +''
      else
        i += 1
      end
    end

    # Attach any trailing vowelless consonant cluster to the last akshara
    if !current.empty? && !aksharas.empty?
      aksharas[-1] = aksharas[-1] + current
    end

    aksharas
  end

  def analyze_pada_weights(aksharas)
    weights = []
    n = aksharas.size
    aksharas.each_with_index do |ak, idx|
      is_guru = false
      # 1. Contains long vowel or long matra?
      is_guru = true if ak.match?(/[आईऊॠॡएऐओऔाीूॄॣेैोौ]/)
      # 2. Ends with anusvara, visarga, or final halant?
      is_guru = true if ak.match?(/[ंःँ]/) || ak.end_with?('्')
      # 3. Followed by a conjunct consonant (Samyuktakshara) in the next akshara?
      if idx + 1 < n
        nxt = aksharas[idx + 1]
        is_guru = true if nxt.include?('्')
      end
      weights << (is_guru ? 'ऽ' : '।')
    end
    weights
  end

  def analyze_chandas(text_raw)
    raw_lines = SanskritTransliterator.ensure_utf8(text_raw).split(/\r?\n/).map(&:strip).reject(&:empty?)
    return { padas: [], summary: 'कृपया श्लोकं वा पादं वा लिखत (Please enter verse lines).' } if raw_lines.empty?

    padas = []
    raw_lines.each do |line|
      # Split by danda inside the line so prosodic conjunct weight does not cross pada boundaries
      segments = line.split(/[।॥]+/).map(&:strip).reject(&:empty?)
      segments = [line] if segments.empty?

      aksharas = []
      weights = []
      segments.each do |seg|
        seg_ak = split_aksharas(seg)
        next if seg_ak.empty?
        seg_wt = analyze_pada_weights(seg_ak)
        aksharas.concat(seg_ak)
        weights.concat(seg_wt)
      end

      next if aksharas.empty?
      idx = padas.size + 1
      pattern = weights.join
      matras = weights.sum { |w| w == 'ऽ' ? 2 : 1 }

      # Group into Gana triads
      ganas = []
      i = 0
      while i < weights.size
        chunk = weights[i, 3].join
        if chunk.chars.size == 3 && GANA_MAP.key?(chunk)
          ganas << GANA_MAP[chunk].merge(pattern: chunk)
        else
          chunk.chars.each do |c|
            ganas << {
              name: c == 'ऽ' ? 'गुरुः (Ga)' : 'लघुः (La)',
              symbol: c == 'ऽ' ? 'G' : 'L',
              pattern: c
            }
          end
        end
        i += 3
      end

      # Identify meter for this line
      matched_meter = nil
      syl_count = aksharas.size

      # 1. Check exact Vritta match (allowing final syllable to be optionally Guru by पादान्तगोऽपि वा)
      pattern_padanta_guru = pattern.empty? ? '' : (pattern[0...-1] + 'ऽ')
      METERS.each do |m|
        if m[:syllables] == syl_count && (m[:pattern] == pattern || m[:pattern] == pattern_padanta_guru)
          matched_meter = m
          break
        end
      end

      # 2. Check if line contains 2 padas of a known Vritta (e.g. 11+11=22, 12+12=24, 14+14=28)
      if matched_meter.nil? && syl_count.even? && syl_count >= 22
        half = syl_count / 2
        p1_pat = pattern[0...half]
        p2_pat = pattern[half..-1]
        p1_guru = p1_pat[0...-1] + 'ऽ'
        p2_guru = p2_pat[0...-1] + 'ऽ'
        METERS.each do |m|
          if m[:syllables] == half &&
             (m[:pattern] == p1_pat || m[:pattern] == p1_guru) &&
             (m[:pattern] == p2_pat || m[:pattern] == p2_guru)
            matched_meter = m.merge(
              name_sa: "#{m[:name_sa]} (द्विपाद-पंक्तिः #{half}+#{half})",
              name_en: "#{m[:name_en]} (2 Pādas: #{half}+#{half} syllables)"
            )
            break
          end
        end
      end

      # 3. Check Anushtubh (8 syllables per pada, or 16 syllables for an ardha-shloka line of 2 padas)
      if matched_meter.nil? && (syl_count == 8 || syl_count == 16)
        if syl_count == 8
          fifth = weights[4]
          sixth = weights[5]
          seventh = weights[6]
          note = if fifth == '।' && sixth == 'ऽ'
                   seventh == 'ऽ' ? 'अनुष्टुभ् (विषमपादः - पञ्चमं लघु, षष्ठं गुरु, सप्तमं गुरु)' : 'अनुष्टुभ् (समपादः - पञ्चमं लघु, षष्ठं गुरु, सप्तमं लघु)'
                 else
                   'अनुष्टुभ् (अष्टाक्षरी पादः)'
                 end
          matched_meter = {
            name_sa: 'अनुष्टुभ् (श्लोकः)',
            name_en: 'Anuṣṭubh (Śloka — 8 syllables)',
            syllables: 8,
            ganas: note,
            yati: '8',
            lakshana: 'श्लोके षष्ठं गुरु ज्ञेयं सर्वत्र लघु पञ्चमम् । द्विचतुष्पादयोर्ह्रस्वं सप्तमं दीर्घमन्ययोः ॥'
          }
        else
          matched_meter = {
            name_sa: 'अनुष्टुभ् (अर्धश्लोकः — ८ + ८)',
            name_en: 'Anuṣṭubh Half-Śloka (8 + 8 = 16 syllables)',
            syllables: 16,
            ganas: "पादौ १-२ (५-६-७: #{weights[4..6].join} | #{weights[12..14].join})",
            yati: '8, 8',
            lakshana: 'श्लोके षष्ठं गुरु ज्ञेयं सर्वत्र लघु पञ्चमम् । द्विचतुष्पादयोर्ह्रस्वं सप्तमं दीर्घमन्ययोः ॥'
          }
        end
      end

      # 4. Check Upajati (11 syllables matching Indravajra/Upendravajra after 1st syllable)
      if matched_meter.nil? && syl_count == 11 && pattern_padanta_guru[1..-1] == 'ऽ।ऽऽ।।ऽ।ऽऽ'
        matched_meter = {
          name_sa: 'उपजातिः',
          name_en: 'Upajāti',
          syllables: 11,
          ganas: 'इन्द्रवज्रा-उपेन्द्रवज्रामिश्रितम्',
          yati: '11',
          lakshana: 'अनन्तरोदीरितलक्ष्मभाजौ पादौ यदीयावुपजातयस्ताः ।'
        }
      end

      # Fallback by Vedic/Classical Chandas syllable family (जातिः)
      jati_names = {
        6 => 'गायत्री (6)', 7 => 'उष्णिक् (7)', 8 => 'अनुष्टुभ् (8)', 9 => 'बृहती (9)',
        10 => 'पङ्क्तिः (10)', 11 => 'त्रिष्टुभ् (11)', 12 => 'जगती (12)', 13 => 'अतिजगती (13)',
        14 => 'शक्वरी (14)', 15 => 'अतिशक्वरी (15)', 16 => 'अष्टिः (16)', 17 => 'अत्यष्टिः (17)',
        18 => 'धृतिः (18)', 19 => 'अतिधृतिः (19)', 20 => 'कृतिः (20)', 21 => 'प्रकृतिः (21)'
      }

      padas << {
        line_number: idx,
        pada_number: idx,
        text: line,
        aksharas: aksharas,
        weights: weights,
        pattern: pattern,
        syllable_count: syl_count,
        matra_count: matras,
        ganas: ganas,
        meter: matched_meter || {
          name_sa: jati_names[syl_count] || "#{syl_count}-अक्षरी पंक्तिः",
          name_en: "Line Meter (#{syl_count} syllables, #{matras} mātrās)",
          syllables: syl_count,
          ganas: ganas.map { |g| g[:symbol] }.join('-'),
          yati: syl_count.to_s,
          lakshana: 'मात्रा-अक्षरगणनाधारितम्'
        }
      }
    end

    return { padas: [], summary: 'कृपया श्लोकं वा पादं वा लिखत।' } if padas.empty?
    primary_meter = padas.first[:meter]
    {
      padas: padas,
      primary_meter: primary_meter,
      total_syllables: padas.sum { |p| p[:syllable_count] },
      total_matras: padas.sum { |p| p[:matra_count] },
      reference_meters: METERS
    }
  end
end
