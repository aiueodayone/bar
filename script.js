"use strict";

/* ---------- データ定義 ---------- */

const DRINKS = [
  { id: "beer", name: "生ビール", emoji: "🍺", cost: 100, satisfaction: 5, buzz: 8, minLevel: 1, color: "linear-gradient(180deg,#f4d879,#d99a1f)" },
  { id: "highball", name: "ハイボール", emoji: "🥃", cost: 150, satisfaction: 8, buzz: 12, minLevel: 1, color: "linear-gradient(180deg,#e8d9a8,#c9a95a)" },
  { id: "mojito", name: "モヒート", emoji: "🍹", cost: 220, satisfaction: 11, buzz: 13, minLevel: 2, color: "linear-gradient(180deg,#a8e8b0,#4fae6a)" },
  { id: "wine", name: "グラスワイン", emoji: "🍷", cost: 200, satisfaction: 10, buzz: 10, minLevel: 3, color: "linear-gradient(180deg,#9a2b46,#5a1224)" },
  { id: "martini", name: "マティーニ", emoji: "🍸", cost: 320, satisfaction: 16, buzz: 18, minLevel: 5, color: "linear-gradient(180deg,#f2f2e0,#c9c9a0)" },
  { id: "whiskey", name: "ウイスキー(ロック)", emoji: "🥃", cost: 380, satisfaction: 19, buzz: 20, minLevel: 7, color: "linear-gradient(180deg,#c9822f,#7a4413)" },
  { id: "oldfashioned", name: "オールドファッションド", emoji: "🍹", cost: 450, satisfaction: 22, buzz: 23, minLevel: 9, color: "linear-gradient(180deg,#c9702f,#7a3c13)" },
  { id: "champagne", name: "高級シャンパン", emoji: "🥂", cost: 900, satisfaction: 42, buzz: 35, minLevel: 12, color: "linear-gradient(180deg,#f7ecb0,#d9be5a)" },
];

const CIGARS = [
  { id: "cigarillo", name: "シガリロ", emoji: "🚬", cost: 130, relax: 6, minLevel: 1 },
  { id: "robusto", name: "ロブスト", emoji: "🚬", cost: 320, relax: 15, minLevel: 4 },
  { id: "toro", name: "トロ", emoji: "🚬", cost: 470, relax: 22, minLevel: 6 },
  { id: "churchill", name: "チャーチル", emoji: "🚬", cost: 750, relax: 32, minLevel: 10 },
  { id: "cuban", name: "クラシック・キューバン", emoji: "🚬", cost: 1300, relax: 50, minLevel: 14 },
];

const ACHIEVEMENTS = [
  { id: "first_drink", name: "はじめの一杯", emoji: "🍻", desc: "ドリンクを1杯注文する", check: s => s.totalDrinks >= 1, reward: 50 },
  { id: "first_cigar", name: "葉巻デビュー", emoji: "🚬", desc: "葉巻を1本吸う", check: s => s.totalCigars >= 1, reward: 50 },
  { id: "regular_10", name: "常連さん", emoji: "🙂", desc: "ドリンクを10杯注文する", check: s => s.totalDrinks >= 10, reward: 200 },
  { id: "regular_100", name: "バーのヌシ", emoji: "👑", desc: "ドリンクを100杯注文する", check: s => s.totalDrinks >= 100, reward: 2000 },
  { id: "ashtray_50", name: "灰皿の主", emoji: "🌫️", desc: "葉巻を50本吸う", check: s => s.totalCigars >= 50, reward: 1500 },
  { id: "overdrunk_once", name: "飲みすぎ注意", emoji: "🥴", desc: "泥酔状態を経験する", check: s => s.overdrunkCount >= 1, reward: 100 },
  { id: "gold_10000", name: "ゴールドコレクター", emoji: "💰", desc: "累計10,000ゴールドを稼ぐ", check: s => s.totalEarned >= 10000, reward: 500 },
  { id: "gold_100000", name: "億万長者への道", emoji: "💎", desc: "累計100,000ゴールドを稼ぐ", check: s => s.totalEarned >= 100000, reward: 5000 },
  { id: "level_10", name: "夜の常連 Lv.10", emoji: "🌙", desc: "レベル10に到達する", check: s => s.level >= 10, reward: 800 },
  { id: "level_20", name: "深夜の主人公 Lv.20", emoji: "✨", desc: "レベル20に到達する", check: s => s.level >= 20, reward: 3000 },
];

