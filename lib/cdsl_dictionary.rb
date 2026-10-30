# frozen_string_literal: true

require 'cgi'

# Search over the 12 Cologne (CDSL) dictionaries in data/andhrabharati/dict.sqlite, which is
# attached read-only as schema "c" by SqliteHelper. Entries keep their rendered HTML
# (definition_html); a plain-text copy (definition) is derived for previews and Telugu display.
module CdslDictionary
  module_function

  # Display priority when results from several dictionaries are merged.
  PRIORITY = %w[ap90 mw wil md cae ben lrv skd vcp bharati amara halayudha yaadava akhyata upasarga abhyankar ae mwe bor].freeze

  def priority(code)
    PRIORITY.index(code) || PRIORITY.size
  end

  def html_to_plain(html)
    t = html.to_s.gsub(%r{<span class="mw-sa">.*?</span>}m, '') # IAST twin; the Devanagari copy stays
    t = t.gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</div>}i, "\n").gsub(/<[^>]+>/, '')
    CGI.unescapeHTML(t).gsub(/[ \t]+/, ' ').gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  def glob_escape(s)
    s.to_s.gsub(/([*?\[\]])/) { "[#{Regexp.last_match(1)}]" }
  end

  # codes: array of CDSL dictionary codes to search (already filtered by the caller)
  # Returns rows shaped like the local dict_entries rows plus definition_html.
  def search(q_dev:, q_norm:, q_raw:, match_type:, scope:, codes:, limit:)
    return [] if codes.empty?
    code_list = codes.map { |c| SqliteHelper.q(c) }.join(',')
    english = q_raw.downcase.strip
    cond =
      if scope == 'fulltext'
        terms = [q_raw.strip, q_dev.strip].reject(&:empty?).uniq.map { |t| '"' + t.delete('"') + '"' }
        return [] if terms.empty?
        "e.id IN (SELECT rowid FROM c.fts WHERE fts MATCH #{SqliteHelper.q(terms.join(' OR '))})"
      else
        keys = [q_norm, q_dev, english].map(&:strip).reject(&:empty?).uniq
        # Some dictionaries (Śabdakalpadruma, Vācaspatyam, Apte) list nouns with their ending.
        keys += [q_norm].reject(&:empty?).flat_map { |k| ["#{k}ः", "#{k}म्", "#{k}ं"] } if match_type == 'exact'
        parts = keys.map do |k|
          g = glob_escape(k)
          case match_type
          when 'exact'    then "e.key_deva = #{SqliteHelper.q(k)}"
          when 'suffix'   then "e.key_deva GLOB #{SqliteHelper.q("*#{g}")}"
          when 'contains' then "e.key_deva GLOB #{SqliteHelper.q("*#{g}*")}"
          else                 "e.key_deva GLOB #{SqliteHelper.q("#{g}*")}"
          end
        end
        "(#{parts.join(' OR ')})"
      end
    base = [q_norm, q_dev, english].reject(&:empty?).uniq
    exact_keys = (base + [q_norm].reject(&:empty?).flat_map { |k| ["#{k}ः", "#{k}म्", "#{k}ं"] }).map { |k| SqliteHelper.q(k) }.join(',')
    rows = SqliteHelper.query(<<~SQL)
      SELECT e.id, dict.code AS dict_code, e.key_deva AS headword, e.key_iast AS headword_iast,
             e.html AS definition_html, e.pc AS page_ref, e.lnum,
             dict.name_sa, dict.name_en, dict.name_te
      FROM c.entries e
      JOIN main.dictionaries dict ON dict.cdsl_id = e.dict
      WHERE dict.code IN (#{code_list}) AND #{cond}
      ORDER BY CASE WHEN e.key_deva IN (#{exact_keys}) THEN 0 ELSE 1 END, length(e.key_deva), e.id
      LIMIT #{limit.to_i * 6};
    SQL
    group(rows).first(limit.to_i).map { |r| decorate(r) }
  end

  # Cologne stores each sense of a headword (e.g. Monier-Williams 1., 2., ...) as its own record.
  # Records of the same dictionary and headword are shown together, in source order.
  def group(rows)
    groups = {}
    rows.each do |r|
      key = [r['dict_code'], r['headword']]
      if (g = groups[key])
        g['parts'] << r
      else
        groups[key] = r.merge('parts' => [r])
      end
    end
    groups.values.map do |g|
      parts = g['parts'].sort_by { |p| p['id'].to_i }
      g.merge('id' => parts.first['id'], 'lnum' => parts.map { |p| p['lnum'] }.join(','),
              'page_ref' => parts.first['page_ref'], 'record_count' => parts.size,
              'definition_html' => parts.map { |p| %(<div class="cdsl-sense">#{p['definition_html']}</div>) }.join)
       .tap { |h| h.delete('parts') }
    end
  end

  # Exact headword lookup in selected dictionaries (used by the rule-explanation panel).
  def lookup(headwords:, codes:, limit:)
    return [] if headwords.empty? || codes.empty?
    hw_sql = headwords.map { |h| SqliteHelper.q(h) }.join(',')
    code_list = codes.map { |c| SqliteHelper.q(c) }.join(',')
    rows = SqliteHelper.query(<<~SQL)
      SELECT e.id, dict.code AS dict_code, e.key_deva AS headword, e.key_iast AS headword_iast,
             e.html AS definition_html, e.pc AS page_ref, e.lnum,
             dict.name_sa, dict.name_en, dict.name_te
      FROM c.entries e
      JOIN main.dictionaries dict ON dict.cdsl_id = e.dict
      WHERE dict.code IN (#{code_list}) AND e.key_deva IN (#{hw_sql})
      ORDER BY e.id
      LIMIT #{limit.to_i * 6};
    SQL
    group(rows).first(limit.to_i).map { |r| decorate(r) }
  end

  def decorate(r)
    plain = html_to_plain(r['definition_html'])
    r.merge(
      'id' => "cdsl-#{r['id']}",
      'source' => 'cdsl',
      'definition' => plain,
      'page_ref' => r['page_ref'].to_s.empty? ? '' : "p. #{r['page_ref']}",
      'headword_te' => SanskritTransliterator.dev_to_telugu(r['headword'].to_s),
      'definition_te' => SanskritTransliterator.dev_to_telugu(plain[0..600])
    )
  end
end
