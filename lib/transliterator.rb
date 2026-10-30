# frozen_string_literal: true

module SanskritTransliterator
  DE_START = 0x0900
  TE_START = 0x0C00
  OFFSET_TE = TE_START - DE_START # 768

  VOWELS_DE_IAST = {
    'अ' => 'a', 'आ' => 'ā', 'इ' => 'i', 'ई' => 'ī',
    'उ' => 'u', 'ऊ' => 'ū', 'ऋ' => 'ṛ', 'ॠ' => 'ṝ',
    'ऌ' => 'ḷ', 'ॡ' => 'ḹ', 'ए' => 'e', 'ऐ' => 'ai',
    'ओ' => 'o', 'औ' => 'au', 'ऍ' => 'ê', 'ऑ' => 'ô'
  }.freeze

  MATRAS_DE_IAST = {
    'ा' => 'ā', 'ि' => 'i', 'ी' => 'ī', 'ु' => 'u', 'ू' => 'ū',
    'ृ' => 'ṛ', 'ॄ' => 'ṝ', 'ॢ' => 'ḷ', 'ॣ' => 'ḹ',
    'े' => 'e', 'ै' => 'ai', 'ो' => 'o', 'ौ' => 'au'
  }.freeze

  CONSONANTS_DE_IAST = {
    'क' => 'k', 'ख' => 'kh', 'ग' => 'g', 'घ' => 'gh', 'ङ' => 'ṅ',
    'च' => 'c', 'छ' => 'ch', 'ज' => 'j', 'झ' => 'jh', 'ञ' => 'ñ',
    'ट' => 'ṭ', 'ठ' => 'ṭh', 'ड' => 'ḍ', 'ढ' => 'ḍh', 'ण' => 'ṇ',
    'त' => 't', 'थ' => 'th', 'द' => 'd', 'ध' => 'dh', 'न' => 'n',
    'प' => 'p', 'फ' => 'ph', 'ब' => 'b', 'भ' => 'bh', 'म' => 'm',
    'य' => 'y', 'र' => 'r', 'ऱ' => 'ṟ', 'ल' => 'l', 'ळ' => 'ḻ', 'व' => 'v',
    'श' => 'ś', 'ष' => 'ṣ', 'स' => 's', 'ह' => 'h'
  }.freeze

  MISC_DE_IAST = {
    'ं' => 'ṃ', 'ः' => 'ḥ', 'ँ' => 'm̐', 'ऽ' => "'", 'ॐ' => 'oṃ',
    '।' => '.', '॥' => '..',
    '०' => '0', '१' => '1', '२' => '2', '३' => '3', '४' => '4',
    '५' => '5', '६' => '6', '७' => '7', '८' => '8', '९' => '9'
  }.freeze

  VOWELS_DE_SLP = {
    'अ' => 'a', 'आ' => 'A', 'इ' => 'i', 'ई' => 'I',
    'उ' => 'u', 'ऊ' => 'U', 'ऋ' => 'f', 'ॠ' => 'F',
    'ऌ' => 'x', 'ॡ' => 'X', 'ए' => 'e', 'ऐ' => 'E',
    'ओ' => 'o', 'औ' => 'O'
  }.freeze

  MATRAS_DE_SLP = {
    'ा' => 'A', 'ि' => 'i', 'ी' => 'I', 'ु' => 'u', 'ू' => 'U',
    'ृ' => 'f', 'ॄ' => 'F', 'ॢ' => 'x', 'ॣ' => 'X',
    'े' => 'e', 'ै' => 'E', 'ो' => 'o', 'ौ' => 'O'
  }.freeze

  CONSONANTS_DE_SLP = {
    'क' => 'k', 'ख' => 'K', 'ग' => 'g', 'घ' => 'G', 'ङ' => 'N',
    'च' => 'c', 'छ' => 'C', 'ज' => 'j', 'झ' => 'J', 'ञ' => 'Y',
    'ट' => 'w', 'ठ' => 'W', 'ड' => 'q', 'ढ' => 'Q', 'ण' => 'R',
    'त' => 't', 'थ' => 'T', 'द' => 'd', 'ध' => 'D', 'न' => 'n',
    'प' => 'p', 'फ' => 'P', 'ब' => 'b', 'भ' => 'B', 'म' => 'm',
    'य' => 'y', 'र' => 'r', 'ऱ' => 'r', 'ल' => 'l', 'ळ' => 'L', 'व' => 'v',
    'श' => 'S', 'ष' => 'z', 'स' => 's', 'ह' => 'h'
  }.freeze

  MISC_DE_SLP = {
    'ं' => 'M', 'ः' => 'H', 'ँ' => '~', 'ऽ' => "'"
  }.freeze

  HALANT = '्'

  module_function

  # Force any string (including WEBrick ASCII-8BIT query/body strings) to valid UTF-8
  def ensure_utf8(str)
    return '' if str.nil?
    s = str.to_s.dup
    s.force_encoding(Encoding::UTF_8)
    s.valid_encoding? ? s : s.scrub('')
  end

  # Convert Devanagari string to Telugu Unicode (using AndhraBharati offset rules)
  def dev_to_telugu(str)
    s = ensure_utf8(str)
    return '' if s.empty?
    out = +''
    s.each_char do |ch|
      cp = ch.ord
      if cp >= 0x0900 && cp <= 0x097F
        offset = cp - DE_START
        offset += 1 if [14, 18, 70, 74].include?(offset)
        if cp == 0x0964
          out << '।'
        elsif cp == 0x0965
          out << '॥'
        elsif cp == 0x0950
          out << 'ఓం'
        elsif cp == 0x0901
          out << "\u0C01"
        else
          out << (TE_START + offset).chr(Encoding::UTF_8)
        end
      else
        out << ch
      end
    end
    out
  end

  # Convert Telugu Unicode string to Devanagari
  def telugu_to_dev(str)
    s = ensure_utf8(str)
    return '' if s.empty?
    out = +''
    s.each_char do |ch|
      cp = ch.ord
      if cp >= 0x0C00 && cp <= 0x0C7F
        offset = cp - TE_START
        offset -= 1 if [14, 18, 70, 74].include?(offset)
        out << (DE_START + offset).chr(Encoding::UTF_8)
      else
        out << ch
      end
    end
    out
  end

  # Convert Devanagari to IAST
  def dev_to_iast(str)
    s = ensure_utf8(str)
    return '' if s.empty?
    chars = s.chars
    out = +''
    i = 0
    n = chars.length
    while i < n
      ch = chars[i]
      if CONSONANTS_DE_IAST.key?(ch)
        out << CONSONANTS_DE_IAST[ch]
        nxt = chars[i + 1]
        if nxt == HALANT
          i += 2
        elsif nxt && MATRAS_DE_IAST.key?(nxt)
          out << MATRAS_DE_IAST[nxt]
          i += 2
        else
          out << 'a'
          i += 1
        end
      elsif VOWELS_DE_IAST.key?(ch)
        out << VOWELS_DE_IAST[ch]
        i += 1
      elsif MATRAS_DE_IAST.key?(ch)
        out << MATRAS_DE_IAST[ch]
        i += 1
      elsif MISC_DE_IAST.key?(ch)
        out << MISC_DE_IAST[ch]
        i += 1
      else
        out << ch
        i += 1
      end
    end
    out
  end

  # Convert Devanagari to SLP1 (for canonical phonetic indexing)
  def dev_to_slp(str)
    s = ensure_utf8(str)
    return '' if s.empty?
    chars = s.chars
    out = +''
    i = 0
    n = chars.length
    while i < n
      ch = chars[i]
      if CONSONANTS_DE_SLP.key?(ch)
        out << CONSONANTS_DE_SLP[ch]
        nxt = chars[i + 1]
        if nxt == HALANT
          i += 2
        elsif nxt && MATRAS_DE_SLP.key?(nxt)
          out << MATRAS_DE_SLP[nxt]
          i += 2
        else
          out << 'a'
          i += 1
        end
      elsif VOWELS_DE_SLP.key?(ch)
        out << VOWELS_DE_SLP[ch]
        i += 1
      elsif MATRAS_DE_SLP.key?(ch)
        out << MATRAS_DE_SLP[ch]
        i += 1
      elsif MISC_DE_SLP.key?(ch)
        out << MISC_DE_SLP[ch]
        i += 1
      else
        out << ch
        i += 1
      end
    end
    out
  end

  # Convert SLP1 directly to Devanagari
  def slp_to_dev(str)
    s = ensure_utf8(str)
    return '' if s.empty?
    vowels_slp_de = VOWELS_DE_SLP.invert
    matras_slp_de = MATRAS_DE_SLP.invert.merge('a' => '')
    cons_slp_de   = CONSONANTS_DE_SLP.invert
    misc_slp_de   = MISC_DE_SLP.invert

    out = +''
    chars = s.chars
    i = 0
    n = chars.length
    while i < n
      ch = chars[i]
      if cons_slp_de.key?(ch)
        out << cons_slp_de[ch]
        nxt = chars[i + 1]
        if nxt && matras_slp_de.key?(nxt)
          out << matras_slp_de[nxt]
          i += 2
        else
          out << HALANT
          i += 1
        end
      elsif vowels_slp_de.key?(ch)
        out << vowels_slp_de[ch]
        i += 1
      elsif misc_slp_de.key?(ch)
        out << misc_slp_de[ch]
        i += 1
      else
        out << ch
        i += 1
      end
    end
    out
  end

  # Preprocess scheme-specific tokens into canonical ITRANS before roman_to_dev conversion
  def normalize_scheme_to_itrans(str, scheme = 'itrans')
    s = ensure_utf8(str).dup
    case scheme.to_s.downcase
    when 'slp1'
      return slp_to_dev(s)
    when 'hk'
      s = s.gsub('lRR', 'LLI').gsub('lR', 'LLi').gsub('RR', 'RRI')
           .gsub('G', '~N').gsub('J', '~n').gsub('z', 'sh').gsub('S', 'Sh')
    when 'velthuis'
      s = s.gsub('.rr', 'RRI').gsub('.r', 'RRi').gsub('.ll', 'LLI').gsub('.l', 'LLi')
           .gsub('"n', '~N').gsub('.t', 'T').gsub('.d', 'D').gsub('.n', 'N')
           .gsub('"s', 'sh').gsub('.s', 'Sh').gsub('.m', 'M').gsub('.h', 'H').gsub('.a', '.a')
    when 'wx'
      wx_map = {
        'q' => 'RRi', 'Q' => 'RRI', 'L' => 'LLi', 'E' => 'ai', 'O' => 'au',
        'K' => 'kh', 'G' => 'gh', 'f' => '~N',
        'C' => 'chh', 'J' => 'jh', 'F' => '~n',
        't' => 'T', 'T' => 'Th', 'd' => 'D', 'D' => 'Dh', 'N' => 'N',
        'w' => 't', 'W' => 'th', 'x' => 'd', 'X' => 'dh', 'n' => 'n',
        'P' => 'ph', 'B' => 'bh', 'z' => 'sh', 'R' => 'Sh', 'Z' => '~'
      }
      s = s.chars.map { |c| wx_map[c] || c }.join
    end
    s
  end

  # Convert Roman (ITRANS / IAST / Harvard-Kyoto / SLP1 / Velthuis / WX / casual phonetic) to Devanagari
  def roman_to_dev(str, scheme = 'itrans')
    s = ensure_utf8(str).strip
    return '' if s.empty?
    return slp_to_dev(s) if scheme.to_s.downcase == 'slp1'

    s = normalize_scheme_to_itrans(s, scheme)

    # Normalize IAST diacritics to ITRANS tokens first
    iast_map = {
      'ā' => 'A', 'ī' => 'I', 'ū' => 'U', 'ṛ' => 'RRi', 'ṝ' => 'RRI',
      'ḷ' => 'LLi', 'ḹ' => 'LLI', 'ṅ' => '~N', 'ñ' => '~n',
      'ṭ' => 'T', 'ḍ' => 'D', 'ṇ' => 'N', 'ś' => 'sh', 'ṣ' => 'Sh',
      'ṃ' => 'M', 'ṁ' => 'M', 'ḥ' => 'H'
    }
    iast_map.each { |k, v| s = s.gsub(k, v).gsub(k.upcase, v) }

    # Common casual English-phonetic Sanskrit adjustments (e.g. krishna -> kRShNa)
    s = s.gsub(/krishn/i, 'kRShN').gsub(/vishn/i, 'viShN').gsub(/shri/i, 'shrI').gsub(/rishi/i, 'RShi')

    vowel_tokens = [
      ['ai', 'ऐ', 'ै'], ['au', 'औ', 'ौ'], ['aa', 'आ', 'ा'], ['ii', 'ई', 'ी'], ['uu', 'ऊ', 'ू'],
      ['ee', 'ई', 'ी'], ['oo', 'ऊ', 'ू'],
      ['RRi', 'ऋ', 'ृ'], ['R^i', 'ऋ', 'ृ'], ['RRI', 'ॠ', 'ॄ'], ['R^I', 'ॠ', 'ॄ'],
      ['LLi', 'ऌ', 'ॢ'], ['L^i', 'ऌ', 'ॢ'], ['LLI', 'ॡ', 'ॣ'], ['R', 'ऋ', 'ृ'],
      ['A', 'आ', 'ा'], ['I', 'ई', 'ी'], ['U', 'ऊ', 'ू'],
      ['e', 'ए', 'े'], ['o', 'ओ', 'ो'], ['a', 'अ', ''], ['i', 'इ', 'ि'], ['u', 'उ', 'ु']
    ]
    cons_tokens = [
      ['kSh', 'क्ष्'], ['ksh', 'क्ष्'], ['x', 'क्ष्'], ['j~n', 'ज्ञ्'], ['GY', 'ज्ञ्'], ['dny', 'ज्ञ्'], ['jn', 'ज्ञ्'],
      ['chh', 'छ्'], ['Ch', 'छ्'], ['shh', 'ष्'], ['Sh', 'ष्'], ['sh', 'श्'],
      ['kh', 'ख्'], ['gh', 'घ्'], ['~N', 'ङ्'], ['N^', 'ङ्'],
      ['ch', 'च्'], ['jh', 'झ्'], ['~n', 'ञ्'], ['JN', 'ञ्'],
      ['Th', 'ठ्'], ['Dh', 'ढ्'], ['th', 'थ्'], ['dh', 'ध्'],
      ['ph', 'फ्'], ['bh', 'भ्'],
      ['k', 'क्'], ['g', 'ग्'], ['c', 'च्'], ['j', 'ज्'],
      ['T', 'ट्'], ['D', 'ड्'], ['N', 'ण्'],
      ['t', 'त्'], ['d', 'द्'], ['n', 'न्'],
      ['p', 'प्'], ['b', 'ब्'], ['m', 'म्'],
      ['y', 'य्'], ['r', 'र्'], ['l', 'ल्'], ['L', 'ळ्'], ['v', 'व्'], ['w', 'व्'],
      ['S', 'श्'], ['s', 'स्'], ['h', 'ह्']
    ]
    specials = [
      ['OM', 'ॐ'], ['AUM', 'ॐ'], ['.a', 'ऽ'], ['||', '॥'], ['|', '।'],
      ['.n', 'ं'], ['.m', 'ं'], ['~', 'ँ'], ['M', 'ं'], ['H', 'ः']
    ]

    out = +''
    i = 0
    after_cons = false
    while i < s.length
      matched = false
      specials.each do |tok, rep|
        if s[i, tok.length] == tok
          out << rep
          i += tok.length
          after_cons = false
          matched = true
          break
        end
      end
      next if matched

      vowel_tokens.each do |tok, indep, matra|
        if s[i, tok.length] == tok
          if after_cons
            out.chop! # remove halant
            out << matra
          else
            out << indep
          end
          i += tok.length
          after_cons = false
          matched = true
          break
        end
      end
      next if matched

      cons_tokens.each do |tok, dev_c|
        if s[i, tok.length] == tok
          # Smart nasal assimilation before velar/palatal/retroflex/dental/labial stops when user types 'n'
          if tok == 'n' && !after_cons
            rem = s[(i + 1)..-1].to_s
            if rem.match?(/\A(k|kh|g|gh)/)
              out << 'ङ्'
              i += 1
              after_cons = true
              matched = true
              break
            elsif rem.match?(/\A(ch|c|jh|j)/)
              out << 'ञ्'
              i += 1
              after_cons = true
              matched = true
              break
            elsif rem.match?(/\A(T|Th|D|Dh)/)
              out << 'ण्'
              i += 1
              after_cons = true
              matched = true
              break
            end
          end
          out << dev_c
          i += tok.length
          after_cons = true
          matched = true
          break
        end
      end
      next if matched

      out << s[i]
      after_cons = false
      i += 1
    end
    out
  end

  # Normalize Sanskrit headword for fuzzy/stem matching
  def normalize_headword(str)
    s = ensure_utf8(str).strip
    return '' if s.empty?
    # Remove only Vedic pitch accents and chandrabindu nasal marker
    s = s.gsub(/[\u0951-\u0954\u1CD0-\u1CFFँ]/, '')
    # Strip trailing visarga or anusvara for stem matching
    s = s.sub(/[ःं]+$/, '')
    s
  end

  # Generate a case-insensitive, vowel-length/retroflex/aspiration-agnostic phonetic skeleton
  # so loose lowercase queries like "rama", "bhu", "path", "sutra", "ikoyanaci", "apeta" match accurately.
  def phonetic_skeleton(str)
    s = ensure_utf8(str).strip
    return '' if s.empty?
    dev = if s.match?(/[\u0C00-\u0C7F]/)
            telugu_to_dev(s)
          elsif s.match?(/[A-Za-zāīūṛṝḷḹṅñṭḍṇśṣṃḥĀĪŪṚṜḶḸṄÑṬḌṆŚṢṂḤ]/)
            roman_to_dev(s)
          else
            s
          end
    slp = dev_to_slp(normalize_headword(dev))
    slp.gsub(/[^A-Za-z]/, '')
       .tr('AIUFXEO', 'aiufxeo')
       .tr('KGNCJYwWqQRTDpPbBSzL', 'kgncjyttddntdppbbssl')
       .gsub(/([a-z])\1+/, '\1')
  end

  # Generate smart Sanskrit Devanagari candidates for a Roman phonetic word
  # Used in the Typing Space Transliteration Options Bar and Phonetic Grammar Search
  def generate_translit_candidates(roman_raw, scheme = 'itrans')
    w = ensure_utf8(roman_raw).strip
    return [] if w.empty?

    # If already Devanagari or Telugu, return its stem/inflected variants
    if !w.match?(/[A-Za-z]/)
      dev_base = w.match?(/[\u0C00-\u0C7F]/) ? telugu_to_dev(w) : w
      stem = dev_base.sub(/[ःं्]+$/, '')
      return [dev_base, "#{stem}ः", "#{stem}म्", "#{stem}्", stem].uniq.reject(&:empty?)
    end

    exact = roman_to_dev(w, scheme)
    variants_roman = [w]

    # 1. Vowel lengthening permutations (a -> A, i -> I, u -> U, ri -> RRi)
    variants_roman << w.sub(/a([^aeiouAEIOU]+a?\z)/, 'A\1')
    variants_roman << w.sub(/a\z/, 'A')
    variants_roman << w.gsub('a', 'A') if w.count('a') <= 2
    variants_roman << w.sub(/i/, 'I')
    variants_roman << w.sub(/i\z/, 'I')
    variants_roman << w.sub(/u/, 'U')
    variants_roman << w.sub(/u\z/, 'U')
    variants_roman << w.sub(/ri/i, 'RRi')
    variants_roman << w.sub(/\A([bcdfghjklmnpqrstvwxyz]+)u\z/i, '\1U')

    # 2. Retroflex / Sibilant / Aspirate smart variations
    variants_roman << w.gsub('t', 'T').gsub('d', 'D').gsub('n', 'N')
    variants_roman << w.sub(/n([aAiIuUeEoO]*\z)/, 'N\1')
    variants_roman << w.sub(/th/, 'Th')
    variants_roman << w.sub(/dh/, 'Dh')
    variants_roman << w.gsub('sh', 'Sh')
    variants_roman << w.sub(/s([tT])/, 'Sh\1')

    # Combine vowel lengthening + retroflex/sibilant for common patterns (e.g. sutra -> sUtra, bhasha -> bhAShA, prana -> prANa, vani -> vANI)
    variants_roman << w.sub(/u/, 'U').sub(/a\z/, 'A')
    variants_roman << w.sub(/a/, 'A').gsub('sh', 'Sh').sub(/a\z/, 'A')
    variants_roman << w.sub(/a/, 'A').sub(/n/, 'N').sub(/i\z/, 'I')
    variants_roman << w.sub(/a/, 'A').sub(/n/, 'N')

    dev_candidates = [exact]
    variants_roman.uniq.each do |vr|
      d = roman_to_dev(vr, scheme)
      dev_candidates << d unless d.empty?
      # Also add vowel-ending version if consonant-final had implicit 'a' omitted or vice versa
      if vr.match?(/[bcdfghjklmnpqrstvwxyz]\z/i) && !vr.end_with?('M', 'H')
        d_with_a = roman_to_dev("#{vr}a", scheme)
        dev_candidates << d_with_a unless d_with_a.empty?
        d_with_aa = roman_to_dev("#{vr}A", scheme)
        dev_candidates << d_with_aa unless d_with_aa.empty?
      end
    end

    # Also add common pada endings (ः, म्, ्) for the top base forms
    base_forms = dev_candidates.uniq.first(5)
    base_forms.each do |bf|
      stem = bf.sub(/्$/, '')
      if bf.end_with?('्')
        dev_candidates << stem
        dev_candidates << "#{stem}ः"
        dev_candidates << "#{stem}म्"
      else
        dev_candidates << "#{bf}ः" unless bf.end_with?('ः', 'ं', 'ा', 'ी')
        dev_candidates << "#{bf}म्" unless bf.end_with?('ः', 'ं')
        dev_candidates << "#{bf}्" if bf.match?(/[क-ह]$/)
      end
    end

    dev_candidates.map(&:strip).reject(&:empty?).uniq.first(12)
  end
end
