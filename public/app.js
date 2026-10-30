// ============================================================================
// संस्कृत-रचना-मञ्जूषा — Offline Sanskrit Composer Studio & Reference Hub
// ============================================================================

const AppState = {
  script: 'deva',         // 'deva' | 'telu' | 'iast' | 'trilingual'
  scheme: 'itrans',       // 'itrans' | 'rts' | 'hk' | 'slp1' | 'velthuis' | 'wx' | 'direct'
  searchInPlaceIME: false,// Optional direct in-place conversion inside search inputs
  activeInputEl: null,
  stats: null,
  dictionaries: [],
  compositions: [],
  currentCompId: null,
  abhyasModules: [],
  activeAbhyasView: 'interactive-tools',
  currentDhatuDetail: null,
  activeDhatuSubTab: 'kartari'
};

// The original websites (also served by /api/config). Links open them in a new tab.
const AppConfig = {
  ashtadhyayi_base: 'https://ashtadhyayi.com',
  andhrabharati_base: 'https://www.andhrabharati.com/dictionary/sanskrit/'
};

// Opens a page of ashtadhyayi.com or andhrabharati.com.
// site: 'ashtadhyayi' (path like '/sutraani/1.1.1') or 'andhrabharati' (path like 'FontHelp').
window.openSource = function (site, path = '') {
  const base = site === 'ashtadhyayi' ? AppConfig.ashtadhyayi_base : AppConfig.andhrabharati_base;
  window.open(base.replace(/\/$/, '') + (path.startsWith('/') ? '' : '/') + path, '_blank', 'noopener');
};

function dictionaryTotals() {
  const c = (AppState.stats && AppState.stats.counts) || {};
  return {
    dictionaries: Number(c.dictionary_count || (AppState.dictionaries || []).length || 0),
    entries: Number(c.dict_entries || 0)
  };
}

// Renders a dictionary entry body. Cologne entries arrive as HTML (definition_html) with Sanskrit
// as IAST (.mw-sa) + Devanagari ([lipi]) pairs; other entries are plain text.
function renderDefinition(e, opts = {}) {
  const style = opts.size ? ` style="font-size:${opts.size}px;"` : '';
  if (e.definition_html) {
    const long = opts.clamp && e.definition_html.length > 700;
    return `<div class="dict-def-body cdsl-entry${long ? ' def-clamp' : ''}"${style}>${e.definition_html}</div>` +
      (long ? `<button class="btn btn-sm def-expand" onclick="toggleDefinitionClamp(this)">Show full entry ▾</button>` : '');
  }
  let text = e.definition || '';
  if (AppState.script === 'telu' && e.dict_code !== 'ae' && e.definition_te) {
    text = `${text}\n\n【తెలుగు లిప్యంతరీకరణము】: ${e.definition_te}`;
  }
  if (opts.clamp && text.length > 420) text = text.slice(0, 420) + '...';
  return `<div class="dict-def-body"${style}>${escapeHtml(text)}</div>`;
}

window.toggleDefinitionClamp = function (btn) {
  const body = btn.previousElementSibling;
  body.classList.toggle('def-clamp');
  btn.textContent = body.classList.contains('def-clamp') ? 'Show full entry ▾' : 'Show less ▴';
};

// Shows the Sanskrit inside rendered Cologne entries in the selected script.
function applyScriptToDefinitions(root) {
  if (!root) return;
  const s = AppState.script;
  root.querySelectorAll('.cdsl-entry .mw-sa').forEach(el => {
    el.style.display = (s === 'iast' || s === 'trilingual') ? 'inline' : 'none';
  });
  root.querySelectorAll('.cdsl-entry [lipi]').forEach(el => {
    const twin = el.previousElementSibling && el.previousElementSibling.classList.contains('mw-sa');
    if (s === 'iast' && twin) { el.style.display = 'none'; return; }
    el.style.display = '';
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) {
      if (n.__deva === undefined) n.__deva = n.nodeValue;
      n.nodeValue = s === 'telu' ? TranslitEngine.devToTelugu(n.__deva)
        : (s === 'iast' ? TranslitEngine.devToIast(n.__deva) : n.__deva);
    }
  });
}

async function apiGet(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) return {};
    return await res.json();
  } catch (err) {
    console.error('GET error:', url, err);
    return {};
  }
}

async function apiPost(url, payload) {
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!res.ok) return {};
    return await res.json();
  } catch (err) {
    console.error('POST error:', url, err);
    return {};
  }
}

// ============================================================================
// 1. MULTI-SCRIPT & PHONETIC TRANSLITERATION ENGINE
// ============================================================================

const TranslitEngine = {
  devToTelugu(str) {
    if (!str) return '';
    let out = '';
    for (let i = 0; i < str.length; i++) {
      const cp = str.charCodeAt(i);
      if (cp >= 0x0900 && cp <= 0x097F) {
        let offset = cp - 0x0900;
        if (offset === 14 || offset === 18 || offset === 70 || offset === 74) offset += 1;
        if (cp === 0x0964) out += '।';
        else if (cp === 0x0965) out += '॥';
        else if (cp === 0x0950) out += 'ఓం';
        else if (cp === 0x0901) out += '\u0C01';
        else out += String.fromCharCode(0x0C00 + offset);
      } else {
        out += str[i];
      }
    }
    return out;
  },

  teluguToDev(str) {
    if (!str) return '';
    let out = '';
    for (let i = 0; i < str.length; i++) {
      const cp = str.charCodeAt(i);
      if (cp >= 0x0C00 && cp <= 0x0C7F) {
        let offset = cp - 0x0C00;
        if (offset === 14 || offset === 18 || offset === 70 || offset === 74) offset -= 1;
        out += String.fromCharCode(0x0900 + offset);
      } else {
        out += str[i];
      }
    }
    return out;
  },

  devToIast(str) {
    if (!str) return '';
    const vowels = { 'अ':'a','आ':'ā','इ':'i','ई':'ī','उ':'u','ऊ':'ū','ऋ':'ṛ','ॠ':'ṝ','ऌ':'ḷ','ॡ':'ḹ','ए':'e','ऐ':'ai','ओ':'o','औ':'au' };
    const matras = { 'ा':'ā','ि':'i','ी':'ī','ु':'u','ू':'ū','ृ':'ṛ','ॄ':'ṝ','ॢ':'ḷ','ॣ':'ḹ','े':'e','ै':'ai','ो':'o','ौ':'au' };
    const cons = {
      'क':'k','ख':'kh','ग':'g','घ':'gh','ङ':'ṅ',
      'च':'c','छ':'ch','ज':'j','झ':'jh','ञ':'ñ',
      'ट':'ṭ','ठ':'ṭh','ड':'ḍ','ढ':'ḍh','ण':'ṇ',
      'त':'t','थ':'th','द':'d','ध':'dh','न':'n',
      'प':'p','फ':'ph','ब':'b','भ':'bh','म':'m',
      'य':'y','र':'r','ऱ':'ṟ','ल':'l','ळ':'ḻ','व':'v',
      'श':'ś','ष':'ṣ','स':'s','ह':'h'
    };
    const misc = { 'ं':'ṃ','ः':'ḥ','ँ':'m̐','ऽ':"'",'ॐ':'oṃ','।':'.','॥':'..','०':'0','१':'1','२':'2','३':'3','४':'4','५':'5','६':'6','७':'7','८':'8','९':'9' };
    let out = '';
    let i = 0;
    while (i < str.length) {
      const ch = str[i];
      if (cons[ch]) {
        out += cons[ch];
        const nxt = str[i + 1];
        if (nxt === '्') {
          i += 2;
        } else if (nxt && matras[nxt]) {
          out += matras[nxt];
          i += 2;
        } else {
          out += 'a';
          i += 1;
        }
      } else if (vowels[ch]) {
        out += vowels[ch];
        i += 1;
      } else if (matras[ch]) {
        out += matras[ch];
        i += 1;
      } else if (misc[ch]) {
        out += misc[ch];
        i += 1;
      } else {
        out += ch;
        i += 1;
      }
    }
    return out;
  },

  romanToDev(input, scheme = 'itrans') {
    if (!input) return '';
    if (scheme === 'direct') return input;

    let s = input;
    if (scheme === 'slp1') return this.slpToDev(s);
    if (scheme === 'wx') return this.wxToDev(s);
    if (scheme === 'velthuis') {
      s = s.replace(/aa/g, 'A').replace(/ii/g, 'I').replace(/uu/g, 'U')
           .replace(/\.rr/g, 'RRI').replace(/\.r/g, 'R').replace(/\.l/g, 'LLi')
           .replace(/\.t/g, 'T').replace(/\.d/g, 'D')
           .replace(/\.n/g, 'N').replace(/\.m/g, 'M').replace(/\.h/g, 'H')
           .replace(/"n/g, '~N').replace(/"s/g, 'sh').replace(/\.s/g, 'Sh');
    } else if (scheme === 'hk') {
      s = s.replace(/RR/g, 'RRI').replace(/lR/g, 'LLi')
           .replace(/G/g, '~N').replace(/J/g, '~n')
           .replace(/S/g, 'Sh').replace(/z/g, 'sh');
    } else if (scheme === 'rts') {
      s = s.replace(/ee/g, 'I').replace(/oo/g, 'U')
           .replace(/~m/g, '~N').replace(/@2/g, '.a');
    }

    // IAST diacritics support
    s = s.replace(/ā/g, 'A').replace(/ī/g, 'I').replace(/ū/g, 'U')
         .replace(/ṛ/g, 'RRi').replace(/ṝ/g, 'RRI').replace(/ḷ/g, 'LLi').replace(/ḹ/g, 'LLI')
         .replace(/ṅ/g, '~N').replace(/ñ/g, '~n')
         .replace(/ṭ/g, 'T').replace(/ḍ/g, 'D').replace(/ṇ/g, 'N')
         .replace(/ś/g, 'sh').replace(/ṣ/g, 'Sh')
         .replace(/ṃ/g, 'M').replace(/ṁ/g, 'M').replace(/ḥ/g, 'H');

    // Smart nasal assimilation for natural typing
    s = s.replace(/n([kg]h?)/g, '~N$1')
         .replace(/n(chh?|jh?)/g, '~n$1')
         .replace(/n([TD]h?)/g, 'N$1');

    const vowelTokens = [
      ['RRI', 'ॠ', 'ॄ'], ['R^I', 'ॠ', 'ॄ'], ['RRi', 'ऋ', 'ृ'], ['R^i', 'ऋ', 'ृ'],
      ['LLI', 'ॡ', 'ॣ'], ['LLi', 'ऌ', 'ॢ'], ['L^i', 'ऌ', 'ॢ'],
      ['ai', 'ऐ', 'ै'], ['au', 'औ', 'ौ'],
      ['aa', 'आ', 'ा'], ['ii', 'ई', 'ी'], ['uu', 'ऊ', 'ू'], ['ee', 'ई', 'ी'], ['oo', 'ऊ', 'ू'],
      ['R', 'ऋ', 'ृ'],
      ['A', 'आ', 'ा'], ['I', 'ई', 'ी'], ['U', 'ऊ', 'ू'],
      ['e', 'ए', 'े'], ['o', 'ओ', 'ो'], ['a', 'अ', ''], ['i', 'इ', 'ि'], ['u', 'उ', 'ु']
    ];
    const consTokens = [
      ['kSh', 'क्ष्'], ['ksh', 'क्ष्'], ['j~n', 'ज्ञ्'], ['GY', 'ज्ञ्'], ['dny', 'ज्ञ्'],
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
    ];
    const specials = [
      ['OM', 'ॐ'], ['AUM', 'ॐ'], ['.a', 'ऽ'], ['||', '॥'], ['|', '।'],
      ['.N', 'ँ'], ['.n', 'ं'], ['.m', 'ं'], ['M', 'ं'], ['H', 'ः'], ["'", 'ऽ']
    ];

    let out = '';
    let i = 0;
    let afterCons = false;

    while (i < s.length) {
      let matched = false;
      for (const [tok, rep] of specials) {
        if (s.startsWith(tok, i)) {
          out += rep;
          i += tok.length;
          afterCons = false;
          matched = true;
          break;
        }
      }
      if (matched) continue;

      for (const [tok, indep, matra] of vowelTokens) {
        if (s.startsWith(tok, i)) {
          if (afterCons) out = out.slice(0, -1) + matra;
          else out += indep;
          i += tok.length;
          afterCons = false;
          matched = true;
          break;
        }
      }
      if (matched) continue;

      for (const [tok, devC] of consTokens) {
        if (s.startsWith(tok, i)) {
          out += devC;
          i += tok.length;
          afterCons = true;
          matched = true;
          break;
        }
      }
      if (matched) continue;

      out += s[i];
      afterCons = false;
      i += 1;
    }
    return out;
  },

  generateCandidates(romanRaw, scheme = 'itrans') {
    if (!romanRaw || !/[a-zA-Z]/.test(romanRaw)) return [];
    const s = romanRaw.trim();
    const variants = [s];

    if (!/[AIU]/.test(s)) {
      const idxA = s.indexOf('a');
      if (idxA !== -1) variants.push(s.slice(0, idxA) + 'A' + s.slice(idxA + 1));
      const lastA = s.lastIndexOf('a');
      if (lastA !== -1 && lastA !== idxA) variants.push(s.slice(0, lastA) + 'A' + s.slice(lastA + 1));
      if (idxA !== -1 && lastA !== -1 && idxA !== lastA) {
        variants.push(s.slice(0, idxA) + 'A' + s.slice(idxA + 1, lastA) + 'A' + s.slice(lastA + 1));
      }
      const idxI = s.indexOf('i');
      if (idxI !== -1) variants.push(s.slice(0, idxI) + 'I' + s.slice(idxI + 1));
      const idxU = s.indexOf('u');
      if (idxU !== -1) variants.push(s.slice(0, idxU) + 'U' + s.slice(idxU + 1));
    }

    if (s.includes('ri')) variants.push(s.replace(/ri/g, 'RRi'));
    if (s.includes('sh')) variants.push(s.replace(/sh/g, 'Sh'));
    if (s.includes('s')) variants.push(s.replace(/s/g, 'sh'), s.replace(/s/g, 'Sh'));
    if (s.includes('n')) variants.push(s.replace(/n/g, 'N'));
    if (s.includes('t')) variants.push(s.replace(/t/g, 'T'));
    if (s.includes('d')) variants.push(s.replace(/d/g, 'D'));

    const seen = new Set();
    const results = [];
    const addDeva = (devStr, label = '') => {
      if (!devStr || seen.has(devStr)) return;
      seen.add(devStr);
      results.push({
        deva: devStr,
        telu: this.devToTelugu(devStr),
        iast: this.devToIast(devStr),
        label
      });
    };

    variants.forEach(v => {
      const dev = this.romanToDev(v, scheme);
      addDeva(dev);
      if (dev.endsWith('्')) {
        const noHal = dev.slice(0, -1);
        addDeva(noHal);
        addDeva(noHal + 'ः');
        addDeva(noHal + 'म्');
      } else {
        addDeva(dev + 'ः');
        addDeva(dev + 'म्');
      }
    });

    return results.slice(0, 10);
  },

  wxToDev(s) {
    const vMap = { 'a':['अ',''],'A':['आ','ा'],'i':['इ','ि'],'I':['ई','ी'],'u':['उ','ु'],'U':['ऊ','ू'],'q':['ऋ','ृ'],'Q':['ॠ','ॄ'],'L':['ऌ','ॢ'],'e':['ए','े'],'E':['ऐ','ै'],'o':['ओ','ो'],'O':['औ','ौ'] };
    const cMap = { 'k':'क्','K':'ख्','g':'ग्','G':'घ्','f':'ङ्','c':'च्','C':'छ्','j':'ज्','J':'झ्','F':'ञ्','t':'ट्','T':'ठ्','d':'ड्','D':'ढ्','N':'ण्','w':'त्','W':'थ्','x':'द्','X':'ध्','n':'न्','p':'प्','P':'फ्','b':'ब्','B':'भ्','m':'म्','y':'य्','r':'र्','l':'ल्','v':'व्','S':'श्','R':'ष्','s':'स्','h':'ह्' };
    const mMap = { 'M':'ं','H':'ः','z':'ँ','Z':'ऽ','|':'।' };
    let out = '';
    let afterC = false;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (vMap[ch]) {
        if (afterC) out = out.slice(0, -1) + vMap[ch][1];
        else out += vMap[ch][0];
        afterC = false;
      } else if (cMap[ch]) {
        out += cMap[ch];
        afterC = true;
      } else if (mMap[ch]) {
        out += mMap[ch];
        afterC = false;
      } else {
        out += ch;
        afterC = false;
      }
    }
    return out;
  },

  slpToDev(s) {
    const vMap = { 'a':['अ',''],'A':['आ','ा'],'i':['इ','ि'],'I':['ई','ी'],'u':['उ','ु'],'U':['ऊ','ू'],'f':['ऋ','ृ'],'F':['ॠ','ॄ'],'x':['ऌ','ॢ'],'X':['ॡ','ॣ'],'e':['ए','े'],'E':['ऐ','ै'],'o':['ओ','ो'],'O':['औ','ौ'] };
    const cMap = { 'k':'क्','K':'ख्','g':'ग्','G':'घ्','N':'ङ्','c':'च्','C':'छ्','j':'ज्','J':'झ्','Y':'ञ्','w':'ट्','W':'ठ्','q':'ड्','Q':'ढ्','R':'ण्','t':'त्','T':'थ्','d':'द्','D':'ध्','n':'न्','p':'प्','P':'फ्','b':'ब्','B':'भ्','m':'म्','y':'य्','r':'र्','l':'ल्','L':'ळ्','v':'व्','S':'श्','z':'ष्','s':'स्','h':'ह्' };
    const mMap = { 'M':'ं','H':'ः','~':'ँ',"'":'ऽ' };
    let out = '';
    let afterC = false;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (vMap[ch]) {
        if (afterC) out = out.slice(0, -1) + vMap[ch][1];
        else out += vMap[ch][0];
        afterC = false;
      } else if (cMap[ch]) {
        out += cMap[ch];
        afterC = true;
      } else if (mMap[ch]) {
        out += mMap[ch];
        afterC = false;
      } else {
        out += ch;
        afterC = false;
      }
    }
    return out;
  },

  toActiveScript(devStr) {
    if (!devStr) return '';
    if (AppState.script === 'telu') return this.devToTelugu(devStr);
    if (AppState.script === 'iast') return this.devToIast(devStr);
    if (AppState.script === 'trilingual') {
      const te = this.devToTelugu(devStr);
      const ia = this.devToIast(devStr);
      return te === devStr ? devStr : `${devStr} · ${te} · ${ia}`;
    }
    return devStr;
  }
};

