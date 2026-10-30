// ============================================================================
// Writing Studio documents are ordinary text files on your computer.
// New / Open… / Save / Save As… (⌘N ⌘O ⌘S ⇧⌘S). In the macOS app the Open and Save panels are
// native (window.webkit.messageHandlers.sanskritFiles); in a plain browser, Open uses a file
// picker and Save downloads the file. Notes are saved beside the document as "<name>.notes.txt".
// Unsaved work is kept as a draft and restored at the next launch.
// ============================================================================
const DocFile = {
  path: null,
  name: 'Untitled.txt',
  dirty: false,
  draftKey: 'studioDraft.v1',
  draftTimer: null,

  native() {
    return window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.sanskritFiles;
  },
  async call(msg) {
    try { return (await this.native().postMessage(msg)) || { ok: false }; }
    catch (e) { return { ok: false, error: String(e && e.message || e) }; }
  },
  editor() { return document.getElementById('sanskritEditor'); },
  notes() { return document.getElementById('compNotesInput'); },

  render() {
    const label = document.getElementById('docNameLabel');
    if (label) {
      label.textContent = (this.dirty ? '● ' : '') + this.name;
      label.title = this.path ? this.path : 'Not saved to a file yet';
      label.classList.toggle('dirty', this.dirty);
    }
  },

  load({ path = null, name = 'Untitled.txt', text = '', notes = '', dirty = false }) {
    this.path = path;
    this.name = name;
    this.editor().value = text;
    this.notes().value = notes;
    this.dirty = dirty;
    if (typeof EditorIME !== 'undefined') EditorIME.reset();
    if (typeof updateEditorLiveChandas === 'function') updateEditorLiveChandas();
    this.render();
    this.saveDraftSoon();
  },

  markDirty() {
    if (!this.dirty) { this.dirty = true; this.render(); }
    this.saveDraftSoon();
  },

  confirmDiscard() {
    return !this.dirty || window.confirm(`“${this.name}” has unsaved changes. Discard them?`);
  },

  newDoc() {
    if (!this.confirmDiscard()) return;
    this.load({});
    this.editor().focus();
  },

  async open() {
    if (!this.confirmDiscard()) return;
    if (this.native()) {
      const r = await this.call({ action: 'open' });
      if (r.ok) this.load(r);
      else if (r.error) window.alert(r.error);
      return;
    }
    const input = document.getElementById('docFileInput');
    input.value = '';
    input.onchange = async () => {
      const f = input.files && input.files[0];
      if (!f) return;
      this.load({ path: null, name: f.name, text: await f.text(), notes: '' });
    };
    input.click();
  },

  payload() {
    return { text: this.editor().value, notes: this.notes().value, name: this.name };
  },

  async save() {
    if (!this.native()) return this.download();
    if (!this.path) return this.saveAs();
    const r = await this.call({ action: 'save', path: this.path, ...this.payload() });
    if (r.ok) this.saved(r);
    else if (r.error) { window.alert(r.error); }
  },

  async saveAs() {
    if (!this.native()) return this.download();
    const r = await this.call({ action: 'saveAs', ...this.payload() });
    if (r.ok) this.saved(r);
    else if (r.error) window.alert(r.error);
  },

  saved(r) {
    this.path = r.path;
    this.name = r.name;
    this.dirty = false;
    this.render();
    this.saveDraftSoon();
    const btn = document.getElementById('saveDocBtn');
    if (btn) { const t = btn.textContent; btn.textContent = '✓ Saved'; setTimeout(() => { btn.textContent = t; }, 1300); }
  },

  // Browser fallback: download the text (and notes, if any).
  download() {
    const dl = (name, text) => {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain;charset=utf-8' }));
      a.download = name;
      a.click();
    };
    dl(this.name, this.editor().value);
    if (this.notes().value) dl(this.name.replace(/\.[^.]*$/, '') + '.notes.txt', this.notes().value);
    this.dirty = false;
    this.render();
  },

  saveDraftSoon() {
    clearTimeout(this.draftTimer);
    this.draftTimer = setTimeout(() => {
      try {
        localStorage.setItem(this.draftKey, JSON.stringify({
          path: this.path, name: this.name, dirty: this.dirty,
          text: this.dirty ? this.editor().value : '', notes: this.dirty ? this.notes().value : ''
        }));
      } catch (e) { /* storage unavailable */ }
    }, 400);
  },

  // At launch: unsaved work first, otherwise the file that was open last time.
  async restore() {
    let draft = null;
    try { draft = JSON.parse(localStorage.getItem(this.draftKey) || 'null'); } catch (e) { draft = null; }
    let last = null;
    if (this.native()) {
      const r = await this.call({ action: 'restoreLast' });
      if (r.ok) last = r;
    }
    if (draft && draft.dirty) {
      const samePath = last && draft.path === last.path;
      this.load({ path: samePath ? last.path : null, name: draft.name || 'Untitled.txt',
                  text: draft.text || '', notes: draft.notes || '', dirty: true });
    } else if (last) {
      this.load(last);
    } else {
      this.load({});
    }
  },

  init() {
    // Tooltips are written with Mac keys; show Ctrl / Shift on Windows and Linux.
    if (!/Mac|iPhone|iPad/.test(navigator.platform)) {
      document.querySelectorAll('[title*="⌘"]').forEach(el => {
        el.title = el.title.replace(/⇧⌘/g, 'Ctrl+Shift+').replace(/⌘/g, 'Ctrl+').replace(/⇧/g, 'Shift+');
      });
    }
    const on = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', () => fn.call(this)); };
    on('newDocBtn', this.newDoc);
    on('openDocBtn', this.open);
    on('saveDocBtn', this.save);
    on('saveAsDocBtn', this.saveAs);
    this.editor().addEventListener('input', () => this.markDirty());
    this.notes().addEventListener('input', () => this.markDirty());
    document.addEventListener('keydown', (e) => {
      if (!(e.metaKey || e.ctrlKey)) return;
      const studio = document.getElementById('view-studio').classList.contains('active');
      const k = e.key.toLowerCase();
      if (k === 's') { e.preventDefault(); e.shiftKey ? this.saveAs() : this.save(); }
      else if (k === 'o' && studio) { e.preventDefault(); this.open(); }
      else if (k === 'n' && studio) { e.preventDefault(); this.newDoc(); }
    });
  }
};
window.DocFile = DocFile;
