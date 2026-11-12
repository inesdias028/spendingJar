// Spending Jar — plain JavaScript, no build step.
// Data is stored on the device with localStorage.

const KEY = 'spending-jar-v1';
const DEFAULT_CATS = [
  { key: 'food', label: 'Food', emoji: '🍔' },
  { key: 'coffee', label: 'Coffee', emoji: '☕' },
  { key: 'transport', label: 'Transport', emoji: '🚌' },
  { key: 'shopping', label: 'Shopping', emoji: '🛍️' },
  { key: 'fun', label: 'Fun', emoji: '🎉' },
  { key: 'other', label: 'Other', emoji: '📦' },
];
const SUGGESTED = ['🏋️', '🐶', '💊', '🎁', '✈️', '🏠', '📚', '🍺', '💇', '🎮', '🚗', '👶'];
const FALLBACK = { label: 'Deleted', emoji: '🏷️' };

// ---------- Storage ----------
let state = { budget: 100, expenses: [], categories: DEFAULT_CATS };
try {
  const raw = localStorage.getItem(KEY);
  if (raw) state = Object.assign(state, JSON.parse(raw));
} catch (e) { /* storage unavailable: app still works for this visit */ }

function save() {
  try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {}
}

// Ask the browser to keep our data (helps on iPhone)
if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});

// ---------- Helpers ----------
const $ = (id) => document.getElementById(id);
const euro = (n) => '€' + n.toFixed(2).replace('.', ',');
const parse = (t) => {
  const n = parseFloat(String(t).replace(',', '.'));
  return isNaN(n) || n <= 0 ? null : Math.round(n * 100) / 100;
};
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function startOfWeek() {
  const d = new Date();
  const day = (d.getDay() + 6) % 7; // Monday = 0
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - day);
  return d.getTime();
}

function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.style.display = 'block';
  clearTimeout(t._h);
  t._h = setTimeout(() => (t.style.display = 'none'), 1800);
}

// Expenses keep a copy of emoji/label so old entries look right after a category is deleted
function catFor(item) {
  return state.categories.find((c) => c.key === item.category)
    || (item.emoji ? { emoji: item.emoji, label: item.label } : FALLBACK);
}

