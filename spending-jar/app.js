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

// Re-render when the app comes back to the foreground (so a new week starts fresh)
document.addEventListener('visibilitychange', () => { if (!document.hidden) render(); });

// ---------- Offline support ----------
if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

render();
