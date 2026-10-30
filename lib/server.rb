#!/usr/bin/env ruby
# frozen_string_literal: true

begin
  require 'webrick'
rescue LoadError
  # Ruby 3 no longer includes WEBrick; release packages carry a copy in lib/vendor/webrick.
  $LOAD_PATH.unshift(File.join(__dir__, 'vendor', 'webrick', 'lib'))
  require 'webrick'
end
require 'set'
require 'json'
require 'uri'
require 'open3'
require 'fileutils'
require_relative 'transliterator'
require_relative 'sanskrit_grammar_engine'
require_relative 'sanskrit_abhyas_data'
require_relative 'cdsl_dictionary'

ROOT_DIR    = File.expand_path('..', __dir__)
PUBLIC_DIR  = File.join(ROOT_DIR, 'public')
# Read-only reference data (built from the ashtadhyayi.com data repository; see data/README.md)
DB_PATH     = ENV['REFERENCE_DB'] || File.join(ROOT_DIR, 'data', 'reference.sqlite')
# The 12 Cologne Digital Sanskrit Lexicon dictionaries, attached as schema "c"
CDSL_DB     = ENV['CDSL_DB'] || File.join(ROOT_DIR, 'data', 'cologne.sqlite')
SQLITE3     = ENV['SQLITE3'] || 'sqlite3'
# 127.0.0.1 for local use; the container sets BIND_ADDRESS=0.0.0.0
BIND_ADDRESS = ENV['BIND_ADDRESS'] || '127.0.0.1'
PORT        = (ENV['PORT'] || 4567).to_i
# Longest text accepted in one request parameter (a long poem is far below this)
MAX_PARAM_CHARS = 20_000

module SqliteHelper
  module_function

  ATTACH_SQL = "ATTACH DATABASE '#{CDSL_DB.gsub("'", "''")}' AS c;"

  def q(val)
    return "''" if val.nil?
    s = SanskritTransliterator.ensure_utf8(val)
    "'" + s.gsub("'", "''") + "'"
  end

  # Every reference query runs read-only, with the Cologne database attached as "c".
  def query(sql_str)
    sql = "#{ATTACH_SQL}\n#{SanskritTransliterator.ensure_utf8(sql_str)}"
    stdout, stderr, status = Open3.capture3(SQLITE3, '-readonly', '-json', DB_PATH, sql)
    warn "SQL error: #{stderr.strip[0, 300]}" unless stderr.to_s.strip.empty?
    out = SanskritTransliterator.ensure_utf8(stdout).strip
    return [] unless status.success? && !out.empty?
    JSON.parse(out)
  rescue StandardError
    []
  end
end

def dictionary_catalog
  @dictionary_catalog ||= SqliteHelper.query('SELECT * FROM dictionaries ORDER BY storage DESC, rowid;')
end

def cdsl_codes
  @cdsl_codes ||= dictionary_catalog.select { |d| d['storage'] == 'cdsl' }.map { |d| d['code'] }
end

LAKARA_METADATA = [
  ['lat',  'लट् (वर्तमानकालः)',      'Laṭ (Present Indicative)',           'లట్ (వర్తమానకాలము)'],
  ['lit',  'लिट् (परोक्षभूतकालः)',   'Liṭ (Perfect Past)',                 'లిట్ (పరోక్షభూతకాలము)'],
  ['lut',  'लुट् (अनद्यतनभविष्यत्)', 'Luṭ (Periphrastic Future)',          'లుట్ (అనద్యతనభవిష్యత్తు)'],
  ['lrt',  'लृट् (सामान्यभविष्यत्)', 'Lṛṭ (Simple Future)',                'లృట్ (సామాన్యభవిష్యత్తు)'],
  ['lot',  'लोट् (आज्ञार्थः)',       'Loṭ (Imperative)',                   'లోట్ (ఆజ్ఞార్థము)'],
  ['lang', 'लङ् (अनद्यतनभूतः)',      'Laṅ (Imperfect Past)',               'లఙ్ (అనద్యతనభూతకాలము)'],
  ['vlin', 'विधिलिङ् (विध्यर्थः)',   'Vidhiliṅ (Optative / Potential)',    'విధిలిఙ్ (విధ్యర్థము)'],
  ['alin', 'आशीर्लिङ् (आशीरर्थः)',   'Āśīrliṅ (Benedictive)',              'ఆశీర్లిఙ్ (ఆశీరర్థము)'],
  ['lung', 'लुङ् (सामान्यभूतः)',     'Luṅ (Aorist Past)',                  'లుఙ్ (సామాన్యభూతకాలము)'],
  ['lrng', 'लृङ् (हेतुहेतुमद्भावः)', 'Lṛṅ (Conditional)',                  'లృఙ్ (హేతుహేతుమద్భావము)']
].freeze

VIBHAKTI_NAMES = [
  ['प्रथमा (1st — Nominative)',   'ప్రథమా విభక్తి'],
  ['द्वितीया (2nd — Accusative)',  'ద్వితీయా విభక్తి'],
  ['तृतीया (3rd — Instrumental)', 'తృతీయా విభక్తి'],
  ['चतुर्थी (4th — Dative)',      'చతుర్థీ విభక్తి'],
  ['पञ्चमी (5th — Ablative)',     'పంచమీ విభక్తి'],
  ['षष्ठी (6th — Genitive)',      'షష్ఠీ విభక్తి'],
  ['सप्तमी (7th — Locative)',     'సప్తమీ విభక్తి'],
  ['सम्बोधनम् (Vocative)',        'సంబోధన ప్రథమా']
].freeze

def req_params(req)
  params = {}
  return params if req.body && req.body.bytesize > 4 * MAX_PARAM_CHARS
  # WEBrick parses the query string only for GET/HEAD, so read it directly for other methods.
  if req.request_method != 'GET' && req.request_method != 'HEAD' && req.query_string && !req.query_string.empty?
    URI.decode_www_form(req.query_string).each do |k, v|
      params[SanskritTransliterator.ensure_utf8(k)] = SanskritTransliterator.ensure_utf8(v).strip
    end
  end
  if %w[GET HEAD].include?(req.request_method) && req.query.is_a?(Hash)
    req.query.each do |k, v|
      params[SanskritTransliterator.ensure_utf8(k)] = SanskritTransliterator.ensure_utf8(v).strip
    end
  end
  if req.request_method == 'POST' && req.body && !req.body.empty?
    raw_body = SanskritTransliterator.ensure_utf8(req.body)
    begin
      parsed = JSON.parse(raw_body)
      if parsed.is_a?(Hash)
        parsed.each { |k, v| params[SanskritTransliterator.ensure_utf8(k)] = v.is_a?(String) ? SanskritTransliterator.ensure_utf8(v) : v }
      end
    rescue StandardError
      # Ignore non-JSON body
    end
  end
  params.transform_values { |v| v.is_a?(String) && v.length > MAX_PARAM_CHARS ? v[0, MAX_PARAM_CHARS] : v }
end

def normalize_query_to_dev(q_raw, scheme = 'itrans')
  q = SanskritTransliterator.ensure_utf8(q_raw).strip
  return '' if q.empty?
  if q.match?(/[\u0C00-\u0C7F]/)
    SanskritTransliterator.telugu_to_dev(q)
  elsif q.match?(/[A-Za-zāīūṛṝḷḹṅñṭḍṇśṣṃḥĀĪŪṚṜḶḸṄÑṬḌṆŚṢṂḤ]/) && !q.match?(/[\u0900-\u097F]/)
    # Convert each space-separated token while preserving punctuation/numbers
    q.split(/(\s+)/).map do |part|
      if part.match?(/[A-Za-zāīūṛṝḷḹṅñṭḍṇśṣṃḥĀĪŪṚṜḶḸṄÑṬḌṆŚṢṂḤ]/)
        SanskritTransliterator.roman_to_dev(part, scheme)
      else
        part
      end
    end.join
  else
    q
  end
end

# SQLite expression to compute the phonetic skeleton of an SLP1 column for loose lowercase phonetic search
def sql_phonetic_skeleton(col)
  expr = "LOWER(#{col})"
  [
    ["'h'", "''"], ["'m'", "''"], ["'~'", "''"], ["''''", "''"], ["'-'", "''"], ["' '", "''"],
    ["'w'", "'t'"], ["'q'", "'d'"], ["'r'", "'r'"], ["'z'", "'s'"], ["'x'", "'l'"], ["'f'", "'r'"]
  ].each do |from_c, to_c|
    expr = "REPLACE(#{expr}, #{from_c}, #{to_c})"
  end
  expr