const SAVE_KEY = "bar_nightcap_save_v1";
const TICK_MS = 200;
const MAX_OFFLINE_MS = 12 * 60 * 60 * 1000; // 12時間分まで清算
const OVERDRUNK_DURATION_MS = 15000;
const STATUS_MESSAGES = [
  "今夜も静かな夜。まずは一杯どうですか。",
  "グラスの氷が溶ける音が心地いい。",
  "遠くでジャズのレコードが回っている。",
  "バーテンダーが静かにグラスを磨いている。",
  "煙がゆっくりと天井に消えていく。",
  "今日あった嫌なことも、ここでは忘れよう。",
];

/* ---------- 状態 ---------- */

function defaultState() {
  return {
    gold: 300,
    totalEarned: 300,
    xp: 0,
    level: 1,
    buzz: 0,
    relax: 0,
    overdrunkUntil: 0,
    overdrunkCount: 0,
    totalDrinks: 0,
    totalCigars: 0,
    drinkCounts: {},
    cigarCounts: {},
    achievements: {},
    lastSeen: Date.now(),
  };
}

let state = loadState();

function loadState() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return defaultState();
    const parsed = JSON.parse(raw);
    return Object.assign(defaultState(), parsed);
  } catch (e) {
    return defaultState();
  }
}

function saveState() {
  state.lastSeen = Date.now();
  localStorage.setItem(SAVE_KEY, JSON.stringify(state));
}

/* ---------- レベル計算 ---------- */

function xpForLevel(level) {
  return Math.round(80 * Math.pow(level, 1.5));
}

function recalcLevel() {
  let level = 1;
  let remaining = state.xp;
  while (remaining >= xpForLevel(level)) {
    remaining -= xpForLevel(level);
    level++;
  }
  return level;
}

function baseGoldRate() {
  return 1 + (state.level - 1) * 0.6;
}

function currentMultiplier() {
  if (Date.now() < state.overdrunkUntil) return 0.2;
  return 1 + (state.buzz / 100) * 0.6 + (state.relax / 100) * 0.6;
}

function currentGoldRate() {
  return baseGoldRate() * currentMultiplier();
}

/* ---------- ゲームループ ---------- */

let lastTick = Date.now();

function tick() {
  const now = Date.now();
  const deltaMs = now - lastTick;
  lastTick = now;
  applyProgress(deltaMs);
  render();
}

function applyProgress(deltaMs) {
  const deltaSec = deltaMs / 1000;
  const wasOverdrunk = Date.now() - deltaMs < state.overdrunkUntil;

  // 受動収入
  const earned = currentGoldRate() * deltaSec;
  state.gold += earned;
  state.totalEarned += earned;

  // メーター減衰
  const overdrunkActive = Date.now() < state.overdrunkUntil;
  const buzzDecay = overdrunkActive ? 6 : 1.1;
  state.buzz = Math.max(0, state.buzz - buzzDecay * deltaSec);
  state.relax = Math.max(0, state.relax - 0.55 * deltaSec);

  if (wasOverdrunk && Date.now() >= state.overdrunkUntil) {
    state.buzz = Math.min(state.buzz, 35);
  }

  checkLevelUp();
  checkAchievements();
}

function checkLevelUp() {
  const newLevel = recalcLevel();
  if (newLevel > state.level) {
    state.level = newLevel;
    showToast(`🎉 レベルアップ！ Lv.${state.level} になりました`, "levelup");
    setStatus(`常連度が上がった。今夜のあなたは少し余裕がある。`);
  }
}

function checkAchievements() {
  for (const a of ACHIEVEMENTS) {
    if (state.achievements[a.id]) continue;
    if (a.check(state)) {
      state.achievements[a.id] = true;
      state.gold += a.reward;
      state.totalEarned += a.reward;
      showToast(`🏆 実績解除: ${a.name} (+${a.reward}💰)`, "achievement");
      updateAchievementsState();
    }
  }
}

/* ---------- アクション ---------- */

function orderDrink(drink) {
  if (state.gold < drink.cost) {
    setStatus("お会計が足りないみたいだ…");
    return;
  }
  if (Date.now() < state.overdrunkUntil) {
    setStatus("今はちょっと飲みすぎている。少し休もう。");
    return;
  }
  state.gold -= drink.cost;
  state.xp += drink.satisfaction;
  state.buzz = Math.min(100, state.buzz + drink.buzz);
  state.totalDrinks += 1;
  state.drinkCounts[drink.id] = (state.drinkCounts[drink.id] || 0) + 1;

  if (state.buzz >= 100) {
    state.overdrunkUntil = Date.now() + OVERDRUNK_DURATION_MS;
    state.overdrunkCount += 1;
    setStatus("うっ…飲みすぎたかもしれない。少しペースを落とそう。");
  } else {
    setStatus(`${drink.name}を注文した。${randomStatus()}`);
  }

  playGlassAnimation(drink);
  checkLevelUp();
  checkAchievements();
  render();
  saveState();
}

