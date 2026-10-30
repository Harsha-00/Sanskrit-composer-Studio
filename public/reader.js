// ============================================================================
// Reader: open a Sanskrit document (PDF, .txt, .md) and look words up beside it.
// * PDFs are rendered with PDF.js (vendor/pdfjs, offline). When a PDF has a text layer, words can be
//   selected or double-clicked for lookup, and "Find in document" searches its text.
// * Scanned PDFs (no text layer) are shown as images; the lookup box stays available for typing.
// * Text files are shown as text, with the same selection lookup and find.
// ============================================================================
// Devanagari text extracted from PDFs is often in *visual* glyph order: the short-i sign before its
// consonant (िपतरौ for पितरौ) and the reph after its syllable (धमर् for धर्म), with stray spaces inside
// words. These helpers convert between visual and logical order and compare text without spaces.
const Indic = {
  C: '[\\u0915-\\u0939\\u0958-\\u095F]\\u093C?',
  get cluster() { return `${this.C}(?:\\u094D${this.C})*`; },
  MATRA: '[\\u093E\\u0940-\\u094C\\u0962\\u0963]',   // dependent vowel signs except ि
  toLogical(s) {
    s = s.replace(new RegExp(`\\u093F(${this.cluster})`, 'g'), '$1\u093F');
    return s.replace(new RegExp(`(${this.cluster}${this.MATRA}*)\\u0930\\u094D`, 'g'), '\u0930\u094D$1');
  },
  toVisual(s) {
    s = s.replace(new RegExp(`(${this.cluster})\\u093F`, 'g'), '\u093F$1');
    return s.replace(new RegExp(`\\u0930\\u094D(${this.cluster}${this.MATRA}*)`, 'g'), '$1\u0930\u094D');
  },
  // Text without whitespace/zero-width characters, plus the original index of every kept character.
  compact(s) {
    let text = ''; const map = [];
    for (let i = 0; i < s.length; i++) {
      if (/[\s\u200B-\u200D\u00AD]/.test(s[i])) continue;
      text += s[i]; map.push(i);
    }
    return { text, map };
  },
  // A short-i sign that cannot be in logical position (at word start, or after a vowel) means visual order.
  looksVisual(s) {
    return (s.match(/(^|[\s\u0900-\u0914\u093E-\u094C\u0964\u0965।॥])\u093F/g) || []).length >= 2;
  },
  // Sorted, non-overlapping occurrences of any needle in hay (both already lower-cased/compacted).
  findAll(hay, needles) {
    const hits = [];
    needles.filter(Boolean).forEach(n => {
      let at = hay.indexOf(n);
      while (at >= 0) { hits.push([at, at + n.length]); at = hay.indexOf(n, at + 1); }
    });
    hits.sort((a, b) => a[0] - b[0] || b[1] - a[1]);
    const out = []; let end = -1;
    hits.forEach(h => { if (h[0] >= end) { out.push(h); end = h[1]; } });
    return out;
  }
};
window.Indic = Indic;