end

# Map of grammatical rules, Pratyayas, Samasas, Karakas, Voices, and Chandas terms to their governing Paninian Sutras
GRAMMAR_TERM_SUTRA_MAP = {
  # Pratyayas (Kridanta, Taddhita, Stri)
  'क्त्वा' => %w[3.4.21 1.1.40],
  'ल्यप्' => %w[7.1.37 1.1.40],
  'तुमुन्' => %w[3.3.10 3.3.158],
  'क्त' => %w[1.1.26 3.2.102 3.4.70],
  'क्तवतु' => %w[1.1.26 3.2.102],
  'शतृ' => %w[3.2.124 3.2.127],
  'शानच्' => %w[3.2.124 3.2.127],
  'तव्यत्' => %w[3.1.96 3.4.70],
  'तव्य' => %w[3.1.96],
  'अनीयर्' => %w[3.1.96],
  'यत्' => %w[3.1.97],
  'ण्यत्' => %w[3.1.124],
  'क्यप्' => %w[3.1.106 3.1.109],
  'तृच्' => %w[3.1.133],
  'ण्वुल्' => %w[3.1.133],
  'ल्युट्' => %w[3.3.115],
  'घञ्' => %w[3.3.18 3.3.19],
  'क्तिन्' => %w[3.3.94],
  'अण्' => %w[4.1.83 4.1.92],
  'इञ्' => %w[4.1.95],
  'ढक्' => %w[4.1.120],
  'ठक्' => %w[4.4.1],
  'मतुप्' => %w[5.2.94],
  'इनि' => %w[5.2.115],
  'विनि' => %w[5.2.121],
  'तल्' => %w[5.1.119],
  'त्व' => %w[5.1.119],
  'तरप्' => %w[5.3.57],
  'तमप्' => %w[5.3.55],
  'इष्ठन्' => %w[5.3.55],
  'ईयसुन्' => %w[5.3.57],
  'टाप्' => %w[4.1.4],
  'ङीप्' => %w[4.1.5 4.1.6],
  # Samasas
  'अव्ययीभाव' => %w[2.1.5 2.1.6 2.4.18],
  'अधि' => %w[2.1.6],
  'उप' => %w[2.1.6],
  'अनु' => %w[2.1.6 2.1.15],
  'निर्' => %w[2.1.6],
  'यथा' => %w[2.1.7],
  'प्रति' => %w[2.1.6 1.4.90],
  'स' => %w[2.1.6],
  'तत्पुरुष' => %w[2.1.22],
  'कर्मधारय' => %w[1.2.42 2.1.57],
  'विशेषणपूर्वपद' => %w[2.1.57],
  'उपमानपूर्वपद' => %w[2.1.55],
  'उपमित' => %w[2.1.56],
  'रूपक' => %w[2.1.72],
  'उभयपदविशेषण' => %w[2.1.57],
  'समाहारद्विगु' => %w[2.1.52 2.4.1],
  'द्विगु' => %w[2.1.52 2.4.1],
  'बहुव्रीहि' => %w[2.2.24],
  'समानाधिकरण-बहुव्रीहि' => %w[2.2.24],
  'व्यधिकरण-बहुव्रीहि' => %w[2.2.24],
  'तुल्ययोग-बहुव्रीहि' => %w[2.2.28],
  'द्वन्द्व' => %w[2.2.29],
  'इतरेतरद्वन्द्व' => %w[2.2.29],
  'समाहारद्वन्द्व' => %w[2.2.29 2.4.2],
  # Vachya (Voice) & Upasargas & Avyayas & Sankhya
  'कर्तृवाच्य' => %w[3.4.69 2.3.18 2.3.2],
  'कर्मवाच्य' => %w[3.4.69 3.1.67 2.3.18],
  'भाववाच्य' => %w[3.4.69 3.1.67 2.3.18],
  'उपसर्ग' => %w[1.4.58 1.4.59],
  'अव्यय' => %w[1.1.37]
}.freeze