function fmt(deva, telu, iast) {
  if (!deva) return '';
  const t = telu || TranslitEngine.devToTelugu(deva);
  const i = iast || TranslitEngine.devToIast(deva);
  switch (AppState.script) {
    case 'telu': return t;
    case 'iast': return i;
    case 'trilingual': return `${deva} <span style="color:var(--text-secondary); font-weight:normal;">(${t} · ${i})</span>`;
    default: return deva;
  }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function switchStageView(viewId) {
  if (viewId === 'view-reader' && window.Reader && Reader.kind === 'pdf' && Reader.fitWidth) setTimeout(() => Reader.applyFit(), 0);
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-view') === viewId);
  });
  document.querySelectorAll('.stage-view').forEach(sec => {
    sec.classList.toggle('active', sec.id === viewId);
  });
}

// ============================================================================
// 2. FONTHELP KEYBOARD MAP DRAWER & VIEW 8 (FONTHELP + DATA HUB)
// ============================================================================

const FONTHELP_GROUPS = [
  {
    title: 'Vowels & Mātrās (स्वराः)',
    keys: [
      ['अ','a'],['आ','A/aa'],['इ','i'],['ई','I/ii'],['उ','u'],['ऊ','U/uu'],
      ['ऋ','RRi'],['ॠ','RRI'],['ऌ','LLi'],['ए','e'],['ऐ','ai'],['ओ','o'],['औ','au'],
      ['ं','M'],['ः','H'],['ँ','.N'],['ऽ','.a'],['ॐ','OM'],
      ['ा','aa'],['ि','i'],['ी','ii'],['ु','u'],['ू','uu'],['ृ','R'],['े','e'],['ै','ai'],['ो','o'],['ौ','au'],['्','halant']
    ]
  },
  {
    title: 'Stop Consonants (वर्गीयव्यञ्जनानि)',
    keys: [
      ['क','ka'],['ख','kha'],['ग','ga'],['घ','gha'],['ङ','~Na'],
      ['च','cha'],['छ','Cha'],['ज','ja'],['झ','jha'],['ञ','~na'],
      ['ट','Ta'],['ठ','Tha'],['ड','Da'],['ढ','Dha'],['ण','Na'],
      ['त','ta'],['थ','tha'],['द','da'],['ध','dha'],['न','na'],
      ['प','pa'],['फ','pha'],['ब','ba'],['भ','bha'],['म','ma']
    ]
  },
  {
    title: 'Semivowels, Sibilants & Conjuncts (अन्तःस्थाः & संयुक्ताक्षराणि)',
    keys: [
      ['य','ya'],['र','ra'],['ल','la'],['ळ','La'],['व','va'],
      ['श','sha'],['ष','Sha'],['स','sa'],['ह','ha'],
      ['क्ष','kSha'],['त्र','tra'],['ज्ञ','j~na'],['श्र','shra'],['द्ध','ddha'],['द्य','dya'],['क्त','kta'],['न्त','nta'],
      ['।','|'],['॥','||'],['०','0'],['१','1'],['२','2'],['३','3'],['४','4'],['५','5'],['६','6'],['७','7'],['८','8'],['९','9']
    ]
  }
];

function renderFontHelpDrawer() {
  const grid = document.getElementById('fontHelpDrawerGrid');
  if (!grid) return;
  grid.innerHTML = FONTHELP_GROUPS.map(group => `
    <div class="key-group-box">
      <div class="key-group-title">${group.title}</div>
      <div class="key-grid">
        ${group.keys.map(([deva, code]) => {
          const disp = AppState.script === 'telu' ? TranslitEngine.devToTelugu(deva) : deva;
          return `
            <button class="vk-btn" data-insert="${disp}" title="Devanagari: ${deva} | Telugu: ${TranslitEngine.devToTelugu(deva)} | Phonetic: ${code}">
              <span class="vk-char">${disp}</span>
              <span class="vk-code">${code}</span>
            </button>
          `;
        }).join('')}
      </div>
    </div>
  `).join('');

  grid.querySelectorAll('.vk-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      insertIntoActiveField(btn.getAttribute('data-insert'));
    });
  });
}

function insertIntoActiveField(textToInsert) {
  const target = AppState.activeInputEl || document.getElementById('sanskritEditor');
  if (!target) return;
  if (typeof EditorIME !== 'undefined') EditorIME.reset();
  const start = target.selectionStart || 0;
  const end = target.selectionEnd || 0;
  const val = target.value || '';
  target.value = val.slice(0, start) + textToInsert + val.slice(end);
  target.focus();
  target.selectionStart = target.selectionEnd = start + textToInsert.length;
  target.dispatchEvent(new Event('input'));
}

function renderFontHelpTab() {
  const container = document.getElementById('fontHelpBodyContainer');
  if (!container) return;
  const counts = (AppState.stats && AppState.stats.counts) || {};
  const dicts = AppState.dictionaries || [];
  const tot = dictionaryTotals();
  const n = (v) => (v === undefined || v === null) ? '—' : Number(v).toLocaleString();

  container.innerHTML = `
    <div class="grid-2col">
      <div class="card">
        <div class="card-header">
          <div class="card-title">📊 Data in this app</div>
          <span class="badge">${AppState.stats ? AppState.stats.db_size_mb : '—'} MB · read-only</span>
        </div>
        <table class="grammar-table">
          <thead>
            <tr><th>Dataset</th><th>Records</th><th>Source</th></tr>
          </thead>
          <tbody>
            <tr><td><strong>${tot.dictionaries} dictionaries</strong></td><td><strong>${n(counts.dict_entries)}</strong></td><td>12 Cologne (CDSL) dictionaries listed by andhrabharati.com · 7 kośas from ashtadhyayi.com</td></tr>
            <tr><td><strong>Kośa verses</strong></td><td><strong>${n(counts.kosha_verses)}</strong></td><td>Amara, Halāyudha, Vaijayantī, Ākhyātacandrikā (ashtadhyayi.com)</td></tr>
            <tr><td><strong>Dhātus (10 lakāras)</strong></td><td><strong>${n(counts.dhatus)}</strong></td><td>ashtadhyayi.com Dhātupāṭha, forms by Vidyut Prakriyā</td></tr>
            <tr><td><strong>Indexed verb forms</strong></td><td><strong>${n(counts.dhatu_inflections)}</strong></td><td>ashtadhyayi.com (Vidyut) conjugation tables</td></tr>
            <tr><td><strong>Śabdapāṭha paradigms</strong></td><td><strong>${n(counts.shabdas)}</strong></td><td>ashtadhyayi.com Śabdapāṭha</td></tr>
            <tr><td><strong>Prakriyā derivations</strong></td><td><strong>${n(counts.shabda_prakriya)}</strong></td><td>ashtadhyayi.com Śabda-prakriyā</td></tr>
            <tr><td><strong>Aṣṭādhyāyī sūtras</strong></td><td><strong>${n(counts.sutras)}</strong></td><td>ashtadhyayi.com with Kāśikā, Kaumudī, Bālamanoramā, Vasu</td></tr>
            <tr><td><strong>Vyākaraṇa auxiliaries</strong></td><td><strong>${n(counts.vyakarana_texts)}</strong></td><td>Śiva-sūtras, pratyāhāras, gaṇapāṭha, uṇādi, śikṣā (ashtadhyayi.com)</td></tr>
          </tbody>
        </table>
        <p style="font-size:12px; color:var(--text-secondary); margin-top:8px;">
          All data is read from verified copies: the ashtadhyayi.com data repository at the commit the site serves, and the
          Cologne dictionary sources checked against their git hashes. The Studio runs on your own computer: documents and
          lookups never leave it.
          <a href="#" onclick="switchStageView('view-credits'); return false;">Credits &amp; thanks →</a>
        </p>
        <div style="display:flex; gap:8px; flex-wrap:wrap; margin-top:10px;">
          <button class="btn btn-primary" onclick="openSource('andhrabharati', '')">Andhra Bharati Sanskrit dictionary ↗</button>
          <button class="btn" onclick="openSource('andhrabharati', 'FontHelp')">Andhra Bharati Font Help ↗</button>
          <button class="btn" onclick="openSource('ashtadhyayi', '/')">ashtadhyayi.com ↗</button>
        </div>
        <div id="syncStatusBox" style="margin-top:8px; font-size:12px; color:var(--text-secondary);"></div>
      </div>

      <div class="card">
        <div class="card-header">
          <div class="card-title">🔤 Multi-Scheme Phonetic Reference Chart</div>
          <span class="badge">ITRANS · RTS · SLP1 · HK · Velthuis · WX</span>
        </div>
        <table class="grammar-table" style="font-size:12.5px;">
          <thead>
            <tr>
              <th>Devanagari</th><th>Telugu</th><th>IAST</th><th>ITRANS</th><th>RTS</th><th>SLP1</th><th>HK</th><th>Velthuis</th><th>WX</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>अ, आ</td><td>అ, ఆ</td><td>a, ā</td><td>a, A / aa</td><td>a, A / aa</td><td>a, A</td><td>a, A</td><td>a, aa</td><td>a, A</td></tr>
            <tr><td>इ, ई</td><td>ఇ, ఈ</td><td>i, ī</td><td>i, I / ii</td><td>i, I / ee</td><td>i, I</td><td>i, I</td><td>i, ii</td><td>i, I</td></tr>
            <tr><td>उ, ऊ</td><td>ఉ, ఊ</td><td>u, ū</td><td>u, U / uu</td><td>u, U / oo</td><td>u, U</td><td>u, U</td><td>u, uu</td><td>u, U</td></tr>
            <tr><td>ऋ, ॠ</td><td>ఋ, ౠ</td><td>ṛ, ṝ</td><td>RRi, RRI</td><td>R, RR</td><td>f, F</td><td>R, RR</td><td>.r, .rr</td><td>q, Q</td></tr>
            <tr><td>ए, ऐ</td><td>ఏ, ఐ</td><td>e, ai</td><td>e, ai</td><td>e / E, ai</td><td>e, E</td><td>e, ai</td><td>e, ai</td><td>e, E</td></tr>
            <tr><td>ओ, औ</td><td>ఓ, ఔ</td><td>o, au</td><td>o, au</td><td>o / O, au</td><td>o, O</td><td>o, au</td><td>o, au</td><td>o, O</td></tr>
            <tr><td>ं, ः, ऽ</td><td>ం, ః, ఽ</td><td>ṃ, ḥ, '</td><td>M, H, .a</td><td>M, H, @2</td><td>M, H, '</td><td>M, H, '</td><td>.m, .h, .a</td><td>M, H, Z</td></tr>
            <tr><td>क, ख, ग, घ, ङ</td><td>క, ఖ, గ, ఘ, ఙ</td><td>k, kh, g, gh, ṅ</td><td>k, kh, g, gh, ~N</td><td>k, kh, g, gh, ~m</td><td>k, K, g, G, N</td><td>k, kh, g, gh, G</td><td>k, kh, g, gh, "n</td><td>k, K, g, G, f</td></tr>
            <tr><td>च, छ, ज, झ, ञ</td><td>చ, ఛ, జ, ఝ, ఞ</td><td>c, ch, j, jh, ñ</td><td>ch, Ch, j, jh, ~n</td><td>c, ch, j, jh, ~n</td><td>c, C, j, J, Y</td><td>c, ch, j, jh, J</td><td>c, ch, j, jh, ~n</td><td>c, C, j, J, F</td></tr>
            <tr><td>ट, ठ, ड, ढ, ण</td><td>ట, ఠ, డ, ఢ, ణ</td><td>ṭ, ṭh, ḍ, ḍh, ṇ</td><td>T, Th, D, Dh, N</td><td>T, Th, D, Dh, N</td><td>w, W, q, Q, R</td><td>T, Th, D, Dh, N</td><td>.t, .th, .d, .dh, .n</td><td>t, T, d, D, N</td></tr>
            <tr><td>त, थ, द, ध, न</td><td>త, థ, ద, ధ, న</td><td>t, th, d, dh, n</td><td>t, th, d, dh, n</td><td>t, th, d, dh, n</td><td>t, T, d, D, n</td><td>t, th, d, dh, n</td><td>t, th, d, dh, n</td><td>w, W, x, X, n</td></tr>
            <tr><td>प, फ, ब, भ, म</td><td>ప, ఫ, బ, భ, మ</td><td>p, ph, b, bh, m</td><td>p, ph, b, bh, m</td><td>p, ph, b, bh, m</td><td>p, P, b, B, m</td><td>p, ph, b, bh, m</td><td>p, ph, b, bh, m</td><td>p, P, b, B, m</td></tr>
            <tr><td>य, र, ल, व</td><td>య, ర, ల, వ</td><td>y, r, l, v</td><td>y, r, l, v/w</td><td>y, r, l, v/w</td><td>y, r, l, v</td><td>y, r, l, v</td><td>y, r, l, v</td><td>y, r, l, v</td></tr>
            <tr><td>श, ष, स, ह</td><td>శ, ష, స, హ</td><td>ś, ṣ, s, h</td><td>sh, Sh, s, h</td><td>S, sh, s, h</td><td>S, z, s, h</td><td>z, S, s, h</td><td>"s, .s, s, h</td><td>S, R, s, h</td></tr>
            <tr><td>क्ष, त्र, ज्ञ, श्र</td><td>క్ష, త్ర, జ్ఞ, శ్ర</td><td>kṣa, tra, jña, śra</td><td>kSha, tra, j~na, shra</td><td>ksha, tra, j~na, Sra</td><td>kza, tra, jYa, Sra</td><td>kSa, tra, jJa, zra</td><td>k.sa, tra, j~na, "sra</td><td>kRa, wra, jFa, Sra</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <div class="card-title">📚 All ${tot.dictionaries} Dictionaries</div>
      </div>
      <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap:10px;">
        ${dicts.map(d => `
          <div style="border:1px solid var(--border-color); border-radius:6px; padding:10px 12px; background:var(--bg-elevated);">
            <div style="font-weight:700; color:var(--accent-primary); font-family:var(--font-indic);">${d.name_sa}</div>
            <div style="font-size:12px; color:var(--text-secondary);">${d.name_te || ''}</div>
            <div style="font-size:12px; margin-top:2px;">${d.name_en}</div>
            <div style="margin-top:6px; display:flex; justify-content:space-between; font-size:11.5px;">
              <span class="badge">${d.code.toUpperCase()} · ${d.category}</span>
              <strong>${Number(d.entry_count).toLocaleString()} ${d.storage === 'cdsl' ? 'records' : 'entries'}</strong>
            </div>
            ${d.source ? `<div style="font-size:11px; color:var(--text-muted); margin-top:4px;">${escapeHtml(d.source)}</div>` : ''}
          </div>
        `).join('')}
      </div>
    </div>
  `;


}

// ============================================================================
// 3. WRITING STUDIO QUICK ASSISTANT (Right Column of Writing Studio)
// ============================================================================

// The lookup panel exists twice: beside the Writing Studio editor and beside the Reader.
const LOOKUP_TARGETS = {
  studio: { input: 'studioQuickLookupInput', container: 'studioAssistantResults',
            hint: 'Double-click any word in your Sanskrit composition or type a word above to see its Dictionary meanings, Dhātu root, Śabda Vibhakti, and Sandhi splits here.' },
  reader: { input: 'readerLookupInput', container: 'readerLookupResults',
            hint: 'Select or double-click a word in the document (PDFs with a text layer and text files), or type any word above, to see its dictionary meanings, dhātu, śabda and sandhi splits here.' }
};
const lookupSeq = {};

window.insertIntoEditor = function (text) {
  AppState.activeInputEl = document.getElementById('sanskritEditor');
  insertIntoActiveField(text);
};