function smokeCigar(cigar) {
  if (state.gold < cigar.cost) {
    setStatus("お会計が足りないみたいだ…");
    return;
  }
  state.gold -= cigar.cost;
  state.xp += Math.round(cigar.relax * 0.6);
  state.relax = Math.min(100, state.relax + cigar.relax);
  state.totalCigars += 1;
  state.cigarCounts[cigar.id] = (state.cigarCounts[cigar.id] || 0) + 1;

  setStatus(`${cigar.name}に火を灯した。${randomStatus()}`);
  playCigarAnimation();
  checkLevelUp();
  checkAchievements();
  render();
  saveState();
}

function randomStatus() {
  return STATUS_MESSAGES[Math.floor(Math.random() * STATUS_MESSAGES.length)];
}

/* ---------- シーン演出 ---------- */

let glassAnimTimer = null;
function playGlassAnimation(drink) {
  const liquid = document.getElementById("scene-liquid");
  const emoji = document.getElementById("scene-glass-emoji");
  liquid.style.background = drink.color;
  liquid.style.height = "0%";
  emoji.textContent = drink.emoji;
  requestAnimationFrame(() => {
    liquid.style.height = "78%";
  });
  clearTimeout(glassAnimTimer);
  glassAnimTimer = setTimeout(() => {
    liquid.style.height = "20%";
  }, 4000);
}

let cigarAnimTimer = null;
function playCigarAnimation() {
  const cigar = document.getElementById("scene-cigar");
  cigar.classList.add("lit");
  clearTimeout(cigarAnimTimer);
  cigarAnimTimer = setTimeout(() => {
    cigar.classList.remove("lit");
  }, 8000);
}

/* ---------- UI描画 ---------- */

function fmt(n) {
  return Math.floor(n).toLocaleString("ja-JP");
}

function setStatus(msg) {
  document.getElementById("status-line").textContent = msg;
}

function render() {
  document.getElementById("stat-gold").textContent = fmt(state.gold);
  document.getElementById("stat-rate").textContent = `+${currentGoldRate().toFixed(1)}/秒`;
  document.getElementById("stat-level").textContent = state.level;

  const xpIntoLevel = xpIntoCurrentLevel();
  const xpNeeded = xpForLevel(state.level);
  document.getElementById("meter-xp").style.width = `${Math.min(100, (xpIntoLevel / xpNeeded) * 100)}%`;
  document.getElementById("meter-xp-text").textContent = `${fmt(xpIntoLevel)} / ${fmt(xpNeeded)}`;

  const buzzFill = document.getElementById("meter-buzz");
  buzzFill.style.width = `${state.buzz}%`;
  buzzFill.classList.toggle("over", Date.now() < state.overdrunkUntil);
  document.getElementById("meter-buzz-text").textContent =
    Date.now() < state.overdrunkUntil ? "泥酔中" : `${Math.round(state.buzz)}%`;

  document.getElementById("meter-relax").style.width = `${state.relax}%`;
  document.getElementById("meter-relax-text").textContent = `${Math.round(state.relax)}%`;

  updateMenuState();
}

function xpIntoCurrentLevel() {
  let remaining = state.xp;
  for (let l = 1; l < state.level; l++) remaining -= xpForLevel(l);
  return Math.max(0, remaining);
}

// メニューのボタンは一度だけ生成し、以降は disabled 状態やテキストだけを
// 更新する。tick のたびに innerHTML を作り直すと、クリック中にボタンが
// 消えて操作が取りこぼされたり、リスト内のスクロール位置が飛んだりするため。
function buildMenuOnce() {
  const drinksGrid = document.getElementById("drinks-grid");
  const cigarsGrid = document.getElementById("cigars-grid");
  drinksGrid.innerHTML = "";
  cigarsGrid.innerHTML = "";

  for (const d of DRINKS) drinksGrid.appendChild(buildMenuButton(d, "drink"));
  for (const c of CIGARS) cigarsGrid.appendChild(buildMenuButton(c, "cigar"));
}

function buildMenuButton(item, kind) {
  const btn = document.createElement("button");
  btn.className = "menu-item";
  btn.dataset.id = item.id;
  btn.dataset.kind = kind;

  btn.innerHTML = `
    <span class="m-emoji">${item.emoji}</span>
    <span class="m-info">
      <span class="m-name">${item.name}</span><br>
      <span class="m-effect"></span>
    </span>
    <span class="m-cost"></span>
  `;

  btn.addEventListener("click", () => {
    if (state.level < item.minLevel) return;
    if (kind === "drink") orderDrink(item);
    else smokeCigar(item);
  });
  return btn;
}