def parse_conjugation_grid(forms_str)
  s = SanskritTransliterator.ensure_utf8(forms_str).strip
  return nil if s.empty?
  cells = s.split(';', -1)
  purushas = [
    ['प्रथमपुरुषः (3rd Person)', cells[0].to_s, cells[1].to_s, cells[2].to_s],
    ['मध्यमपुरुषः (2nd Person)', cells[3].to_s, cells[4].to_s, cells[5].to_s],
    ['उत्तमपुरुषः (1st Person)', cells[6].to_s, cells[7].to_s, cells[8].to_s]
  ]
  purushas.map do |pname, ek, dv, ba|
    {
      purusha: pname,
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
end

def parse_shabda_table(forms_str)
  cells = SanskritTransliterator.ensure_utf8(forms_str).split(';', -1)
  VIBHAKTI_NAMES.each_with_index.map do |(v_sa, v_te), idx|
    ek = cells[idx * 3].to_s
    dv = cells[idx * 3 + 1].to_s
    ba = cells[idx * 3 + 2].to_s
    {
      vibhakti: v_sa,
      vibhakti_te: v_te,
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
end

def json_response(res, data, status = 200)
  res.status = status
  res['Content-Type'] = 'application/json; charset=utf-8'
  res['Cache-Control'] = 'no-store'
  res.body = JSON.generate(data)
end

def safe_api(res)
  yield
rescue StandardError => e
  json_response(res, { error: "#{e.class}: #{e.message}" }, 500)
end

server_options = {
  Port: PORT,
  BindAddress: BIND_ADDRESS,
  DocumentRoot: PUBLIC_DIR,
  AccessLog: [],
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN)
}
server = begin
  WEBrick::HTTPServer.new(server_options)
rescue Errno::EADDRINUSE
  WEBrick::HTTPServer.new(server_options.merge(Port: 0)) # preferred port taken: use any free port
end

# ============================================================================
# API 1: SYSTEM & DATABASE STATS
# ============================================================================
server.mount_proc '/api/stats' do |_req, res|
  safe_api(res) do
    dicts = dictionary_catalog
    counts = SqliteHelper.query(<<~SQL)
      SELECT
        (SELECT count(*) FROM dict_entries) + (SELECT count(*) FROM c.entries) AS dict_entries,
        (SELECT count(*) FROM dictionaries) AS dictionary_count,
        (SELECT count(*) FROM kosha_verses) AS kosha_verses,
        (SELECT count(*) FROM dhatus) AS dhatus,
        (SELECT count(*) FROM dhatu_inflections) AS dhatu_inflections,
        (SELECT count(*) FROM shabdas) AS shabdas,
        (SELECT count(*) FROM shabda_prakriya) AS shabda_prakriya,
        (SELECT count(*) FROM sutras) AS sutras,
        (SELECT count(*) FROM vyakarana_texts) AS vyakarana_texts,
        (SELECT count(*) FROM abhyas_modules) AS abhyas_modules;
    SQL
    db_size_mb = [DB_PATH, CDSL_DB].select { |f| File.exist?(f) }.sum { |f| File.size(f) }
    db_size_mb = (db_size_mb.to_f / (1024 * 1024)).round(2)
    db_mtime   = File.exist?(DB_PATH) ? File.mtime(DB_PATH).strftime('%Y-%m-%d %H:%M:%S') : 'N/A'

    json_response(res, {
      status: 'ok',
      db_size_mb: db_size_mb,
      db_updated_at: db_mtime,
      counts: counts.first || {},
      dictionaries: dicts
    })
  end
end

# ============================================================================
# API 2: MULTI-DICTIONARY & KOSHA SEARCH (14 Lexicons + Grammar Quick-Match)
# ============================================================================
server.mount_proc '/api/dictionary/search' do |req, res|
  safe_api(res) do
    params = req_params(req)
    q_raw = params['q'].to_s
    dicts_param = params['dicts'].to_s
    match_type = (params['match'] || 'prefix').to_s
    scope = (params['scope'] || 'headword').to_s
    limit = [(params['limit'] || 80).to_i, 200].min
    limit = 80 if limit <= 0

    selected = if dicts_param.empty? || dicts_param == 'all'
                 dictionary_catalog.map { |d| d['code'] }
               else
                 dicts_param.split(',').map(&:strip)
               end
    sel_cdsl  = selected & cdsl_codes
    sel_local = selected - cdsl_codes
    dict_filter_sql = sel_local.empty? ? ' AND 0' : " AND d.dict_code IN (#{sel_local.map { |c| SqliteHelper.q(c) }.join(',')})"

    if q_raw.empty?
      next json_response(res, { query: '', entries: [], grammar_matches: { dhatus: [], shabdas: [] } })
    end

    q_dev  = normalize_query_to_dev(q_raw)
    q_norm = SanskritTransliterator.normalize_headword(q_dev)
    q_slp  = SanskritTransliterator.dev_to_slp(q_norm)
    q_ascii_lower = q_raw.downcase

    sql = if scope == 'fulltext'
            fts_q = [q_raw, q_dev].map { |t| t.gsub(/["'*]/, '').strip }.reject(&:empty?).uniq.map { |t| %("#{t}") }.join(' OR ')
            <<~SQL
              SELECT d.id, d.dict_code, d.headword, d.definition, d.page_ref,
                     dict.name_sa, dict.name_en, dict.name_te
              FROM dict_fts f
              JOIN dict_entries d ON d.id = f.entry_id
              JOIN dictionaries dict ON dict.code = d.dict_code
              WHERE dict_fts MATCH #{SqliteHelper.q(fts_q)} #{dict_filter_sql}
              LIMIT #{limit};
            SQL
          else
            pattern_norm = case match_type
                           when 'exact'    then q_norm
                           when 'suffix'   then "%#{q_norm}"
                           when 'contains' then "%#{q_norm}%"
                           else                 "#{q_norm}%"
                           end
            pattern_raw  = case match_type
                           when 'exact'    then q_ascii_lower
                           when 'suffix'   then "%#{q_ascii_lower}"
                           when 'contains' then "%#{q_ascii_lower}%"
                           else                 "#{q_ascii_lower}%"
                           end
            pattern_slp  = case match_type
                           when 'exact'    then q_slp.downcase
                           when 'suffix'   then "%#{q_slp.downcase}"
                           when 'contains' then "%#{q_slp.downcase}%"
                           else                 "#{q_slp.downcase}%"
                           end
            op = match_type == 'exact' ? '=' : 'LIKE'
            <<~SQL
              SELECT d.id, d.dict_code, d.headword, d.definition, d.page_ref,
                     dict.name_sa, dict.name_en, dict.name_te
              FROM dict_entries d
              JOIN dictionaries dict ON dict.code = d.dict_code
              WHERE (d.headword_norm #{op} #{SqliteHelper.q(pattern_norm)}
                 OR d.headword #{op} #{SqliteHelper.q(pattern_norm)}
                 OR LOWER(d.headword_slp) #{op} #{SqliteHelper.q(pattern_slp)}
                 OR LOWER(d.headword_norm) #{op} #{SqliteHelper.q(pattern_raw)})
              #{dict_filter_sql}
              ORDER BY
                CASE
                  WHEN d.headword_norm = #{SqliteHelper.q(q_norm)} THEN 0
                  WHEN LOWER(d.headword_norm) = #{SqliteHelper.q(q_ascii_lower)} THEN 0
                  WHEN LOWER(d.headword_slp) = #{SqliteHelper.q(q_slp.downcase)} THEN 1
                  ELSE 2
                END,
                length(d.headword) ASC
              LIMIT #{limit};
            SQL
          end

    raw_entries = sel_local.empty? ? [] : SqliteHelper.query(sql)
    cdsl_entries = CdslDictionary.search(q_dev: q_dev, q_norm: q_norm, q_raw: q_raw, match_type: match_type,
                                         scope: scope, codes: sel_cdsl, limit: limit)

    # Fallback to fulltext FTS5 if user typed an English meaning word in headword mode and no headword matched
    if raw_entries.empty? && cdsl_entries.empty? && q_raw.match?(/\A[A-Za-z\s]+\z/)
      fts_q = q_raw.gsub(/["'*]/, '').strip
      unless fts_q.empty?
        raw_entries = SqliteHelper.query(<<~SQL)
          SELECT d.id, d.dict_code, d.headword, d.definition, d.page_ref,
                 dict.name_sa, dict.name_en, dict.name_te
          FROM dict_fts f
          JOIN dict_entries d ON d.id = f.entry_id
          JOIN dictionaries dict ON dict.code = d.dict_code
          WHERE dict_fts MATCH #{SqliteHelper.q(fts_q)} #{dict_filter_sql}
          LIMIT #{limit};
        SQL
        cdsl_entries = CdslDictionary.search(q_dev: fts_q, q_norm: fts_q, q_raw: fts_q, match_type: match_type,
                                             scope: 'fulltext', codes: sel_cdsl, limit: limit)
      end
    end

    local_entries = raw_entries.map do |r|
      hw = r['headword'].to_s
      r.merge(
        'source' => 'local',
        'headword_te' => SanskritTransliterator.dev_to_telugu(hw),
        'headword_iast' => SanskritTransliterator.dev_to_iast(hw),
        'definition_te' => SanskritTransliterator.dev_to_telugu(r['definition'].to_s[0..600])
      )
    end
    exact_keys = [q_norm, q_dev, q_ascii_lower].reject(&:empty?)
    exact_keys += exact_keys.first(1).flat_map { |k| ["#{k}ः", "#{k}म्", "#{k}ं"] }
    entries = (cdsl_entries + local_entries).each_with_index.sort_by do |e, i|
      hw = e['headword'].to_s
      [exact_keys.include?(hw) || exact_keys.include?(hw.downcase) ? 0 : 1,
       scope == 'fulltext' ? 0 : hw.length, CdslDictionary.priority(e['dict_code']), i]
    end.map(&:first).first(limit)

    dhatu_hits = SqliteHelper.query(<<~SQL)
      SELECT DISTINCT form, baseindex, dhatu, artha_sa, artha_en, lakara, prayoga
      FROM dhatu_inflections
      WHERE form = #{SqliteHelper.q(q_dev)} OR form_norm = #{SqliteHelper.q(q_norm)}
      LIMIT 8;
    SQL

    shabda_hits = SqliteHelper.query(<<~SQL)
      SELECT urlid, word, linga, anta, artha_sa, artha_en
      FROM shabdas
      WHERE word_norm = #{SqliteHelper.q(q_norm)} OR word = #{SqliteHelper.q(q_dev)} OR LOWER(word_slp) = #{SqliteHelper.q(q_slp.downcase)}
      LIMIT 6;
    SQL

    json_response(res, {
      query: q_raw,
      query_dev: q_dev,
      query_te: SanskritTransliterator.dev_to_telugu(q_dev),
      query_iast: SanskritTransliterator.dev_to_iast(q_dev),
      entries: entries,
      grammar_matches: {
        dhatus: dhatu_hits,
        shabdas: shabda_hits
      }
    })
  end
end

# ============================================================================
# API 2b: POSSIBLE STEMS FOR A WORD WITH NO DICTIONARY ENTRY (inflected forms, compounds)
#   Only candidates that exist as headwords in some dictionary are returned.
# ============================================================================
# [ending, replacement] for common nominal endings (a, ā, i, ī, u, ṛ and an-stems)
STEM_RULES = [
  ['ाभ्याम्', ''], ['ेभ्यः', ''], ['ानाम्', ''], ['ाणाम्', ''], ['स्य', ''], ['ेषु', ''], ['ैः', ''], ['ेन', ''], ['ेण', ''],
  ['ाय', ''], ['ात्', ''], ['ानि', ''], ['ाणि', ''], ['ाः', ''], ['ान्', ''], ['योः', ''], ['ौ', ''], ['े', ''], ['ः', ''], ['म्', ''], ['ं', ''],
  ['ायाः', 'ा'], ['ायै', 'ा'], ['ायाम्', 'ा'], ['ाभिः', 'ा'], ['ासु', 'ा'], ['या', 'ा'], ['ाम्', 'ा'], ['ाः', 'ा'], ['े', 'ा'],
  ['ीनाम्', 'ि'], ['िषु', 'ि'], ['िना', 'ि'], ['ीन्', 'ि'], ['िः', 'ि'], ['िम्', 'ि'], ['यः', 'ि'], ['ये', 'ि'], ['ेः', 'ि'], ['ी', 'ि'],
  ['ूनाम्', 'ु'], ['ुषु', 'ु'], ['ुना', 'ु'], ['ुः', 'ु'], ['ुम्', 'ु'], ['वः', 'ु'], ['वे', 'ु'], ['ोः', 'ु'], ['ू', 'ु'],
  ['्यायाः', 'ी'], ['्याः', 'ी'], ['्यै', 'ी'], ['्याम्', 'ी'], ['ीम्', 'ी'], ['ीः', 'ी'],
  ['ॄणाम्', 'ृ'], ['ृषु', 'ृ'], ['रौ', 'ृ'], ['रः', 'ृ'], ['रम्', 'ृ'], ['रा', 'ृ'], ['रे', 'ृ'], ['ुः', 'ृ'], ['ा', 'ृ'],
  ['ानौ', 'न्'], ['ानः', 'न्'], ['्ना', 'न्'], ['्ने', 'न्'], ['ा', 'न्']
].freeze

def stem_candidates(word)
  STEM_RULES.each_with_object([]) do |(ending, repl), out|
    next unless word.end_with?(ending) && word.length > ending.length + 1
    out << word[0, word.length - ending.length] + repl
  end.uniq
end

server.mount_proc '/api/dictionary/stems' do |req, res|
  safe_api(res) do
    params = req_params(req)
    word = SanskritTransliterator.ensure_utf8(normalize_query_to_dev(params['q'].to_s)).strip
    word = word.gsub(/[\s\u200c\u200d।॥]/, '')
    next json_response(res, { query: word, stems: [], members: [] }) if word.length < 2 || !word.match?(/[\u0900-\u097F]/)
    stems = stem_candidates(word)
    prefixes = (3...word.length).map { |n| word[0, n] }.reverse # longest first
    probe = (stems + prefixes).uniq
    rest_cands = prefixes.flat_map { |pf| r = word[pf.length..-1]; [r] + stem_candidates(r) }.uniq
    sql_list = ->(arr) { arr.map { |w| SqliteHelper.q(w) }.join(',') }
    all = (probe + rest_cands).uniq
    found = SqliteHelper.query(<<~SQL).map { |r| r['w'] }.to_set
      SELECT DISTINCT key_deva AS w FROM c.entries WHERE key_deva IN (#{sql_list.(all)})
      UNION SELECT DISTINCT headword_norm AS w FROM dict_entries WHERE headword_norm IN (#{sql_list.(all)});
    SQL
    stems_found = stems.select { |w| found.include?(w) }
    members = []
    first = prefixes.find { |pf| found.include?(pf) }
    if first
      members << first
      rest = word[first.length..-1]
      second = ([rest] + stem_candidates(rest)).find { |w| w.length >= 2 && found.include?(w) }
      members << second if second
    end
    json_response(res, { query: word, stems: stems_found.first(4), members: members.uniq })
  end
end

# ============================================================================
# API 3: CLASSICAL KOSHA VERSE BROWSER (Amarakosha, Halayudha, Vaijayanti, Akhyata)
# ============================================================================
server.mount_proc '/api/kosha/browse' do |req, res|
  safe_api(res) do
    params = req_params(req)
    kosha = (params['kosha'] || 'amara').to_s
    kanda = params['kanda'].to_s
    varga = params['varga'].to_s
    q_raw = params['q'].to_s
    limit = [(params['limit'] || 50).to_i, 150].min
    limit = 50 if limit <= 0

    nav = SqliteHelper.query(<<~SQL)
      SELECT kanda, varga, count(*) AS verse_count
      FROM kosha_verses
      WHERE kosha_code = #{SqliteHelper.q(kosha)}
      GROUP BY kanda, varga
      ORDER BY id ASC;
    SQL

    conds = ["kosha_code = #{SqliteHelper.q(kosha)}"]
    if !q_raw.empty?
      q_dev = normalize_query_to_dev(q_raw)
      conds << "(verse_text LIKE #{SqliteHelper.q("%#{q_dev}%")} OR words_json LIKE #{SqliteHelper.q("%#{q_dev}%")} OR verse_num LIKE #{SqliteHelper.q("%#{q_raw}%")})"
    else
      if kanda.empty? && nav.any?
        kanda = nav.first['kanda'].to_s
        varga = nav.first['varga'].to_s
      end
      conds << "kanda = #{SqliteHelper.q(kanda)}" unless kanda.empty?
      conds << "varga = #{SqliteHelper.q(varga)}" unless varga.empty?
    end

    verses = SqliteHelper.query(<<~SQL).map do |v|
      SELECT * FROM kosha_verses
      WHERE #{conds.join(' AND ')}
      ORDER BY id ASC
      LIMIT #{limit};
    SQL
      words = JSON.parse(v['words_json'] || '[]') rescue []
      v.merge(
        'verse_text_te' => SanskritTransliterator.dev_to_telugu(v['verse_text'].to_s),
        'verse_text_iast' => SanskritTransliterator.dev_to_iast(v['verse_text'].to_s),
        'words' => words
      )
    end

    json_response(res, {
      kosha: kosha,
      active_kanda: kanda,
      active_varga: varga,
      navigation: nav,
      verses: verses
    })
  end
end

# ============================================================================
# API 4: DHATUPATHA SEARCH & FULL 10-LAKARA CONJUGATION TABLES
# ============================================================================
server.mount_proc '/api/dhatu/search' do |req, res|
  safe_api(res) do
    params = req_params(req)
    q_raw = params['q'].to_s
    gana  = params['gana'].to_s
    pada  = params['pada'].to_s
    karma = params['karma'].to_s
    limit = [(params['limit'] || 80).to_i, 200].min
    limit = 80 if limit <= 0

    conds = ['1=1']
    conds << "gana = #{gana.to_i}" unless gana.empty? || gana == 'all'
    conds << "pada = #{SqliteHelper.q(pada)}" unless pada.empty? || pada == 'all'
    conds << "karma = #{SqliteHelper.q(karma)}" unless karma.empty? || karma == 'all'

    inflection_matches = []
    q_dev = ''
    translit_cands = []
    unless q_raw.empty?
      scheme = (params['scheme'] || 'itrans').to_s
      q_dev  = normalize_query_to_dev(q_raw, scheme)
      q_norm = SanskritTransliterator.normalize_headword(q_dev)
      q_slp  = SanskritTransliterator.dev_to_slp(q_norm).downcase
      translit_cands = SanskritTransliterator.generate_translit_candidates(q_raw, scheme)
      cand_norms = ([q_dev, q_norm] + translit_cands).map { |c| SanskritTransliterator.normalize_headword(c).sub(/्$/, '') }.uniq.reject(&:empty?)
      cand_with_hal = (cand_norms + cand_norms.map { |c| "#{c}्" }).uniq
      cand_sql_list = cand_with_hal.map { |c| SqliteHelper.q(c) }.join(',')

      inflection_matches = SqliteHelper.query(<<~SQL)
        SELECT DISTINCT form, baseindex, dhatu, artha_sa, artha_en, lakara, prayoga
        FROM dhatu_inflections
        WHERE form IN (#{cand_sql_list}) OR form_norm IN (#{cand_sql_list})
        LIMIT 15;
      SQL

      infl_bidxs = inflection_matches.map { |m| SqliteHelper.q(m['baseindex']) }
      infl_clause = infl_bidxs.any? ? "OR baseindex IN (#{infl_bidxs.join(',')})" : ''
      cand_like_clauses = cand_norms.first(6).map { |c| "dhatu_norm LIKE #{SqliteHelper.q("%#{c}%")}" }.join(' OR ')

      conds << <<~COND
        (dhatu LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR dhatu_norm IN (#{cand_sql_list})
         OR (#{cand_like_clauses.empty? ? '0=1' : cand_like_clauses})
         OR LOWER(dhatu_slp) LIKE #{SqliteHelper.q("%#{q_slp}%")}
         OR aupadeshik LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR artha_sa LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR LOWER(artha_en) LIKE #{SqliteHelper.q("%#{q_raw.downcase}%")}
         OR baseindex = #{SqliteHelper.q(q_raw)}
         #{infl_clause})
      COND
    end

    rows = SqliteHelper.query(<<~SQL).map do |d|
      SELECT id, baseindex, dhatu, aupadeshik, gana, pada, settva, karma, artha_sa, artha_en, artha_te, tags,
             json_extract(kartari_json, '$.plat') AS plat_preview,
             json_extract(kartari_json, '$.alat') AS alat_preview
      FROM dhatus
      WHERE #{conds.join(' AND ')}
      ORDER BY
        CASE
          WHEN dhatu_norm = #{SqliteHelper.q(q_dev.sub(/्$/, ''))} THEN 0
          WHEN dhatu = #{SqliteHelper.q(q_dev)} THEN 0
          ELSE 1
        END,
        baseindex ASC
      LIMIT #{limit};
    SQL
      lat_3sg = (d['plat_preview'] || d['alat_preview'] || '').to_s.split(';').first.to_s
      d.merge(
        'dhatu_te' => SanskritTransliterator.dev_to_telugu(d['dhatu'].to_s),
        'dhatu_iast' => SanskritTransliterator.dev_to_iast(d['dhatu'].to_s),
        'lat_3sg' => lat_3sg,
        'lat_3sg_te' => SanskritTransliterator.dev_to_telugu(lat_3sg),
        'lat_3sg_iast' => SanskritTransliterator.dev_to_iast(lat_3sg)
      )
    end

    json_response(res, {
      query: q_raw,
      query_dev: q_dev,
      query_te: SanskritTransliterator.dev_to_telugu(q_dev),
      query_iast: SanskritTransliterator.dev_to_iast(q_dev),
      translit_candidates: translit_cands.first(8),
      inflection_matches: inflection_matches,
      dhatus: rows
    })
  end
end

server.mount_proc '/api/dhatu/detail' do |req, res|
  safe_api(res) do
    params = req_params(req)
    bidx = params['baseindex'].to_s
    id   = params['id'].to_s
    cond = !bidx.empty? ? "baseindex = #{SqliteHelper.q(bidx)}" : "id = #{SqliteHelper.q(id)}"
    cond = "baseindex = '01.0001'" if bidx.empty? && id.empty?

    rows = SqliteHelper.query("SELECT * FROM dhatus WHERE #{cond} LIMIT 1;")
    next json_response(res, { error: 'Dhatu not found' }, 404) if rows.empty?

    d = rows.first
    kartari_raw = JSON.parse(d['kartari_json'] || '{}') rescue {}
    karmani_raw = JSON.parse(d['karmani_json'] || '{}') rescue {}
    krut_raw    = JSON.parse(d['krut_json'] || '{}') rescue {}
    prayoga_raw = JSON.parse(d['prayogas_json'] || '{}') rescue {}

    kartari_tables = []
    karmani_tables = []

    LAKARA_METADATA.each do |lcode, name_sa, name_en, name_te|
      p_grid = parse_conjugation_grid(kartari_raw["p#{lcode}"])
      a_grid = parse_conjugation_grid(kartari_raw["a#{lcode}"])
      if p_grid || a_grid
        kartari_tables << {
          code: lcode,
          name_sa: name_sa,
          name_en: name_en,
          name_te: name_te,
          parasmaipada: p_grid,
          atmanepada: a_grid
        }
      end

      kp_grid = parse_conjugation_grid(karmani_raw["a#{lcode}"] || karmani_raw["p#{lcode}"])
      if kp_grid
        karmani_tables << {
          code: lcode,
          name_sa: name_sa,
          name_en: name_en,
          name_te: name_te,
          atmanepada: kp_grid
        }
      end
    end

    krut_list = krut_raw.map do |pratyay, forms_csv|
      parts = forms_csv.to_s.split(',', -1)
      {
        pratyay: pratyay,
        pratyay_te: SanskritTransliterator.dev_to_telugu(pratyay),
        pratyay_iast: SanskritTransliterator.dev_to_iast(pratyay),
        stem: parts[0].to_s,
        pum: parts[1].to_s,
        stri: parts[2].to_s,
        napum: parts[3].to_s,
        forms_te: SanskritTransliterator.dev_to_telugu(forms_csv.to_s),
        forms_iast: SanskritTransliterator.dev_to_iast(forms_csv.to_s)
      }
    end

    upasargas = SqliteHelper.query(<<~SQL)
      SELECT headword, definition, page_ref
      FROM dict_entries
      WHERE dict_code = 'upasarga' AND headword_norm = #{SqliteHelper.q(d['dhatu_norm'])}
      LIMIT 30;
    SQL

    json_response(res, {
      id: d['id'],
      baseindex: d['baseindex'],
      dhatu: d['dhatu'],
      dhatu_te: SanskritTransliterator.dev_to_telugu(d['dhatu'].to_s),
      dhatu_iast: SanskritTransliterator.dev_to_iast(d['dhatu'].to_s),
      aupadeshik: d['aupadeshik'],
      gana: d['gana'],
      pada: d['pada'],
      settva: d['settva'],
      karma: d['karma'],
      artha_sa: d['artha_sa'],
      artha_en: d['artha_en'],
      artha_te: d['artha_te'],
      tags: d['tags'],
      kartari: kartari_tables,
      karmani: karmani_tables,
      kridantas: krut_list,
      upasargas: upasargas,
      prayogas: prayoga_raw
    })
  end
end

# ============================================================================
# API 5: SHABDAPATHA DECLENSIONS, PRAKRIYA, & ALGORITHMIC GENERATOR
# ============================================================================
server.mount_proc '/api/shabda/search' do |req, res|
  safe_api(res) do
    params = req_params(req)
    q_raw = params['q'].to_s
    linga = params['linga'].to_s
    limit = [(params['limit'] || 80).to_i, 200].min
    limit = 80 if limit <= 0

    conds = ['1=1']
    conds << "linga = #{SqliteHelper.q(linga)}" unless linga.empty? || linga == 'all'

    scheme = (params['scheme'] || 'itrans').to_s
    q_dev  = normalize_query_to_dev(q_raw, scheme)
    q_norm = SanskritTransliterator.normalize_headword(q_dev)
    q_slp  = SanskritTransliterator.dev_to_slp(q_norm).downcase
    translit_cands = q_raw.empty? ? [] : SanskritTransliterator.generate_translit_candidates(q_raw, scheme)
    cand_norms = ([q_dev, q_norm] + translit_cands).map { |c| SanskritTransliterator.normalize_headword(c).sub(/्$/, '') }.uniq.reject(&:empty?)
    cand_sql_list = cand_norms.map { |c| SqliteHelper.q(c) }.join(',')
    cand_prefix_clauses = cand_norms.first(5).map { |c| "word_norm LIKE #{SqliteHelper.q("#{c}%")}" }.join(' OR ')

    unless q_raw.empty?
      conds << <<~COND
        (word LIKE #{SqliteHelper.q("#{q_dev}%")}
         OR word_norm LIKE #{SqliteHelper.q("#{q_norm}%")}
         OR #{cand_sql_list.empty? ? '0=1' : "word_norm IN (#{cand_sql_list})"}
         OR (#{cand_prefix_clauses.empty? ? '0=1' : cand_prefix_clauses})
         OR LOWER(word_slp) LIKE #{SqliteHelper.q("#{q_slp}%")}
         OR artha_sa LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR LOWER(artha_en) LIKE #{SqliteHelper.q("%#{q_raw.downcase}%")}
         OR forms LIKE #{SqliteHelper.q("%#{q_dev}%")})
      COND
    end

    rows = SqliteHelper.query(<<~SQL).map do |s|
      SELECT urlid, word, linga, anta, artha_sa, artha_hi, artha_en, artha_te, substr(forms, 1, 90) AS forms_preview
      FROM shabdas
      WHERE #{conds.join(' AND ')}
      ORDER BY
        CASE
          WHEN word_norm = #{SqliteHelper.q(q_norm)} THEN 0
          WHEN #{cand_sql_list.empty? ? '0=1' : "word_norm IN (#{cand_sql_list})"} THEN 1
          WHEN LOWER(word_slp) = #{SqliteHelper.q(q_slp)} THEN 1
          ELSE 2
        END,
        length(word) ASC
      LIMIT #{limit};
    SQL
      nom_row = s['forms_preview'].to_s.split(';')[0..2].join(' · ')
      s.merge(
        'word_te' => SanskritTransliterator.dev_to_telugu(s['word'].to_s),
        'word_iast' => SanskritTransliterator.dev_to_iast(s['word'].to_s),
        'prathama' => nom_row
      )
    end

    json_response(res, {
      query: q_raw,
      query_dev: q_dev,
      query_te: SanskritTransliterator.dev_to_telugu(q_dev),
      query_iast: SanskritTransliterator.dev_to_iast(q_dev),
      translit_candidates: translit_cands.first(8),
      shabdas: rows
    })
  end
end

server.mount_proc '/api/shabda/detail' do |req, res|
  safe_api(res) do
    params = req_params(req)
    urlid = params['urlid'].to_s
    urlid = '@rAma1' if urlid.empty?

    rows = SqliteHelper.query("SELECT * FROM shabdas WHERE urlid = #{SqliteHelper.q(urlid)} LIMIT 1;")
    if rows.empty?
      rows = SqliteHelper.query("SELECT * FROM shabdas WHERE word = #{SqliteHelper.q(normalize_query_to_dev(urlid))} LIMIT 1;")
    end
    next json_response(res, { error: 'Shabda not found' }, 404) if rows.empty?

    s = rows.first
    table = parse_shabda_table(s['forms'])
    prakriyas = SqliteHelper.query(<<~SQL).map do |p|
      SELECT form, vibhakti, vachan, steps_json
      FROM shabda_prakriya
      WHERE word = #{SqliteHelper.q(s['word'])}
      LIMIT 30;
    SQL
      p.merge('steps' => (JSON.parse(p['steps_json'] || '[]') rescue []))
    end

    json_response(res, {
      urlid: s['urlid'],
      word: s['word'],
      word_te: SanskritTransliterator.dev_to_telugu(s['word'].to_s),
      word_iast: SanskritTransliterator.dev_to_iast(s['word'].to_s),
      linga: s['linga'],
      anta: s['anta'],
      artha_sa: s['artha_sa'],
      artha_hi: s['artha_hi'],
      artha_en: s['artha_en'],
      artha_te: s['artha_te'],
      vyutpatti: s['vyutpatti'],
      notes: s['notes'],
      mw_meaning: s['mw_meaning'],
      ap_meaning: s['ap_meaning'],
      bh_meaning: s['bh_meaning'],
      table: table,
      prakriyas: prakriyas
    })
  end
end

server.mount_proc '/api/shabda/generate' do |req, res|
  safe_api(res) do
    params = req_params(req)
    stem_raw = params['stem'].to_s
    linga = (params['linga'] || 'P').to_s
    next json_response(res, { error: 'Please provide a Sanskrit stem' }, 400) if stem_raw.empty?

    stem_dev = normalize_query_to_dev(stem_raw)
    result = SanskritGrammarEngine.generate_declension(stem_dev, linga)
    json_response(res, result)
  end
end

# ============================================================================
# API 6: ASHTADHYAYI SUTRAPATHA (~4,000 Sutras + Commentaries + Auxiliaries)
# ============================================================================
server.mount_proc '/api/sutra/search' do |req, res|
  safe_api(res) do
    params  = req_params(req)
    q_raw   = params['q'].to_s
    scheme  = (params['scheme'] || 'itrans').to_s
    adhyaya = params['adhyaya'].to_s
    pada    = params['pada'].to_s
    limit   = [(params['limit'] || 100).to_i, 300].min
    limit   = 100 if limit <= 0

    conds = ['1=1']
    conds << "adhyaya = #{adhyaya.to_i}" unless adhyaya.empty? || adhyaya == 'all'
    conds << "pada = #{pada.to_i}" unless pada.empty? || pada == 'all'

    q_dev = ''
    translit_cands = []
    unless q_raw.empty?
      q_dev  = normalize_query_to_dev(q_raw, scheme)
      q_norm = SanskritTransliterator.normalize_headword(q_dev)
      q_norm_nospace = q_norm.gsub(/\s+/, '')
      q_ascii_nospace = q_raw.downcase.gsub(/\s+/, '')
      translit_cands = SanskritTransliterator.generate_translit_candidates(q_raw, scheme)
      cand_likes = translit_cands.first(6).map do |c|
        cn = SanskritTransliterator.normalize_headword(c).sub(/्$/, '')
        "REPLACE(sutra_norm, ' ', '') LIKE #{SqliteHelper.q("%#{cn.gsub(/\s+/, '')}%")}"
      end.join(' OR ')

      conds << <<~COND
        (code LIKE #{SqliteHelper.q("#{q_raw}%")}
         OR sutra LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR sutra_norm LIKE #{SqliteHelper.q("%#{q_norm}%")}
         OR REPLACE(sutra_norm, ' ', '') LIKE #{SqliteHelper.q("%#{q_norm_nospace}%")}
         OR (#{cand_likes.empty? ? '0=1' : cand_likes})
         OR LOWER(sutra_iast) LIKE #{SqliteHelper.q("%#{q_raw.downcase}%")}
         OR LOWER(REPLACE(sutra_iast, ' ', '')) LIKE #{SqliteHelper.q("%#{q_ascii_nospace}%")}
         OR sutrartha_sa LIKE #{SqliteHelper.q("%#{q_dev}%")}
         OR LOWER(sutrartha_en) LIKE #{SqliteHelper.q("%#{q_raw.downcase}%")}
         OR sk_num = #{SqliteHelper.q(q_raw)}
         OR lsk_num = #{SqliteHelper.q(q_raw)})
      COND
    end

    rows = SqliteHelper.query(<<~SQL)
      SELECT id, code, adhyaya, pada, num, sutra, sutra_iast, sutra_te, type,
             anuvritti, adhikara, sutrartha_sa, sutrartha_en, sk_num, lsk_num
      FROM sutras
      WHERE #{conds.join(' AND ')}
      ORDER BY adhyaya ASC, pada ASC, num ASC
      LIMIT #{limit};
    SQL

    json_response(res, {
      query: q_raw,
      query_dev: q_dev,
      query_te: SanskritTransliterator.dev_to_telugu(q_dev),
      query_iast: SanskritTransliterator.dev_to_iast(q_dev),
      translit_candidates: translit_cands.first(8),
      sutras: rows
    })
  end
end

server.mount_proc '/api/sutra/detail' do |req, res|
  safe_api(res) do
    params = req_params(req)
    id   = params['id'].to_s
    code = params['code'].to_s
    cond = if !code.empty?
             "code = #{SqliteHelper.q(code)}"
           elsif !id.empty?
             "id = #{SqliteHelper.q(id)} OR code = #{SqliteHelper.q(id)}"
           else
             "code = '1.1.1'"
           end

    rows = SqliteHelper.query("SELECT * FROM sutras WHERE #{cond} LIMIT 1;")
    next json_response(res, { error: 'Sutra not found' }, 404) if rows.empty?

    s = rows.first
    vartikas = JSON.parse(s['vartikas_json'] || '[]') rescue []

    neighbors = SqliteHelper.query(<<~SQL)
      SELECT
        (SELECT code FROM sutras WHERE id < #{SqliteHelper.q(s['id'])} ORDER BY id DESC LIMIT 1) AS prev_code,
        (SELECT code FROM sutras WHERE id > #{SqliteHelper.q(s['id'])} ORDER BY id ASC LIMIT 1) AS next_code;
    SQL
    nb = neighbors.first || {}

    json_response(res, s.merge(
      'vartikas' => vartikas,
      'prev_code' => nb['prev_code'],
      'next_code' => nb['next_code'],
      'sutrartha_te' => SanskritTransliterator.dev_to_telugu(s['sutrartha_sa'].to_s),
      'kashika_te' => SanskritTransliterator.dev_to_telugu(s['kashika'].to_s),
      'kaumudi_te' => SanskritTransliterator.dev_to_telugu(s['kaumudi'].to_s)
    ))
  end
end

server.mount_proc '/api/vyakarana/list' do |req, res|
  safe_api(res) do
    params = req_params(req)
    cat    = (params['category'] || 'shivasutra').to_s
    q_raw  = params['q'].to_s
    scheme = (params['scheme'] || 'itrans').to_s
    limit  = [(params['limit'] || 150).to_i, 400].min
    limit  = 150 if limit <= 0

    conds = ["category = #{SqliteHelper.q(cat)}"]
    q_dev = ''
    unless q_raw.empty?
      q_dev = normalize_query_to_dev(q_raw, scheme)
      cands = SanskritTransliterator.generate_translit_candidates(q_raw, scheme).first(5)
      cand_clauses = ([q_dev] + cands).uniq.reject(&:empty?).map do |c|
        cn = c.sub(/्$/, '')
        "(title LIKE #{SqliteHelper.q("%#{cn}%")} OR body LIKE #{SqliteHelper.q("%#{cn}%")})"
      end.join(' OR ')
      conds << "(#{cand_clauses.empty? ? '0=1' : cand_clauses} OR LOWER(subtitle) LIKE #{SqliteHelper.q("%#{q_raw.downcase}%")})"
    end

    rows = SqliteHelper.query(<<~SQL).map do |r|
      SELECT id, category, item_num, title, subtitle, body, extra_json
      FROM vyakarana_texts
      WHERE #{conds.join(' AND ')}
      ORDER BY id ASC
      LIMIT #{limit};
    SQL
      r.merge(
        'title_te' => SanskritTransliterator.dev_to_telugu(r['title'].to_s),
        'title_iast' => SanskritTransliterator.dev_to_iast(r['title'].to_s),
        'body_te' => SanskritTransliterator.dev_to_telugu(r['body'].to_s)
      )
    end

    json_response(res, { category: cat, query_dev: q_dev, items: rows })
  end
end

# ============================================================================
# API 7: SANSKRITABHYAS MODULES & INTERACTIVE GRAMMAR/PROSODY TOOLS
# ============================================================================
server.mount_proc '/api/abhyas/list' do |_req, res|
  safe_api(res) do
    rows = SqliteHelper.query('SELECT * FROM abhyas_modules ORDER BY rowid ASC;').map do |m|
      sections = JSON.parse(m['sections_json'] || '[]') rescue []
      m.merge('sections' => sections)
    end
    json_response(res, { modules: rows })
  end
end

# Verbatim Published Rule & Chandas Meter Explanation Endpoint
# Uses ONLY authentic published sources in database/sanskrit_offline.db:
#   1. Srisa Chandra Vasu's The Ashtadhyayi of Panini (1891) & Ashtadhyayi.com Sutrartha
#   2. Prof. K.V. Abhyankar's A Dictionary of Sanskrit Grammar (1961, Oriental Institute, Baroda)
#   3. V.S. Apte's The Practical Sanskrit-English Dictionary (1890)
#   4. Sir Monier Monier-Williams' A Sanskrit-English Dictionary (1899, Oxford)
#   5. Prof. A.A. Macdonell's A Practical Sanskrit Dictionary (1929, Oxford)
#   6. Prof. H.H. Wilson's Sanskrit-English Dictionary (1832) & Carl Cappeller (1891)
server.mount_proc '/api/grammar/rule_explanation' do |req, res|
  safe_api(res) do
    params = req_params(req)
    raw_rule = (params['rule'] || params['q'] || params['term'] || '').to_s.strip
    raw_code = (params['code'] || params['sutra_code'] || '').to_s.strip
    raw_context = params['context'].to_s.strip

    # 1. Extract all Paninian Sutra codes (e.g. 6.1.77, 2.1.38, 8.4.40) from raw_code, raw_rule, raw_context
    combined_text = "#{raw_code} #{raw_rule} #{raw_context}"
    sutra_codes = combined_text.scan(/\b([1-8]\.[1-4]\.\d{1,3})\b/).flatten.uniq

    # 2. Extract Sanskrit terms / tokens to look up in GRAMMAR_TERM_SUTRA_MAP and published dictionaries
    clean_terms = []
    [raw_rule, raw_context].each do |txt|
      next if txt.empty?
      # Remove parentheticals like (6.1.77) or (Vasantatilaka) and split by /, —, (, ), ,, ;
      stripped = txt.gsub(/\([^)]*\)/, ' ').gsub(/\[[^\]]*\]/, ' ')
      parts = stripped.split(/[\/—–,;:|+→=]+/).map(&:strip).reject(&:empty?)
      clean_terms.concat(parts)
    end

    search_headwords = []
    clean_terms.each do |t|
      dev_t = normalize_query_to_dev(t)
      norm_t = SanskritTransliterator.normalize_headword(dev_t).sub(/[ःंम्]+$/, '').strip
      next if norm_t.empty?

      search_headwords << norm_t
      search_headwords << dev_t.sub(/ः$/, '')

      # Check GRAMMAR_TERM_SUTRA_MAP for direct or stripped terms
      [norm_t, norm_t.sub(/समास$/, ''), norm_t.sub(/सन्धि$/, ''), norm_t.sub(/वाच्य$/, 'वाच्य')].each do |k|
        sutra_codes.concat(GRAMMAR_TERM_SUTRA_MAP[k]) if GRAMMAR_TERM_SUTRA_MAP.key?(k)
      end

      # Decompose compound rule names into canonical Paninian & Prosodic headwords
      if norm_t.end_with?('सन्धि')
        base_s = norm_t.sub(/सन्धि$/, '').sub(/[-–]/, '')
        search_headwords << base_s unless base_s.empty?
        search_headwords << 'सन्धि'
        search_headwords << 'संहिता'
        search_headwords.concat(%w[सवर्ण दीर्घ]) if base_s.include?('सवर्ण') || base_s.include?('दीर्घ')
        search_headwords << 'गुण' if base_s.include?('गुण')
        search_headwords.concat(%w[वृद्धि आदिवृद्धि]) if base_s.include?('वृद्धि')
        search_headwords << 'यण्' if base_s.include?('यण्')
        search_headwords << 'एच्' if base_s.include?('अयादि')
        search_headwords << 'पूर्वरूप' if base_s.include?('पूर्वरूप')
        search_headwords << 'पररूप' if base_s.include?('पररूप')
        search_headwords.concat(%w[प्रकृतिभाव प्रगृह्य]) if base_s.include?('प्रकृतिभाव')
        search_headwords << 'श्चुत्व' if base_s.include?('श्चुत्व')
        search_headwords << 'ष्टुत्व' if base_s.include?('ष्टुत्व')
        search_headwords.concat(%w[जश्त्व जश्]) if base_s.include?('जश्त्व')
        search_headwords.concat(%w[चर्त्व चर्]) if base_s.include?('चर्त्व')
        search_headwords << 'अनुनासिक' if base_s.include?('अनुनासिक')
        search_headwords << 'अनुस्वार' if base_s.include?('अनुस्वार')
        search_headwords << 'परसवर्ण' if base_s.include?('परसवर्ण')
        search_headwords << 'पूर्वसवर्णदीर्ध' if base_s.include?('पूर्वसवर्ण')
        search_headwords.concat(%w[तुक् आगम]) if base_s.include?('तुगागम')
        search_headwords.concat(%w[विसर्जनीय विसर्ग लोप]) if base_s.include?('विसर्ग')
      elsif norm_t.end_with?('समास') || norm_t.end_with?('तत्पुरुष') || norm_t.end_with?('कर्मधारय') || norm_t.end_with?('द्विगु') || norm_t.end_with?('बहुव्रीहि') || norm_t.end_with?('द्वन्द्व')
        search_headwords << 'समास'
        search_headwords << 'अव्ययीभाव' if norm_t.include?('अव्ययीभाव')
        search_headwords << 'तत्पुरुष' if norm_t.include?('तत्पुरुष')
        search_headwords.concat(%w[कर्मधारय समानाधिकरण उपमान]) if norm_t.include?('कर्मधारय')
        search_headwords.concat(%w[द्विगु समाहार]) if norm_t.include?('द्विगु')
        search_headwords.concat(%w[बहुव्रीहि समानाधिकरण व्यधिकरण]) if norm_t.include?('बहुव्रीहि')
        search_headwords.concat(%w[द्वन्द्व द्वन्द्ध इतरेतर समाहार]) if norm_t.include?('द्वन्द्व')
      elsif norm_t.include?('वाच्य')
        search_headwords.concat(%w[वाच्य कर्तृ कर्मन् भाव])
      end

      # Chandas meter stem variations (feminine -आ -> stem, -िनी -> -िन्, compound base stems)
      search_headwords << norm_t.sub(/ा$/, '') if norm_t.end_with?('ा') && norm_t.length >= 2
      search_headwords << norm_t.sub(/िनी$/, 'िन्') if norm_t.end_with?('िनी')
      search_headwords << norm_t.sub(/णी$/, 'न्') if norm_t.end_with?('णी') && !norm_t.include?('प्रहर्षि')
      search_headwords << 'हरिण' if norm_t == 'हरिणी'
      search_headwords << 'वंशस्थविल' if norm_t.start_with?('वंशस्थ')
      search_headwords << 'वसन्त' if norm_t.start_with?('वसन्ततिलक')
      search_headwords << 'उपेन्द्र' if norm_t.start_with?('उपेन्द्रवज्र')
      search_headwords << 'इन्द्र' if norm_t.start_with?('इन्द्रवज्र')
      search_headwords << 'भुजङ्ग' if norm_t.start_with?('भुजङ्गप्रयात')
      search_headwords << 'शार्दूल' if norm_t.start_with?('शार्दूलविक्रीडित')
      search_headwords << 'यगण' if norm_t.start_with?('य-गण')
      search_headwords << 'मगण' if norm_t.start_with?('म-गण')
      search_headwords << 'तगण' if norm_t.start_with?('त-गण')
      search_headwords << 'रगण' if norm_t.start_with?('र-गण')
      search_headwords << 'जगण' if norm_t.start_with?('ज-गण')
      search_headwords << 'भगण' if norm_t.start_with?('भ-गण')
      search_headwords << 'नगण' if norm_t.start_with?('न-गण')
      search_headwords << 'सगण' if norm_t.start_with?('स-गण')
      search_headwords << 'गण' if norm_t.include?('-गण')
    end

    sutra_codes = sutra_codes.uniq

    # If no explicit sutra_code was found, also check if any clean_term matches a sutra text in `sutras`
    if sutra_codes.empty? && clean_terms.any?
      first_dev = normalize_query_to_dev(clean_terms.first)
      first_norm = SanskritTransliterator.normalize_headword(first_dev)
      if first_norm.length >= 3
        matched_s = SqliteHelper.query(<<~SQL)
          SELECT code FROM sutras
          WHERE sutra = #{SqliteHelper.q(first_dev)}
             OR sutra_norm = #{SqliteHelper.q(first_norm)}
             OR sutra LIKE #{SqliteHelper.q("#{first_dev}%")}
          LIMIT 3;
        SQL
        sutra_codes.concat(matched_s.map { |r| r['code'] })
      end
    end

    sutras_found = []
    if sutra_codes.any?
      code_list = sutra_codes.uniq.map { |c| SqliteHelper.q(c) }.join(',')
      sutras_found = SqliteHelper.query(<<~SQL).map do |s|
        SELECT id, code, adhyaya, pada, num, sutra, sutra_iast, sutra_te, padaccheda, type,
               anuvritti, adhikara, sutrartha_sa, sutrartha_en, vasu_en,
               kashika, kaumudi, laghukaumudi, balamanorama, vartikas_json
        FROM sutras
        WHERE code IN (#{code_list});
      SQL
        s.merge('vartikas' => (JSON.parse(s['vartikas_json'] || '[]') rescue []))
      end
    end

    # 3. Query published English dictionaries (Abhyankar, Apte, Wilson, Macdonell, Cappeller, Monier-Williams)
    dict_explanations = []
    hw_list = search_headwords.map(&:strip).reject(&:empty?).uniq.first(15)
    if hw_list.any?
      hw_sql = hw_list.map { |h| SqliteHelper.q(h) }.join(',')
      raw_dicts = SqliteHelper.query(<<~SQL)
        SELECT d.id, d.dict_code, d.headword, d.headword_norm, d.definition, d.page_ref,
               dict.name_sa, dict.name_en, dict.name_te
        FROM dict_entries d
        JOIN dictionaries dict ON dict.code = d.dict_code
        WHERE d.dict_code = 'abhyankar'
          AND (d.headword_norm IN (#{hw_sql}) OR d.headword IN (#{hw_sql}))
        ORDER BY length(d.definition) DESC
        LIMIT 10;
      SQL
      local = raw_dicts.map do |r|
        hw = r['headword'].to_s
        r.merge(
          'source' => 'local',
          'headword_te' => SanskritTransliterator.dev_to_telugu(hw),
          'headword_iast' => SanskritTransliterator.dev_to_iast(hw)
        )
      end
      order = %w[abhyankar wil md ap90 cae mw]
      cologne = CdslDictionary.lookup(headwords: hw_list, codes: %w[wil md ap90 cae mw], limit: 40)
      dict_explanations = (local + cologne).each_with_index.sort_by { |e, i| [order.index(e['dict_code']) || 9, i] }.map(&:first).first(25)
    end

    # 4. Also check if the clicked item is a Chandas meter in SanskritGrammarEngine::METERS
    chandas_meter_info = nil
    SanskritGrammarEngine::METERS.each do |m|
      m_stem = m[:name_sa].sub(/[म्ः]$/, '')
      if raw_rule.include?(m_stem) || raw_context.include?(m_stem) || raw_rule.downcase.include?(m[:name_en].downcase)
        chandas_meter_info = m
        break
      end
    end

    json_response(res, {
      rule: raw_rule,
      context: raw_context,
      sutra_codes: sutra_codes.uniq,
      sutras: sutras_found,
      dict_entries: dict_explanations,
      published_dictionaries: dict_explanations,
      chandas_meter: chandas_meter_info
    })
  end
end

server.mount_proc '/api/tools/sandhi' do |req, res|
  safe_api(res) do
    params = req_params(req)
    mode = (params['mode'] || 'join').to_s
    scheme = (params['scheme'] || 'itrans').to_s
    if mode == 'split'
      word = normalize_query_to_dev(params['word'].to_s, scheme)
      splits = SanskritGrammarEngine.split_sandhi(word)
      json_response(res, { mode: 'split', word: word, splits: splits })
    else
      p1 = normalize_query_to_dev(params['pada1'].to_s, scheme)
      p2 = normalize_query_to_dev(params['pada2'].to_s, scheme)
      joins = SanskritGrammarEngine.join_sandhi(p1, p2)
      json_response(res, { mode: 'join', pada1: p1, pada2: p2, joins: joins })
    end
  end
end

server.mount_proc '/api/tools/chandas' do |req, res|
  safe_api(res) do
    params = req_params(req)
    text = params['text'].to_s
    analysis = SanskritGrammarEngine.analyze_chandas(text)
    json_response(res, analysis)
  end
end

server.mount_proc '/api/tools/transliterate' do |req, res|
  safe_api(res) do
    params = req_params(req)
    text   = params['text'].to_s
    word   = (params['word'] || text).to_s.strip
    scheme = (params['scheme'] || 'itrans').to_s
    dev    = normalize_query_to_dev(text, scheme)

    # Build rich transliteration candidate options for the active word in the typing space
    raw_cands = word.empty? ? [] : SanskritTransliterator.generate_translit_candidates(word, scheme)

    # Also query matching shabdas / dictionary headwords so common Sanskrit words appear in the candidate bar
    db_cands = []
    if !word.empty? && raw_cands.any?
      cand_stems = raw_cands.first(6).map { |c| SanskritTransliterator.normalize_headword(c).sub(/्$/, '') }.uniq.reject(&:empty?)
      if cand_stems.any?
        sql_list = cand_stems.map { |c| SqliteHelper.q(c) }.join(',')
        prefix_likes = cand_stems.first(3).map { |c| "word_norm LIKE #{SqliteHelper.q("#{c}%")}" }.join(' OR ')
        shabda_rows = SqliteHelper.query(<<~SQL)
          SELECT word, artha_en, forms
          FROM shabdas
          WHERE word_norm IN (#{sql_list}) OR (#{prefix_likes})
          ORDER BY length(word) ASC
          LIMIT 6;
        SQL
        shabda_rows.each do |sr|
          w_dev = sr['word'].to_s
          nom_sg = sr['forms'].to_s.split(';').first.to_s
          db_cands << w_dev unless w_dev.empty?
          db_cands << nom_sg unless nom_sg.empty?
        end
      end
    end

    all_deva_cands = (raw_cands.first(4) + db_cands + raw_cands).map(&:strip).reject(&:empty?).uniq.first(10)
    candidate_objects = all_deva_cands.map do |c_dev|
      {
        deva: c_dev,
        telu: SanskritTransliterator.dev_to_telugu(c_dev),
        iast: SanskritTransliterator.dev_to_iast(c_dev)
      }
    end

    json_response(res, {
      deva: dev,
      telu: SanskritTransliterator.dev_to_telugu(dev),
      iast: SanskritTransliterator.dev_to_iast(dev),
      slp1: SanskritTransliterator.dev_to_slp(dev),
      word: word,
      candidates: candidate_objects
    })
  end
end

# Where "open on the original site" links go. Nothing from these sites is copied or served here.
server.mount_proc '/api/config' do |_req, res|
  json_response(res, {
    ashtadhyayi_base: 'https://ashtadhyayi.com',
    andhrabharati_base: 'https://www.andhrabharati.com/dictionary/sanskrit/'
  })
end

%w[INT TERM].each do |sig|
  trap(sig) { server.shutdown }
rescue ArgumentError
  # signal not available on this platform
end

def open_browser(url)
  if Gem.win_platform?
    system('cmd', '/c', 'start', '', url)
  elsif RUBY_PLATFORM.include?('darwin')
    system('open', url)
  else
    system('xdg-open', url, out: File::NULL, err: File::NULL)
  end
rescue StandardError
  nil
end

actual_port = server.listeners.first.addr[1]
url = "http://#{BIND_ADDRESS == '0.0.0.0' ? '127.0.0.1' : BIND_ADDRESS}:#{actual_port}/"
$stdout.sync = true
puts "Sanskrit Composer Studio is running at #{url}"
puts 'Keep this window open while you use it; close it (or press Ctrl+C) to stop.'
# Set by the Start launchers: open the Studio in the default browser once the server is listening.
Thread.new { sleep 0.5; open_browser(url) } if ENV['OPEN_BROWSER'] == '1'
server.start