async function runStudioAssistantLookup(wordOverride = null, targetKey = 'studio', fromWord = null, others = []) {
  const target = LOOKUP_TARGETS[targetKey] || LOOKUP_TARGETS.studio;
  const input = document.getElementById(target.input);
  if (wordOverride !== null && input) input.value = wordOverride;
  const rawQ = (input ? input.value : '').replace(/[।॥0-9०-९,.\-!?()\[\]"'\s]+/g, '').trim();
  const container = document.getElementById(target.container);
  if (!container) return;
  const seq = (lookupSeq[targetKey] = (lookupSeq[targetKey] || 0) + 1);

  if (!rawQ) {
    container.innerHTML = `<div class="card"><p style="color:var(--text-secondary);">${target.hint}</p></div>`;
    return;
  }

  container.innerHTML = `<div class="card">⏳ Inspecting "<strong>${escapeHtml(rawQ)}</strong>"...</div>`;

  const [dictData, sandhiData] = await Promise.all([
    apiGet(`/api/dictionary/search?q=${encodeURIComponent(rawQ)}&dicts=all&match=prefix&scope=headword&limit=15`),
    apiGet(`/api/tools/sandhi?mode=split&word=${encodeURIComponent(rawQ)}`)
  ]);
  if (seq !== lookupSeq[targetKey]) return; // a newer lookup has started

  const gm = dictData.grammar_matches || { dhatus: [], shabdas: [] };
  const entries = dictData.entries || [];
  const splits = (sandhiData.splits || []).slice(0, 4);

  // No entry for the word as written: try possible stems and compound members (only real headwords).
  if (!fromWord && entries.length === 0 && !(gm.dhatus || []).length && !(gm.shabdas || []).length) {
    const st = await apiGet(`/api/dictionary/stems?q=${encodeURIComponent(rawQ)}`);
    if (seq !== lookupSeq[targetKey]) return;
    const stems = st.stems || [];
    const members = (st.members || []).filter(m => !stems.some(x => x !== m && x.startsWith(m)));
    const cands = [...new Set([...stems, ...members])];
    if (cands.length) {
      runStudioAssistantLookup(cands[0], targetKey, dictData.query_dev || rawQ, cands);
      return;
    }
  }

  let html = `
    <div class="card" style="background:var(--bg-elevated);">
      <div class="card-header">
        <div>
          <span class="card-title">${fmt(dictData.query_dev || rawQ, dictData.query_te, dictData.query_iast)}</span>
          <span class="badge" style="margin-left:6px;">Quick Inspector</span>
        </div>
        <button class="btn btn-sm" onclick="openFullDictionarySearch('${escapeHtml(rawQ)}')">Open in Full Dictionary →</button>
      </div>
  `;

  if ((gm.dhatus && gm.dhatus.length > 0) || (gm.shabdas && gm.shabdas.length > 0)) {
    html += `<div style="display:flex; flex-wrap:wrap; gap:6px; margin-bottom:8px;">`;
    (gm.dhatus || []).forEach(d => {
      html += `<button class="btn btn-sm" onclick="openDhatuFromAnywhere('${d.baseindex}')">⚡ Verb: ${fmt(d.form)} → √${fmt(d.dhatu)} (${d.artha_en || d.artha_sa})</button>`;
    });
    (gm.shabdas || []).forEach(s => {
      html += `<button class="btn btn-sm" onclick="openShabdaFromAnywhere('${s.urlid}')">🏛️ Noun: ${fmt(s.word)} (${s.linga})</button>`;
    });
    html += `</div>`;
  }

  if (splits.length > 0) {
    html += `
      <div style="font-size:12px; border-top:1px dashed var(--border-color); padding-top:6px;">
        <strong>🔗 Possible Sandhi Splits:</strong>
        <div style="display:flex; flex-wrap:wrap; gap:5px; margin-top:4px;">
          ${splits.map(s => `
            <span class="badge clickable-form" onclick="runStudioAssistantLookup('${escapeHtml(s.pada1)}', '${targetKey}')" title="${escapeHtml(s.sandhi_name)} (${escapeHtml(s.sutra)})">
              ${fmt(s.pada1)} + ${fmt(s.pada2)}
            </span>
          `).join('')}
        </div>
      </div>
    `;
  }
  html += `</div>`;

  if (fromWord) {
    html = `
      <div class="card stem-note">
        No entry for <strong class="indic">${fmt(fromWord)}</strong> as written. Showing the possible stem or compound member
        <strong class="indic">${fmt(dictData.query_dev || rawQ)}</strong>; check that it fits the context.
        ${others.length > 1 ? `<div class="stem-chips">${others.map(w => `<span class="badge clickable-form${w === rawQ ? ' active' : ''}" onclick="runStudioAssistantLookup('${escapeHtml(w)}', '${targetKey}', '${escapeHtml(fromWord)}', ${escapeHtml(JSON.stringify(others)).replace(/"/g, '&quot;')})">${fmt(w)}</span>`).join('')}</div>` : ''}
      </div>` + html;
  }

  if (entries.length === 0) {
    html += `<div class="card"><p style="font-size:13px; color:var(--text-secondary);">No exact headword matches. Click "Open in Full Dictionary" or click a Sandhi split above.</p></div>`;
  } else {
    html += entries.slice(0, 8).map(e => `
      <div class="card">
        <div class="card-header">
          <div>
            <strong class="indic" style="font-size:15px; color:var(--accent-primary);">${fmt(e.headword, e.headword_te, e.headword_iast)}</strong>
            <span class="badge" style="margin-left:6px;">${e.name_sa.split(' ')[0]} (${e.dict_code})</span>
          </div>
          <button class="btn btn-sm" onclick="${targetKey === 'studio' ? 'insertIntoActiveField' : 'insertIntoEditor'}('${escapeHtml(e.headword)}')" title="Insert into the Writing Studio editor">＋ Insert</button>
        </div>
        ${renderDefinition(e, { clamp: true, size: 13 })}
      </div>
    `).join('');
  }

  container.innerHTML = html;
  applyScriptToDefinitions(container);
}

// ============================================================================
// 4. VIEW 2: MULTI-DICTIONARY SEARCH CONTROLLER
// ============================================================================

function populateDictBookSelect() {
  const sel = document.getElementById('dictBookSelect');
  if (!sel) return;
  const tot = dictionaryTotals();
  sel.innerHTML = `<option value="all">All ${tot.dictionaries} dictionaries (सर्वे कोशाः — ${tot.entries.toLocaleString()} entries)</option>` +
    AppState.dictionaries.map(d => `
      <option value="${d.code}">${d.name_sa} — ${d.name_en} (${Number(d.entry_count).toLocaleString()})</option>
    `).join('');
}

async function runDictionarySearch(overrideQuery = null) {
  const input = document.getElementById('dictSearchInput');
  if (overrideQuery !== null && input) input.value = overrideQuery;
  const rawQ = input ? input.value.trim() : '';
  const dictCode = document.getElementById('dictBookSelect').value || 'all';
  const match = document.getElementById('dictMatchSelect').value || 'prefix';
  const scope = document.getElementById('dictScopeSelect').value || 'headword';

  const container = document.getElementById('dictResultsContainer');
  if (!container) return;
  container.innerHTML = `<div class="card">⏳ Searching ${dictionaryTotals().entries.toLocaleString()} dictionary entries...</div>`;

  const data = await apiGet(`/api/dictionary/search?q=${encodeURIComponent(rawQ)}&dicts=${encodeURIComponent(dictCode)}&match=${match}&scope=${scope}&limit=80`);
  renderDictionaryResults(data);
}

function renderDictionaryResults(data) {
  const container = document.getElementById('dictResultsContainer');
  if (!container) return;
  const entries = data.entries || [];
  const gm = data.grammar_matches || { dhatus: [], shabdas: [] };

  let html = '';
  const qWord = data.query_dev || data.query || '';
  if (qWord) {
    html += `
      <div class="source-strip">
        <span>On the original sites:</span>
        <button class="btn btn-sm" onclick="openSource('andhrabharati', '')" title="Opens andhrabharati.com's Sanskrit dictionary; search for the word there">Andhra Bharati dictionary ↗</button>
        <button class="btn btn-sm" onclick="openSource('ashtadhyayi', '/kosha?search=' + encodeURIComponent(${JSON.stringify(qWord).replace(/"/g, '&quot;')}))">ashtadhyayi.com kośa search ↗</button>
      </div>
    `;
  }

  if ((gm.dhatus && gm.dhatus.length > 0) || (gm.shabdas && gm.shabdas.length > 0)) {
    html += `
      <div class="card" style="border-left: 4px solid var(--accent-primary); background: var(--bg-elevated);">
        <div class="card-header">
          <div class="card-title" style="font-size:15px;">⚡ Grammatical Root &amp; Declension Matches</div>
        </div>
        <div style="display:flex; flex-wrap:wrap; gap:8px;">
          ${(gm.dhatus || []).map(d => `
            <button class="btn btn-sm" onclick="openDhatuFromAnywhere('${d.baseindex}')">
              ⚡ Verb: <strong>${fmt(d.form)}</strong> → √${fmt(d.dhatu)} (${d.artha_sa} / ${d.artha_en}) [${d.prayoga}]
            </button>
          `).join('')}
          ${(gm.shabdas || []).map(s => `
            <button class="btn btn-sm" onclick="openShabdaFromAnywhere('${s.urlid}')">
              🏛️ Noun Stem: <strong>${fmt(s.word)}</strong> (${s.linga}) — ${s.artha_sa} ${s.artha_en ? '· ' + s.artha_en : ''}
            </button>
          `).join('')}
        </div>
      </div>
    `;
  }

  if (entries.length === 0) {
    html += `
      <div class="card">
        <p>No dictionary entries found for "<strong>${escapeHtml(data.query || '')}</strong>".</p>
        <p style="font-size:12.5px; color:var(--text-secondary); margin-top:6px;">
          💡 Try switching Match Mode to <strong>Contains Anywhere</strong> or Search Scope to <strong>Full-Text Definitions (FTS5)</strong>.
        </p>
      </div>
    `;
    container.innerHTML = html;
    return;
  }

  html += entries.map(e => {
    const hwDisp = fmt(e.headword, e.headword_te, e.headword_iast);

    return `
      <div class="card">
        <div class="card-header">
          <div>
            <span class="card-title">${hwDisp}</span>
            <span class="badge" style="margin-left:8px;">${e.name_sa} (${e.dict_code.toUpperCase()})</span>
            ${e.page_ref ? `<span class="card-subtitle" style="margin-left:6px;">Ref: ${escapeHtml(e.page_ref)}</span>` : ''}
          </div>
          <button class="btn btn-sm" onclick="insertIntoActiveField('${escapeHtml(e.headword)}')">＋ Insert in Studio</button>
        </div>
        ${renderDefinition(e)}
      </div>
    `;
  }).join('');

  container.innerHTML = html;
  applyScriptToDefinitions(container);
}

// ============================================================================
// 5. VIEW 3: CLASSICAL KOSHA VERSE BROWSER
// ============================================================================

async function loadKoshaBrowser(resetNav = false) {
  const kosha = document.getElementById('koshaBookSelect').value;
  const navSelect = document.getElementById('koshaKandaVargaSelect');
  const q = document.getElementById('koshaVerseSearchInput').value.trim();

  let kanda = '';
  let varga = '';
  if (!resetNav && navSelect.value) {
    const parts = navSelect.value.split('||');
    kanda = parts[0] || '';
    varga = parts[1] || '';
  }

  const data = await apiGet(`/api/kosha/browse?kosha=${encodeURIComponent(kosha)}&kanda=${encodeURIComponent(kanda)}&varga=${encodeURIComponent(varga)}&q=${encodeURIComponent(q)}&limit=80`);

  if (resetNav || navSelect.options.length === 0) {
    navSelect.innerHTML = (data.navigation || []).map(n => {
      const val = `${n.kanda}||${n.varga}`;
      const sel = (n.kanda === data.active_kanda && n.varga === data.active_varga) ? 'selected' : '';
      return `<option value="${escapeHtml(val)}" ${sel}>Kāṇḍa ${escapeHtml(n.kanda)} · Varga ${escapeHtml(n.varga)} (${n.verse_count} verses)</option>`;
    }).join('');
  }

  const container = document.getElementById('koshaVersesContainer');
  const verses = data.verses || [];
  if (verses.length === 0) {
    container.innerHTML = `<div class="card">No verses matched your filter.</div>`;
    return;
  }

  container.innerHTML = verses.map(v => {
    const vDisp = fmt(v.verse_text, v.verse_text_te, v.verse_text_iast);
    const words = v.words || [];
    let wordsHtml = '';

    if (words.length > 0) {
      if (data.kosha === 'akhyata') {
        wordsHtml = words.map(vb => `
          <div style="margin-top:6px; padding:6px 10px; background:var(--bg-subtle); border-radius:6px; font-size:13px;">
            <strong>अर्थः — ${fmt(vb.artha)}:</strong>
            ${(vb.entries || []).map(en => `
              <span class="clickable-form badge" onclick="openDhatuFromAnywhere('${en.dhatu_id}')">${fmt(en.form)} (${en.dhatu_id})</span>
            `).join(' ')}
          </div>
        `).join('');
      } else {
        wordsHtml = `
          <div style="margin-top:8px; display:flex; flex-wrap:wrap; gap:6px;">
            ${words.map(w => `
              <span class="clickable-form badge" onclick="openFullDictionarySearch('${escapeHtml(w.word)}')" title="अर्थः: ${escapeHtml(w.artha || '')} | पर्यायाः: ${escapeHtml((w.synonyms || []).join(', '))}">
                ${fmt(w.word)} (${w.linga || ''}) : ${fmt(w.artha || '')}
              </span>
            `).join('')}
          </div>
        `;
      }
    }

    return `
      <div class="card">
        <div class="card-header">
          <span class="badge">${(data.kosha || '').toUpperCase()} · ${escapeHtml(v.verse_num)} (Kāṇḍa ${escapeHtml(v.kanda)}, Varga ${escapeHtml(v.varga)})</span>
          <button class="btn btn-sm" onclick="insertIntoActiveField('${escapeHtml(v.verse_text)}')">＋ Insert Verse</button>
        </div>
        <div class="indic" style="font-size:16.5px; font-weight:600; white-space:pre-wrap;">${vDisp}</div>
        ${wordsHtml}
      </div>
    `;
  }).join('');
}

// ============================================================================
// 6. VIEW 4: DHATUPATHA & 10-LAKARA CONJUGATOR
// ============================================================================

async function searchDhatus(overrideQuery = null) {
  const input = document.getElementById('dhatuSearchInput');
  if (overrideQuery !== null && input) input.value = overrideQuery;
  const rawQ = input ? input.value.trim() : '';
  const gana = document.getElementById('dhatuGanaSelect').value;
  const pada = document.getElementById('dhatuPadaSelect').value;

  const data = await apiGet(`/api/dhatu/search?q=${encodeURIComponent(rawQ)}&gana=${gana}&pada=${pada}&limit=100`);
  const sidebar = document.getElementById('dhatuListSidebar');
  const dhatus = data.dhatus || [];
  const infl = data.inflection_matches || [];

  let html = '';
  if (infl.length > 0) {
    html += `
      <div style="padding:10px 12px; background:var(--badge-bg); border-bottom:1px solid var(--border-strong); font-size:12px;">
        <strong>⚡ Conjugated Verb Form Match:</strong>
        ${infl.map(m => `
          <div style="margin-top:4px; cursor:pointer;" onclick="loadDhatuDetail('${m.baseindex}')">
            <strong>${fmt(m.form)}</strong> → √${fmt(m.dhatu)} (${m.artha_sa}) [${m.prayoga}]
          </div>
        `).join('')}
      </div>
    `;
  }

  html += dhatus.map((d, idx) => `
    <div class="list-item ${idx === 0 ? 'active' : ''}" data-bidx="${d.baseindex}" onclick="loadDhatuDetail('${d.baseindex}', this)">
      <div class="list-item-title">
        <span>√${fmt(d.dhatu, d.dhatu_te, d.dhatu_iast)} <small style="font-weight:normal; color:var(--text-muted);">(${d.aupadeshik})</small></span>
        <span class="badge">${d.baseindex} · G${d.gana}</span>
      </div>
      <div class="list-item-sub">
        <strong>${fmt(d.artha_sa, d.artha_te)}</strong> — ${escapeHtml(d.artha_en || '')}
      </div>
      <div style="font-size:11.5px; color:var(--accent-primary); margin-top:2px;">
        लट्: ${fmt(d.lat_3sg, d.lat_3sg_te, d.lat_3sg_iast)} · ${d.pada} · ${d.settva}
      </div>
    </div>
  `).join('');

  sidebar.innerHTML = html || `<div style="padding:14px;">No matching Dhātus found.</div>`;

  if (dhatus.length > 0) {
    loadDhatuDetail(dhatus[0].baseindex);
  }
}

async function loadDhatuDetail(baseindex, clickedEl = null) {
  if (clickedEl) {
    document.querySelectorAll('#dhatuListSidebar .list-item').forEach(el => el.classList.remove('active'));
    clickedEl.classList.add('active');
  }
  const d = await apiGet(`/api/dhatu/detail?baseindex=${encodeURIComponent(baseindex)}`);
  AppState.currentDhatuDetail = d;
  renderDhatuDetail();
}

function renderDhatuDetail() {
  const d = AppState.currentDhatuDetail;
  const viewport = document.getElementById('dhatuDetailViewport');
  if (!d || !d.dhatu || !viewport) return;

  const subTab = AppState.activeDhatuSubTab || 'kartari';
  const padaMap = { P: 'परस्मैपदी (Parasmaipadī)', A: 'आत्मनेपदी (Ātmanepadī)', U: 'उभयपदी (Ubhayapadī)' };
  const setMap = { S: 'सेट् (Seṭ)', A: 'अनिट् (Aniṭ)', V: 'वेट् (Veṭ)' };
  const karmaMap = { S: 'सकर्मकः (Transitive)', A: 'अकर्मकः (Intransitive)', D: 'द्विकर्मकः' };

  let bodyHtml = '';

  if (subTab === 'kartari' || subTab === 'karmani') {
    const tables = subTab === 'kartari' ? (d.kartari || []) : (d.karmani || []);
    bodyHtml = `
      <div class="grid-2col">
        ${tables.map(t => `
          <div class="card">
            <div class="card-header">
              <span class="card-title" style="font-size:15.5px;">${fmt(t.name_sa, t.name_te, t.name_en)}</span>
              <span class="card-subtitle">${t.name_en}</span>
            </div>
            ${t.parasmaipada ? renderLakaraGrid(t.parasmaipada, 'परस्मैपदम् (Parasmaipada)') : ''}
            ${t.atmanepada ? renderLakaraGrid(t.atmanepada, subTab === 'karmani' ? 'कर्मणि / भावे आत्मनेपदम्' : 'आत्मनेपदम् (Ātmanepada)') : ''}
          </div>
        `).join('')}
      </div>
    `;
  } else if (subTab === 'kridanta') {
    const krids = d.kridantas || [];
    bodyHtml = `
      <div class="card">
        <div class="card-header">
          <span class="card-title">कृदन्तरूपाणि (Kṛdanta Participles, Infinitives, Gerunds &amp; Agent Nouns)</span>
        </div>
        <table class="grammar-table">
          <thead>
            <tr><th>Suffix (प्रत्ययः)</th><th>Stem</th><th>Masculine (पुं)</th><th>Feminine (स्त्री)</th><th>Neuter / Indeclinable</th></tr>
          </thead>
          <tbody>
            ${krids.map(k => `
              <tr>
                <td>
                  <span class="clickable-form" onclick="openRuleExplanationModal('${escapeHtml(k.pratyay)}')" title="Click for published English explanation of ${escapeHtml(k.pratyay)}">
                    <strong>📖 ${fmt(k.pratyay, k.pratyay_te, k.pratyay_iast)}</strong>
                  </span>
                </td>
                <td><span class="clickable-form" onclick="insertIntoActiveField('${escapeHtml(k.stem)}')">${fmt(k.stem)}</span></td>
                <td><span class="clickable-form" onclick="insertIntoActiveField('${escapeHtml(k.pum)}')">${fmt(k.pum)}</span></td>
                <td><span class="clickable-form" onclick="insertIntoActiveField('${escapeHtml(k.stri)}')">${fmt(k.stri)}</span></td>
                <td><span class="clickable-form" onclick="insertIntoActiveField('${escapeHtml(k.napum)}')">${fmt(k.napum)}</span></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
  } else if (subTab === 'upasarga') {
    const upas = d.upasargas || [];
    const prayogas = d.prayogas || {};
    const prayogaKeys = Object.keys(prayogas);

    bodyHtml = `
      <div class="card">
        <div class="card-header"><span class="card-title">उपसर्गार्थचन्द्रिका (Preverb Combinations)</span></div>
        ${upas.length === 0 ? '<p>No special Upasargarthachandrika entries recorded for this root.</p>' : upas.map(u => `
          <div class="commentary-block">
            <div class="commentary-label">${fmt(u.headword)}</div>
            <div class="dict-def-body">${escapeHtml(u.definition)}</div>
          </div>
        `).join('')}
      </div>
      <div class="card">
        <div class="card-header"><span class="card-title">काव्य-शास्त्र-प्रयोगाः (Classical Literary Citations)</span></div>
        ${prayogaKeys.length === 0 ? '<p>No literary citations indexed for this root.</p>' : prayogaKeys.map(pk => {
          const items = prayogas[pk] || [];
          return items.map(it => `
            <div class="commentary-block">
              <div class="commentary-label">${escapeHtml(it.book)} (${escapeHtml(it.num)}) — पदम्: ${escapeHtml(pk.split('_').pop())}</div>
              <div class="indic" style="font-size:15px;">${fmt(it.text)}</div>
            </div>
          `).join('');
        }).join('')}
      </div>
    `;
  }

  viewport.innerHTML = `
    <div class="card" style="background:var(--bg-elevated);">
      <div class="card-header">
        <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
          <span class="card-title" style="font-size:22px;">√${fmt(d.dhatu, d.dhatu_te, d.dhatu_iast)}</span>
          <span class="badge">औपदेशिकः: ${fmt(d.aupadeshik)}</span>
          <span class="badge">गणः ${d.gana}</span>
          <span class="badge">${padaMap[d.pada] || d.pada}</span>
          <span class="badge">${setMap[d.settva] || d.settva}</span>
          <span class="badge">${karmaMap[d.karma] || d.karma}</span>
        </div>
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="card-subtitle">Index: ${d.baseindex}</span>
          <button class="btn btn-sm" onclick="openSource('ashtadhyayi', '/dhatu/${encodeURIComponent(d.baseindex)}')" title="Open this dhātu on ashtadhyayi.com (all prayogas, sanādyanta forms and prakriyā)">ashtadhyayi.com ↗</button>
        </div>
      </div>
      <div style="font-size:15px; margin-bottom:10px;">
        <strong>धात्वर्थः (Meaning):</strong> <span class="indic">${fmt(d.artha_sa, d.artha_te)}</span> — <strong>${escapeHtml(d.artha_en || '')}</strong>
      </div>
      <div class="sub-tabs">
        <button class="sub-tab-btn ${subTab === 'kartari' ? 'active' : ''}" onclick="switchDhatuSubTab('kartari')">1. कर्तरि १० लकाराः (Active)</button>
        <button class="sub-tab-btn ${subTab === 'karmani' ? 'active' : ''}" onclick="switchDhatuSubTab('karmani')">2. कर्मणि/भावे १० लकाराः (Passive)</button>
        <button class="sub-tab-btn ${subTab === 'kridanta' ? 'active' : ''}" onclick="switchDhatuSubTab('kridanta')">3. कृदन्तरूपाणि (Kṛdantas)</button>
        <button class="sub-tab-btn ${subTab === 'upasarga' ? 'active' : ''}" onclick="switchDhatuSubTab('upasarga')">4. उपसर्गाः &amp; प्रयोगाः (Citations)</button>
      </div>
    </div>
    ${bodyHtml}
  `;
}

function renderLakaraGrid(rows, label) {
  return `
    <div style="font-size:11.5px; font-weight:700; color:var(--accent-secondary); margin:4px 0;">${label}</div>
    <table class="grammar-table">
      <thead>
        <tr><th>पुरुषः</th><th>एकवचनम् (Sg.)</th><th>द्विवचनम् (Du.)</th><th>बहुवचनम् (Pl.)</th></tr>
      </thead>
      <tbody>
        ${rows.map(r => `
          <tr>
            <td style="font-size:12px; color:var(--text-secondary); font-weight:600;">${r.purusha.split(' ')[0]}</td>
            <td>${formatClickableForms(r.ekavachana, r.ekavachana_te, r.ekavachana_iast)}</td>
            <td>${formatClickableForms(r.dvivachana, r.dvivachana_te, r.dvivachana_iast)}</td>
            <td>${formatClickableForms(r.bahuvachana, r.bahuvachana_te, r.bahuvachana_iast)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function formatClickableForms(devaStr, teluStr, iastStr) {
  if (!devaStr) return '-';
  const disp = fmt(devaStr, teluStr, iastStr);
  const firstForm = devaStr.split(',')[0].split('/')[0].trim();
  return `<span class="clickable-form" onclick="insertIntoActiveField('${escapeHtml(firstForm)}')" title="Click to insert '${escapeHtml(firstForm)}' into editor">${disp}</span>`;
}

function switchDhatuSubTab(tab) {
  AppState.activeDhatuSubTab = tab;
  renderDhatuDetail();
}

// ============================================================================
// 7. VIEW 5: SHABDAPATHA & ALGORITHMIC VIBHAKTI GENERATOR
// ============================================================================

async function searchShabdas(overrideQuery = null) {
  const input = document.getElementById('shabdaSearchInput');
  if (overrideQuery !== null && input) input.value = overrideQuery;
  const rawQ = input ? input.value.trim() : '';
  const linga = document.getElementById('shabdaLingaSelect').value;

  const data = await apiGet(`/api/shabda/search?q=${encodeURIComponent(rawQ)}&linga=${linga}&limit=100`);
  const shabdas = data.shabdas || [];

  const sidebar = document.getElementById('shabdaListSidebar');
  sidebar.innerHTML = shabdas.map((s, idx) => `
    <div class="list-item ${idx === 0 ? 'active' : ''}" onclick="loadShabdaDetail('${escapeHtml(s.urlid)}', this)">
      <div class="list-item-title">
        <span>${fmt(s.word, s.word_te, s.word_iast)}</span>
        <span class="badge">${s.linga} · ${s.anta || 'सुबन्तः'}</span>
      </div>
      <div class="list-item-sub">${fmt(s.artha_sa, s.artha_te)} ${s.artha_en ? '· ' + escapeHtml(s.artha_en) : ''}</div>
      <div style="font-size:11.5px; color:var(--accent-primary); margin-top:2px;">प्रथमा: ${fmt(s.prathama)}</div>
    </div>
  `).join('') || `<div style="padding:14px;">No matching Śabdas in database. Use the Custom Stem Generator in the toolbar to decline any word!</div>`;

  if (shabdas.length > 0) {
    loadShabdaDetail(shabdas[0].urlid);
  }
}

async function loadShabdaDetail(urlid, clickedEl = null) {
  if (clickedEl) {
    document.querySelectorAll('#shabdaListSidebar .list-item').forEach(el => el.classList.remove('active'));
    clickedEl.classList.add('active');
  }
  const s = await apiGet(`/api/shabda/detail?urlid=${encodeURIComponent(urlid)}`);
  renderShabdaViewport(s, false);
}

async function generateCustomShabda() {
  const rawStem = document.getElementById('customShabdaStemInput').value.trim();
  const linga = document.getElementById('customShabdaLingaSelect').value;
  if (!rawStem) return;

  const data = await apiGet(`/api/shabda/generate?stem=${encodeURIComponent(rawStem)}&linga=${linga}`);
  renderShabdaViewport(data, true);
}

function renderShabdaViewport(s, isGenerated = false) {
  const viewport = document.getElementById('shabdaDetailViewport');
  if (!s || !s.word || !viewport) return;

  const lingaNames = { P: 'पुंलिङ्गः (Masculine)', S: 'स्त्रीलिङ्गः (Feminine)', N: 'नपुंसकलिङ्गः (Neuter)' };

  let prakriyaHtml = '';
  if (s.prakriyas && s.prakriyas.length > 0) {
    prakriyaHtml = `
      <div class="card">
        <div class="card-header">
          <span class="card-title">⚙️ पाणिनीय-शब्दप्रक्रिया (Step-by-Step Paninian Derivation)</span>
        </div>
        <div class="grid-2col">
          ${s.prakriyas.map(p => `
            <div class="commentary-block">
              <div class="commentary-label">पदम्: ${fmt(p.form)} (विभक्तिः ${p.vibhakti}, वचनम् ${p.vachan})</div>
              <ol style="padding-left:18px; font-size:13px;">
                ${(p.steps || []).map(st => `
                  <li>
                    <strong>${fmt(st.step)}</strong>
                    ${(st.sutras || []).map(sc => `<span class="badge clickable-form" onclick="openRuleExplanationModal('${escapeHtml(sc)}', '', '${escapeHtml(sc)}')" title="Click for published English explanation of Sūtra ${escapeHtml(sc)}">📖 सूत्रम् ${escapeHtml(sc)}</span>`).join(' ')}
                  </li>
                `).join('')}
              </ol>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }

  let koshaNotesHtml = '';
  if (s.mw_meaning || s.ap_meaning || s.bh_meaning || s.vyutpatti) {
    koshaNotesHtml = `
      <div class="card">
        <div class="card-header"><span class="card-title">📖 Lexicon Meanings &amp; Etymology</span></div>
        ${s.vyutpatti ? `<div class="commentary-block"><div class="commentary-label">व्युत्पत्तिः (Vyutpatti)</div><div class="indic">${fmt(s.vyutpatti)}</div></div>` : ''}
        ${s.ap_meaning ? `<div class="commentary-block"><div class="commentary-label">आप्टेकोशः (Apte Sanskrit-English)</div><div class="dict-def-body">${escapeHtml(s.ap_meaning)}</div></div>` : ''}
        ${s.mw_meaning ? `<div class="commentary-block"><div class="commentary-label">मोनियर्-विलियम्स् (Monier-Williams)</div><div class="dict-def-body">${escapeHtml(s.mw_meaning)}</div></div>` : ''}
        ${s.bh_meaning ? `<div class="commentary-block"><div class="commentary-label">भारतीकोशः (Bhāratī Sanskrit-Sanskrit)</div><div class="dict-def-body">${escapeHtml(s.bh_meaning)}</div></div>` : ''}
      </div>
    `;
  }

  viewport.innerHTML = `
    <div class="card" style="background:var(--bg-elevated);">
      <div class="card-header">
        <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
          <span class="card-title" style="font-size:22px;">${fmt(s.word, s.word_te, s.word_iast)}</span>
          <span class="badge">${lingaNames[s.linga] || s.linga}</span>
          ${s.anta ? `<span class="badge">${s.anta}</span>` : ''}
          ${isGenerated ? `<span class="badge">⚡ Computed by the app's declension engine — not from the Śabdapāṭha data; check unusual stems</span>` : ''}
        </div>
        ${(!isGenerated && s.urlid) ? `<button class="btn btn-sm" onclick="openSource('ashtadhyayi', '/shabda/${encodeURIComponent(s.urlid)}')" title="Open this śabda on ashtadhyayi.com">ashtadhyayi.com ↗</button>` : ''}
      </div>
      ${(s.artha_sa || s.artha_en) ? `
        <div style="font-size:14.5px; margin-bottom:6px;">
          <strong>अर्थः:</strong> ${fmt(s.artha_sa, s.artha_te)} ${s.artha_en ? '— ' + escapeHtml(s.artha_en) : ''}
        </div>
      ` : ''}
    </div>

    <div class="card">
      <table class="grammar-table">
        <thead>
          <tr>
            <th>विभक्तिः (Case)</th>
            <th>एकवचनम् (Singular)</th>
            <th>द्विवचनम् (Dual)</th>
            <th>बहुवचनम् (Plural)</th>
          </tr>
        </thead>
        <tbody>
          ${(s.table || []).map(r => `
            <tr>
              <td style="font-weight:700; color:var(--accent-secondary);">
                ${AppState.script === 'telu' && r.vibhakti_te ? r.vibhakti_te : r.vibhakti}
              </td>
              <td>${formatClickableForms(r.ekavachana, r.ekavachana_te, r.ekavachana_iast)}</td>
              <td>${formatClickableForms(r.dvivachana, r.dvivachana_te, r.dvivachana_iast)}</td>
              <td>${formatClickableForms(r.bahuvachana, r.bahuvachana_te, r.bahuvachana_iast)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
    ${prakriyaHtml}
    ${koshaNotesHtml}
  `;
}

// ============================================================================
// 8. VIEW 6: ASHTADHYAYI SUTRAPATHA & 7 VYAKARANA GRANTHAS
// ============================================================================

async function runSutraOrVyakaranaSearch(overrideQuery = null) {
  const mode = document.getElementById('vyakaranaModeSelect').value;
  const input = document.getElementById('sutraSearchInput');
  if (overrideQuery !== null && input) input.value = overrideQuery;
  const rawQ = input ? input.value.trim() : '';

  const adhyayaEl = document.getElementById('sutraAdhyayaSelect');
  const padaEl = document.getElementById('sutraPadaSelect');

  if (mode !== 'sutrapatha') {
    adhyayaEl.style.display = 'none';
    padaEl.style.display = 'none';
    await loadVyakaranaAuxiliary(mode, rawQ);
    return;
  }

  adhyayaEl.style.display = '';
  padaEl.style.display = '';

  const adhyaya = adhyayaEl.value;
  const pada = padaEl.value;

  const data = await apiGet(`/api/sutra/search?q=${encodeURIComponent(rawQ)}&adhyaya=${adhyaya}&pada=${pada}&limit=150`);
  const sutras = data.sutras || [];

  const sidebar = document.getElementById('sutraListSidebar');
  sidebar.innerHTML = sutras.map((s, idx) => `
    <div class="list-item ${idx === 0 ? 'active' : ''}" onclick="loadSutraDetail('${s.code}', this)">
      <div class="list-item-title">
        <span>${fmt(s.sutra, s.sutra_te, s.sutra_iast)}</span>
        <span class="badge">${s.code}</span>
      </div>
      <div class="list-item-sub">${escapeHtml((s.sutrartha_en || s.sutrartha_sa || '').slice(0, 95))}</div>
    </div>
  `).join('') || `<div style="padding:14px;">No matching Sūtras found.</div>`;

  if (sutras.length > 0) {
    loadSutraDetail(sutras[0].code);
  }
}

async function loadSutraDetail(code, clickedEl = null) {
  if (clickedEl) {
    document.querySelectorAll('#sutraListSidebar .list-item').forEach(el => el.classList.remove('active'));
    clickedEl.classList.add('active');
  }
  const s = await apiGet(`/api/sutra/detail?code=${encodeURIComponent(code)}`);
  const viewport = document.getElementById('sutraDetailViewport');
  if (!s || !s.sutra || !viewport) return;

  const pcClean = (s.padaccheda || '').replace(/\$[A-Z]\$\d\$\d\$/g, '').replace(/##/g, ' · ');
  const typeClean = (s.type || '').replace(/\$/g, ' ');
  const anuvrittiClean = (s.anuvritti || '').replace(/\$/g, ' ').replace(/##/g, ', ');
  const adhikaraClean = (s.adhikara || '').replace(/\$/g, ' ').replace(/##/g, ', ');
  const vartikas = s.vartikas || [];

  viewport.innerHTML = `
    <div class="card" style="background:var(--bg-elevated);">
      <div class="card-header">
        <div style="display:flex; gap:6px; flex-wrap:wrap;">
          <span class="badge" style="font-size:13px;">अष्टाध्यायी ${s.code}</span>
          ${s.sk_num ? `<span class="badge">सिद्धान्तकौमुदी #${s.sk_num}</span>` : ''}
          ${s.lsk_num ? `<span class="badge">लघुकौमुदी #${s.lsk_num}</span>` : ''}
          ${typeClean ? `<span class="badge">${escapeHtml(typeClean)}</span>` : ''}
        </div>
        <div style="display:flex; gap:6px;">
          ${s.prev_code ? `<button class="btn btn-sm" onclick="loadSutraDetail('${s.prev_code}')">← ${s.prev_code}</button>` : ''}
          ${s.next_code ? `<button class="btn btn-sm" onclick="loadSutraDetail('${s.next_code}')">${s.next_code} →</button>` : ''}
          <button class="btn btn-sm" onclick="insertIntoActiveField('${escapeHtml(s.sutra)} (${s.code})')">＋ Cite Sūtra</button>
          <button class="btn btn-sm" onclick="openSource('ashtadhyayi', '/sutraani/${s.code}')" title="Open on ashtadhyayi.com: all 14 commentaries, Mahābhāṣya, Nyāsa, Padamañjarī, audio">ashtadhyayi.com ↗</button>
        </div>
      </div>

      <div class="indic" style="font-size:24px; font-weight:700; color:var(--accent-primary); margin:8px 0;">
        ${fmt(s.sutra, s.sutra_te, s.sutra_iast)}
      </div>

      <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap:8px; font-size:13px; margin-top:8px; padding-top:8px; border-top:1px solid var(--border-color);">
        ${pcClean ? `<div><strong>पदच्छेदः (Padaccheda):</strong> ${fmt(pcClean)}</div>` : ''}
        ${s.samasa ? `<div><strong>समासः (Samāsa):</strong> ${fmt(s.samasa)}</div>` : ''}
        ${anuvrittiClean ? `<div><strong>अनुवृत्तिः (Anuvṛtti):</strong> ${fmt(anuvrittiClean)}</div>` : ''}
        ${adhikaraClean ? `<div><strong>अधिकारः (Adhikāra):</strong> ${fmt(adhikaraClean)}</div>` : ''}
      </div>
    </div>

    ${s.sutrartha_sa ? `
      <div class="commentary-block">
        <div class="commentary-label">सूत्रार्थः (Sanskrit Explanation)</div>
        <div class="indic" style="font-size:15.5px; font-weight:600;">${fmt(s.sutrartha_sa, s.sutrartha_te)}</div>
        ${s.sutrartha_detail ? `<div class="indic" style="margin-top:6px; font-size:14px; color:var(--text-secondary);">${fmt(s.sutrartha_detail)}</div>` : ''}
      </div>
    ` : ''}

    ${(s.sutrartha_en || s.vasu_en) ? `
      <div class="commentary-block">
        <div class="commentary-label">English Meaning &amp; S.C. Vasu Commentary</div>
        ${s.sutrartha_en ? `<div style="font-weight:600; margin-bottom:6px;">${s.sutrartha_en}</div>` : ''}
        ${s.vasu_en ? `<div style="font-size:13.5px; line-height:1.6;">${s.vasu_en}</div>` : ''}
      </div>
    ` : ''}

    ${vartikas.length > 0 ? `
      <div class="commentary-block">
        <div class="commentary-label">कात्यायन-वार्त्तिकानि (Kātyāyana Vārttikas)</div>
        ${vartikas.map(v => `<div class="indic" style="font-weight:600; margin-bottom:4px;">• ${fmt(v)}</div>`).join('')}
      </div>
    ` : ''}

    ${s.kaumudi ? `
      <div class="commentary-block">
        <div class="commentary-label">वैयाकरण-सिद्धान्तकौमुदी (Siddhānta Kaumudī)</div>
        <div class="indic" style="white-space:pre-wrap;">${fmt(s.kaumudi, s.kaumudi_te)}</div>
      </div>
    ` : ''}

    ${s.laghukaumudi ? `
      <div class="commentary-block">
        <div class="commentary-label">लघुसिद्धान्तकौमुदी (Laghu Siddhānta Kaumudī)</div>
        <div class="indic" style="white-space:pre-wrap;">${fmt(s.laghukaumudi)}</div>
      </div>
    ` : ''}

    ${s.kashika ? `
      <div class="commentary-block">
        <div class="commentary-label">काशिकावृत्तिः (Kāśikā Vṛtti)</div>
        <div class="indic" style="white-space:pre-wrap;">${fmt(s.kashika, s.kashika_te)}</div>
      </div>
    ` : ''}

    ${s.balamanorama ? `
      <div class="commentary-block">
        <div class="commentary-label">बालमनोरमा (Bālamanoramā)</div>
        <div class="indic" style="white-space:pre-wrap;">${fmt(s.balamanorama)}</div>
      </div>
    ` : ''}
  `;
}

async function loadVyakaranaAuxiliary(category, q = '') {
  const data = await apiGet(`/api/vyakarana/list?category=${encodeURIComponent(category)}&q=${encodeURIComponent(q)}&limit=300`);
  const items = data.items || [];

  const sidebar = document.getElementById('sutraListSidebar');
  const viewport = document.getElementById('sutraDetailViewport');

  sidebar.innerHTML = items.map((it, idx) => `
    <div class="list-item ${idx === 0 ? 'active' : ''}" data-idx="${idx}">
      <div class="list-item-title">
        <span>${fmt(it.title, it.title_te, it.title_iast)}</span>
        <span class="badge">#${it.item_num}</span>
      </div>
      <div class="list-item-sub">${escapeHtml(it.subtitle || '')}</div>
    </div>
  `).join('');

  const renderItem = (it) => {
    if (!it) return;
    viewport.innerHTML = `
      <div class="card">
        <div class="card-header">
          <span class="card-title" style="font-size:20px;">${fmt(it.title, it.title_te, it.title_iast)}</span>
          <span class="badge">${it.category.toUpperCase()} #${it.item_num}</span>
        </div>
        ${it.subtitle ? `<div style="font-weight:600; color:var(--accent-secondary); margin-bottom:8px;">${fmt(it.subtitle)}</div>` : ''}
        <div class="dict-def-body">${fmt(it.body, it.body_te)}</div>
      </div>
    `;
  };

  if (items.length > 0) renderItem(items[0]);

  sidebar.querySelectorAll('.list-item').forEach(el => {
    el.addEventListener('click', () => {
      sidebar.querySelectorAll('.list-item').forEach(x => x.classList.remove('active'));
      el.classList.add('active');
      const idx = Number(el.getAttribute('data-idx'));
      renderItem(items[idx]);
    });
  });
}

// ============================================================================
// 9. PUBLISHED ENGLISH RULE EXPLANATION MODAL (S.C. Vasu, Abhyankar, Apte, MW)
// ============================================================================

const CLASSICAL_CHANDAS_REFERENCE = [
  { name_sa: 'गायत्री', name_en: 'Gāyatrī (Vedic 6/8-syllable)', syllables: 6, ganas: '24 अक्षराणि (त्रिपाद्)', lakshana: 'गायत्री त्रिपदा षडक्षरा पादशः' },
  { name_sa: 'अनुष्टुभ्', name_en: 'Anuṣṭubh (Śloka)', syllables: 8, ganas: '5th Laghu, 6th Guru', lakshana: 'श्लोके षष्ठं गुरु ज्ञेयं सर्वत्र लघु पञ्चमम् । द्विचतुष्पादयोर्ह्रस्वं सप्तमं दीर्घमन्ययोः ॥' },
  { name_sa: 'इन्द्रवज्रा', name_en: 'Indravajrā', syllables: 11, ganas: 'त, त, ज, ग, ग', lakshana: 'स्यादिन्द्रवज्रा यदि तौ जगौ गः' },
  { name_sa: 'उपेन्द्रवज्रा', name_en: 'Upendravajrā', syllables: 11, ganas: 'ज, त, ज, ग, ग', lakshana: 'उपेन्द्रवज्रा जतजास्ततो गौ' },
  { name_sa: 'उपजातिः', name_en: 'Upajāti (Mixed 11-syllable)', syllables: 11, ganas: 'इन्द्रवज्रा + उपेन्द्रवज्रा', lakshana: 'अनन्तरोदीरितलक्ष्मभाजौ पादौ यदीयावुपजातयस्ताः' },
  { name_sa: 'शालिनी', name_en: 'Śālinī', syllables: 11, ganas: 'म, त, त, ग, ग (यतिः ४, ७)', lakshana: 'मात्तौ गौ चेच्छालिनी वेदलोकैः' },
  { name_sa: 'रथोद्धता', name_en: 'Rathoddhatā', syllables: 11, ganas: 'र, न, र, ल, ग', lakshana: 'रात्परैर्नरलगै रथोद्धता' },
  { name_sa: 'स्वागता', name_en: 'Svāgatā', syllables: 11, ganas: 'र, न, भ, ग, ग', lakshana: 'स्वागता रनभगैर्गुरुणा च' },
  { name_sa: 'भुजङ्गप्रयातम्', name_en: 'Bhujaṅgaprayātam', syllables: 12, ganas: 'य, य, य, य (4 Ya-gaṇas)', lakshana: 'भुजङ्गप्रयातं चतुर्भिर्यकारैः' },
  { name_sa: 'वंशस्थम्', name_en: 'Vaṃśastham', syllables: 12, ganas: 'ज, त, ज, र', lakshana: 'जतौ तु वंशस्थमुदीरितं जरौ' },
  { name_sa: 'द्रुतविलम्बितम्', name_en: 'Drutavilambitam', syllables: 12, ganas: 'न, भ, भ, र', lakshana: 'द्रुतविलम्बितमाह नभौ भरौ' },
  { name_sa: 'तोटकम्', name_en: 'Toṭakam', syllables: 12, ganas: 'स, स, स, स (4 Sa-gaṇas)', lakshana: 'वद तोटकमब्धिसकारयुतम्' },
  { name_sa: 'प्रहर्षिणी', name_en: 'Praharṣiṇī', syllables: 13, ganas: 'म, न, ज, र, ग (यतिः ३, १०)', lakshana: 'त्र्याशाभिर्मनजरगाः प्रहर्षिणीये' },
  { name_sa: 'वसन्ततिलका', name_en: 'Vasantatilakā', syllables: 14, ganas: 'त, भ, ज, ज, ग, ग', lakshana: 'उक्ता वसन्ततिलका तभजा जगौ गः' },
  { name_sa: 'मालिनी', name_en: 'Mālinī', syllables: 15, ganas: 'न, न, म, य, य (यतिः ८, ७)', lakshana: 'ननमयययुतेयं मालिनी भोगिलोकैः' },
  { name_sa: 'पञ्चचामरम्', name_en: 'Pañcacāmaram', syllables: 16, ganas: 'ज, र, ज, र, ज, ग', lakshana: 'जरौ जरौ ततो जगाविदं तु पञ्चचामरम्' },
  { name_sa: 'शिखरिणी', name_en: 'Śikhariṇī', syllables: 17, ganas: 'य, म, न, स, भ, ल, ग (यतिः ६, ११)', lakshana: 'रसैरुद्रैश्छिन्ना यमनसभलागः शिखरिणी' },
  { name_sa: 'मन्दाक्रान्ता', name_en: 'Mandākrāntā', syllables: 17, ganas: 'म, भ, न, त, त, ग, ग (यतिः ४, ६, ७)', lakshana: 'मन्दाक्रान्ता जलधिरसनैर्म्भौ नतौ ताद्गुरौ चेत्' },
  { name_sa: 'हरिणी', name_en: 'Hariṇī', syllables: 17, ganas: 'न, स, म, र, स, ल, ग (यतिः ६, ४, ७)', lakshana: 'नसमरसलागः षड्वेदैर्हयैर्हरिणी मता' },
  { name_sa: 'शार्दूलविक्रीडितम्', name_en: 'Śārdūlavikrīḍitam', syllables: 19, ganas: 'म, स, ज, स, त, त, ग (यतिः १२, ७)', lakshana: 'सूर्याश्वैर्यदि मः सजौ सततगाः शार्दूलविक्रीडितम्' },
  { name_sa: 'स्रग्धरा', name_en: 'Sragdharā', syllables: 21, ganas: 'म, र, भ, न, य, य, य (यतिः ७, ७, ७)', lakshana: 'म्रभ्नैर्याणां त्रयेण त्रिमुनियतियुता स्रग्धरा कीर्तितेयम्' },
  { name_sa: 'आर्या', name_en: 'Āryā (Mātrā-vṛtta)', syllables: 'Mātrā', ganas: '12, 18, 12, 15 मात्राः', lakshana: 'यस्याः पादे प्रथमे द्वादश मात्रास्तथा तृतीयेऽपि । अष्टादश द्वितीये चतुर्थके पञ्चदश सार्या ॥' }
];

window.openRuleExplanationModal = async function(ruleText, contextText = '', sutraCode = '') {
  const modal = document.getElementById('ruleExplanationModal');
  const titleEl = document.getElementById('ruleModalTitle');
  const subEl = document.getElementById('ruleModalSubtitle');
  const bodyEl = document.getElementById('ruleModalBody');
  if (!modal || !bodyEl) return;

  modal.classList.add('open');
  titleEl.innerHTML = `📖 ${escapeHtml(ruleText || sutraCode || 'Grammar & Prosody Rule')}`;
  subEl.textContent = 'Published sources · Aṣṭādhyāyī with S.C. Vasu (1891), K.V. Abhyankar (1961), Wilson (1832), Macdonell (1893), Apte (1890), Cappeller (1891), Monier-Williams (1899)';
  bodyEl.innerHTML = `<div class="card">⏳ Loading verbatim published English explanations...</div>`;

  const url = `/api/grammar/rule_explanation?rule=${encodeURIComponent(ruleText || '')}&context=${encodeURIComponent(contextText || '')}&sutra_code=${encodeURIComponent(sutraCode || '')}`;
  const data = await apiGet(url);

  const sutras = data.sutras || [];
  const dicts = data.dict_entries || [];
  const meter = data.chandas_meter;

  let html = '';

  // 1. Chandas Meter Lakshana Header (if applicable)
  if (meter) {
    html += `
      <div class="published-source-card">
        <div class="published-source-header">
          <span class="published-source-title">📐 Piṅgala Chandaḥśāstra &amp; Vṛttaratnākara Lakṣaṇa</span>
          <span class="published-source-cite">Classical Prosody Definition</span>
        </div>
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:8px;">
          <div class="indic" style="font-size:18px; font-weight:700; color:var(--accent-primary);">
            ${fmt(meter.name_sa)} — ${escapeHtml(meter.name_en)}
          </div>
          <span class="badge">${meter.syllables ? meter.syllables + ' syllables / pāda' : 'Mātrā-vṛtta'} · Gaṇas: ${escapeHtml(meter.ganas)}</span>
        </div>
        ${meter.lakshana ? `<div class="indic" style="margin-top:6px; font-size:15px; font-weight:600;">लक्षणम्: ${fmt(meter.lakshana)}</div>` : ''}
      </div>
    `;
  }

  // 2. Verbatim Published Paninian Sutras (S.C. Vasu 1891 & Ashtadhyayi.com Sutrartha)
  if (sutras.length > 0) {
    html += sutras.map(s => {
      const pcClean = (s.padaccheda || '').replace(/\$[A-Z]\$\d\$\d\$/g, '').replace(/##/g, ' · ');
      const anuvrittiClean = (s.anuvritti || '').replace(/\$/g, ' ').replace(/##/g, ', ');
      return `
        <div class="published-source-card">
          <div class="published-source-header">
            <span class="published-source-title">🏛️ Pāṇini's Aṣṭādhyāyī Sūtra ${escapeHtml(s.code)} — Published English Translation &amp; Commentary</span>
            <div style="display:flex; gap:6px; align-items:center;">
              <span class="published-source-cite">Srisa Chandra Vasu (1891) &amp; Ashtadhyayi Corpus</span>
              <button class="btn btn-sm" onclick="closeRuleExplanationModal(); openSutraFromAnywhere('${escapeHtml(s.code)}')">Open Sūtra ${escapeHtml(s.code)} →</button>
            </div>
          </div>

          <div class="indic" style="font-size:20px; font-weight:700; color:var(--accent-primary); margin-bottom:4px;">
            ${fmt(s.sutra, s.sutra_te, s.sutra_iast)} <span class="badge">${escapeHtml(s.code)}</span>
          </div>

          ${pcClean ? `<div style="font-size:12.5px; color:var(--text-secondary); margin-bottom:6px;"><strong>पदच्छेदः:</strong> ${fmt(pcClean)} ${anuvrittiClean ? ` | <strong>अनुवृत्तिः:</strong> ${fmt(anuvrittiClean)}` : ''}</div>` : ''}

          ${s.sutrartha_en ? `
            <div style="background:var(--bg-panel); border:1px solid var(--border-color); border-radius:6px; padding:9px 12px; margin-top:6px;">
              <div style="font-size:11px; font-weight:700; color:var(--accent-secondary); text-transform:uppercase; margin-bottom:3px;">
                Published English Sūtrārtha (Ashtadhyayi Corpus)
              </div>
              <div style="font-size:14px; font-weight:600; line-height:1.55;">${s.sutrartha_en}</div>
            </div>
          ` : ''}

          ${s.vasu_en ? `
            <div style="background:var(--bg-panel); border:1px solid var(--border-color); border-radius:6px; padding:10px 12px; margin-top:8px;">
              <div style="font-size:11px; font-weight:700; color:var(--accent-secondary); text-transform:uppercase; margin-bottom:4px;">
                Srisa Chandra Vasu — "The Ashtadhyayi of Panini" (Published 1891, Allahabad)
              </div>
              <div style="font-size:13.5px; line-height:1.65;">${s.vasu_en}</div>
            </div>
          ` : ''}

          ${s.sutrartha_sa ? `
            <div style="margin-top:8px; font-size:14px;" class="indic">
              <strong>संस्कृत-सूत्रार्थः:</strong> ${fmt(s.sutrartha_sa, s.sutrartha_te)}
            </div>
          ` : ''}

          ${s.laghukaumudi ? `
            <details style="margin-top:6px; font-size:13px;">
              <summary style="cursor:pointer; font-weight:600; color:var(--accent-secondary);">लघुसिद्धान्तकौमुदी &amp; काशिकावृत्तिः (Original Sanskrit Vṛttis)</summary>
              <div class="indic" style="margin-top:6px; padding:8px; background:var(--bg-panel); border-radius:6px; white-space:pre-wrap;">${fmt(s.laghukaumudi)}</div>
              ${s.kashika ? `<div class="indic" style="margin-top:6px; padding:8px; background:var(--bg-panel); border-radius:6px; white-space:pre-wrap;"><strong>काशिका:</strong> ${fmt(s.kashika)}</div>` : ''}
            </details>
          ` : ''}
        </div>
      `;
    }).join('');
  }

  // 3. Verbatim Published Dictionary Entries (K.V. Abhyankar 1961, Apte 1890, Monier-Williams 1899, Macdonell 1929, Wilson 1832)
  const dictSourceCitations = {
    abhyankar: "Prof. K.V. Abhyankar — A Dictionary of Sanskrit Grammar (Oriental Institute, Baroda, 1961)",
    wil: "Prof. H.H. Wilson — A Dictionary in Sanscrit and English (Calcutta, 1832)",
    md: "A.A. Macdonell — A Sanskrit-English Dictionary (1893)",
    ap90: "V.S. Apte — The Practical Sanskrit-English Dictionary (Poona, 1890)",
    mw: "Sir Monier Monier-Williams — A Sanskrit-English Dictionary (Oxford University Press, 1899)",
    cae: "Prof. Carl Cappeller — A Sanskrit-English Dictionary (Strassburg, 1891)"
  };

  if (dicts.length > 0) {
    html += dicts.map(d => `
      <div class="published-source-card">
        <div class="published-source-header">
          <span class="published-source-title">📚 ${escapeHtml(dictSourceCitations[d.dict_code] || d.name_en || d.name_sa)}</span>
          <span class="published-source-cite">Headword: ${escapeHtml(d.headword)} (${d.dict_code.toUpperCase()})</span>
        </div>
        <div style="margin-bottom:4px;">
          <strong class="indic" style="font-size:16px; color:var(--accent-primary);">${fmt(d.headword, d.headword_te, d.headword_iast)}</strong>
        </div>
        <div class="rule-def-wrap">${renderDefinition(d, { size: 13.5 })}</div>
      </div>
    `).join('');
  }

  if (!html) {
    html = `
      <div class="card">
        <p>No direct entry found under "<strong>${escapeHtml(ruleText)}</strong>". Click below to search all Aṣṭādhyāyī sūtras or all dictionaries:</p>
        <div style="display:flex; gap:8px; margin-top:8px;">
          <button class="btn btn-primary" onclick="closeRuleExplanationModal(); switchStageView('view-sutra'); runSutraOrVyakaranaSearch('${escapeHtml(ruleText)}')">Search in Aṣṭādhyāyī Sūtrapāṭha →</button>
          <button class="btn" onclick="closeRuleExplanationModal(); openFullDictionarySearch('${escapeHtml(ruleText)}')">Search all dictionaries →</button>
        </div>
      </div>
    `;
  }

  bodyEl.innerHTML = html;
  applyScriptToDefinitions(bodyEl);
};

window.closeRuleExplanationModal = function() {
  const modal = document.getElementById('ruleExplanationModal');
  if (modal) modal.classList.remove('open');
};

// ============================================================================
// 10. VIEW 7: SANSKRITABHYAS GRAMMAR & CHANDAS LAB (With Clickable Rules)
// ============================================================================

async function loadAbhyasModules() {
  const data = await apiGet('/api/abhyas/list');
  AppState.abhyasModules = data.modules || [];
  renderAbhyasTab();
}

function renderAbhyasTab() {
  const container = document.getElementById('abhyasBodyContainer');
  if (!container) return;
  const view = AppState.activeAbhyasView;

  if (view === 'interactive-tools') {
    container.innerHTML = `
      <div class="grid-2col">
        <!-- Interactive Sandhi Joiner & Splitter -->
        <div class="card">
          <div class="card-header">
            <span class="card-title">🔗 Interactive Pāṇinian Sandhi Joiner &amp; Splitter</span>
            <span class="badge">Phonetic Typing Enabled · Click Any Rule for Published English Explanation</span>
          </div>

          <div style="background:var(--bg-subtle); padding:12px; border-radius:7px; margin-bottom:12px;">
            <div style="font-weight:700; font-size:13px; margin-bottom:6px;">1. Sandhi Join (सन्धियोजनम्: पूर्वपदम् + परपदम् — Type in Sanskrit or Phonetic e.g. iti + Adi)</div>
            <div style="display:flex; gap:6px; align-items:center; flex-wrap:wrap;">
              <input type="text" id="sandhiPada1Input" value="इति" placeholder="पूर्वपदम् (e.g. इति / iti, विद्या / vidyA, तत् / tat)" style="flex:1;" />
              <strong>+</strong>
              <input type="text" id="sandhiPada2Input" value="आदि" placeholder="परपदम् (e.g. आदि / Adi, आलयः / AlayaH)" style="flex:1;" />
              <button class="btn btn-primary" id="runSandhiJoinBtn">Join</button>
            </div>
            <div id="sandhiJoinOutput" style="margin-top:8px;"></div>
          </div>

          <div style="background:var(--bg-subtle); padding:12px; border-radius:7px;">
            <div style="font-weight:700; font-size:13px; margin-bottom:6px;">2. Sandhi Split (सन्धिविच्छेदः: समस्तपदम् → पूर्वपदम् + परपदम् — e.g. devalayaH, ityadi)</div>
            <div style="display:flex; gap:6px; align-items:center;">
              <input type="text" id="sandhiSplitWordInput" value="देवालयः" placeholder="Enter joined word in Sanskrit or Phonetic (e.g. देवालयः / devalayaH, इत्यादि / ityadi)..." style="flex:1;" />
              <button class="btn btn-primary" id="runSandhiSplitBtn">Split</button>
            </div>
            <div id="sandhiSplitOutput" style="margin-top:8px;"></div>
          </div>
        </div>

        <!-- Interactive Chandas (Prosody / Meter) Scanner -->
        <div class="card">
          <div class="card-header">
            <span class="card-title">📐 Chandas Prosody &amp; Laghu-Guru Scanner</span>
            <span class="badge">Click Any Meter for Published English Explanation</span>
          </div>
          <textarea id="chandasLabInput" rows="3" style="width:100%; font-size:15px;" class="indic" placeholder="Paste Sanskrit verse or type phonetically (e.g. vagartaaviva sampriktau)...">निन्दन्तु नीतिनिपुणा यदि वा स्तुवन्तु
लक्ष्मीः समाविशतु गच्छतु वा यथेष्टम् ।</textarea>
          <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:6px; margin-top:8px;">
            <div style="display:flex; gap:5px; flex-wrap:wrap;">
              <button class="btn btn-sm" onclick="loadSampleVerse('anushtubh')">अनुष्टुभ्</button>
              <button class="btn btn-sm" onclick="loadSampleVerse('vasantatilaka')">वसन्ततिलका</button>
              <button class="btn btn-sm" onclick="loadSampleVerse('mandakranta')">मन्दाक्रान्ता</button>
              <button class="btn btn-sm" onclick="loadSampleVerse('shardula')">शार्दूलविक्रीडितम्</button>
              <button class="btn btn-sm" onclick="loadSampleVerse('bhujanga')">भुजङ्गप्रयातम्</button>
            </div>
            <button class="btn btn-primary" id="runChandasLabBtn">Scan Meter</button>
          </div>
          <div id="chandasLabOutput" style="margin-top:10px;"></div>
        </div>
      </div>

      <!-- Classical Chandas Prosody Reference Table (All 22 Meters — Clickable for Published English Explanations) -->
      <div class="card">
        <div class="card-header">
          <div>
            <span class="card-title">📐 Classical Chandas Prosody Reference (छन्दःशास्त्र-वृत्तरत्नाकरः)</span>
            <span class="badge" style="margin-left:8px;">Click any Chandas rule/meter to view published English explanation (Wilson 1832 · Macdonell 1929 · Apte 1890 · Monier-Williams 1899)</span>
          </div>
        </div>
        <table class="grammar-table">
          <thead>
            <tr>
              <th>Meter (छन्दः)</th>
              <th>English Name</th>
              <th>Syllables / Pāda</th>
              <th>Gaṇa Pattern (गणलक्षणम्)</th>
              <th>Classical Lakṣaṇa Sūtra</th>
              <th>Published Explanation</th>
            </tr>
          </thead>
          <tbody>
            ${CLASSICAL_CHANDAS_REFERENCE.map(m => `
              <tr class="clickable-rule" onclick="openRuleExplanationModal('${escapeHtml(m.name_sa)}', '${escapeHtml(m.lakshana)}')">
                <td><strong class="indic" style="color:var(--accent-primary); font-size:15px;">${fmt(m.name_sa)}</strong></td>
                <td><strong>${escapeHtml(m.name_en)}</strong></td>
                <td><span class="badge">${escapeHtml(String(m.syllables))}</span></td>
                <td>${escapeHtml(m.ganas)}</td>
                <td class="indic">${fmt(m.lakshana)}</td>
                <td>
                  <button class="explain-rule-btn" onclick="event.stopPropagation(); openRuleExplanationModal('${escapeHtml(m.name_sa)}', '${escapeHtml(m.lakshana)}')">
                    📖 English Explanation
                  </button>
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;

    document.getElementById('runSandhiJoinBtn').addEventListener('click', runSandhiJoin);
    document.getElementById('runSandhiSplitBtn').addEventListener('click', runSandhiSplit);
    document.getElementById('runChandasLabBtn').addEventListener('click', runChandasLab);

    PhoneticSearchHelper.attach(document.getElementById('sandhiPada1Input'), () => runSandhiJoin());
    PhoneticSearchHelper.attach(document.getElementById('sandhiPada2Input'), () => runSandhiJoin());
    PhoneticSearchHelper.attach(document.getElementById('sandhiSplitWordInput'), () => runSandhiSplit());
    PhoneticSearchHelper.attach(document.getElementById('chandasLabInput'), () => runChandasLab());

    runSandhiJoin();
    runSandhiSplit();
    runChandasLab();
    return;
  }

  const mod = AppState.abhyasModules.find(m => m.id === view);
  if (!mod) return;

  container.innerHTML = `
    <div class="card" style="background:var(--bg-elevated);">
      <div class="card-header">
        <div>
          <span class="card-title" style="font-size:20px;">${fmt(mod.title_sa, mod.title_te, mod.title_en)}</span>
          <span class="badge" style="margin-left:8px;">${mod.category}</span>
        </div>
        <span class="badge">💡 Click any rule row below to read its verbatim English explanation from published sources (S.C. Vasu 1891 &amp; K.V. Abhyankar 1961)</span>
      </div>
      <p style="font-size:13.5px; color:var(--text-secondary);">${escapeHtml(mod.summary)}</p>
    </div>

    ${(mod.sections || []).map(sec => `
      <div class="card">
        <div class="card-header">
          <span class="card-title" style="font-size:16px;">${fmt(sec.heading)}</span>
          <span class="card-subtitle">Click any rule for published English explanation</span>
        </div>
        <p style="font-size:13px; color:var(--text-secondary); margin-bottom:8px;">${escapeHtml(sec.description || '')}</p>
        <table class="grammar-table">
          <thead>
            <tr>
              ${(sec.headers || []).map(h => `<th>${escapeHtml(h)}</th>`).join('')}
              <th style="width:155px;">Published Source</th>
            </tr>
          </thead>
          <tbody>
            ${(sec.rows || []).map(row => {
              const ruleTitle = row[0] || '';
              const rowContext = row.join(' · ');
              return `
                <tr class="clickable-rule" onclick="openRuleExplanationModal('${escapeHtml(ruleTitle)}', '${escapeHtml(rowContext)}')" title="Click to view verbatim published English explanation for ${escapeHtml(ruleTitle)}">
                  ${row.map((cell, cidx) => `
                    <td class="${cidx === row.length - 1 || cidx === 0 ? 'indic' : ''}">
                      ${cidx === 0 ? `<strong style="color:var(--accent-primary);">${AppState.script === 'telu' ? TranslitEngine.devToTelugu(cell) : escapeHtml(cell)}</strong>` : (AppState.script === 'telu' ? TranslitEngine.devToTelugu(cell) : escapeHtml(cell))}
                    </td>
                  `).join('')}
                  <td>
                    <button class="explain-rule-btn" onclick="event.stopPropagation(); openRuleExplanationModal('${escapeHtml(ruleTitle)}', '${escapeHtml(rowContext)}')">
                      📖 English Explanation
                    </button>
                  </td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>
    `).join('')}
  `;
}

async function runSandhiJoin() {
  const p1El = document.getElementById('sandhiPada1Input');
  const p2El = document.getElementById('sandhiPada2Input');
  if (!p1El || !p2El) return;
  const p1 = p1El.value.trim();
  const p2 = p2El.value.trim();
  const data = await apiGet(`/api/tools/sandhi?mode=join&pada1=${encodeURIComponent(p1)}&pada2=${encodeURIComponent(p2)}`);
  const out = document.getElementById('sandhiJoinOutput');
  if (!out) return;
  out.innerHTML = (data.joins || []).map(j => {
    const codeMatch = (j.sutra || '').match(/(\d+\.\d+\.\d+)/);
    const sCode = codeMatch ? codeMatch[1] : '';
    return `
      <div style="padding:8px 10px; background:var(--bg-panel); border:1px solid var(--border-color); border-radius:6px; margin-top:4px;">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:6px;">
          <span class="indic" style="font-size:18px; font-weight:700; color:var(--accent-primary);">
            ${fmt(j.result, j.result_te, j.result_iast)}
          </span>
          <div style="display:flex; gap:5px;">
            <button class="explain-rule-btn" onclick="openRuleExplanationModal('${escapeHtml(j.sandhi_name)}', '${escapeHtml(j.sutra)}', '${escapeHtml(sCode)}')">
              📖 Published English Explanation
            </button>
            <button class="btn btn-sm" onclick="insertIntoActiveField('${escapeHtml(j.result)}')">＋ Insert</button>
          </div>
        </div>
        <div style="font-size:12px; margin-top:4px; display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
          <span class="badge clickable-form" onclick="openRuleExplanationModal('${escapeHtml(j.sandhi_name)}', '${escapeHtml(j.sutra)}', '${escapeHtml(sCode)}')">${escapeHtml(j.sandhi_name)}</span>
          <span class="badge clickable-form" onclick="openRuleExplanationModal('${escapeHtml(j.sutra)}', '', '${escapeHtml(sCode)}')">${escapeHtml(j.sutra)}</span>
          <strong>${escapeHtml(j.rule)}</strong>
        </div>
        <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">${escapeHtml(j.explanation)}</div>
      </div>
    `;
  }).join('');
}

async function runSandhiSplit() {
  const wEl = document.getElementById('sandhiSplitWordInput');
  if (!wEl) return;
  const w = wEl.value.trim();
  const data = await apiGet(`/api/tools/sandhi?mode=split&word=${encodeURIComponent(w)}`);
  const out = document.getElementById('sandhiSplitOutput');
  if (!out) return;
  const splits = data.splits || [];
  if (splits.length === 0) {
    out.innerHTML = `<div style="font-size:12.5px; color:var(--text-muted);">No sandhi split points detected.</div>`;
    return;
  }
  out.innerHTML = splits.slice(0, 6).map(s => {
    const codeMatch = (s.sutra || '').match(/(\d+\.\d+\.\d+)/);
    const sCode = codeMatch ? codeMatch[1] : '';
    return `
      <div style="padding:7px 10px; background:var(--bg-panel); border:1px solid var(--border-color); border-radius:6px; margin-top:4px; display:flex; justify-content:space-between; align-items:center; gap:8px; flex-wrap:wrap;">
        <div>
          <strong class="indic" style="font-size:15px; color:var(--accent-primary);">${fmt(s.pada1, s.pada1_te, s.pada1_iast)} + ${fmt(s.pada2, s.pada2_te, s.pada2_iast)}</strong>
          <span class="badge clickable-form" style="margin-left:6px;" onclick="openRuleExplanationModal('${escapeHtml(s.sandhi_name)}', '${escapeHtml(s.sutra)}', '${escapeHtml(sCode)}')" title="Click for published English explanation">
            📖 ${escapeHtml(s.sandhi_name)} (${escapeHtml(s.sutra)})
          </span>
        </div>
        <div style="display:flex; gap:4px;">
          <button class="explain-rule-btn" onclick="openRuleExplanationModal('${escapeHtml(s.sandhi_name)}', '${escapeHtml(s.sutra)}', '${escapeHtml(sCode)}')">📖 Rule</button>
          <button class="btn btn-sm" onclick="openFullDictionarySearch('${escapeHtml(s.pada1)}')">🔍 ${escapeHtml(s.pada1)}</button>
          <button class="btn btn-sm" onclick="openFullDictionarySearch('${escapeHtml(s.pada2)}')">🔍 ${escapeHtml(s.pada2)}</button>
        </div>
      </div>
    `;
  }).join('');
}

function loadSampleVerse(type) {
  const samples = {
    anushtubh: "वागर्थाविव संपृक्तौ वागर्थप्रतिपत्तये ।\nजगतः पितरौ वन्दे पार्वतीपरमेश्वरौ ॥",
    vasantatilaka: "निन्दन्तु नीतिनिपुणा यदि वा स्तुवन्तु\nलक्ष्मीः समाविशतु गच्छतु वा यथेष्टम् ।",
    mandakranta: "कश्चित्कान्ताविरहगुरुणा स्वाधिकारात्प्रमत्तः\nशापेनास्तंगमितमहिमा वर्षभोग्येण भर्तुः ।",
    shardula: "ये नाम केचिदिह नः प्रथयन्त्यवज्ञां\nजानन्ति ते किमपि तान्प्रति नैष यत्नः ।",
    bhujanga: "सदा बालरूपापि विघ्नाद्रिहन्त्री\nमहादन्तिवक्त्रापि पञ्चास्यमान्या ।"
  };
  const input = document.getElementById('chandasLabInput');
  if (input && samples[type]) {
    input.value = samples[type];
    runChandasLab();
  }
}

async function runChandasLab() {
  const input = document.getElementById('chandasLabInput');
  if (!input) return;
  const data = await apiPost('/api/tools/chandas', { text: input.value });
  const out = document.getElementById('chandasLabOutput');
  if (!out) return;

  const padas = data.padas || [];
  out.innerHTML = padas.map(p => `
    <div style="padding:8px 10px; background:var(--bg-subtle); border-radius:6px; margin-bottom:8px;">
      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:6px; margin-bottom:4px;">
        <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
          <strong>Line ${p.line_number || p.pada_number} (पंक्तिः ${p.line_number || p.pada_number}):</strong>
          <span class="badge clickable-form" onclick="openRuleExplanationModal('${escapeHtml(p.meter.name_sa)}', '${escapeHtml(p.meter.lakshana || '')}')" title="Click for published English prosody explanation">
            ${fmt(p.meter.name_sa)} — ${escapeHtml(p.meter.name_en)}
          </span>
          <button class="explain-rule-btn" onclick="openRuleExplanationModal('${escapeHtml(p.meter.name_sa)}', '${escapeHtml(p.meter.lakshana || '')}')">
            📖 Explain Meter
          </button>
        </div>
        <span style="font-size:12px; color:var(--text-secondary);">
          ${p.syllable_count} syllables · ${p.matra_count} mātrās · Gaṇas: <strong>${escapeHtml(p.meter.ganas)}</strong>
        </span>
      </div>
      <div class="akshara-pills">
        ${p.aksharas.map((ak, i) => {
          const w = p.weights[i];
          return `<span class="akshara-pill ${w === 'ऽ' ? 'guru' : 'laghu'}">${fmt(ak)} <small>${w}</small></span>`;
        }).join('')}
      </div>
      ${p.meter.lakshana ? `<div style="font-size:11.5px; color:var(--text-secondary); margin-top:4px; cursor:pointer;" onclick="openRuleExplanationModal('${escapeHtml(p.meter.name_sa)}', '${escapeHtml(p.meter.lakshana)}')">लक्षणम्: ${fmt(p.meter.lakshana)} <span style="color:var(--accent-primary); text-decoration:underline;">(View English Explanation)</span></div>` : ''}
    </div>
  `).join('');
}

// ============================================================================
// 11. PHONETIC SEARCH HELPER FOR ALL GRAMMAR & DICTIONARY SEARCH INPUTS
// ============================================================================

const PhoneticSearchHelper = {
  attach(inputEl, onTriggerSearch) {
    if (!inputEl || inputEl.dataset.phoneticAttached === '1') return;
    inputEl.dataset.phoneticAttached = '1';

    const helperBar = document.createElement('div');
    helperBar.className = 'phonetic-search-helper';

    // Insert helperBar right after input's parent toolbar or after input itself
    const parent = inputEl.parentElement;
    if (parent && (parent.classList.contains('toolbar') || parent.style.display === 'flex')) {
      parent.insertAdjacentElement('afterend', helperBar);
    } else {
      inputEl.insertAdjacentElement('afterend', helperBar);
    }

    let currentCandidates = [];
    let debounceTimer = null;

    const updateHelper = () => {
      const val = inputEl.value || '';
      const words = val.split(/(\s+)/);
      const lastWord = words[words.length - 1] || '';

      if (!/[a-zA-Z]/.test(val)) {
        helperBar.classList.remove('visible');
        currentCandidates = [];
        return;
      }

      // Compute multi-word converted string and candidates for the active word
      const fullConvertedDeva = val.split(/(\s+)/).map(tok => {
        if (/^[a-zA-Z~^.|'"]+$/.test(tok)) {
          return TranslitEngine.romanToDev(tok, AppState.scheme === 'direct' ? 'itrans' : AppState.scheme);
        }
        return tok;
      }).join('');

      const cands = TranslitEngine.generateCandidates(
        /[a-zA-Z]/.test(lastWord) ? lastWord : val.trim(),
        AppState.scheme === 'direct' ? 'itrans' : AppState.scheme
      );
      currentCandidates = cands;

      helperBar.classList.add('visible');
      helperBar.innerHTML = `
        <span style="font-weight:700; color:var(--text-secondary);">🔤 Phonetic (${escapeHtml(val.trim())}):</span>
        ${fullConvertedDeva && fullConvertedDeva !== val ? `
          <span class="phonetic-cand-chip" data-replace-full="${escapeHtml(fullConvertedDeva)}" title="Click or press Tab to replace with Sanskrit">
            1. ${escapeHtml(AppState.script === 'telu' ? TranslitEngine.devToTelugu(fullConvertedDeva) : fullConvertedDeva)}
          </span>
        ` : ''}
        ${cands.slice(0, 6).map((c, idx) => {
          const disp = AppState.script === 'telu' ? c.telu : c.deva;
          if (c.deva === fullConvertedDeva) return '';
          return `
            <span class="phonetic-cand-chip" data-replace-last="${escapeHtml(disp)}" title="${escapeHtml(c.deva)} · ${escapeHtml(c.telu)} · ${escapeHtml(c.iast)}">
              ${escapeHtml(disp)}
            </span>
          `;
        }).join('')}
        <span style="font-size:11px; color:var(--text-muted);">[Tab / Click to insert · Enter searches directly]</span>
        <label class="phonetic-mode-toggle" title="When checked, Roman keys convert directly inside search boxes as you type">
          <input type="checkbox" class="in-place-search-toggle" ${AppState.searchInPlaceIME ? 'checked' : ''} />
          ⚡ Auto-Devanagari in box
        </label>
      `;

      helperBar.querySelectorAll('[data-replace-full]').forEach(chip => {
        chip.addEventListener('mousedown', (ev) => {
          ev.preventDefault();
          inputEl.value = chip.getAttribute('data-replace-full');
          helperBar.classList.remove('visible');
          if (onTriggerSearch) onTriggerSearch();
        });
      });

      helperBar.querySelectorAll('[data-replace-last]').forEach(chip => {
        chip.addEventListener('mousedown', (ev) => {
          ev.preventDefault();
          const chosen = chip.getAttribute('data-replace-last');
          const parts = inputEl.value.split(/(\s+)/);
          parts[parts.length - 1] = chosen;
          inputEl.value = parts.join('');
          helperBar.classList.remove('visible');
          if (onTriggerSearch) onTriggerSearch();
        });
      });

      const toggleCb = helperBar.querySelector('.in-place-search-toggle');
      if (toggleCb) {
        toggleCb.addEventListener('change', (ev) => {
          AppState.searchInPlaceIME = ev.target.checked;
          if (AppState.searchInPlaceIME && fullConvertedDeva) {
            inputEl.value = AppState.script === 'telu' ? TranslitEngine.devToTelugu(fullConvertedDeva) : fullConvertedDeva;
            helperBar.classList.remove('visible');
            if (onTriggerSearch) onTriggerSearch();
          }
        });
      }
    };

    inputEl.addEventListener('input', () => {
      updateHelper();
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        if (onTriggerSearch) onTriggerSearch();
      }, 220);
    });

    inputEl.addEventListener('keydown', (e) => {
      if (e.key === 'Tab' && currentCandidates.length > 0 && /[a-zA-Z]/.test(inputEl.value)) {
        e.preventDefault();
        const best = currentCandidates[0];
        const disp = AppState.script === 'telu' ? best.telu : best.deva;
        const parts = inputEl.value.split(/(\s+)/);
        parts[parts.length - 1] = disp;
        inputEl.value = parts.join('');
        helperBar.classList.remove('visible');
        if (onTriggerSearch) onTriggerSearch();
      }
    });

    inputEl.addEventListener('blur', () => {
      setTimeout(() => helperBar.classList.remove('visible'), 200);
    });
  }
};

// ============================================================================
// 12. COMPOSITIONS CRUD, DIRECT IN-PLACE PHONETIC IME & TRANSLITERATION BAR
// ============================================================================

const EditorIME = {
  romanBuffer: '',
  startPos: 0,
  renderedLen: 0,
  candidates: [],
  candidateIndex: 0,
  fetchTimer: null,

  reset() {
    this.romanBuffer = '';
    this.renderedLen = 0;
    this.candidates = [];
    this.candidateIndex = 0;
    this.updateIndicator();
    this.renderTranslitOptionsBar();
  },

  updateIndicator(indicPreview = '') {
    const ind = document.getElementById('liveTypingIndicator');
    if (!ind) return;
    if (AppState.scheme === 'direct') {
      ind.textContent = '⌨️ Direct Unicode';
      return;
    }
    const schemeLabel = AppState.scheme.toUpperCase();
    if (this.romanBuffer && indicPreview) {
      ind.textContent = `⌨️ ${this.romanBuffer} → ${indicPreview}`;
    } else {
      ind.textContent = `⌨️ Direct Typing: ${schemeLabel}`;
    }
  },

  formatForActiveScript(devaStr) {
    if (!devaStr) return '';
    if (AppState.script === 'telu') return TranslitEngine.devToTelugu(devaStr);
    if (AppState.script === 'iast') return TranslitEngine.devToIast(devaStr);
    return devaStr;
  },

  replaceActiveWord(chosenText) {
    const textarea = document.getElementById('sanskritEditor');
    if (!textarea || !chosenText) return;
    const val = textarea.value;
    textarea.value = val.slice(0, this.startPos) + chosenText + val.slice(this.startPos + this.renderedLen);
    this.renderedLen = chosenText.length;
    textarea.focus();
    textarea.selectionStart = textarea.selectionEnd = this.startPos + this.renderedLen;
    this.updateIndicator(chosenText);
    updateEditorLiveChandas();
  },

  renderTranslitOptionsBar() {
    const strip = document.getElementById('studioTranslitCandidates');
    if (!strip) return;

    // Case 1: Actively typing a phonetic word in the document editor
    if (this.romanBuffer && AppState.scheme !== 'direct') {
      const localCands = TranslitEngine.generateCandidates(this.romanBuffer, AppState.scheme);
      this.candidates = localCands;
      this.renderCandidatePills(strip, localCands);

      // Also fetch lexicon/Shabdapatha-enriched candidates from offline server
      clearTimeout(this.fetchTimer);
      const bufSnapshot = this.romanBuffer;
      this.fetchTimer = setTimeout(async () => {
        if (this.romanBuffer !== bufSnapshot) return;
        const data = await apiPost('/api/tools/transliterate', { text: bufSnapshot, scheme: AppState.scheme });
        if (this.romanBuffer !== bufSnapshot) return;
        if (data.candidates && data.candidates.length > 0) {
          const merged = [];
          const seen = new Set();
          [...localCands, ...data.candidates].forEach(c => {
            if (c && c.deva && !seen.has(c.deva)) {
              seen.add(c.deva);
              merged.push(c);
            }
          });
          this.candidates = merged.slice(0, 9);
          this.renderCandidatePills(strip, this.candidates);
        }
      }, 75);
      return;
    }

    // Case 2: Idle / between words — show Quick Sanskrit Punctuation, Diacritics & Active Word Script Options
    const editor = document.getElementById('sanskritEditor');
    let wordNearCursor = '';
    if (editor && editor.value) {
      const before = editor.value.slice(0, editor.selectionStart || 0);
      const m = before.match(/([^\s।॥,.\-!?()\[\]"']+)$/);
      if (m) wordNearCursor = m[1];
    }

    const quickSymbols = [
      { label: '। Daṇḍa', insert: ' । ' },
      { label: '॥ Double Daṇḍa', insert: ' ॥ ' },
      { label: 'ऽ Avagraha', insert: 'ऽ' },
      { label: 'ं Anusvāra', insert: 'ं' },
      { label: 'ः Visarga', insert: 'ः' },
      { label: '् Halanta', insert: '्' },
      { label: 'ॐ Oṃ', insert: 'ॐ ' }
    ];

    let wordOptionsHtml = '';
    if (wordNearCursor) {
      const devW = TranslitEngine.teluguToDev(wordNearCursor);
      const telW = TranslitEngine.devToTelugu(devW);
      const iastW = TranslitEngine.devToIast(devW);
      wordOptionsHtml = `
        <span style="font-size:11.5px; font-weight:700; color:var(--accent-secondary); margin-right:2px;">Word "${escapeHtml(wordNearCursor)}":</span>
        <span class="translit-cand-pill" onclick="runStudioAssistantLookup('${escapeHtml(devW)}')" title="Inspect meaning, Dhātu, Śabda &amp; Sandhi">🔍 Inspect</span>
        <span class="translit-cand-pill" onclick="insertIntoActiveField('ः')" title="Append Visarga (ः)">+ ः</span>
        <span class="translit-cand-pill" onclick="insertIntoActiveField('म्')" title="Append Anusvāra/Makāra (+म्)">+ म्</span>
        <span class="translit-cand-pill" title="Telugu: ${escapeHtml(telW)} · IAST: ${escapeHtml(iastW)}" onclick="navigator.clipboard && navigator.clipboard.writeText('${escapeHtml(iastW)}')">
          <span class="translit-cand-sub">${escapeHtml(telW)} · ${escapeHtml(iastW)}</span>
        </span>
        <span style="color:var(--border-strong); margin:0 4px;">|</span>
      `;
    }

    strip.innerHTML = `
      ${wordOptionsHtml}
      <span class="translit-hint">Quick Insert:</span>
      ${quickSymbols.map(q => `
        <span class="translit-cand-pill" data-quick-insert="${escapeHtml(q.insert)}" title="Click to insert ${escapeHtml(q.label)}">
          ${escapeHtml(q.label)}
        </span>
      `).join('')}
    `;

    strip.querySelectorAll('[data-quick-insert]').forEach(pill => {
      pill.addEventListener('mousedown', (ev) => {
        ev.preventDefault();
        AppState.activeInputEl = document.getElementById('sanskritEditor');
        insertIntoActiveField(pill.getAttribute('data-quick-insert'));
      });
    });
  },

  renderCandidatePills(strip, candidates) {
    if (!candidates || candidates.length === 0) return;

    // Also include explicit Telugu & IAST script pills for the primary candidate
    const primary = candidates[0];
    const pillsHtml = candidates.slice(0, 8).map((c, idx) => {
      const targetText = this.formatForActiveScript(c.deva);
      const isSelected = idx === this.candidateIndex;
      const subText = AppState.script === 'telu' ? c.deva : c.telu;
      return `
        <span class="translit-cand-pill ${isSelected ? 'active-cand' : ''}" data-cand-text="${escapeHtml(targetText)}" title="Devanagari: ${escapeHtml(c.deva)} | Telugu: ${escapeHtml(c.telu)} | IAST: ${escapeHtml(c.iast)} (Press ${idx + 1} or Click)">
          <span class="translit-cand-num">${idx + 1}</span>
          <span>${escapeHtml(targetText)}</span>
          <span class="translit-cand-sub">${escapeHtml(subText)}</span>
        </span>
      `;
    }).join('');

    const scriptAltHtml = primary ? `
      <span style="color:var(--border-strong); margin:0 2px;">|</span>
      <span class="translit-cand-pill" data-cand-text="${escapeHtml(primary.telu)}" title="Insert in Telugu script">
        <span class="translit-cand-num">TE</span> ${escapeHtml(primary.telu)}
      </span>
      <span class="translit-cand-pill" data-cand-text="${escapeHtml(primary.iast)}" title="Insert in IAST Roman Diacritics">
        <span class="translit-cand-num">IAST</span> ${escapeHtml(primary.iast)}
      </span>
    ` : '';

    strip.innerHTML = `
      ${pillsHtml}
      ${scriptAltHtml}
      <span class="translit-hint" style="margin-left:4px;">[Tab / 1-8 to choose · Space to keep]</span>
    `;

    strip.querySelectorAll('[data-cand-text]').forEach(pill => {
      pill.addEventListener('mousedown', (ev) => {
        ev.preventDefault();
        const chosen = pill.getAttribute('data-cand-text');
        this.replaceActiveWord(chosen);
      });
    });
  },

  attach(textarea) {
    if (!textarea) return;

    textarea.addEventListener('mousedown', () => setTimeout(() => this.reset(), 10));
    textarea.addEventListener('blur', () => setTimeout(() => this.reset(), 180));
    textarea.addEventListener('paste', () => setTimeout(() => this.reset(), 0));

    textarea.addEventListener('keydown', (e) => {
      if (AppState.scheme === 'direct' || e.ctrlKey || e.metaKey || e.altKey) {
        this.reset();
        return;
      }

      // Tab cycles through live transliteration candidates for the current word!
      if (e.key === 'Tab' && this.romanBuffer.length > 0 && this.candidates.length > 0) {
        e.preventDefault();
        this.candidateIndex = (this.candidateIndex + 1) % Math.min(this.candidates.length, 8);
        const chosen = this.formatForActiveScript(this.candidates[this.candidateIndex].deva);
        this.replaceActiveWord(chosen);
        const strip = document.getElementById('studioTranslitCandidates');
        if (strip) this.renderCandidatePills(strip, this.candidates);
        return;
      }

      // Number keys 1-8 select the corresponding transliteration candidate while typing a word
      if (/^[1-8]$/.test(e.key) && this.romanBuffer.length > 0 && this.candidates.length > 0) {
        const idx = Number(e.key) - 1;
        if (this.candidates[idx]) {
          e.preventDefault();
          this.candidateIndex = idx;
          const chosen = this.formatForActiveScript(this.candidates[idx].deva);
          this.replaceActiveWord(chosen);
          this.reset();
          return;
        }
      }

      if (e.key === 'Backspace') {
        if (
          this.romanBuffer.length > 0 &&
          textarea.selectionStart === textarea.selectionEnd &&
          textarea.selectionStart === this.startPos + this.renderedLen
        ) {
          e.preventDefault();
          this.romanBuffer = this.romanBuffer.slice(0, -1);
          this.candidateIndex = 0;
          const devWord = TranslitEngine.romanToDev(this.romanBuffer, AppState.scheme);
          const indicWord = this.formatForActiveScript(devWord);
          const val = textarea.value;
          textarea.value = val.slice(0, this.startPos) + indicWord + val.slice(this.startPos + this.renderedLen);
          this.renderedLen = indicWord.length;
          textarea.selectionStart = textarea.selectionEnd = this.startPos + this.renderedLen;
          this.updateIndicator(indicWord);
          this.renderTranslitOptionsBar();
          updateEditorLiveChandas();
          return;
        }
        this.reset();
        return;
      }

      if (
        [' ', 'Enter', 'Escape', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown'].includes(e.key)
      ) {
        setTimeout(() => this.reset(), 0);
        return;
      }

      if (e.key.length === 1) {
        const isPhoneticChar = /^[a-zA-Z~^.|'"]$/.test(e.key);
        if (!isPhoneticChar) {
          this.reset();
          return;
        }

        e.preventDefault();

        // Replace any active selection first
        if (textarea.selectionStart !== textarea.selectionEnd) {
          const s = textarea.selectionStart;
          const end = textarea.selectionEnd;
          textarea.value = textarea.value.slice(0, s) + textarea.value.slice(end);
          textarea.selectionStart = textarea.selectionEnd = s;
          this.reset();
        }

        if (this.romanBuffer === '' || textarea.selectionStart !== this.startPos + this.renderedLen) {
          this.startPos = textarea.selectionStart;
          this.renderedLen = 0;
          this.romanBuffer = '';
          this.candidateIndex = 0;
        }

        this.romanBuffer += e.key;
        const devWord = TranslitEngine.romanToDev(this.romanBuffer, AppState.scheme);
        const indicWord = this.formatForActiveScript(devWord);

        const val = textarea.value;
        textarea.value = val.slice(0, this.startPos) + indicWord + val.slice(this.startPos + this.renderedLen);
        this.renderedLen = indicWord.length;
        textarea.selectionStart = textarea.selectionEnd = this.startPos + this.renderedLen;
        this.updateIndicator(indicWord);
        this.renderTranslitOptionsBar();
        updateEditorLiveChandas();
      }
    });
  }
};

let chandasTimer = null;
function updateEditorLiveChandas() {
  clearTimeout(chandasTimer);
  chandasTimer = setTimeout(async () => {
    const editor = document.getElementById('sanskritEditor');
    if (!editor) return;
    const content = editor.value.trim();
    const badge = document.getElementById('liveMeterBadge');
    const stats = document.getElementById('liveSyllableStats');
    const pills = document.getElementById('liveChandasPadas');

    if (!content) {
      if (badge) badge.textContent = '—';
      if (stats) stats.textContent = '0 lines · 0 syllables';
      if (pills) pills.innerHTML = `<div style="font-size:12px; color:var(--text-muted);">Type directly in the document space above to see live line-by-line Chandas meter &amp; Laghu/Guru syllables.</div>`;
      return;
    }

    const data = await apiPost('/api/tools/chandas', { text: content });
    const padas = data.padas || [];

    if (data.primary_meter && badge) {
      const uniqueMeters = [...new Set(padas.map(p => p.meter && p.meter.name_sa).filter(Boolean))];
      badge.textContent = uniqueMeters.length <= 2
        ? uniqueMeters.join(' · ')
        : `${data.primary_meter.name_sa} (${padas.length} lines)`;
      badge.style.cursor = 'pointer';
      badge.title = 'Click for published English explanation of this Chandas meter';
      badge.onclick = () => openRuleExplanationModal(data.primary_meter.name_sa, data.primary_meter.lakshana || '');
      stats.textContent = `${padas.length} ${padas.length === 1 ? 'line' : 'lines'} · ${data.total_syllables} syllables · ${data.total_matras} mātrās`;
    }

    if (pills) {
      pills.innerHTML = padas.map(p => {
        const lineNum = p.line_number || p.pada_number;
        return `
          <div class="chandas-line-row">
            <div class="chandas-line-header">
              <div style="display:flex; align-items:center; gap:5px; flex-wrap:wrap;">
                <span class="chandas-line-num">Line ${lineNum} (पंक्तिः ${lineNum}):</span>
                <span class="badge clickable-form" onclick="openRuleExplanationModal('${escapeHtml(p.meter.name_sa)}', '${escapeHtml(p.meter.lakshana || '')}')" title="Click for published English prosody explanation">
                  📖 ${fmt(p.meter.name_sa)} — ${escapeHtml(p.meter.name_en)}
                </span>
              </div>
              <span style="color:var(--text-secondary);">
                <strong>${p.syllable_count}</strong> अक्षराणि · <strong>${p.matra_count}</strong> मात्राः · गणः: <strong>${escapeHtml(p.meter.ganas)}</strong>
              </span>
            </div>
            <div class="akshara-pills">
              ${p.aksharas.map((ak, i) => {
                const w = p.weights[i];
                return `<span class="akshara-pill ${w === 'ऽ' ? 'guru' : 'laghu'}">${fmt(ak)}<small>${w}</small></span>`;
              }).join('')}
            </div>
          </div>
        `;
      }).join('');
    }
  }, 180);
}

// Global Navigation Helpers
window.openDhatuFromAnywhere = function(baseindex) {
  switchStageView('view-dhatu');
  loadDhatuDetail(baseindex);
};

window.openShabdaFromAnywhere = function(urlid) {
  switchStageView('view-shabda');
  loadShabdaDetail(urlid);
};

window.openSutraFromAnywhere = function(code) {
  switchStageView('view-sutra');
  document.getElementById('vyakaranaModeSelect').value = 'sutrapatha';
  loadSutraDetail(code);
};

window.openFullDictionarySearch = function(word) {
  switchStageView('view-dictionary');
  runDictionarySearch(word);
};

window.runStudioAssistantLookup = runStudioAssistantLookup;
window.insertIntoActiveField = insertIntoActiveField;
window.loadDhatuDetail = loadDhatuDetail;
window.loadShabdaDetail = loadShabdaDetail;
window.loadSutraDetail = loadSutraDetail;
window.switchDhatuSubTab = switchDhatuSubTab;
window.loadSampleVerse = loadSampleVerse;

// ============================================================================
// 13. INITIALIZATION
// ============================================================================

async function loadSystemStats() {
  const data = await apiGet('/api/stats');
  AppState.stats = data;
  AppState.dictionaries = data.dictionaries || [];
  const navCount = document.getElementById('navDictCount');
  if (navCount) navCount.textContent = String(dictionaryTotals().dictionaries);
  populateDictBookSelect();
  renderFontHelpTab();
}

function syncScriptSelectors(newScript) {
  AppState.script = newScript;
  const globalSel = document.getElementById('globalScriptSelect');
  const studioSel = document.getElementById('studioScriptSelect');
  if (globalSel && globalSel.value !== newScript) globalSel.value = newScript;
  if (studioSel && studioSel.value !== newScript) studioSel.value = newScript;

  renderFontHelpDrawer();
  EditorIME.renderTranslitOptionsBar();
  runStudioAssistantLookup();
  runDictionarySearch();
  if (AppState.currentDhatuDetail) renderDhatuDetail();
  renderAbhyasTab();
  renderFontHelpTab();
  updateEditorLiveChandas();
}

function syncSchemeSelectors(newScheme) {
  AppState.scheme = newScheme;
  const globalSel = document.getElementById('phoneticSchemeSelect');
  const studioSel = document.getElementById('studioSchemeSelect');
  if (globalSel && globalSel.value !== newScheme) globalSel.value = newScheme;
  if (studioSel && studioSel.value !== newScheme) studioSel.value = newScheme;
  EditorIME.reset();
}

document.addEventListener('DOMContentLoaded', async () => {
  const editor = document.getElementById('sanskritEditor');
  AppState.activeInputEl = editor;

  document.querySelectorAll('input[type="text"], textarea').forEach(el => {
    el.addEventListener('focus', () => { AppState.activeInputEl = el; });
  });

  // Left Sidebar Navigation
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
      switchStageView(btn.getAttribute('data-view'));
    });
  });

  // Global & Studio Script Selectors (Synced)
  document.getElementById('globalScriptSelect').addEventListener('change', (e) => syncScriptSelectors(e.target.value));
  const studioScriptSel = document.getElementById('studioScriptSelect');
  if (studioScriptSel) {
    studioScriptSel.addEventListener('change', (e) => syncScriptSelectors(e.target.value));
  }

  // Global & Studio Phonetic Scheme Selectors (Synced)
  document.getElementById('phoneticSchemeSelect').addEventListener('change', (e) => syncSchemeSelectors(e.target.value));
  const studioSchemeSel = document.getElementById('studioSchemeSelect');
  if (studioSchemeSel) {
    studioSchemeSel.addEventListener('change', (e) => syncSchemeSelectors(e.target.value));
  }

  // FontHelp Keyboard Drawer (from Top Header & Studio Toolbar)
  document.getElementById('toggleFontHelpDrawerBtn').addEventListener('click', () => {
    document.getElementById('fontHelpDrawer').classList.toggle('open');
  });
  const studioKeyMapBtn = document.getElementById('studioKeyMapBtn');
  if (studioKeyMapBtn) {
    studioKeyMapBtn.addEventListener('click', () => {
      document.getElementById('fontHelpDrawer').classList.toggle('open');
    });
  }
  document.getElementById('closeFontHelpDrawerBtn').addEventListener('click', () => {
    document.getElementById('fontHelpDrawer').classList.remove('open');
  });

  // Rule Explanation Modal Close Listeners
  const closeRuleModalBtn = document.getElementById('closeRuleModalBtn');
  if (closeRuleModalBtn) {
    closeRuleModalBtn.addEventListener('click', closeRuleExplanationModal);
  }
  const ruleModal = document.getElementById('ruleExplanationModal');
  if (ruleModal) {
    ruleModal.addEventListener('click', (e) => {
      if (e.target === ruleModal) closeRuleExplanationModal();
    });
  }
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeRuleExplanationModal();
  });

  // Theme Toggle
  document.getElementById('toggleThemeBtn').addEventListener('click', () => {
    document.body.classList.toggle('dark-theme');
  });

  // Attach Direct In-Place Phonetic Typing IME & Live Transliteration Options Bar to the Document Editor
  EditorIME.attach(editor);
  EditorIME.updateIndicator();
  EditorIME.renderTranslitOptionsBar();

  // Attach Phonetic Search Helper to all Grammar, Dictionary & Reference Search Inputs
  PhoneticSearchHelper.attach(document.getElementById('studioQuickLookupInput'), () => runStudioAssistantLookup());
  PhoneticSearchHelper.attach(document.getElementById('dictSearchInput'), () => runDictionarySearch());
  PhoneticSearchHelper.attach(document.getElementById('koshaVerseSearchInput'), () => loadKoshaBrowser(false));
  PhoneticSearchHelper.attach(document.getElementById('dhatuSearchInput'), () => searchDhatus());
  PhoneticSearchHelper.attach(document.getElementById('shabdaSearchInput'), () => searchShabdas());
  PhoneticSearchHelper.attach(document.getElementById('customShabdaStemInput'), () => generateCustomShabda());
  PhoneticSearchHelper.attach(document.getElementById('sutraSearchInput'), () => runSutraOrVyakaranaSearch());

  // Editor Script Conversions
  document.getElementById('convertEditorDevaBtn').addEventListener('click', () => {
    EditorIME.reset();
    DocFile.markDirty();
    editor.value = TranslitEngine.teluguToDev(editor.value);
    updateEditorLiveChandas();
  });
  document.getElementById('convertEditorTeluBtn').addEventListener('click', () => {
    EditorIME.reset();
    DocFile.markDirty();
    editor.value = TranslitEngine.devToTelugu(TranslitEngine.teluguToDev(editor.value));
  });
  document.getElementById('convertEditorIastBtn').addEventListener('click', () => {
    EditorIME.reset();
    DocFile.markDirty();
    editor.value = TranslitEngine.devToIast(TranslitEngine.teluguToDev(editor.value));
  });

  // Word Lookup in Studio (Double-click or button)
  editor.addEventListener('dblclick', () => {
    const sel = editor.value.substring(editor.selectionStart, editor.selectionEnd).trim();
    if (sel) runStudioAssistantLookup(sel);
  });
  editor.addEventListener('input', updateEditorLiveChandas);

  document.getElementById('lookupSelectedWordBtn').addEventListener('click', () => {
    const sel = editor.value.substring(editor.selectionStart, editor.selectionEnd).trim();
    if (sel) runStudioAssistantLookup(sel);
    else {
      const words = editor.value.trim().split(/\s+/);
      if (words.length > 0) runStudioAssistantLookup(words[0]);
    }
  });
  document.getElementById('studioQuickLookupBtn').addEventListener('click', () => runStudioAssistantLookup());
  document.getElementById('studioQuickLookupInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') runStudioAssistantLookup();
  });
  document.getElementById('insertDandaBtn').addEventListener('click', () => {
    AppState.activeInputEl = editor;
    insertIntoActiveField(' । ');
  });
  const dblDandaBtn = document.getElementById('insertDoubleDandaBtn');
  if (dblDandaBtn) {
    dblDandaBtn.addEventListener('click', () => {
      AppState.activeInputEl = editor;
      insertIntoActiveField(' ॥ ');
    });
  }

  // Dictionary View Listeners
  document.getElementById('dictSearchBtn').addEventListener('click', () => runDictionarySearch());
  document.getElementById('dictSearchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') runDictionarySearch();
  });
  document.getElementById('dictBookSelect').addEventListener('change', () => runDictionarySearch());
  document.getElementById('dictMatchSelect').addEventListener('change', () => runDictionarySearch());
  document.getElementById('dictScopeSelect').addEventListener('change', () => runDictionarySearch());

  // Kosha Browser Listeners
  document.getElementById('koshaBookSelect').addEventListener('change', () => loadKoshaBrowser(true));
  document.getElementById('koshaKandaVargaSelect').addEventListener('change', () => loadKoshaBrowser(false));
  document.getElementById('koshaBrowseBtn').addEventListener('click', () => loadKoshaBrowser(false));
  document.getElementById('koshaVerseSearchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') loadKoshaBrowser(false);
  });

  // Dhatu Listeners
  document.getElementById('dhatuSearchBtn').addEventListener('click', () => searchDhatus());
  document.getElementById('dhatuSearchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') searchDhatus();
  });
  document.getElementById('dhatuGanaSelect').addEventListener('change', () => searchDhatus());
  document.getElementById('dhatuPadaSelect').addEventListener('change', () => searchDhatus());

  // Shabda Listeners
  document.getElementById('shabdaSearchBtn').addEventListener('click', () => searchShabdas());
  document.getElementById('shabdaSearchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') searchShabdas();
  });
  document.getElementById('shabdaLingaSelect').addEventListener('change', () => searchShabdas());
  document.getElementById('generateCustomShabdaBtn').addEventListener('click', generateCustomShabda);
  document.getElementById('customShabdaStemInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') generateCustomShabda();
  });

  // Sutra & Vyakarana Listeners
  document.getElementById('vyakaranaModeSelect').addEventListener('change', () => runSutraOrVyakaranaSearch());
  document.getElementById('sutraAdhyayaSelect').addEventListener('change', () => runSutraOrVyakaranaSearch());
  document.getElementById('sutraPadaSelect').addEventListener('change', () => runSutraOrVyakaranaSearch());
  document.getElementById('sutraSearchBtn').addEventListener('click', () => runSutraOrVyakaranaSearch());
  document.getElementById('sutraSearchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') runSutraOrVyakaranaSearch();
  });

  // Abhyas Sub-tabs
  document.querySelectorAll('#abhyasSubTabs .sub-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#abhyasSubTabs .sub-tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      AppState.activeAbhyasView = btn.getAttribute('data-abhyas-view');
      renderAbhyasTab();
    });
  });

  // Boot initial data across all modules
  Object.assign(AppConfig, await apiGet('/api/config'));
  renderFontHelpDrawer();
  await loadSystemStats();
  DocFile.init();
  await DocFile.restore();
  runStudioAssistantLookup('वागर्थाविव');
  runDictionarySearch('धर्म');
  loadKoshaBrowser(true);
  searchDhatus('');
  searchShabdas('राम');
  runSutraOrVyakaranaSearch('');
  loadAbhyasModules();
});