// Long-press (touch) or right-click (desktop). Returns a function telling whether the last press was long.
function addLongPress(el, onLong) {
  let timer, wasLong = false;
  el.addEventListener('pointerdown', () => {
    wasLong = false;
    timer = setTimeout(() => {
      wasLong = true;
      if (navigator.vibrate) navigator.vibrate(15);
      onLong();
    }, 500);
  });
  ['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => el.addEventListener(ev, () => clearTimeout(timer)));
  el.addEventListener('contextmenu', (e) => { e.preventDefault(); clearTimeout(timer); wasLong = true; onLong(); });
  return () => wasLong;
}

// ---------- Confirm dialog ----------
let confirmAction = null;
function askConfirm(text, action, okLabel = 'Delete', danger = true) {
  $('confirmText').textContent = text;
  $('confirmOk').textContent = okLabel;
  $('confirmOk').className = danger ? 'del' : 'primary';
  confirmAction = action;
  $('confirmBg').style.display = 'flex';
}
$('confirmCancel').onclick = () => { confirmAction = null; $('confirmBg').style.display = 'none'; };
$('confirmOk').onclick = () => {
  if (confirmAction) confirmAction();
  confirmAction = null;
  $('confirmBg').style.display = 'none';
  save();
  render();
};

// ---------- Rendering ----------
let editingBudget = false;

function renderCats() {
  const box = $('cats');
  box.innerHTML = '';
  state.categories.forEach((c) => {
    const b = document.createElement('button');
    b.className = 'cat';
    b.innerHTML = `<span class="e">${esc(c.emoji)}</span><span class="l">${esc(c.label)}</span>`;
    const wasLong = addLongPress(b, () => askConfirm(`Delete category ${c.emoji} ${c.label}?`, () => {
      state.categories = state.categories.filter((x) => x.key !== c.key);
    }));
    b.addEventListener('click', () => {
      if (wasLong()) return;
      const amount = parse($('amount').value);
      if (!amount) { toast('Type an amount first, like 4,50'); return; }
      state.expenses.unshift({
        id: Date.now().toString(), amount, category: c.key,
        emoji: c.emoji, label: c.label, date: new Date().toISOString(),
      });
      $('amount').value = '';
      $('amount').blur();
      save();
      render();
    });
    box.appendChild(b);
  });

  const add = document.createElement('button');
  add.className = 'cat new';
  add.innerHTML = '<span class="e">＋</span><span class="l">New</span>';
  add.onclick = openNew;
  box.appendChild(add);
}

function render() {
  const start = startOfWeek();
  const week = state.expenses
    .filter((e) => new Date(e.date).getTime() >= start)
    .sort((a, b) => new Date(b.date) - new Date(a.date));
  const spent = week.reduce((s, e) => s + e.amount, 0);
  const left = state.budget - spent;
  const fill = Math.max(0, Math.min(1, left / state.budget));

  $('fill').style.height = fill * 100 + '%';
  $('fill').style.background = fill > 0.5 ? '#4CAF7A' : fill > 0.2 ? '#F2A541' : '#E05A5A';
  $('left').textContent = euro(left);
  $('left').classList.toggle('neg', left < 0);
  $('spent').textContent = 'Spent ' + euro(spent);

  const bb = $('budgetBox');
  if (editingBudget) {
    bb.innerHTML = '<input class="budget-input" id="bIn" inputmode="decimal" aria-label="Weekly budget">';
    const bIn = $('bIn');
    bIn.value = String(state.budget).replace('.', ',');
    bIn.focus();
    bIn.select();
    const done = () => {
      if (!editingBudget) return;
      const n = parse(bIn.value);
      if (n) state.budget = n;
      editingBudget = false;
      save();
      render();
    };
    bIn.addEventListener('blur', done);
    bIn.addEventListener('keydown', (e) => { if (e.key === 'Enter') done(); });
  } else {
    bb.innerHTML = `<button class="budget" id="bBtn">Budget ${euro(state.budget)} ✏️</button>`;
    $('bBtn').onclick = () => { editingBudget = true; render(); };
  }

  renderCats();

  const list = $('list');
  if (!week.length) {
    list.innerHTML = '<div class="empty">Nothing yet — your jar is full 🎉</div>';
    return;
  }
  list.innerHTML = '';
  week.forEach((item) => {
    const c = catFor(item);
    const d = new Date(item.date);
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `<span class="e">${esc(c.emoji)}</span>
      <div class="mid">
        <div class="lab">${esc(c.label)}</div>
        <div class="small">${d.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric' })} · ${d.toLocaleTimeString('pt-PT', { hour: '2-digit', minute: '2-digit' })}</div>
      </div>
      <span class="amt">${euro(item.amount)}</span>`;
    addLongPress(row, () => askConfirm('Delete ' + euro(item.amount) + '?', () => {
      state.expenses = state.expenses.filter((e) => e.id !== item.id);
    }));
    list.appendChild(row);
  });
}

// ---------- New category ----------
SUGGESTED.forEach((e) => {
  const b = document.createElement('button');
  b.textContent = e;
  b.onclick = () => { $('newEmoji').value = e; $('newName').focus(); };
  $('suggest').appendChild(b);
});

function openNew() {
  $('newEmoji').value = '';
  $('newName').value = '';
  $('newBg').style.display = 'flex';
  $('newName').focus();
}
function closeNew() { $('newBg').style.display = 'none'; }
function saveNew() {
  const label = $('newName').value.trim();
  if (!label) { toast('Give your category a name'); return; }
  if (state.categories.some((c) => c.label.toLowerCase() === label.toLowerCase())) {
    toast('You already have that category');
    return;
  }
  state.categories.push({ key: 'c' + Date.now(), label, emoji: $('newEmoji').value.trim() || '🏷️' });
  closeNew();
  save();
  render();
}
$('newCancel').onclick = closeNew;
$('newSave').onclick = saveNew;
$('newName').addEventListener('keydown', (e) => { if (e.key === 'Enter') saveNew(); });

// ---------- Backup and restore ----------
const BACKUP_KEY = 'spending-jar-last-backup';

function showLastBackup() {
  let when = null;
  try { when = localStorage.getItem(BACKUP_KEY); } catch (e) {}
  $('lastBackup').textContent = when
    ? 'Last backup: ' + new Date(when).toLocaleDateString('pt-PT', { day: 'numeric', month: 'short', year: 'numeric' })
    : 'No backup yet';
}

function markBackedUp() {
  try { localStorage.setItem(BACKUP_KEY, new Date().toISOString()); } catch (e) {}
  showLastBackup();
}

async function backup() {
  const data = {
    app: 'spending-jar',
    version: 1,
    exportedAt: new Date().toISOString(),
    budget: state.budget,
    categories: state.categories,
    expenses: state.expenses,
  };
  const json = JSON.stringify(data, null, 2);
  const name = `spending-jar-backup-${new Date().toISOString().slice(0, 10)}.json`;
  const file = new File([json], name, { type: 'application/json' });

  // iPhone: opens the share sheet → "Save to Files", AirDrop, Mail…
  if (navigator.canShare && navigator.canShare({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: 'Spending Jar backup' });
      markBackedUp();
      toast('Backup saved');
    } catch (e) {
      if (e.name !== 'AbortError') toast("Couldn't share the backup. Try again.");
    }
    return;
  }

  // Computers: download the file
  const url = URL.createObjectURL(file);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  markBackedUp();
  toast('Backup downloaded');
}