const Reader = {
  kind: null,            // 'pdf' | 'text' | null
  name: '',
  pdf: null,
  scale: 1.25,
  fitWidth: true,
  pageCount: 0,
  baseSize: null,        // unscaled size of page 1
  pages: [],             // [{el, rendered, renderTask, textItems}]
  textContentCache: {},  // pageNumber -> joined text
  hasText: false,
  visualOrder: false,    // PDF text stored in visual glyph order (repaired for lookup and find)
  text: '',              // full text of a text document
  find: { query: '', matches: [], index: -1 },
  observer: null,
  loadToken: 0,

  $(id) { return document.getElementById(id); },

  status(html, cls = '') {
    const el = this.$('readerTextStatus');
    el.innerHTML = html;
    el.className = 'badge reader-status ' + cls;
  },

  init() {
    if (window.pdfjsLib) pdfjsLib.GlobalWorkerOptions.workerSrc = '/vendor/pdfjs/pdf.worker.min.js';
    this.$('readerOpenBtn').addEventListener('click', () => this.pick());
    this.$('readerFileInput').addEventListener('change', () => {
      const f = this.$('readerFileInput').files[0];
      if (f) this.openFile(f);
    });
    this.$('readerZoomIn').addEventListener('click', () => this.setScale(this.scale * 1.15));
    this.$('readerZoomOut').addEventListener('click', () => this.setScale(this.scale / 1.15));
    this.$('readerFitBtn').addEventListener('click', () => { this.fitWidth = true; this.applyFit(); });
    this.$('readerPrevPage').addEventListener('click', () => this.goToPage(this.currentPage() - 1));
    this.$('readerNextPage').addEventListener('click', () => this.goToPage(this.currentPage() + 1));
    this.$('readerPageInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') this.goToPage(parseInt(this.$('readerPageInput').value, 10) || 1);
    });
    this.$('readerFindInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); e.shiftKey ? this.findStep(-1) : this.runFind(); }
    });
    this.$('readerFindNext').addEventListener('click', () => this.runFind());
    this.$('readerFindPrev').addEventListener('click', () => this.findStep(-1));
    this.$('readerLookupBtn').addEventListener('click', () => runStudioAssistantLookup(null, 'reader'));
    this.$('readerLookupInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') runStudioAssistantLookup(null, 'reader');
    });
    if (typeof PhoneticSearchHelper !== 'undefined') {
      PhoneticSearchHelper.attach(this.$('readerLookupInput'), () => runStudioAssistantLookup(null, 'reader'));
    }
    const doc = this.$('readerDoc');
    // Drag-select looks up the selection; double-click selects the whole word itself, because the
    // browser's word detection breaks inside words whose PDF text is in visual order (िपतरौ).
    doc.addEventListener('mouseup', (e) => { if (e.detail < 2) setTimeout(() => this.lookupSelection(), 0); });
    doc.addEventListener('dblclick', (e) => this.selectWordAt(e));
    doc.addEventListener('scroll', () => this.updatePageLabel());
    window.addEventListener('resize', () => { if (this.fitWidth && this.kind === 'pdf') this.applyFit(); });
    document.addEventListener('keydown', (e) => {
      const active = this.$('view-reader').classList.contains('active');
      if (!active || !(e.metaKey || e.ctrlKey)) return;
      const k = e.key.toLowerCase();
      if (k === 'o') { e.preventDefault(); this.pick(); }
      if (k === 'f' && this.hasText) { e.preventDefault(); this.$('readerFindInput').focus(); this.$('readerFindInput').select(); }
      if (k === '=' || k === '+') { e.preventDefault(); this.setScale(this.scale * 1.15); }
      if (k === '-') { e.preventDefault(); this.setScale(this.scale / 1.15); }
    });
    this.updateControls();
    runStudioAssistantLookup('', 'reader');
  },

  pick() {
    const input = this.$('readerFileInput');
    input.value = '';
    input.click();
  },

  // ---------------------------------------------------------------- opening
  async openFile(file) {
    const token = ++this.loadToken;
    this.reset();
    this.name = file.name;
    this.$('readerDocName').textContent = file.name;
    this.$('readerDocName').title = file.name;
    const isPdf = /\.pdf$/i.test(file.name) || file.type === 'application/pdf';
    try {
      if (isPdf) {
        if (!window.pdfjsLib) throw new Error('The PDF viewer could not be loaded.');
        this.status('Opening…');
        const data = new Uint8Array(await file.arrayBuffer());
        const pdf = await pdfjsLib.getDocument({ data, isEvalSupported: false }).promise;
        if (token !== this.loadToken) return;
        await this.showPdf(pdf, token);
      } else {
        this.showText(await file.text());
      }
    } catch (err) {
      this.kind = null;
      this.$('readerDoc').innerHTML = `<div class="reader-empty"><p>Could not open <strong>${escapeHtml(file.name)}</strong>.</p><p>${escapeHtml(String(err && err.message || err))}</p></div>`;
      this.status('Not opened', 'warn');
    }
    this.updateControls();
  },

  reset() {
    if (this.observer) this.observer.disconnect();
    this.pages.forEach(p => { if (p.renderTask) p.renderTask.cancel(); });
    if (this.pdf) this.pdf.destroy();
    Object.assign(this, { kind: null, pdf: null, pages: [], pageCount: 0, textContentCache: {}, hasText: false, visualOrder: false, text: '' });
    this.$('readerLookupHint').textContent = '';
    this.find = { query: '', matches: [], index: -1 };
    this.$('readerFindCount').textContent = '';
    this.$('readerDoc').innerHTML = '';
    this.$('readerDoc').scrollTop = 0;
  },

  showText(text) {
    this.kind = 'text';
    this.text = text.normalize('NFC');
    this.hasText = this.text.trim().length > 0;
    this.renderTextDoc();
    const lines = this.text.split('\n').length;
    this.status(`Text file · ${lines.toLocaleString()} lines · select a word to look it up`, 'ok');
  },

  renderTextDoc(highlight = null) {
    const doc = this.$('readerDoc');
    let html = '';
    if (highlight && highlight.matches.length) {
      let pos = 0;
      highlight.matches.forEach((m, i) => {
        html += escapeHtml(this.text.slice(pos, m.start));
        html += `<mark class="find-hit${i === highlight.index ? ' find-current' : ''}" data-i="${i}">${escapeHtml(this.text.slice(m.start, m.end))}</mark>`;
        pos = m.end;
      });
      html += escapeHtml(this.text.slice(pos));
    } else {
      html = escapeHtml(this.text);
    }
    doc.innerHTML = `<div class="reader-text indic" style="font-size:${Math.round(16 * this.scale / 1.25)}px">${html}</div>`;
    const cur = doc.querySelector('mark.find-current');
    if (cur) cur.scrollIntoView({ block: 'center' });
  },

  async showPdf(pdf, token) {
    this.kind = 'pdf';
    this.pdf = pdf;
    this.pageCount = pdf.numPages;
    const first = await pdf.getPage(1);
    const vp = first.getViewport({ scale: 1 });
    this.baseSize = { w: vp.width, h: vp.height };
    if (this.fitWidth) this.scale = this.fitScale();
    const doc = this.$('readerDoc');
    for (let i = 1; i <= this.pageCount; i++) {
      const el = document.createElement('div');
      el.className = 'pdf-page';
      el.dataset.page = String(i);
      el.innerHTML = `<div class="pdf-page-label">${i}</div>`;
      doc.appendChild(el);
      this.pages[i] = { el, rendered: false, renderTask: null, size: null };
    }
    this.sizePages();
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(en => { if (en.isIntersecting) this.renderPage(parseInt(en.target.dataset.page, 10)); });
    }, { root: doc, rootMargin: '800px 0px' });
    this.pages.forEach(p => p && this.observer.observe(p.el));
    this.status(`PDF · ${this.pageCount} pages · checking for text…`);
    await this.detectText(token);
  },

  // Does the PDF have a usable text layer? Look at up to the first 8 pages.
  async detectText(token) {
    let letters = 0, sample = '';
    const n = Math.min(this.pageCount, 8);
    for (let i = 1; i <= n; i++) {
      const t = await this.pageText(i);
      if (token !== this.loadToken) return;
      letters += (t.match(/\p{L}/gu) || []).length;
      sample += t + ' ';
      if (letters > 2000) break;
    }
    this.hasText = letters > 40;
    this.visualOrder = this.hasText && Indic.looksVisual(sample);
    if (this.hasText) {
      const note = this.visualOrder ? ' (Devanagari stored in visual order; repaired for lookup and find)' : '';
      this.status(`PDF · ${this.pageCount} pages · text layer found: select a word to look it up, or use Find${note}`, 'ok');
    } else {
      this.status(`PDF · ${this.pageCount} pages · no text layer (scanned): type words in the lookup box`, 'warn');
    }
    this.updateControls();
  },

  async pageText(i) {
    if (this.textContentCache[i] !== undefined) return this.textContentCache[i];
    const page = await this.pdf.getPage(i);
    const tc = await page.getTextContent();
    const joined = tc.items.map(it => it.str || '').join('').normalize('NFC');
    this.textContentCache[i] = joined;
    return joined;
  },

  // ---------------------------------------------------------------- PDF pages
  fitScale() {
    const w = this.$('readerDoc').clientWidth - 48;
    return this.baseSize ? Math.max(0.3, Math.min(4, w / this.baseSize.w)) : 1.25;
  },
  applyFit() {
    if (this.kind === 'pdf') { const f = this.fitScale(); if (Math.abs(f - this.scale) > 0.005) this.setScale(f, true); }
    else if (this.kind === 'text') { this.scale = 1.25; this.renderTextDoc(this.find.matches.length ? this.find : null); this.updateControls(); }
  },
  setScale(s, keepFit = false) {
    if (!keepFit) this.fitWidth = false;
    s = Math.max(0.3, Math.min(4, s));
    if (this.kind === 'text') { this.scale = s; this.renderTextDoc(this.find.matches.length ? this.find : null); this.updateControls(); return; }
    if (this.kind !== 'pdf') return;
    const page = this.currentPage();
    this.scale = s;
    this.pages.forEach(p => {
      if (!p) return;
      if (p.renderTask) p.renderTask.cancel();
      p.rendered = false;
      p.el.querySelectorAll('canvas, .textLayer').forEach(n => n.remove());
    });
    this.sizePages();
    this.goToPage(page, false);
    // re-render what is visible now
    this.pages.forEach(p => { if (p) { this.observer.unobserve(p.el); this.observer.observe(p.el); } });
    this.updateControls();
  },
  sizePages() {
    this.pages.forEach(p => {
      if (!p) return;
      const size = p.size || this.baseSize;
      p.el.style.width = Math.floor(size.w * this.scale) + 'px';
      p.el.style.height = Math.floor(size.h * this.scale) + 'px';
      p.el.style.setProperty('--scale-factor', String(this.scale));
    });
  },

  async renderPage(i) {
    const p = this.pages[i];
    if (!p || p.rendered || p.renderTask) return;
    const token = this.loadToken;
    const scale = this.scale;
    const page = await this.pdf.getPage(i);
    if (token !== this.loadToken || scale !== this.scale) return;
    const vp = page.getViewport({ scale });
    p.size = { w: vp.width / scale, h: vp.height / scale };
    p.el.style.width = Math.floor(vp.width) + 'px';
    p.el.style.height = Math.floor(vp.height) + 'px';
    const ratio = window.devicePixelRatio || 1;
    const canvas = document.createElement('canvas');
    canvas.width = Math.floor(vp.width * ratio);
    canvas.height = Math.floor(vp.height * ratio);
    canvas.style.width = Math.floor(vp.width) + 'px';
    canvas.style.height = Math.floor(vp.height) + 'px';
    p.el.appendChild(canvas);
    const ctx = canvas.getContext('2d');
    p.renderTask = page.render({ canvasContext: ctx, viewport: vp, transform: ratio !== 1 ? [ratio, 0, 0, ratio, 0, 0] : null });
    try {
      await p.renderTask.promise;
    } catch (e) {
      p.renderTask = null; canvas.remove(); return; // cancelled (zoom changed)
    }
    p.renderTask = null;
    if (token !== this.loadToken || scale !== this.scale) { canvas.remove(); return; }
    // Text layer for selection, lookup and find
    const tc = await page.getTextContent();
    const layer = document.createElement('div');
    layer.className = 'textLayer';
    p.el.appendChild(layer);
    const textDivs = [];
    const textContentItemsStr = [];
    try {
      await pdfjsLib.renderTextLayer({ textContentSource: tc, container: layer, viewport: vp, textDivs, textContentItemsStr }).promise;
    } catch (e) { /* page without text */ }
    p.textDivs = textDivs;
    p.textStrs = textContentItemsStr;
    p.rendered = true;
    this.highlightPage(i);
    this.trimRendered(i);
  },

  // Keep memory bounded on long documents: release canvases far from the current page.
  trimRendered() {
    const cur = this.currentPage();
    const rendered = this.pages.filter(p => p && p.rendered);
    if (rendered.length <= 14) return;
    rendered.forEach(p => {
      const n = parseInt(p.el.dataset.page, 10);
      if (Math.abs(n - cur) > 6) {
        p.el.querySelectorAll('canvas, .textLayer').forEach(x => x.remove());
        p.rendered = false;
        this.observer.unobserve(p.el); this.observer.observe(p.el);
      }
    });
  },

  currentPage() {
    if (this.kind !== 'pdf') return 1;
    const doc = this.$('readerDoc');
    const mid = doc.scrollTop + doc.clientHeight / 3;
    let cur = 1;
    for (let i = 1; i <= this.pageCount; i++) {
      if (this.pages[i].el.offsetTop <= mid) cur = i; else break;
    }
    return cur;
  },
  goToPage(n, smooth = true) {
    if (this.kind !== 'pdf') return;
    n = Math.max(1, Math.min(this.pageCount, n));
    const doc = this.$('readerDoc');
    doc.scrollTo({ top: this.pages[n].el.offsetTop - 12, behavior: smooth ? 'smooth' : 'auto' });
    this.$('readerPageInput').value = String(n);
  },
  updatePageLabel() {
    if (this.kind === 'pdf') this.$('readerPageInput').value = String(this.currentPage());
  },

  updateControls() {
    const pdf = this.kind === 'pdf';
    ['readerPrevPage', 'readerNextPage', 'readerPageInput'].forEach(id => { this.$(id).disabled = !pdf; });
    ['readerZoomIn', 'readerZoomOut', 'readerFitBtn'].forEach(id => { this.$(id).disabled = !this.kind; });
    this.$('readerPageCount').textContent = pdf ? String(this.pageCount) : '–';
    if (pdf) this.$('readerPageInput').value = String(this.currentPage());
    this.$('readerZoomLabel').textContent = this.kind ? Math.round(this.scale * 100 / (this.kind === 'pdf' ? 1 : 1.25)) + '%' : '';
    const findOk = this.hasText;
    ['readerFindInput', 'readerFindNext', 'readerFindPrev'].forEach(id => { this.$(id).disabled = !findOk; });
    this.$('readerFindInput').placeholder = !this.kind ? 'Find in document'
      : (findOk ? 'Find in document (Enter)' : 'No searchable text in this document');
  },

  // ---------------------------------------------------------------- lookup
  selectWordAt(e) {
    const range = document.caretRangeFromPoint ? document.caretRangeFromPoint(e.clientX, e.clientY) : null;
    const node = range && range.startContainer;
    if (!node || node.nodeType !== Node.TEXT_NODE || !this.$('readerDoc').contains(node)) { this.lookupSelection(); return; }
    const text = node.nodeValue;
    const stop = /[\s।॥|,.;:!?()\[\]{}"'“”‘’\-–—]/;
    let a = Math.min(range.startOffset, text.length), b = a;
    if (a > 0 && (a === text.length || stop.test(text[a]))) a--, b--; // clicked just after a word
    while (a > 0 && !stop.test(text[a - 1])) a--;
    while (b < text.length && !stop.test(text[b])) b++;
    if (a >= b) return;
    let startNode = node, startOff = a, endNode = node, endOff = b;
    // In a PDF text layer a word is often split over several pieces, sometimes with stray spaces
    // that sit at (almost) zero distance; real word gaps have visible width. Continue the word
    // into neighbouring pieces on the same line until a real gap or punctuation.
    const span = node.parentElement;
    if (span && span.parentElement && span.parentElement.classList.contains('textLayer')) {
      const top = span.getBoundingClientRect().top, h = span.getBoundingClientRect().height || 1;
      const sameLine = (sp) => Math.abs(sp.getBoundingClientRect().top - top) < h * 0.5;
      const textOf = (sp) => (sp && sp.firstChild && sp.firstChild.nodeType === Node.TEXT_NODE) ? sp.firstChild : null;
      const strayGap = (sp) => {
        const prev = sp.previousElementSibling, next = sp.nextElementSibling;
        if (!prev || !next || !textOf(prev) || !textOf(next)) return false;
        return next.getBoundingClientRect().left - prev.getBoundingClientRect().right <= 1;
      };
      if (a === 0) {
        for (let sp = span.previousElementSibling; sp && sameLine(sp); sp = sp.previousElementSibling) {
          const tn = textOf(sp); if (!tn) break;
          const t = tn.nodeValue;
          if (/^\s+$/.test(t)) { if (strayGap(sp)) continue; break; }
          let k = t.length; while (k > 0 && !stop.test(t[k - 1])) k--;
          if (k === t.length) break;
          startNode = tn; startOff = k;
          if (k > 0) break;
        }
      }
      if (b === text.length) {
        for (let sp = span.nextElementSibling; sp && sameLine(sp); sp = sp.nextElementSibling) {
          const tn = textOf(sp); if (!tn) break;
          const t = tn.nodeValue;
          if (/^\s+$/.test(t)) { if (strayGap(sp)) continue; break; }
          let k = 0; while (k < t.length && !stop.test(t[k])) k++;
          if (k === 0) break;
          endNode = tn; endOff = k;
          if (k < t.length) break;
        }
      }
    }
    const r = document.createRange();
    r.setStart(startNode, startOff); r.setEnd(endNode, endOff);
    const sel = window.getSelection();
    sel.removeAllRanges(); sel.addRange(r);
    this.lookupSelection();
  },

  async lookupSelection() {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;
    const doc = this.$('readerDoc');
    if (!doc.contains(sel.anchorNode)) return;
    const text = sel.toString().replace(/\s+/g, ' ').trim();
    if (!text || text.length > 60) return;
    // PDFs often break words with spaces; join up to three pieces, otherwise take the first word.
    const raw = (text.split(' ').length > 3 ? text.split(' ')[0] : text.replace(/\s+/g, ''))
      .replace(/[।॥|,.;:!?()\[\]"'“”‘’]/g, '').normalize('NFC');
    if (!raw) return;
    const hint = this.$('readerLookupHint');
    let word = raw;
    const repaired = Indic.toLogical(raw);
    if (this.kind === 'pdf' && repaired !== raw) {
      if (this.visualOrder || !(await this.hasMatches(raw))) word = repaired;
    }
    hint.textContent = word !== raw ? `From the PDF: “${raw}” → looked up as “${word}” (visual glyph order repaired)` : '';
    runStudioAssistantLookup(word, 'reader');
  },
  async hasMatches(q) {
    const d = await apiGet(`/api/dictionary/search?q=${encodeURIComponent(q)}&dicts=all&match=prefix&scope=headword&limit=1`);
    const gm = d.grammar_matches || {};
    return (d.entries || []).length > 0 || (gm.dhatus || []).length > 0 || (gm.shabdas || []).length > 0;
  },

  // ---------------------------------------------------------------- find
  needles(q) {
    const base = Indic.compact(q.normalize('NFC')).text.toLowerCase();
    return [...new Set([base, Indic.toVisual(base)])];
  },
  async runFind() {
    const q = this.$('readerFindInput').value.normalize('NFC').trim();
    if (!q || !this.hasText) return;
    if (q === this.find.query && this.find.matches.length) return this.findStep(1);
    this.find = { query: q, matches: [], index: -1 };
    const needles = this.needles(q);
    if (this.kind === 'text') {
      const c = Indic.compact(this.text);
      Indic.findAll(c.text.toLowerCase(), needles).forEach(([a, b]) => {
        this.find.matches.push({ start: c.map[a], end: c.map[b - 1] + 1 });
      });
    } else {
      for (let i = 1; i <= this.pageCount; i++) {
        if (i % 10 === 0) this.$('readerFindCount').textContent = `searching ${i}/${this.pageCount}…`;
        const hits = Indic.findAll(Indic.compact(await this.pageText(i)).text.toLowerCase(), needles);
        hits.forEach((h, k) => this.find.matches.push({ page: i, k }));
        if (this.find.query !== q) return; // a newer search started
      }
    }
    if (!this.find.matches.length) {
      this.$('readerFindCount').textContent = 'not found';
      if (this.kind === 'text') this.renderTextDoc();
      this.pages.forEach((p, i) => p && p.rendered && this.highlightPage(i));
      return;
    }
    this.find.index = -1;
    this.findStep(1);
  },
  findStep(dir) {
    const f = this.find;
    if (!f.matches.length) return;
    f.index = (f.index + dir + f.matches.length) % f.matches.length;
    this.$('readerFindCount').textContent = `${f.index + 1} / ${f.matches.length}`;
    if (this.kind === 'text') { this.renderTextDoc(f); return; }
    const m = f.matches[f.index];
    this.pages.forEach((p, i) => p && p.rendered && this.highlightPage(i));
    if (this.pages[m.page].rendered) this.scrollToCurrentHit(m.page);
    else { this.goToPage(m.page, false); this.renderPage(m.page); }
  },
  // Marks the text spans of a rendered PDF page that contain matches of the current search.
  highlightPage(i) {
    const p = this.pages[i];
    if (!p || !p.textDivs) return;
    p.textDivs.forEach(d => d.classList.remove('find-hit', 'find-current'));
    if (!this.find.query) return;
    const strs = p.textStrs.map(x => (x || '').normalize('NFC'));
    const starts = []; let acc = 0;
    strs.forEach(x => { starts.push(acc); acc += x.length; });
    const c = Indic.compact(strs.join(''));
    const divAt = (pos) => { let lo = 0; for (let j = 0; j < starts.length; j++) { if (starts[j] <= pos) lo = j; else break; } return lo; };
    const cur = this.find.matches[this.find.index];
    Indic.findAll(c.text.toLowerCase(), this.needles(this.find.query)).forEach(([a0, b0], k) => {
      const a = divAt(c.map[a0]), b = divAt(c.map[b0 - 1]);
      for (let j = a; j <= b; j++) {
        if (!p.textDivs[j]) continue;
        p.textDivs[j].classList.add('find-hit');
        if (cur && cur.page === i && cur.k === k) p.textDivs[j].classList.add('find-current');
      }
    });
    if (cur && cur.page === i) this.scrollToCurrentHit(i);
  },
  scrollToCurrentHit(i) {
    const el = this.pages[i].el.querySelector('.find-current');
    if (el) el.scrollIntoView({ block: 'center' });
  }
};

document.addEventListener('DOMContentLoaded', () => Reader.init());
window.Reader = Reader;