function updateMenuState() {
  document.querySelectorAll(".menu-item").forEach(btn => {
    const kind = btn.dataset.kind;
    const item = (kind === "drink" ? DRINKS : CIGARS).find(x => x.id === btn.dataset.id);
    if (!item) return;
    const locked = state.level < item.minLevel;
    const affordable = state.gold >= item.cost;
    btn.disabled = locked || !affordable;

    const effectText = kind === "drink"
      ? `満足度+${item.satisfaction} ／ ほろ酔い+${item.buzz}`
      : `満足度+${Math.round(item.relax * 0.6)} ／ リラックス+${item.relax}`;

    btn.querySelector(".m-effect").textContent = locked ? `Lv.${item.minLevel} で解放` : effectText;
    btn.querySelector(".m-cost").textContent = locked ? "🔒" : `💰${fmt(item.cost)}`;
  });
}

function buildAchievementsOnce() {
  const grid = document.getElementById("achievements-grid");
  grid.innerHTML = "";
  for (const a of ACHIEVEMENTS) {
    const div = document.createElement("div");
    div.className = "ach-item";
    div.dataset.id = a.id;
    div.innerHTML = `
      <span class="ach-emoji"></span>
      <span class="ach-name"></span>
      <div class="ach-desc" style="margin-top:4px;"></div>
    `;
    grid.appendChild(div);
  }
  updateAchievementsState();
}

function updateAchievementsState() {
  document.querySelectorAll(".ach-item").forEach(div => {
    const a = ACHIEVEMENTS.find(x => x.id === div.dataset.id);
    if (!a) return;
    const unlocked = !!state.achievements[a.id];
    div.classList.toggle("unlocked", unlocked);
    div.querySelector(".ach-emoji").textContent = unlocked ? a.emoji : "❔";
    div.querySelector(".ach-name").textContent = unlocked ? a.name : "???";
    div.querySelector(".ach-desc").textContent = unlocked ? a.desc : "未解放";
  });
}

/* ---------- トースト ---------- */

function showToast(msg, cls) {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");
  toast.className = "toast" + (cls ? ` ${cls}` : "");
  toast.textContent = msg;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3200);
}

/* ---------- タブ切り替え ---------- */

function setupTabs() {
  const buttons = document.querySelectorAll(".tab-btn");
  buttons.forEach(btn => {
    btn.addEventListener("click", () => {
      buttons.forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      document.querySelectorAll(".tab-content").forEach(tc => tc.classList.remove("active"));
      document.getElementById(`tab-${btn.dataset.tab}`).classList.add("active");
    });
  });
}

/* ---------- オフライン進行 ---------- */

function resolveOfflineProgress() {
  const now = Date.now();
  const elapsed = Math.min(now - (state.lastSeen || now), MAX_OFFLINE_MS);
  if (elapsed < 30000) {
    state.lastSeen = now;
    return;
  }
  // オフライン中はバフなしの基礎レートのみで清算
  const seconds = elapsed / 1000;
  const earned = baseGoldRate() * seconds;
  state.gold += earned;
  state.totalEarned += earned;
  state.buzz = 0;
  state.relax = 0;
  state.lastSeen = now;

  const modal = document.getElementById("welcome-modal");
  const text = document.getElementById("welcome-text");
  text.textContent = `${formatDuration(elapsed)}お店を離れていましたね。留守の間に 💰${fmt(earned)} ゴールドが貯まっていました。`;
  modal.classList.add("show");
}

function formatDuration(ms) {
  const totalMin = Math.floor(ms / 60000);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  if (h > 0) return `${h}時間${m}分`;
  return `${m}分`;
}

/* ---------- リセット ---------- */

function setupResetModal() {
  const resetBtn = document.getElementById("reset-btn");
  const overlay = document.getElementById("reset-modal");
  const cancel = document.getElementById("reset-cancel");
  const confirm = document.getElementById("reset-confirm");

  resetBtn.addEventListener("click", () => overlay.classList.add("show"));
  cancel.addEventListener("click", () => overlay.classList.remove("show"));
  confirm.addEventListener("click", () => {
    localStorage.removeItem(SAVE_KEY);
    state = defaultState();
    overlay.classList.remove("show");
    setStatus("新しい夜が始まった。ようこそ、Bar Nightcapへ。");
    updateAchievementsState();
    render();
  });
}

/* ---------- 初期化 ---------- */

function init() {
  state.level = recalcLevel();
  resolveOfflineProgress();
  setupTabs();
  setupResetModal();
  buildMenuOnce();
  buildAchievementsOnce();

  document.getElementById("welcome-close").addEventListener("click", () => {
    document.getElementById("welcome-modal").classList.remove("show");
  });

  render();
  lastTick = Date.now();
  setInterval(tick, TICK_MS);
  setInterval(saveState, 5000);

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") saveState();
  });
  window.addEventListener("beforeunload", saveState);
}

init();