function isValidBackup(d) {
  return d && d.app === 'spending-jar'
    && typeof d.budget === 'number'
    && Array.isArray(d.categories)
    && Array.isArray(d.expenses)
    && d.expenses.every((e) => e && typeof e.amount === 'number' && e.date);
}

function restoreFrom(file) {
  const reader = new FileReader();
  reader.onload = () => {
    let data;
    try { data = JSON.parse(reader.result); } catch (e) { data = null; }
    if (!isValidBackup(data)) {
      toast("That file isn't a Spending Jar backup");
      return;
    }
    const when = data.exportedAt
      ? new Date(data.exportedAt).toLocaleDateString('pt-PT', { day: 'numeric', month: 'short', year: 'numeric' })
      : 'an unknown date';
    askConfirm(
      `Restore the backup from ${when}? It has ${data.expenses.length} entries and replaces what's on this phone now.`,
      () => {
        state = { budget: data.budget, categories: data.categories, expenses: data.expenses };
        toast('Backup restored');
      },
      'Restore',
      false
    );
  };
  reader.onerror = () => toast("Couldn't read that file");
  reader.readAsText(file);
}

$('backupBtn').onclick = backup;
$('restoreBtn').onclick = () => $('restoreFile').click();
$('restoreFile').addEventListener('change', (e) => {
  const file = e.target.files && e.target.files[0];
  if (file) restoreFrom(file);
  e.target.value = ''; // allow picking the same file again
});
showLastBackup();

// ---------- Stats page ----------
let period = 'week';   // 'week' | 'month' | 'year'
let offset = 0;        // 0 = current, -1 = previous, ...
let view = 'home';

const WEEKDAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const MONTHS = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
const DAY = 86400000;

// Returns { start, end, buckets: [{ start, end, label }], days, label }
function periodRange(p, off) {
  const now = new Date();
  let start, end, buckets = [], label;
  if (p === 'week') {
    start = new Date(startOfWeek());
    start.setDate(start.getDate() + off * 7);
    end = new Date(start); end.setDate(end.getDate() + 7);
    for (let i = 0; i < 7; i++) {
      const b = new Date(start); b.setDate(b.getDate() + i);
      const e = new Date(b); e.setDate(e.getDate() + 1);
      buckets.push({ start: b, end: e, label: WEEKDAYS[i] });
    }
    const last = new Date(end - DAY);
    label = off === 0 ? 'This week' : off === -1 ? 'Last week'
      : `${start.toLocaleDateString('pt-PT', { day: 'numeric', month: 'short' })} – ${last.toLocaleDateString('pt-PT', { day: 'numeric', month: 'short' })}`;
  } else if (p === 'month') {
    start = new Date(now.getFullYear(), now.getMonth() + off, 1);
    end = new Date(start.getFullYear(), start.getMonth() + 1, 1);
    const n = Math.round((end - start) / DAY);
    for (let i = 0; i < n; i++) {
      const b = new Date(start.getFullYear(), start.getMonth(), i + 1);
      const e = new Date(start.getFullYear(), start.getMonth(), i + 2);
      const d = i + 1;
      buckets.push({ start: b, end: e, label: d === 1 || d % 5 === 0 ? String(d) : '' });
    }
    label = start.toLocaleDateString('pt-PT', { month: 'long', year: 'numeric' });
  } else {
    start = new Date(now.getFullYear() + off, 0, 1);
    end = new Date(start.getFullYear() + 1, 0, 1);
    for (let m = 0; m < 12; m++) {
      buckets.push({ start: new Date(start.getFullYear(), m, 1), end: new Date(start.getFullYear(), m + 1, 1), label: MONTHS[m] });
    }
    label = String(start.getFullYear());
  }
  const days = Math.round((end - start) / DAY);
  return { start, end, buckets, days, label };
}

