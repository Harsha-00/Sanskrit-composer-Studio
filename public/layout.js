// ============================================================================
// Resizable layout: drag handles between the sidebar, editor, lookup panel, notes, chandas
// footer, list/detail panes and the key-map drawer. Sizes are remembered in this browser.
// Double-click a handle to reset it; "Reset layout" in the sidebar resets everything.
// ============================================================================
const Layout = {
  key: 'sanskritStudioLayout.v1',
  state: {},

  load() {
    try { this.state = JSON.parse(localStorage.getItem(this.key) || '{}') || {}; } catch (e) { this.state = {}; }
  },
  save() {
    try { localStorage.setItem(this.key, JSON.stringify(this.state)); } catch (e) { /* storage unavailable */ }
  },

  apply() {
    const root = document.documentElement.style;
    const s = this.state;
    const set = (name, v) => (v === undefined || v === null) ? root.removeProperty(name) : root.setProperty(name, v);
    set('--sidebar-w', s.sidebar !== undefined ? s.sidebar + 'px' : undefined);
    document.body.classList.toggle('sidebar-collapsed', s.sidebar === 0);
    set('--studio-left', s.studioLeft !== undefined ? s.studioLeft + '%' : undefined);
    set('--notes-h', s.notes !== undefined ? s.notes + 'px' : undefined);
    set('--meter-h', s.meter !== undefined ? s.meter + 'px' : undefined);
    document.body.classList.toggle('meter-sized', s.meter !== undefined);
    set('--drawer-h', s.drawer !== undefined ? s.drawer + 'px' : undefined);
    set('--reader-right', s.readerRight !== undefined ? s.readerRight + 'px' : undefined);
    if (window.Reader && Reader.fitWidth && Reader.kind === 'pdf') { clearTimeout(this.fitTimer); this.fitTimer = setTimeout(() => Reader.applyFit(), 150); }
    document.body.classList.toggle('drawer-sized', s.drawer !== undefined);
    document.querySelectorAll('.master-detail-layout').forEach(el => {
      const v = (s.master || {})[el.dataset.layoutId];
      if (v === undefined) el.style.removeProperty('--master-w'); else el.style.setProperty('--master-w', v + 'px');
    });
  },

  reset(part) {
    if (part) {
      if (part.startsWith('master:')) { if (this.state.master) delete this.state.master[part.slice(7)]; }
      else delete this.state[part];
    } else {
      this.state = {};
    }
    this.save();
    this.apply();
  },

  // Generic drag handle. axis 'x' or 'y'; onMove(delta, startValue) returns nothing.
  handle(el, axis, part, getStart, onMove) {
    el.classList.add('splitter', axis === 'x' ? 'splitter-x' : 'splitter-y');
    el.title = 'Drag to resize · double-click to reset';
    el.addEventListener('pointerdown', (ev) => {
      if (ev.button !== 0) return;
      ev.preventDefault();
      const start = getStart();
      const origin = axis === 'x' ? ev.clientX : ev.clientY;
      el.setPointerCapture(ev.pointerId);
      document.body.classList.add(axis === 'x' ? 'resizing-x' : 'resizing-y');
      el.classList.add('dragging');
      const move = (e) => {
        onMove((axis === 'x' ? e.clientX : e.clientY) - origin, start);
        this.apply();
      };
      const up = () => {
        el.removeEventListener('pointermove', move);
        el.removeEventListener('pointerup', up);
        el.removeEventListener('pointercancel', up);
        document.body.classList.remove('resizing-x', 'resizing-y');
        el.classList.remove('dragging');
        this.save();
      };
      el.addEventListener('pointermove', move);
      el.addEventListener('pointerup', up);
      el.addEventListener('pointercancel', up);
    });
    el.addEventListener('dblclick', () => this.reset(part));
  },

  clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); },

  init() {
    this.load();
    const make = () => document.createElement('div');

    // 1. Sidebar | main stage (drag far left to hide the sidebar, drag back to show it)
    const shell = document.querySelector('.app-shell');
    const sidebar = document.querySelector('.app-sidebar');
    if (shell && sidebar) {
      const h = make();
      sidebar.after(h);
      this.handle(h, 'x', 'sidebar', () => sidebar.getBoundingClientRect().width, (d, start) => {
        const w = start + d;
        this.state.sidebar = w < 110 ? 0 : Math.round(this.clamp(w, 170, 480));
      });
    }

    // 2. Writing Studio: editor | lookup panel (stored as a percentage of the width)
    const split = document.querySelector('.studio-split-layout');
    const editorCol = document.querySelector('.studio-editor-col');
    if (split && editorCol) {
      const h = make();
      editorCol.after(h);
      this.handle(h, 'x', 'studioLeft', () => editorCol.getBoundingClientRect().width, (d, start) => {
        const total = split.getBoundingClientRect().width;
        const w = this.clamp(start + d, 320, total - 260);
        this.state.studioLeft = Math.round((w / total) * 1000) / 10;
      });
    }

    // 3. Editor | notes, and notes | chandas footer (vertical)
    const notes = document.getElementById('compNotesInput');
    const footer = document.querySelector('.studio-meter-footer');
    // The writing area itself always keeps at least MIN_EDITOR px.
    const editor = document.getElementById('sanskritEditor');
    const MIN_EDITOR = 120;
    let editorAtStart = 0;
    if (notes && editorCol && editor) {
      const h = make();
      notes.before(h);
      this.handle(h, 'y', 'notes', () => { editorAtStart = editor.getBoundingClientRect().height; return notes.getBoundingClientRect().height; }, (d, start) => {
        const max = start + Math.max(0, editorAtStart - MIN_EDITOR);
        this.state.notes = Math.round(this.clamp(start - d, 28, max));
      });
    }
    if (footer && editorCol && editor) {
      const h = make();
      footer.before(h);
      this.handle(h, 'y', 'meter', () => { editorAtStart = editor.getBoundingClientRect().height; return footer.getBoundingClientRect().height; }, (d, start) => {
        const max = start + Math.max(0, editorAtStart - MIN_EDITOR);
        this.state.meter = Math.round(this.clamp(start - d, 44, max));
      });
    }

    // 4. List | detail in Verbs, Nouns and Sūtras
    document.querySelectorAll('.master-detail-layout').forEach(layout => {
      const view = layout.closest('.stage-view');
      layout.dataset.layoutId = view ? view.id : 'layout';
      const list = layout.querySelector('.master-list');
      if (!list) return;
      const h = make();
      list.after(h);
      const id = layout.dataset.layoutId;
      this.handle(h, 'x', 'master:' + id, () => list.getBoundingClientRect().width, (d, start) => {
        const total = layout.getBoundingClientRect().width;
        this.state.master = this.state.master || {};
        this.state.master[id] = Math.round(this.clamp(start + d, 180, total - 320));
      });
    });

    // 4b. Reader: document | lookup panel (the lookup panel width is stored)
    const rsplit = document.querySelector('.reader-split-layout');
    const rdoc = document.getElementById('readerDoc');
    const rlook = document.querySelector('.reader-lookup-col');
    if (rsplit && rdoc && rlook) {
      const h = make();
      rdoc.after(h);
      this.handle(h, 'x', 'readerRight', () => rlook.getBoundingClientRect().width, (d, start) => {
        const total = rsplit.getBoundingClientRect().width;
        this.state.readerRight = Math.round(this.clamp(start - d, 260, total - 320));
      });
    }

    // 5. Key-map drawer height (handle on its top edge)
    const drawer = document.getElementById('fontHelpDrawer');
    if (drawer) {
      const h = make();
      h.classList.add('drawer-grip');
      drawer.prepend(h);
      this.handle(h, 'y', 'drawer', () => drawer.getBoundingClientRect().height, (d, start) => {
        this.state.drawer = Math.round(this.clamp(start - d, 120, window.innerHeight * 0.85));
      });
    }

    // 6. "Reset layout" next to the theme button
    const themeBtn = document.getElementById('toggleThemeBtn');
    if (themeBtn) {
      const b = document.createElement('button');
      b.className = 'btn btn-sm';
      b.id = 'resetLayoutBtn';
      b.title = 'Restore the default sizes of all panels';
      b.textContent = '↔ Reset layout';
      b.addEventListener('click', () => this.reset());
      themeBtn.parentElement.after(Object.assign(document.createElement('div'), { className: 'layout-reset-row' }));
      themeBtn.parentElement.nextElementSibling.appendChild(b);
    }

    this.apply();
  }
};

document.addEventListener('DOMContentLoaded', () => Layout.init());
window.Layout = Layout;