function renderStats() {
  const r = periodRange(period, offset);
  const inRange = state.expenses.filter((e) => {
    const t = new Date(e.date).getTime();
    return t >= r.start.getTime() && t < r.end.getTime();
  });
  const total = inRange.reduce((s, e) => s + e.amount, 0);

  // Days counted for the average: only up to today for the current period
  const now = Date.now();
  const elapsed = offset === 0
    ? Math.max(1, Math.ceil((Math.min(now, r.end.getTime()) - r.start.getTime()) / DAY))
    : r.days;
  const periodBudget = state.budget * r.days / 7;

  $('periodLabel').textContent = r.label;
  $('nextPeriod').classList.toggle('off', offset === 0);
  $('stSpent').textContent = euro(total);
  $('stAvg').textContent = euro(total / elapsed);

  const pct = periodBudget > 0 ? total / periodBudget : 0;
  const bar = $('stBar');
  bar.style.width = Math.min(100, pct * 100) + '%';
  bar.style.background = pct < 0.8 ? '#4CAF7A' : pct <= 1 ? '#F2A541' : '#E05A5A';
  const diff = periodBudget - total;
  $('stBudget').textContent = `${Math.round(pct * 100)}% of ${euro(periodBudget)} budget · ` +
    (diff >= 0 ? `${euro(diff)} under` : `${euro(-diff)} over`);

  // Chart
  const sums = r.buckets.map((b) => inRange
    .filter((e) => { const t = new Date(e.date).getTime(); return t >= b.start.getTime() && t < b.end.getTime(); })
    .reduce((s, e) => s + e.amount, 0));
  const max = Math.max(...sums, 0);
  const chart = $('chart');
  chart.innerHTML = '';
  r.buckets.forEach((b, i) => {
    const col = document.createElement('div');
    col.className = 'col';
    const isNow = now >= b.start.getTime() && now < b.end.getTime();
    const h = max > 0 ? (sums[i] / max) * 100 : 0;
    col.innerHTML = `<div class="bar${sums[i] === 0 ? ' zero' : ''}${isNow ? ' now' : ''}" style="height:${h}%"></div>` +
      (b.label ? `<span class="lab">${b.label}</span>` : '');
    col.title = `${b.start.toLocaleDateString('pt-PT')}: ${euro(sums[i])}`;
    chart.appendChild(col);
  });
  if (max === 0) {
    const m = document.createElement('div');
    m.className = 'empty-chart';
    m.textContent = 'No spending in this period';
    chart.appendChild(m);
  }

  // By category
  const groups = {};
  inRange.forEach((e) => {
    const c = catFor(e);
    const k = e.category || c.label;
    if (!groups[k]) groups[k] = { emoji: c.emoji, label: c.label, total: 0, count: 0 };
    groups[k].total += e.amount;
    groups[k].count++;
  });
  const rows = Object.values(groups).sort((a, b) => b.total - a.total);
  const top = rows.length ? rows[0].total : 0;
  $('byCat').innerHTML = rows.length
    ? rows.map((g) => `<div class="catrow">
        <div class="top"><span class="e">${esc(g.emoji)}</span><span class="name">${esc(g.label)} <span class="small">· ${g.count}×</span></span>
        <span class="val">${euro(g.total)}</span><span class="pct">${Math.round((g.total / total) * 100)}%</span></div>
        <div class="track"><div style="width:${(g.total / top) * 100}%"></div></div></div>`).join('')
    : '<div class="empty">Nothing spent in this period</div>';
}

document.querySelectorAll('.seg button').forEach((b) => {
  b.onclick = () => {
    period = b.dataset.period;
    offset = 0;
    document.querySelectorAll('.seg button').forEach((x) => x.classList.toggle('on', x === b));
    renderStats();
  };
});
$('prevPeriod').onclick = () => { offset--; renderStats(); };
$('nextPeriod').onclick = () => { if (offset < 0) { offset++; renderStats(); } };

function showView(v) {
  view = v;
  $('viewHome').hidden = v !== 'home';
  $('viewStats').hidden = v !== 'stats';
  document.querySelectorAll('.tabbar button').forEach((x) => x.classList.toggle('on', x.dataset.view === v));
  if (v === 'stats') renderStats(); else render();
  window.scrollTo(0, 0);
}
document.querySelectorAll('.tabbar button').forEach((b) => { b.onclick = () => showView(b.dataset.view); });

// Re-render when the app comes back to the foreground (so a new week starts fresh)
document.addEventListener('visibilitychange', () => {
  if (document.hidden) return;
  if (view === 'stats') renderStats(); else render();
});

// ---------- Offline support ----------
if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

render();
