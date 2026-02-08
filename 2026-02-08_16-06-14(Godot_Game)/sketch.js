/*
  頂尖 HTML5 / JavaScript 遊戲工程師實現的 p5.js 單檔遊戲
  遊戲名稱：簡易版卡牌對戰 (Inspired by Clash Royale)
*/

// --- 遊戲設定與常數 ---
const APP_VERSION = "1.0.0";
const CANVAS_WIDTH = 1280;
const CANVAS_HEIGHT = 720;
const FPS_TARGET = 60;

const TILE_SIZE = 40; // 遊戲世界的格子大小，用於單位尺寸和距離

const ELIXIR_MAX = 10;
const ELIXIR_RATE_NORMAL = 1 / 2.8; // 每秒聖水回復量
const ELIXIR_RATE_OVERTIME = 3 / 2.8; // 加時賽聖水回復量 (規格指定3倍)

const MATCH_DURATION_SECONDS = 3 * 60; // 3分鐘
const OVERTIME_DURATION_SECONDS = 2 * 60; // 2分鐘
const TIEBREAKER_DURATION_SECONDS = 30; // 30秒
const TIEBREAKER_HP_LOSS_PER_SECOND = 100;

const KING_TOWER_Y_OFFSET = 50;
const PRINCESS_TOWER_Y_OFFSET = 60;
const PRINCESS_TOWER_X_SPACING = 200; // 公主塔與中線的水平距離

const BRIDGE_Y_POSITION = CANVAS_HEIGHT / 2;
const BRIDGE_WIDTH = 120;
const BRIDGE_HEIGHT = 60;

// AI 設定
const AI_PLAY_INTERVAL_MIN = 3; // 秒
const AI_PLAY_INTERVAL_MAX = 7; // 秒
const AI_DEFEND_HP_THRESHOLD = 0.3; // 塔血量低於30%時優先防守

// 顏色定義
const COLOR_PLAYER = [50, 150, 255];
const COLOR_AI = [255, 100, 100];
const COLOR_GROUND_UNIT = [100, 100, 100];
const COLOR_AIR_UNIT = [180, 180, 200];
const COLOR_BUILDING = [150, 100, 50];
const COLOR_SPELL_EFFECT = [200, 50, 200, 150]; // RGBA

const PARTICLE_LIMIT = 200; // 最大粒子數量



// --- 資料結構 ---

// 卡牌資料庫
// 額外添加的欄位:
//   movementType: "ground" | "air" (部隊移動類型)
//   targetType: "any" | "ground" | "air" | "buildings" (攻擊目標類型)
//   spawnCount: N (若為召喚單位，一次召喚的數量)
//   spawnUnitId: ID (若為召喚單位，召喚的單位ID - 這裡簡化，假設召喚的是基礎骷髏兵等)
//   splashRadius: N (範圍傷害半徑，0為單體)
//   special: "" (特殊能力標記，例如 "charge", "spawn_on_death", "ramping_damage")
const CARD_POOL = [
  { id: 1, name: "巨人 Giant", type: "troop", elixir: 5, rarity: "rare", hp: 3400, dmg: 200, speed: "medium", attackRange: 1.5 * TILE_SIZE, description: "高血量，專攻建築", movementType: "ground", targetType: "buildings", splashRadius: 0 },
  { id: 2, name: "皇家巨人 Royal Giant", type: "troop", elixir: 6, rarity: "common", hp: 2500, dmg: 150, speed: "slow", attackRange: 6.5 * TILE_SIZE, description: "遠程坦克，直射塔", movementType: "ground", targetType: "buildings", splashRadius: 0 },
  { id: 3, name: "小皮卡 Mini P.E.K.K.A", type: "troop", elixir: 4, rarity: "rare", hp: 1100, dmg: 600, speed: "fast", attackRange: 1.2 * TILE_SIZE, description: "高單體傷害", movementType: "ground", targetType: "any", splashRadius: 0 },
  { id: 4, name: "骷髏軍團 Skeleton Army", type: "troop", elixir: 3, rarity: "epic", hp: 0, dmg: 0, speed: "medium", attackRange: 0, description: "大量 1 費骷髏群", movementType: "ground", targetType: "any", spawnCount: 15, spawnUnitId: "skeleton_basic", splashRadius: 0 }, // hp/dmg 0 as it's a spawner
  { id: 5, name: "王子 Prince", type: "troop", elixir: 5, rarity: "epic", hp: 1500, dmg: 350, speed: "medium", attackRange: 1.6 * TILE_SIZE, description: "蓄力衝刺雙倍傷害", movementType: "ground", targetType: "any", splashRadius: 0, special: "charge" },
  { id: 6, name: "飛龍寶寶 Baby Dragon", type: "troop", elixir: 4, rarity: "epic", hp: 1000, dmg: 130, speed: "medium", attackRange: 3.5 * TILE_SIZE, description: "空中範圍傷", movementType: "air", targetType: "any", splashRadius: 1.5 * TILE_SIZE },
  { id: 7, name: "女武神 Valkyrie", type: "troop", elixir: 4, rarity: "rare", hp: 1600, dmg: 220, speed: "medium", attackRange: 1.2 * TILE_SIZE, description: "360° 迴旋 AOE", movementType: "ground", targetType: "ground", splashRadius: 1.2 * TILE_SIZE, special: "spin_attack" },
  { id: 8, name: "火球 Fireball", type: "spell", elixir: 4, rarity: "rare", hp: 0, dmg: 570, speed: "n/a", attackRange: 2.5 * TILE_SIZE, description: "中費範圍法術", movementType: "n/a", targetType: "any", splashRadius: 2.5 * TILE_SIZE },
  { id: 9, name: "滾木 The Log", type: "spell", elixir: 2, rarity: "legendary", hp: 0, dmg: 240, speed: "n/a", attackRange: 10 * TILE_SIZE, description: "地面直線滾動", movementType: "n/a", targetType: "ground", splashRadius: 3.0 * TILE_SIZE, special: "linear_pushback" }, // attackRange here is length
  { id: 10, name: "箭雨 Arrows", type: "spell", elixir: 3, rarity: "common", hp: 0, dmg: 240, speed: "n/a", attackRange: 4 * TILE_SIZE, description: "大範圍群傷", movementType: "n/a", targetType: "any", splashRadius: 4 * TILE_SIZE },
  { id: 11, name: "雷擊 Lightning", type: "spell", elixir: 6, rarity: "epic", hp: 0, dmg: 860, speed: "n/a", attackRange: 3.5 * TILE_SIZE, description: "選 3 目標高傷", movementType: "n/a", targetType: "any", splashRadius: 0, special: "multi_target_3" }, // attackRange is selection radius
  { id: 12, name: "火塔 Inferno Tower", type: "building", elixir: 5, rarity: "rare", hp: 1500, dmg: 50, speed: "n/a", attackRange: 6 * TILE_SIZE, description: "遞增傷坦克殺手", movementType: "n/a", targetType: "any", splashRadius: 0, special: "ramping_damage" },
  { id: 13, name: "加農砲 Cannon", type: "building", elixir: 3, rarity: "common", hp: 800, dmg: 130, speed: "n/a", attackRange: 5.5 * TILE_SIZE, description: "低費防坦建築", movementType: "n/a", targetType: "ground", splashRadius: 0 },
  { id: 14, name: "特斯拉 Tesla", type: "building", elixir: 4, rarity: "common", hp: 1000, dmg: 190, speed: "n/a", attackRange: 5.5 * TILE_SIZE, description: "潛地反空陸", movementType: "n/a", targetType: "any", splashRadius: 0, special: "hide_until_attack" },
  { id: 15, name: "墓園 Graveyard", type: "spell", elixir: 5, rarity: "legendary", hp: 0, dmg: 0, speed: "n/a", attackRange: 3.5 * TILE_SIZE, description: "在敵塔隨機生成骷髏", movementType: "n/a", targetType: "ground", spawnCount: 1, spawnUnitId: "skeleton_basic", special: "area_spawn_over_time" }, // attackRange is spell radius
  { id: 16, name: "冰凍 Freeze", type: "spell", elixir: 4, rarity: "epic", hp: 0, dmg: 100, speed: "n/a", attackRange: 3 * TILE_SIZE, description: "定身並傷害", movementType: "n/a", targetType: "any", splashRadius: 3 * TILE_SIZE, special: "freeze" },
  { id: 17, name: "女巫 Witch", type: "troop", elixir: 5, rarity: "epic", hp: 700, dmg: 110, speed: "medium", attackRange: 5 * TILE_SIZE, description: "召骷髏＋AOE", movementType: "ground", targetType: "any", splashRadius: 0.5 * TILE_SIZE, special: "spawn_skeletons_periodically" },
  { id: 18, name: "弓箭手 Archers", type: "troop", elixir: 3, rarity: "common", hp: 250, dmg: 90, speed: "medium", attackRange: 5 * TILE_SIZE, description: "雙遠程輕單位", movementType: "ground", targetType: "any", spawnCount: 2, spawnUnitId: "archer_single", splashRadius: 0 }, // spawn 2 archers
  { id: 19, name: "騎士 Knight", type: "troop", elixir: 3, rarity: "common", hp: 1400, dmg: 160, speed: "medium", attackRange: 1.2 * TILE_SIZE, description: "中費平衡坦", movementType: "ground", targetType: "any", splashRadius: 0 },
  { id: 20, name: "猴子 Bandit", type: "troop", elixir: 3, rarity: "legendary", hp: 750, dmg: 160, speed: "fast", attackRange: 0.8 * TILE_SIZE, description: "瞬移衝刺", movementType: "ground", targetType: "ground", splashRadius: 0, special: "dash_attack" }, // attackRange is melee, dash range is separate
  { id: 21, name: "電法 Electro Wizard", type: "troop", elixir: 4, rarity: "legendary", hp: 600, dmg: 100, speed: "fast", attackRange: 5 * TILE_SIZE, description: "降低攻速暈眩", movementType: "ground", targetType: "any", splashRadius: 0, special: "stun_split_attack" }, // Hits 2 targets
  { id: 22, name: "精靈 Spirit", type: "troop", elixir: 1, rarity: "common", hp: 190, dmg: 150, speed: "very fast", attackRange: 2.5 * TILE_SIZE, description: "消耗循環", movementType: "ground", targetType: "any", splashRadius: 1.5 * TILE_SIZE, special: "kamikaze" }, // Usually kamikaze
  { id: 23, name: "加農車 Cannon Cart", type: "troop", elixir: 5, rarity: "epic", hp: 700, dmg: 200, speed: "medium", attackRange: 5.5 * TILE_SIZE, description: "破盾後變建築", movementType: "ground", targetType: "ground", splashRadius: 0, special: "shield_to_building" }, // HP is shield, then becomes building
  { id: 24, name: "X 砲 X-Bow", type: "building", elixir: 6, rarity: "epic", hp: 1300, dmg: 40, speed: "n/a", attackRange: 11.5 * TILE_SIZE, description: "長射程火力", movementType: "n/a", targetType: "ground", splashRadius: 0, special: "fast_attack_rate" },
  { id: 25, name: "氣球 Balloon", type: "troop", elixir: 5, rarity: "epic", hp: 1300, dmg: 700, speed: "medium", attackRange: 1.2 * TILE_SIZE, description: "空坦克，死亡爆炸", movementType: "air", targetType: "buildings", splashRadius: 0, special: "death_damage" }, // attackRange is melee, death_damage has radius
  { id: 26, name: "女弓 Queen", type: "troop", elixir: 5, rarity: "legendary", hp: 1000, dmg: 200, speed: "medium", attackRange: 5 * TILE_SIZE, description: "隱身技能", movementType: "ground", targetType: "any", splashRadius: 0, special: "invisibility_skill" }, // Archer Queen inspired
  { id: 27, name: "鏡像 Mirror", type: "spell", elixir: "+1", rarity: "epic", hp: 0, dmg: 0, speed: "n/a", attackRange: 0, description: "重複上一張", movementType: "n/a", targetType: "n/a", special: "mirror_last_card" },
  { id: 28, name: "骷髏守衛 Guards", type: "troop", elixir: 3, rarity: "epic", hp: 80, dmg: 80, speed: "fast", attackRange: 1.2 * TILE_SIZE, description: "盾牌骷髏", movementType: "ground", targetType: "any", spawnCount: 3, spawnUnitId: "guard_skeleton", splashRadius: 0 }, // HP is shield HP, then unit HP
  { id: 29, name: "黃金騎士 Golden Knight", type: "troop", elixir: 4, rarity: "legendary", hp: 1200, dmg: 180, speed: "medium", attackRange: 1.2 * TILE_SIZE, description: "連鎖衝", movementType: "ground", targetType: "ground", splashRadius: 0, special: "chain_dash" },
  { id: 30, name: "鑽地礦工 Miner", type: "troop", elixir: 3, rarity: "legendary", hp: 1000, dmg: 130, speed: "fast", attackRange: 1.2 * TILE_SIZE, description: "任意生成地底", movementType: "ground", targetType: "any", splashRadius: 0, special: "deploy_anywhere_ground" },
];

// 為了簡化，定義一些基礎單位類型，給召喚類卡牌使用
const UNIT_TEMPLATES = {
  skeleton_basic: { name: "Skeleton", hp: 67, dmg: 67, speed: "fast", attackRange: 1.2 * TILE_SIZE, movementType: "ground", targetType: "any", splashRadius: 0, visual: { size: 15, color: [200,200,200] } },
  archer_single: { name: "Archer", hp: 250, dmg: 90, speed: "medium", attackRange: 5 * TILE_SIZE, movementType: "ground", targetType: "any", splashRadius: 0, visual: { size: 20, color: [255,100,200] } },
  guard_skeleton: { name: "Guard Skeleton", hp: 80, shieldHp: 199, dmg: 80, speed: "fast", attackRange: 1.2 * TILE_SIZE, movementType: "ground", targetType: "any", splashRadius: 0, visual: { size: 18, color: [180,180,220] } },
};


const STARTING_HP = { king: 4000, princess: 2000 };

const SPEED_MAP = {
  "slow": 0.8 * TILE_SIZE, // pixels per second
  "medium": 1.2 * TILE_SIZE,
  "fast": 1.8 * TILE_SIZE,
  "very fast": 2.5 * TILE_SIZE,
};

// --- 全域變數 ---
let gameState = "MENU"; // MENU | DECK_BUILDER | BATTLE | POST_GAME
let currentMatch = null;
let deckBuilder = null;
let playerDeck = []; // 玩家選擇的牌組 (CardData objects)
let lastUsedDeck = []; // 用於 localStorage

let simpleFont; // 字體
let hoveredCardDetails = null;


// 音效相關
let sounds = {};
let soundEnabled = true; // 簡易音量控制（開/關）

// --- p5.js 主要函式 ---
function preload() {
  // 若有外部資源（如字體），在此載入
  // simpleFont = loadFont('assets/your_font.ttf'); // 範例，本專案不使用外部字體
}

function mouseMoved() {
  hoveredCardDetails = null; // 每次滑鼠移動時先重置

  if (gameState === "DECK_BUILDER" && deckBuilder) {
    deckBuilder.handleMouseMoved(mouseX, mouseY); // 請 DeckBuilder 處理懸停
  } else if (gameState === "BATTLE" && currentMatch && currentMatch.players[0]) {
    // 假設玩家0是人類玩家
    currentMatch.players[0].handleHandHover(mouseX, mouseY); // 請玩家物件處理手牌懸停
  }
}

function setup() {
  createCanvas(CANVAS_WIDTH, CANVAS_HEIGHT);
  frameRate(FPS_TARGET);
  // textFont(simpleFont); // 設定預設字體
  textAlign(CENTER, CENTER);
  rectMode(CENTER); // 方便繪製矩形

  // 初始化音效 (使用 p5.Oscillator)
  if (typeof p5.Oscillator !== 'undefined') {
    sounds.click = createSineOscillator(2000, 0.2, 0.01, 0.05); // freq, amp, attack, release
    sounds.explosion = createSineOscillator(100, 0.5, 0.05, 0.5);
    sounds.fanfare_win = createFanfareOscillator(0.4); // 勝利音效序列
    sounds.deploy = createSineOscillator(800, 0.3, 0.02, 0.1);
    sounds.hit = createSineOscillator(1500, 0.1, 0.01, 0.03);
    sounds.unit_death = createSineOscillator(400, 0.2, 0.01, 0.2, 'noise');
  } else {
    console.warn("p5.sound is not available. Sound effects will be disabled.");
    soundEnabled = false;
  }
  
  loadLastUsedDeck(); // 載入上次使用的牌組
  initGame();
}

function draw() {
  const dt = deltaTime / 1000; // 增量時間 (秒)

  background(50, 60, 70); // 深色背景

  // 根據遊戲狀態呼叫對應的更新與繪製函式
  switch (gameState) {
    case "MENU":
      renderMainMenu();
      break;
    case "DECK_BUILDER":
      deckBuilder.update(dt);
      deckBuilder.draw();
      break;
    case "BATTLE":
      if (currentMatch) {
        currentMatch.update(dt);
        currentMatch.render();
      }
      break;
    case "POST_GAME":
      renderPostGameScreen();
      break;
  }

    // <<< 新增：如果 hoveredCardDetails 不是 null，就繪製卡片資訊框 >>>
  if (hoveredCardDetails) {
    drawCardInfoBox(hoveredCardDetails);
  }

  
  // 顯示 FPS
  fill(255);
  textSize(16);
  textAlign(LEFT, TOP);
  text(`FPS: ${frameRate().toFixed(0)}`, 10, 10);
  
  // 簡易音量按鈕
  textAlign(RIGHT, TOP);
  text(`Sound: ${soundEnabled ? 'ON' : 'OFF'} (M to toggle)`, CANVAS_WIDTH - 10, 10);
}

function mousePressed() {
  // 將滑鼠事件傳遞給當前遊戲狀態的處理器
  switch (gameState) {
    case "MENU":
      handleMenuClick();
      break;
    case "DECK_BUILDER":
      deckBuilder.handleMousePressed(mouseX, mouseY);
      break;
    case "BATTLE":
      if (currentMatch) {
        currentMatch.handleMousePressed(mouseX, mouseY);
      }
      break;
    case "POST_GAME":
      // 按任意鍵返回主選單 (這裡用滑鼠點擊代替)
      initGame(); // 重置遊戲並返回主選單
      break;
  }
}

// 鍵盤事件處理
function keyPressed() {
  if (keyCode === ESCAPE) {
    if (gameState === "BATTLE" || gameState === "DECK_BUILDER" || gameState === "POST_GAME") {
      playSound('click');
      initGame(); // 返回主選單
    }
  }
  if (key === 'm' || key === 'M') {
    soundEnabled = !soundEnabled;
  }
  if (gameState === "POST_GAME") {
     playSound('click');
     initGame(); // 重置遊戲並返回主選單
  }
}

// --- 遊戲流程函式 ---
function initGame() {
  gameState = "MENU";
  currentMatch = null; // 清除先前的對戰
  deckBuilder = new DeckBuilder(CARD_POOL);
  if (lastUsedDeck.length === 8) {
    deckBuilder.setSelectedDeck(lastUsedDeck.map(cardName => CARD_POOL.find(c => c.name === cardName)));
  }
}

// --- 主選單 ---
function renderMainMenu() {
  fill(200);
  textSize(64);
  textAlign(CENTER, CENTER);
  text("卡牌對戰遊戲(皇室戰爭玩法)", CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3);

  // 開始按鈕
  let btnX = CANVAS_WIDTH / 2;
  let btnY = CANVAS_HEIGHT / 2 + 50;
  let btnW = 200;
  let btnH = 80;
  fill(100, 200, 100);
  rect(btnX, btnY, btnW, btnH, 10);
  fill(0);
  textSize(32);
  text("開始", btnX, btnY);

  textSize(16);
  text(`版本: ${APP_VERSION}`, CANVAS_WIDTH / 2, CANVAS_HEIGHT - 30);
}

function handleMenuClick() {
  let btnX = CANVAS_WIDTH / 2;
  let btnY = CANVAS_HEIGHT / 2 + 50;
  let btnW = 200;
  let btnH = 80;
  if (mouseX > btnX - btnW/2 && mouseX < btnX + btnW/2 &&
      mouseY > btnY - btnH/2 && mouseY < btnY + btnH/2) {
    playSound('click');
    gameState = "DECK_BUILDER";
  }
}

// --- 牌組編輯畫面 (DeckBuilder Class) ---
class DeckBuilder {
  constructor(cardPool) {
    this.cardPool = [...cardPool].sort((a,b) => a.elixir - b.elixir || a.name.localeCompare(b.name)); // 排序卡牌
    this.selectedDeck = []; // 已選牌組 (CardData objects)
    this.scrollOffset = 0;
    this.cardDisplayHeight = 60;
    this.cardDisplayWidth = CANVAS_WIDTH / 2 - 80; // 左側列表卡牌寬度
    this.deckSlotSize = 80;

    // UI 元素位置
    this.listX = 0;
    this.listY = 50;
    this.listWidth = CANVAS_WIDTH / 2 - 20;
    this.listHeight = CANVAS_HEIGHT - 150;

    this.deckX = CANVAS_WIDTH / 2 + 20;
    this.deckY = 50;
    this.deckWidth = CANVAS_WIDTH / 2 - 40;
    
    this.confirmButton = { x: CANVAS_WIDTH - 150, y: CANVAS_HEIGHT - 80, w: 200, h: 60, text: "確認牌組" };
  }

    handleMouseMoved(mx, my) {
    // 檢查卡牌池列表的懸停
    const itemHeight = this.cardDisplayHeight;
    const itemPadding = 5;
    const listStartY = this.listY;

    for (let i = 0; i < this.cardPool.length; i++) {
      let card = this.cardPool[i];
      // 計算卡牌在列表中的實際繪製區域 (左上角x, 左上角y, 寬, 高)
      // 假設卡牌在列表中是居中顯示的
      let cardRectX = this.listX + (this.listWidth - this.cardDisplayWidth) / 2;
      let cardRectY = listStartY + i * (itemHeight + itemPadding) - this.scrollOffset;

      // 檢查滑鼠是否在該卡牌的區域內，並且該卡牌部分是可見的
      if (mx >= cardRectX && mx <= cardRectX + this.cardDisplayWidth &&
          my >= cardRectY && my <= cardRectY + itemHeight) {
        if (cardRectY + itemHeight >= listStartY && cardRectY <= listStartY + this.listHeight) { // 確保在可視範圍內
            hoveredCardDetails = card;
            return; // 找到一個懸停，就不再檢查其他
        }
      }
    }

    // 檢查已選牌組的懸停
    const slotSize = this.deckSlotSize;
    const deckPadding = 10;
    const cardsPerRow = 4;
    // 計算已選牌組區域第一個卡槽的左上角 X 座標
    const startXDeckContainer = this.deckX + (this.deckWidth - (cardsPerRow * slotSize + (cardsPerRow - 1) * deckPadding)) / 2;
    let currentYDeck = this.deckY; // 已選牌組區域的起始 Y 座標

    for (let i = 0; i < 8; i++) { // 檢查所有8個卡槽
      const row = Math.floor(i / cardsPerRow);
      const col = i % cardsPerRow;
      // 計算當前卡槽的左上角 x, y
      const slotRectX = startXDeckContainer + col * (slotSize + deckPadding);
      const slotRectY = currentYDeck + row * (slotSize + deckPadding);

      if (this.selectedDeck[i]) { // 只有當卡槽裡有卡片時才檢查
        if (mx >= slotRectX && mx <= slotRectX + slotSize &&
            my >= slotRectY && my <= slotRectY + slotSize) {
          hoveredCardDetails = this.selectedDeck[i];
          return; // 找到一個懸停
        }
      }
    }
  }

  
  setSelectedDeck(deck) {
    this.selectedDeck = deck.slice(0, 8);
  }

  update(dt) {
    // 處理滾動 (如果用滑鼠滾輪)
    // for simplicity, this example might omit complex scrollbar UI
  }

  addCardToDeck(cardData) {
    if (this.selectedDeck.length < 8 && !this.selectedDeck.find(c => c.id === cardData.id)) {
      this.selectedDeck.push(cardData);
      playSound('click');
    }
  }

  removeCardFromDeck(cardData) {
    this.selectedDeck = this.selectedDeck.filter(c => c.id !== cardData.id);
    playSound('click');
  }

  getAverageElixir() {
    if (this.selectedDeck.length === 0) return 0;
    let totalElixir = 0;
    for (let card of this.selectedDeck) {
        // Mirror card elixir is variable, handle if Mirror itself is in deck (not practical here for average calc)
        if (card.special === "mirror_last_card") {
             // For avg calculation, maybe use a base value or exclude. Let's use 3 as an average mirrored cost.
            totalElixir += 3;
        } else {
            totalElixir += card.elixir;
        }
    }
    return (totalElixir / this.selectedDeck.length).toFixed(1);
  }

  draw() {
    background(60, 70, 80);
    textSize(24);
    fill(220);
    textAlign(CENTER, TOP);
    text("牌組編輯", CANVAS_WIDTH / 2, 10);

    // 左側：可捲動的卡牌列表
    this.drawCardPoolList();

    // 右側：已選牌組
    this.drawSelectedDeck();

    // 右下：平均聖水消耗
    textAlign(RIGHT, BOTTOM);
    fill(220);
    textSize(20);
    text(`平均聖水: ${this.getAverageElixir()}`, this.deckX + this.deckWidth - 20, CANVAS_HEIGHT - 120);

    // 確認按鈕
    fill(100, 200, 100);
    rect(this.confirmButton.x, this.confirmButton.y, this.confirmButton.w, this.confirmButton.h, 10);
    fill(0);
    textSize(24);
    textAlign(CENTER, CENTER);
    text(this.confirmButton.text, this.confirmButton.x, this.confirmButton.y);
    if (this.selectedDeck.length !== 8) {
        fill(255,0,0,150);
        rect(this.confirmButton.x, this.confirmButton.y, this.confirmButton.w, this.confirmButton.h, 10);
        fill(255); textSize(16);
        text("需選滿8張牌", this.confirmButton.x, this.confirmButton.y + this.confirmButton.h/2 + 15);
    }
  }

  drawCardPoolList() {
    const startY = this.listY;
    const itemHeight = this.cardDisplayHeight;
    const padding = 5;
    const visibleItems = Math.floor(this.listHeight / (itemHeight + padding));

    // 簡易滾動條 (placeholder)
    // fill(100); rect(this.listX + this.listWidth - 10, this.listY + this.listHeight / 2, 10, this.listHeight);

    for (let i = 0; i < this.cardPool.length; i++) {
      let card = this.cardPool[i];
      let cardY = startY + i * (itemHeight + padding) - this.scrollOffset;
      
      // 簡易可見性檢查
      if (cardY + itemHeight < startY || cardY > startY + this.listHeight) {
        continue;
      }

      // 繪製卡牌項
      let cardColor = this.selectedDeck.find(c => c.id === card.id) ? [80,80,80] : [120,120,120];
      fill(cardColor);
      rect(this.listX + this.listWidth/2, cardY + itemHeight/2, this.cardDisplayWidth, itemHeight, 5);
      
      fill(255);
      textSize(16);
      textAlign(LEFT, CENTER);
      text(`${card.name} (${card.elixir})`, this.listX + 20, cardY + itemHeight/2);
      textAlign(RIGHT, CENTER);
      textSize(12);
      text(card.type, this.listX + this.listWidth - 90, cardY + itemHeight/2);
    }
     // 滾動提示
    if (this.cardPool.length * (itemHeight + padding) > this.listHeight) {
      textAlign(CENTER, BOTTOM);
      fill(180);
      textSize(14);
      text("用滑鼠滾輪捲動列表", this.listX + this.listWidth / 2, this.listY + this.listHeight + 20);
    }
  }
  
  mouseWheel(event) { // p5.js specific mouseWheel event
    if (mouseX > this.listX && mouseX < this.listX + this.listWidth &&
        mouseY > this.listY && mouseY < this.listY + this.listHeight) {
        const itemHeight = this.cardDisplayHeight;
        const padding = 5;
        const totalContentHeight = this.cardPool.length * (itemHeight + padding);
        this.scrollOffset += event.delta;
        this.scrollOffset = constrain(this.scrollOffset, 0, Math.max(0, totalContentHeight - this.listHeight));
      
              // <<< 新增：滾動後也檢查一次懸停 >>>
        this.handleMouseMoved(mouseX, mouseY);

    }
  }


  drawSelectedDeck() {
    textAlign(CENTER, TOP);
    fill(220);
    textSize(20);
    text("已選牌組 (8張)", this.deckX + this.deckWidth / 2, this.deckY - 30);

    const slotSize = this.deckSlotSize;
    const padding = 10;
    const cardsPerRow = 4;
    const startX = this.deckX + (this.deckWidth - (cardsPerRow * slotSize + (cardsPerRow - 1) * padding)) / 2;
    let currentY = this.deckY;

    for (let i = 0; i < 8; i++) {
      const row = Math.floor(i / cardsPerRow);
      const col = i % cardsPerRow;
      const x = startX + col * (slotSize + padding) + slotSize/2;
      const y = currentY + row * (slotSize + padding) + slotSize/2;

      if (this.selectedDeck[i]) {
        let card = this.selectedDeck[i];
        fill(getRarityColor(card.rarity));
        rect(x, y, slotSize, slotSize, 8);
        fill(0);
        textSize(12);
        textAlign(CENTER, CENTER);
        text(card.name, x, y - 10, slotSize - 4);
        textSize(16);
        text(card.elixir, x, y + 15);
      } else {
        fill(80, 80, 90);
        rect(x, y, slotSize, slotSize, 8);
      }
    }
  }

  handleMousePressed(mx, my) {
    // 檢查點擊確認按鈕
    if (mx > this.confirmButton.x - this.confirmButton.w/2 && mx < this.confirmButton.x + this.confirmButton.w/2 &&
        my > this.confirmButton.y - this.confirmButton.h/2 && my < this.confirmButton.y + this.confirmButton.h/2) {
      if (this.selectedDeck.length === 8) {
        playSound('click');
        playerDeck = [...this.selectedDeck]; // 複製一份作為玩家牌組
        saveLastUsedDeck(playerDeck.map(c => c.name)); // 保存牌組
        
        currentMatch = new Match(playerDeck, generateAIRandomDeck());
        gameState = "BATTLE";
      } else {
        // 提示需要選滿8張 (已在draw中處理)
        playSound('explosion'); // 錯誤音效
      }
      return;
    }

    // 檢查點擊卡牌列表
    const itemHeight = this.cardDisplayHeight;
    const padding = 5;
    if (mx > this.listX && mx < this.listX + this.listWidth &&
        my > this.listY && my < this.listY + this.listHeight) {
      const clickIndex = Math.floor((my - this.listY + this.scrollOffset) / (itemHeight + padding));
      if (clickIndex >= 0 && clickIndex < this.cardPool.length) {
        this.addCardToDeck(this.cardPool[clickIndex]);
      }
      return;
    }
    
    // 檢查點擊已選牌組
    const slotSize = this.deckSlotSize;
    const deckPadding = 10;
    const cardsPerRow = 4;
    const startXDeck = this.deckX + (this.deckWidth - (cardsPerRow * slotSize + (cardsPerRow - 1) * deckPadding)) / 2;
    let currentYDeck = this.deckY;

    for (let i = 0; i < this.selectedDeck.length; i++) {
      const row = Math.floor(i / cardsPerRow);
      const col = i % cardsPerRow;
      const x = startXDeck + col * (slotSize + deckPadding);
      const y = currentYDeck + row * (slotSize + deckPadding);
      if (mx > x && mx < x + slotSize && my > y && my < y + slotSize) {
        this.removeCardFromDeck(this.selectedDeck[i]);
        return;
      }
    }
  }
}

// 獨立的 mouseWheel 處理函式，因為 p5.js 是這樣呼叫的
function mouseWheel(event) {
  if (gameState === "DECK_BUILDER" && deckBuilder) {
    deckBuilder.mouseWheel(event);
  }
}


// --- 對戰畫面 (BattleArena / Match Class) ---
class Match {
  constructor(playerDeckCards, aiDeckCards) {
    this.players = [
      new Player(0, playerDeckCards, true), // 人類玩家
      new Player(1, aiDeckCards, false)     // AI 對手
    ];
    this.gameObjects = []; // 所有場上單位、建築、法術效果
    this.particles = [];

    this.timer = MATCH_DURATION_SECONDS;
    this.matchPhase = "NORMAL"; // NORMAL | OVERTIME | TIEBREAKER
    this.elixirRateMultiplier = 1;
    this.winner = null; // null | 0 (player) | 1 (AI) | "TIE"
    this.gameOverMessage = "";

    this.lastPlayedCardPlayer = null; // For Mirror card
    this.lastPlayedCardAI = null;

    this.aiNextPlayTime = random(AI_PLAY_INTERVAL_MIN, AI_PLAY_INTERVAL_MAX);
    
    this.paused = false; // 可用於 ESC 暫停等

    this.eventLog = []; // For replay feature (optional)
    this.cardsPlayedCount = [0, 0]; // [player, AI]
  }

  update(dt) {
    if (this.winner !== null) return; // 遊戲結束則停止更新

    // 更新計時器和階段
    this.timer -= dt;
    if (this.matchPhase === "NORMAL" && this.timer <= 0) {
      this.matchPhase = "OVERTIME";
      this.timer = OVERTIME_DURATION_SECONDS;
      this.elixirRateMultiplier = ELIXIR_RATE_OVERTIME / ELIXIR_RATE_NORMAL; // 規格是3倍，但這裡是用相對值
      this.eventLog.push({time: this.getElapsedTime(), event: "OVERTIME_START"});
      // 檢查勝利條件 (摧毀塔數)
      this.checkTowerCountWin();
    } else if (this.matchPhase === "OVERTIME" && this.timer <= 0) {
      this.matchPhase = "TIEBREAKER";
      this.timer = TIEBREAKER_DURATION_SECONDS;
      this.eventLog.push({time: this.getElapsedTime(), event: "TIEBREAKER_START"});
      this.checkTowerCountWin(); // 再次檢查，若平手則進入 tiebreaker
    } else if (this.matchPhase === "TIEBREAKER") {
      if (this.timer <= 0) {
        this.checkTiebreakerWin(); // Tiebreaker結束，判定勝負
      } else {
        // 所有塔每秒損血
        const hpLoss = TIEBREAKER_HP_LOSS_PER_SECOND * dt;
        this.players.forEach(p => {
          p.towers.forEach(t => {
            if (t.hp > 0) t.takeDamage(hpLoss);
          });
        });
      }
    }
    
    // 更新玩家 (聖水、手牌等)
    this.players.forEach(p => p.update(dt, this.elixirRateMultiplier));

    // AI 行為
    this.updateAI(dt);

    // 更新所有遊戲物件 (單位、建築、法術)
    for (let i = this.gameObjects.length - 1; i >= 0; i--) {
      const obj = this.gameObjects[i];
      obj.update(dt, this);
      if (obj.isDestroyed || (obj.duration !== undefined && obj.duration <=0)) {
        if(obj.cardData && obj.cardData.special === "death_damage" && obj.hp <=0) { // e.g. Balloon
            this.spawnSpellEffect(obj.cardData, obj.pos, obj.isFriendly ? this.players[0] : this.players[1], obj.cardData.dmg / 2, obj.cardData.attackRange * 1.5); // Example death damage
        }
        this.gameObjects.splice(i, 1);
        if (obj instanceof Unit) { // 播放死亡動畫
          this.spawnParticleEffect(obj.pos, 20, obj.isFriendly ? COLOR_PLAYER : COLOR_AI, 'death');
          playSound('unit_death');
        }
      }
    }
    
    // 更新粒子效果
    for (let i = this.particles.length - 1; i >= 0; i--) {
      this.particles[i].update(dt);
      if (this.particles[i].isFinished()) {
        this.particles.splice(i, 1);
      }
    }
    
    // 檢查勝利條件 (即時)
    this.checkInstantWinConditions();
  }

  updateAI(dt) {
    const aiPlayer = this.players[1];
    if (!aiPlayer || aiPlayer.isHuman) return;

    this.aiNextPlayTime -= dt;
    if (this.aiNextPlayTime <= 0) {
      this.aiNextPlayTime = random(AI_PLAY_INTERVAL_MIN, AI_PLAY_INTERVAL_MAX);
      
      // AI 決策邏輯
      let cardToPlay = null;
      let availableCards = aiPlayer.hand.filter(card => card && aiPlayer.elixir >= this.getCardElixir(card, aiPlayer));
      if (availableCards.length === 0) return;

      // 策略：塔血 < 30% 優先防守，否則隨機進攻
      let criticalTower = aiPlayer.towers.find(t => t.hp > 0 && (t.hp / t.maxHp) < AI_DEFEND_HP_THRESHOLD);
      let playerThreats = this.gameObjects.filter(obj => obj instanceof Unit && !obj.isFriendly && obj.target && aiPlayer.towers.includes(obj.target));

      if (criticalTower || playerThreats.length > 0) { // 防守邏輯
        // 嘗試找解場牌 (例如法術對付群聚敵人，或單位放在威脅路徑上)
        // 簡化：選擇最便宜的可用牌
        availableCards.sort((a, b) => this.getCardElixir(a, aiPlayer) - this.getCardElixir(b, aiPlayer));
        cardToPlay = availableCards[0];
      } else { // 進攻邏輯
        // 隨機選一張可用的牌
        cardToPlay = random(availableCards);
      }

      if (cardToPlay) {
        // 決定放置位置/目標
        let placementPos = null;
        let targetPos = null;
        
        const deployY = BRIDGE_Y_POSITION - TILE_SIZE * 1.5; // AI方橋前
        const randomXOffset = (random() - 0.5) * (CANVAS_WIDTH / 3);
        let spawnX = CANVAS_WIDTH / 2 + randomXOffset;
        spawnX = constrain(spawnX, TILE_SIZE, CANVAS_WIDTH - TILE_SIZE);

        if (cardToPlay.type === "troop" || cardToPlay.type === "building") {
          placementPos = createVector(spawnX, deployY);
          if (cardToPlay.special === "deploy_anywhere_ground" && cardToPlay.name === "鑽地礦工 Miner") { // Miner AI
            const enemyTowers = this.players[0].towers.filter(t => t.hp > 0);
            if (enemyTowers.length > 0) {
                placementPos = random(enemyTowers).pos.copy(); // 放到敵人塔旁
            } else {
                 placementPos = createVector(spawnX, CANVAS_HEIGHT - deployY); // 深入敵陣
            }
          }
        } else if (cardToPlay.type === "spell") {
          // 選擇目標：優先打擊敵方單位密集區或塔
          let potentialTargets = this.gameObjects.filter(obj => obj.isFriendly === false && obj.hp > 0); // Friendly to AI is Player's units
          if (potentialTargets.length > 0) {
            targetPos = random(potentialTargets).pos.copy();
          } else { // 沒有單位就打塔
            const playerTowers = this.players[0].towers.filter(t => t.hp > 0);
            if (playerTowers.length > 0) targetPos = random(playerTowers).pos.copy();
            else targetPos = createVector(CANVAS_WIDTH / 2, CANVAS_HEIGHT - KING_TOWER_Y_OFFSET); // 玩家國王塔位置
          }
          placementPos = targetPos; // 法術直接指定目標位置
        }
        
        if (placementPos) {
          this.playCard(aiPlayer, cardToPlay, placementPos, targetPos);
        }
      }
    }
  }

  getCardElixir(cardData, player) {
      if (cardData.special === "mirror_last_card") {
          const lastCard = player.id === 0 ? this.lastPlayedCardPlayer : this.lastPlayedCardAI;
          return lastCard ? lastCard.elixir + 1 : 99; // 99 if no last card (should not happen if mirror is playable)
      }
      return cardData.elixir;
  }

  playCard(player, cardData, position, targetPosition = null) {
    const elixirCost = this.getCardElixir(cardData, player);
    if (player.elixir < elixirCost) return false;

    player.elixir -= elixirCost;
    this.cardsPlayedCount[player.id]++;
    playSound('deploy');

    if (cardData.special === "mirror_last_card") {
        const lastCard = player.id === 0 ? this.lastPlayedCardPlayer : this.lastPlayedCardAI;
        if(lastCard) {
            // Play the actual last card, not the mirror card itself
            this.spawnGameObject(lastCard, player, position, targetPosition);
            // Mirror itself becomes the new "last played card" for purposes of not mirroring mirror
             if (player.id === 0) this.lastPlayedCardPlayer = cardData; else this.lastPlayedCardAI = cardData;
        }
    } else {
        this.spawnGameObject(cardData, player, position, targetPosition);
        // Update last played card (excluding Mirror itself from being mirrored immediately)
        if (player.id === 0) this.lastPlayedCardPlayer = cardData; else this.lastPlayedCardAI = cardData;
    }
    
    player.cycleCard(cardData);
    this.eventLog.push({ time: this.getElapsedTime(), player: player.id, card: cardData.name, pos: position ? [position.x, position.y] : null });
    return true;
  }
  
  spawnGameObject(cardData, player, position, targetPosition) {
    const isFriendly = player.isHuman; // Assuming player 0 is human and friendly
    
    if (cardData.type === "troop") {
      const spawnCount = cardData.spawnCount || 1;
      const unitIdToSpawn = cardData.spawnUnitId; // e.g. "skeleton_basic"
      
      for (let i = 0; i < spawnCount; i++) {
        let spawnPos = position.copy();
        if (spawnCount > 1) { // Simple spread for swarm units
          spawnPos.add(random(-TILE_SIZE/2, TILE_SIZE/2), random(-TILE_SIZE/2, TILE_SIZE/2));
        }

        let unitProps;
        if (unitIdToSpawn && UNIT_TEMPLATES[unitIdToSpawn]) { // Spawning predefined sub-units
            unitProps = { ...UNIT_TEMPLATES[unitIdToSpawn], card_id_source: cardData.id };
        } else { // Spawning the card itself as a unit
            unitProps = {
                hp: cardData.hp,
                dmg: cardData.dmg,
                speed: SPEED_MAP[cardData.speed] || SPEED_MAP["medium"],
                attackRange: cardData.attackRange,
                movementType: cardData.movementType,
                targetType: cardData.targetType,
                splashRadius: cardData.splashRadius,
                special: cardData.special,
                name: cardData.name, // For display or specific logic
                card_id_source: cardData.id,
                visual: { // Default visual if not in UNIT_TEMPLATES
                    size: cardData.movementType === 'air' ? TILE_SIZE * 0.8 : TILE_SIZE,
                    color: cardData.movementType === 'air' ? COLOR_AIR_UNIT : COLOR_GROUND_UNIT
                }
            };
        }
        // Override some properties from cardData if it's a direct spawn
        if (!unitIdToSpawn) {
            unitProps.hp = cardData.hp;
            unitProps.dmg = cardData.dmg;
            // etc for other direct stats
        }


        const newUnit = new Unit(spawnPos.x, spawnPos.y, isFriendly, unitProps, cardData);
        this.gameObjects.push(newUnit);
      }

    } else if (cardData.type === "building") {
      const newBuilding = new Building(position.x, position.y, isFriendly, cardData);
      this.gameObjects.push(newBuilding);
    } else if (cardData.type === "spell") {
      this.spawnSpellEffect(cardData, targetPosition || position, player, cardData.dmg, cardData.attackRange, cardData.splashRadius);
    }
  }

  spawnSpellEffect(cardData, position, casterPlayer, spellDmg, spellRange, spellSplashRadius) {
    const spellEffect = new Spell(position.x, position.y, casterPlayer.isHuman, cardData, spellDmg, spellRange, spellSplashRadius);
    this.gameObjects.push(spellEffect);
    spellEffect.applyEffect(this); // Apply instant effects
    this.spawnParticleEffect(position, 30, COLOR_SPELL_EFFECT, cardData.name.includes("Log") ? 'line' : 'circle');
    // Play sound based on spell type
    if (cardData.name.includes("雷擊") || cardData.name.includes("火球")) playSound('explosion');
    else playSound('click'); // Generic spell sound
  }
  
  spawnParticleEffect(pos, count, pColor, type = 'explosion') {
      if (this.particles.length > PARTICLE_LIMIT - count) { // Limit particles for performance
          count = Math.max(0, PARTICLE_LIMIT - this.particles.length);
      }
      for (let i = 0; i < count; i++) {
          this.particles.push(new Particle(pos.x, pos.y, pColor, type));
      }
  }

  getElapsedTime() {
    if (this.matchPhase === "NORMAL") return MATCH_DURATION_SECONDS - this.timer;
    if (this.matchPhase === "OVERTIME") return MATCH_DURATION_SECONDS + (OVERTIME_DURATION_SECONDS - this.timer);
    return MATCH_DURATION_SECONDS + OVERTIME_DURATION_SECONDS + (TIEBREAKER_DURATION_SECONDS - this.timer);
  }

  checkInstantWinConditions() {
    this.players.forEach((player, idx) => {
      if (player.towers.find(t => t.isKing && t.hp <= 0)) {
        this.winner = 1 - idx; // The other player wins
        this.gameOverMessage = `${this.players[this.winner].name} 摧毀了國王塔，取得勝利！`;
        this.endMatch();
      }
    });
  }
  
  checkTowerCountWin() {
    if (this.winner != null) return; // Already decided

    const p0TowersDestroyed = this.players[0].towers.filter(t => t.hp <= 0 && !t.isKing).length;
    const p1TowersDestroyed = this.players[1].towers.filter(t => t.hp <= 0 && !t.isKing).length;

    if (this.matchPhase === "OVERTIME" || this.matchPhase === "TIEBREAKER") { // In OT/TB, any tower destruction can be a win
        const p0KingDown = this.players[0].towers.find(t => t.isKing && t.hp <=0);
        const p1KingDown = this.players[1].towers.find(t => t.isKing && t.hp <=0);

        if (p0KingDown && !p1KingDown) { this.winner = 1; this.gameOverMessage = `${this.players[1].name} 獲勝！`; this.endMatch(); return;}
        if (p1KingDown && !p0KingDown) { this.winner = 0; this.gameOverMessage = `${this.players[0].name} 獲勝！`; this.endMatch(); return;}
        if (p0KingDown && p1KingDown) { this.winner = "TIE"; this.gameOverMessage = `平手！雙方國王塔同時被摧毀！`; this.endMatch(); return;} // Unlikely but possible

        // Check princess towers if kings are up
        const p0PrincessTowersAlive = this.players[0].towers.filter(t => !t.isKing && t.hp > 0).length;
        const p1PrincessTowersAlive = this.players[1].towers.filter(t => !t.isKing && t.hp > 0).length;

        if (p0PrincessTowersAlive < p1PrincessTowersAlive) {
            this.winner = 1; this.gameOverMessage = `${this.players[1].name} 摧毀較多塔，獲勝！`; this.endMatch(); return;
        }
        if (p1PrincessTowersAlive < p0PrincessTowersAlive) {
            this.winner = 0; this.gameOverMessage = `${this.players[0].name} 摧毀較多塔，獲勝！`; this.endMatch(); return;
        }
    }
    
    // If still no winner and it's the end of normal time, proceed based on HP or to next phase
    if (this.matchPhase === "OVERTIME" && this.timer <= 0) { // End of OT, no first tower, go to Tiebreaker
        // No specific win condition here, will go to TIEBREAKER phase if still tied
    } else if (this.matchPhase === "NORMAL" && this.timer <=0) { // End of normal time
        // If one player has more towers standing (fewer destroyed)
        const p0PrincessDestroyed = this.players[0].towers.filter(t => !t.isKing && t.hp <= 0).length;
        const p1PrincessDestroyed = this.players[1].towers.filter(t => !t.isKing && t.hp <= 0).length;

        if (p0PrincessDestroyed > p1PrincessDestroyed) {
            this.winner = 1; this.gameOverMessage = `${this.players[1].name} 摧毀較多塔，獲勝！`; this.endMatch(); return;
        }
        if (p1PrincessDestroyed > p0PrincessDestroyed) {
            this.winner = 0; this.gameOverMessage = `${this.players[0].name} 摧毀較多塔，獲勝！`; this.endMatch(); return;
        }
        // If tower counts are equal, compare total HP of remaining towers (as a more nuanced tiebreak before overtime)
        let p0TotalHP = this.players[0].towers.reduce((sum, t) => sum + t.hp, 0);
        let p1TotalHP = this.players[1].towers.reduce((sum, t) => sum + t.hp, 0);
        if (p0TotalHP < p1TotalHP) {
             // this.winner = 1; this.gameOverMessage = `${this.players[1].name} 剩餘總血量較高，獲勝！`; this.endMatch(); return;
             // Standard CR rules usually go to Overtime if tower counts are equal, not HP. Sticking to that.
        } else if (p1TotalHP < p0TotalHP) {
            // this.winner = 0; this.gameOverMessage = `${this.players[0].name} 剩餘總血量較高，獲勝！`; this.endMatch(); return;
        }
        // If everything is equal, it will proceed to Overtime naturally.
    }
  }

  checkTiebreakerWin() {
    if (this.winner != null) return;
    let p0TotalHP = this.players[0].towers.reduce((sum, t) => sum + Math.max(0, t.hp), 0);
    let p1TotalHP = this.players[1].towers.reduce((sum, t) => sum + Math.max(0, t.hp), 0);

    if (p0TotalHP <= 0 && p1TotalHP <= 0) {
      this.winner = "TIE";
      this.gameOverMessage = "平手！所有塔都被摧毀了！";
    } else if (p0TotalHP <= 0) {
      this.winner = 1; // AI wins
      this.gameOverMessage = `${this.players[1].name} 在 Tiebreaker 中獲勝！`;
    } else if (p1TotalHP <= 0) {
      this.winner = 0; // Player wins
      this.gameOverMessage = `${this.players[0].name} 在 Tiebreaker 中獲勝！`;
    } else { // Time up, but towers still standing
        if (p0TotalHP < p1TotalHP) {
            this.winner = 1;
            this.gameOverMessage = `${this.players[1].name} 剩餘總血量較高，獲勝！`;
        } else if (p1TotalHP < p0TotalHP) {
            this.winner = 0;
            this.gameOverMessage = `${this.players[0].name} 剩餘總血量較高，獲勝！`;
        } else {
            this.winner = "TIE";
            this.gameOverMessage = "平手！血量相同！";
        }
    }
    this.endMatch();
  }

  endMatch() {
    if (this.winner === 0) playSound('fanfare_win');
    else if (this.winner === 1) playSound('explosion'); // Lose sound
    else playSound('click'); // Tie sound

    // Delay transition to post game screen slightly
    setTimeout(() => {
        gameState = "POST_GAME";
    }, 1000); 
  }


  render() {
    // 繪製競技場背景
    this.renderArenaBackground();

    // 繪製橋樑
    fill(100, 80, 60);
    rect(CANVAS_WIDTH / 2, BRIDGE_Y_POSITION, CANVAS_WIDTH, BRIDGE_HEIGHT*1.5); // River
    fill(180, 150, 120); // Bridge color
    rect(CANVAS_WIDTH / 4, BRIDGE_Y_POSITION, BRIDGE_WIDTH, BRIDGE_HEIGHT);
    rect(CANVAS_WIDTH * 3 / 4, BRIDGE_Y_POSITION, BRIDGE_WIDTH, BRIDGE_HEIGHT);


    // 繪製玩家塔、單位、聖水條、手牌等
    this.players.forEach(p => p.render(this.gameObjects));
    
    // 繪製場上物件
    this.gameObjects.sort((a, b) => a.pos.y - b.pos.y); // 繪製順序，y軸較大的後畫 (偽3D)
    this.gameObjects.forEach(obj => obj.draw());

    // 繪製粒子
    this.particles.forEach(p => p.draw());

    // 繪製UI元素 (計時器, 聖水等 - Player class 已經處理了部分)
    this.renderGameInfo();
    
    // 如果有選中要出的牌，顯示放置提示
    if (this.players[0].selectedCardToPlay) {
        const card = this.players[0].selectedCardToPlay;
        const targetRadius = card.attackRange || TILE_SIZE; // Use attackRange for spells, default for units
        const deployColor = this.canDeployAt(card, mouseX, mouseY, this.players[0]) ? [0,255,0,100] : [255,0,0,100];
        
        fill(deployColor);
        if (card.type === "spell") {
            ellipse(mouseX, mouseY, targetRadius * 2, targetRadius * 2);
        } else { // Troop or Building
            rect(mouseX, mouseY, TILE_SIZE, TILE_SIZE);
        }
        // Display card range if applicable
        if(card.attackRange > 0 && card.type !== "spell"){
            noFill();
            stroke(255,255,0,100);
            ellipse(mouseX, mouseY, card.attackRange * 2, card.attackRange * 2);
            noStroke();
        }
    }
  }

  renderArenaBackground() {
    // 玩家區域 (下半部)
    fill(70, 100, 70); // 綠色草地
    rect(CANVAS_WIDTH / 2, CANVAS_HEIGHT * 3 / 4, CANVAS_WIDTH, CANVAS_HEIGHT / 2);
    // AI 區域 (上半部)
    fill(60, 90, 60); //稍暗的草地
    rect(CANVAS_WIDTH / 2, CANVAS_HEIGHT / 4, CANVAS_WIDTH, CANVAS_HEIGHT / 2);
  }

  renderGameInfo() {
    // 計時器
    fill(255);
    textSize(32);
    textAlign(CENTER, TOP);
    let minutes = Math.floor(Math.max(0, this.timer) / 60);
    let seconds = Math.floor(Math.max(0, this.timer) % 60);
    text(`${minutes}:${seconds < 10 ? '0' : ''}${seconds}`, CANVAS_WIDTH / 2, 10);

    if (this.matchPhase === "OVERTIME") {
      fill(255, 200, 0);
      text("加時賽!", CANVAS_WIDTH / 2, 50);
    } else if (this.matchPhase === "TIEBREAKER") {
      fill(255, 0, 0);
      text("Tiebreaker!", CANVAS_WIDTH / 2, 50);
    }
  }

  canDeployAt(cardData, x, y, player) {
      const isFriendlySide = player.isHuman ? (y > BRIDGE_Y_POSITION) : (y < BRIDGE_Y_POSITION);
      const isFriendlyTerritory = player.isHuman ? (y > BRIDGE_Y_POSITION - TILE_SIZE * 2) : (y < BRIDGE_Y_POSITION + TILE_SIZE * 2); // Slightly larger deploy zone past bridge

      if (cardData.special === "deploy_anywhere_ground" && cardData.name === "鑽地礦工 Miner") {
          return true; // Miner can be deployed anywhere on ground
      }
      if (cardData.type === "spell") {
          return true; // Spells can usually be cast anywhere, specific targeting handled by spell logic
      }
      if (cardData.type === "building") {
          return isFriendlySide && x > TILE_SIZE && x < CANVAS_WIDTH - TILE_SIZE; // Buildings only on own side
      }
      // Troops
      return isFriendlyTerritory && x > TILE_SIZE && x < CANVAS_WIDTH - TILE_SIZE;
  }

  handleMousePressed(mx, my) {
    const humanPlayer = this.players.find(p => p.isHuman);
    if (!humanPlayer || this.winner !== null) return;

    // 如果已選中一張牌等待放置
    if (humanPlayer.selectedCardToPlay) {
      const card = humanPlayer.selectedCardToPlay;
      if (this.canDeployAt(card, mx, my, humanPlayer)) {
          let targetPos = null;
          if (card.type === "spell") targetPos = createVector(mx, my); // spell uses click point as target
          
          if (this.playCard(humanPlayer, card, createVector(mx, my), targetPos)) {
            humanPlayer.selectedCardToPlay = null; // 清除選中狀態
          }
      } else {
          // 無法放置，取消選擇
          humanPlayer.selectedCardToPlay = null;
          playSound('explosion'); //無效放置音效
      }
    } else { // 否則，嘗試選擇手牌
      const handCardIndex = humanPlayer.getClickedCardIndex(mx, my);
      if (handCardIndex !== -1) {
        const selectedCard = humanPlayer.hand[handCardIndex];
        const elixirCost = this.getCardElixir(selectedCard, humanPlayer);

        if (selectedCard && humanPlayer.elixir >= elixirCost) {
          if (selectedCard.type === "spell" && selectedCard.special === "mirror_last_card" && !this.lastPlayedCardPlayer) {
            // Can't play mirror if no last card
            playSound('explosion');
            return;
          }
          humanPlayer.selectedCardToPlay = selectedCard;
          playSound('click');
        } else {
            playSound('explosion'); // 聖水不足音效
        }
      }
    }
  }

  // 給單位尋找目標用
  findTargets(unit) {
    let potentialTargets = [];
    const opponentPlayer = this.players[unit.isFriendly ? 1 : 0];

    // 收集所有有效的敵方目標 (單位和塔)
    let allEnemyObjects = [];
    this.gameObjects.forEach(obj => {
      if (obj.isFriendly !== unit.isFriendly && obj.hp > 0 && (obj instanceof Unit || obj instanceof Building)) {
        let canTargetThisType = false; // 單位卡牌設定是否能打此物件類型
        if (unit.targetType === "any") canTargetThisType = true;
        else if (unit.targetType === "buildings" && (obj instanceof Building || obj.isTower)) canTargetThisType = true;
        else if (unit.targetType === "ground" && obj.movementType === "ground") canTargetThisType = true;
        else if (unit.targetType === "air" && obj.movementType === "air") canTargetThisType = true;
        
        let canAttackMovementType = true; // 單位本身是否能攻擊此物件的移動類型
        if (obj.movementType === 'air' && unit.cardData.targetType === 'ground' && unit.movementType === 'ground') {
             // 典型的地面近戰/遠程單位不能打空中，除非卡牌有特殊設定 (例如弓箭手 targetType 是 any)
             // 此處 cardData.targetType 已經處理了這部分，若為 ground 則不會選 air
             // 但需要確保 unit.cardData.targetType 確實反映了對空能力
             if (unit.cardData.targetType !== 'any' && unit.cardData.targetType !== 'air') {
                canAttackMovementType = false;
             }
        }


        if (canTargetThisType && canAttackMovementType) {
          allEnemyObjects.push(obj);
        }
      }
    });
    opponentPlayer.towers.forEach(tower => {
      if (tower.hp > 0) {
        let canTargetThisType = false;
        if (unit.targetType === "any" || unit.targetType === "buildings") canTargetThisType = true;
        // 假設所有單位都能攻擊地面目標的塔 (除非單位只打空中)
        if (unit.targetType === "ground" && unit.cardData.targetType !== "air") canTargetThisType = true;

        if (canTargetThisType) {
          allEnemyObjects.push(tower);
        }
      }
    });

    if (allEnemyObjects.length === 0) return null;

    // 排序邏輯:
    // 1. 優先攻擊最近的敵方 "Unit" (如果單位不是專攻建築)
    // 2. 如果單位專攻建築 ("buildings")，則優先攻擊最近的建築 (包括塔)
    // 3. 如果沒有上述目標，則按原來的建築優先級 (公主塔 > 國王塔 > 其他建築)
    // 4. 最後是按距離選擇。

    allEnemyObjects.sort((a, b) => {
      let distA = p5.Vector.dist(unit.pos, a.pos);
      let distB = p5.Vector.dist(unit.pos, b.pos);

      let aIsUnit = a instanceof Unit;
      let bIsUnit = b instanceof Unit;
      let aIsBuildingType = a instanceof Building || a.isTower; // 廣義的建築
      let bIsBuildingType = b instanceof Building || b.isTower;

      // 規則 A: 如果單位專攻建築
      if (unit.targetType === "buildings") {
        if (aIsBuildingType && !bIsBuildingType) return -1; // a是建築, b不是 -> a優先
        if (!aIsBuildingType && bIsBuildingType) return 1;  // b是建築, a不是 -> b優先
        if (aIsBuildingType && bIsBuildingType) { // 都是建築，按類型細分
            let typePriorityA = (a.isTower ? (a.isKing ? 1 : 2) : 3); // 3:普通建築, 2:公主, 1:國王
            let typePriorityB = (b.isTower ? (b.isKing ? 1 : 2) : 3);
            if (typePriorityA !== typePriorityB) return typePriorityB - typePriorityA; // 數字大的優先
            return distA - distB; // 同類型建築，近的優先
        }
        // 如果都不是建築 (理論上不該發生，因為 unit.targetType 是 buildings)，則按距離
        return distA - distB;
      }

      // 規則 B: 非專攻建築的單位
      // 優先打單位
      if (aIsUnit && !bIsUnit) return -1; // a是單位, b不是 -> a優先
      if (!aIsUnit && bIsUnit) return 1;  // b是單位, a不是 -> b優先
      if (aIsUnit && bIsUnit) return distA - distB; // 都是單位，近的優先

      // 如果都不是單位 (即都是建築了)，則按建築優先級
      if (aIsBuildingType && bIsBuildingType) {
        let typePriorityA = (a.isTower ? (a.isKing ? 1 : 2) : 3); // 3:普通建築, 2:公主, 1:國王
        let typePriorityB = (b.isTower ? (b.isKing ? 1 : 2) : 3);
        if (typePriorityA !== typePriorityB) return typePriorityB - typePriorityA;
        return distA - distB;
      }
      
      // Fallback (不太可能到這裡如果上面邏輯完整)
      return distA - distB;
    });
    
    // 再次過濾，確保選中的目標是單位能夠攻擊的移動類型
    // (例如，一個只打地面的單位，即使排序後最近的是空軍，也不應該選它)
    const finalTarget = allEnemyObjects.find(target => {
        if (target.movementType === 'air') {
            return unit.cardData.targetType === 'any' || unit.cardData.targetType === 'air';
        }
        if (target.movementType === 'ground') {
            return unit.cardData.targetType === 'any' || unit.cardData.targetType === 'ground' || unit.cardData.targetType === 'buildings';
        }
        if (target instanceof Building || target.isTower) { // 建築視為地面
             return unit.cardData.targetType === 'any' || unit.cardData.targetType === 'ground' || unit.cardData.targetType === 'buildings';
        }
        return true; // 預設可攻擊
    });

    return finalTarget || null; // 如果 find 返回 undefined，則返回 null
  }
}

// --- 玩家類別 ---
class Player {
  constructor(id, deckCards, isHuman = false) {
    this.id = id; // 0 for player, 1 for AI
    this.name = isHuman ? "玩家" : "電腦對手";
    this.isHuman = isHuman;
    this.elixir = 5; // 起始聖水
    this.elixirRate = ELIXIR_RATE_NORMAL;

    this.deck = this.shuffleDeck([...deckCards]); // CardData objects
    this.hand = []; // 最多4張牌
    this.nextCard = null; // 下一張牌
    this.fillHand();

    this.towers = this.initTowers();
    this.selectedCardToPlay = null; // For human player, the card selected from hand to be placed
  }

  initTowers() {
    const towers = [];
    const yPos = this.isHuman ? CANVAS_HEIGHT - KING_TOWER_Y_OFFSET : KING_TOWER_Y_OFFSET;
    const princessYPos = this.isHuman ? CANVAS_HEIGHT - PRINCESS_TOWER_Y_OFFSET : PRINCESS_TOWER_Y_OFFSET;

    // 國王塔
    towers.push(BuildingUnit(CANVAS_WIDTH / 2, yPos, this.isHuman, STARTING_HP.king, 100, 7 * TILE_SIZE, true, "KingTower"));
    // 公主塔
    towers.push(BuildingUnit(CANVAS_WIDTH / 2 - PRINCESS_TOWER_X_SPACING, princessYPos, this.isHuman, STARTING_HP.princess, 120, 7.5 * TILE_SIZE, false, "PrincessTowerL"));
    towers.push(BuildingUnit(CANVAS_WIDTH / 2 + PRINCESS_TOWER_X_SPACING, princessYPos, this.isHuman, STARTING_HP.princess, 120, 7.5 * TILE_SIZE, false, "PrincessTowerR"));
    return towers;
  }

  shuffleDeck(deck) {
    for (let i = deck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }
    return deck;
  }

  fillHand() {
    while (this.hand.length < 4 && this.deck.length > 0) {
      this.hand.push(this.deck.shift());
    }
    if (this.deck.length > 0) {
      this.nextCard = this.deck[0];
    } else {
      this.nextCard = null; // Should not happen with 8 card deck cycle
    }
  }
  
  cycleCard(playedCardData) {
    // Remove played card from hand
    const handIndex = this.hand.findIndex(card => card.id === playedCardData.id);
    if (handIndex !== -1) {
        this.hand.splice(handIndex, 1);
    }
    // Add it back to the deck (end of deck)
    this.deck.push(playedCardData);

    // Draw next card into hand
    if(this.deck.length > 0) { // Should always be true if cycling
        this.hand.push(this.deck.shift());
    }
    // Update next card display
    if(this.deck.length > 0) {
        this.nextCard = this.deck[0];
    } else {
        this.nextCard = null;
    }
  }

    handleHandHover(mx, my) {
    if (!this.isHuman) return; // 只對人類玩家有效

    const cardWidth = 80;
    const cardHeight = 100;
    const handCenterY = CANVAS_HEIGHT - 120; // 手牌的中心 Y 座標
    const handSpacing = 10;
    const totalHandWidth = this.hand.length * cardWidth + (this.hand.length - 1) * handSpacing;
    // 計算第一張手牌矩形區域的左上角 X 座標
    let startHandRectX = CANVAS_WIDTH / 2 - totalHandWidth / 2;

    for (let i = 0; i < this.hand.length; i++) {
      if (!this.hand[i]) continue; // 如果該手牌位置為空

      // 當前手牌矩形區域的左上角 X 座標
      const cardRectCurrentX = startHandRectX + i * (cardWidth + handSpacing);
      
      // 檢查滑鼠是否在當前手牌的矩形區域內
      // 注意：你的 `render` 方法中手牌是用 `rectMode(CENTER)` 畫的，中心點是 `(cardCenterX, handBaseY)`
      // 所以這裡的檢測需要對應：
      // cardCenterX = cardRectCurrentX + cardWidth / 2;
      // handBaseY = handCenterY;
      // if (mx >= cardCenterX - cardWidth / 2 && mx <= cardCenterX + cardWidth / 2 &&
      //     my >= handBaseY - cardHeight / 2 && my <= handBaseY + cardHeight / 2) {
      // 或者，更直接地使用計算好的左上角和寬高：
      if (mx >= cardRectCurrentX && mx <= cardRectCurrentX + cardWidth &&
          my >= handCenterY - cardHeight / 2 && my <= handCenterY + cardHeight / 2) {
        hoveredCardDetails = this.hand[i];
        return; // 找到一個懸停
      }
    }
  }


  update(dt, elixirRateMultiplier = 1) {
    // 聖水回復
    if (this.elixir < ELIXIR_MAX) {
      this.elixir += this.elixirRate * elixirRateMultiplier * dt;
      this.elixir = Math.min(this.elixir, ELIXIR_MAX);
    }
    // 塔的更新 (例如攻擊)
    this.towers.forEach(tower => tower.update(dt, currentMatch)); // Pass match for target finding
  }

  render(allGameObjects) {
    // 繪製塔
    this.towers.forEach(tower => tower.draw());

    if (!this.isHuman) return; // 以下只為人類玩家繪製

    // 繪製聖水條
    const elixirBarWidth = 300;
    const elixirBarHeight = 30;
    const elixirBarX = CANVAS_WIDTH / 2;
    const elixirBarY = CANVAS_HEIGHT - 40;
    fill(150, 50, 200, 150); // 背景色
    rect(elixirBarX, elixirBarY, elixirBarWidth, elixirBarHeight, 5);
    fill(220, 100, 255); // 聖水色
    const currentElixirWidth = (this.elixir / ELIXIR_MAX) * elixirBarWidth;
    rect(elixirBarX - (elixirBarWidth - currentElixirWidth)/2 , elixirBarY, currentElixirWidth, elixirBarHeight, 5);
    fill(255);
    textSize(20);
    textAlign(CENTER, CENTER);
    text(Math.floor(this.elixir), elixirBarX, elixirBarY);

    // 繪製手牌
    const cardWidth = 80;
    const cardHeight = 100;
    const handY = CANVAS_HEIGHT - 120;
    const handSpacing = 10;
    const totalHandWidth = this.hand.length * cardWidth + (this.hand.length - 1) * handSpacing;
    let startHandX = CANVAS_WIDTH / 2 - totalHandWidth / 2;

    this.hand.forEach((card, index) => {
      if (!card) return;
      const cardX = startHandX + index * (cardWidth + handSpacing) + cardWidth / 2;
      
      const elixirCost = currentMatch ? currentMatch.getCardElixir(card, this) : card.elixir; // Get actual elixir cost

      // Highlight if selected or affordable
      if (this.selectedCardToPlay && this.selectedCardToPlay.id === card.id) {
          stroke(255,255,0); strokeWeight(3);
      } else if (this.elixir >= elixirCost) {
          stroke(0,255,0); strokeWeight(2);
      } else {
          stroke(100); strokeWeight(1);
      }

      fill(getRarityColor(card.rarity, this.elixir < elixirCost ? 100: 255));
      rect(cardX, handY, cardWidth, cardHeight, 8);
      noStroke();

      fill(this.elixir < elixirCost ? 128 : 0);
      textSize(11);
      textAlign(CENTER, CENTER);
      text(card.name, cardX, handY - cardHeight/2 + 15, cardWidth - 4);
      textSize(18);
      text(elixirCost, cardX, handY + cardHeight/2 - 20);
      
      // Small icon for type
      textSize(10);
      text(card.type, cardX, handY + cardHeight/2 - 40);
    });

    // 繪製下一張牌
    if (this.nextCard) {
      const nextCardX = startHandX + totalHandWidth + handSpacing + cardWidth / 2 + 20;
      const nextCardY = handY;
      fill(getRarityColor(this.nextCard.rarity, 150)); // Dimmed
      rect(nextCardX, nextCardY, cardWidth * 0.8, cardHeight * 0.8, 8);
      fill(50);
      textSize(10);
      text(this.nextCard.name, nextCardX, nextCardY - cardHeight*0.4 + 10, cardWidth*0.8 - 4);
      textSize(14);
      text(this.nextCard.elixir, nextCardX, nextCardY + cardHeight*0.4 - 15);
      textSize(10);
      textAlign(CENTER, TOP);
      fill(255);
      text("Next", nextCardX, nextCardY - cardHeight*0.4 - 15);
    }
  }

  getClickedCardIndex(mx, my) {
    if (!this.isHuman) return -1;
    const cardWidth = 80;
    const cardHeight = 100;
    const handY = CANVAS_HEIGHT - 120;
    const handSpacing = 10;
    const totalHandWidth = this.hand.length * cardWidth + (this.hand.length - 1) * handSpacing;
    let startHandX = CANVAS_WIDTH / 2 - totalHandWidth / 2;

    for (let i = 0; i < this.hand.length; i++) {
      const cardX_rect_start = startHandX + i * (cardWidth + handSpacing);
      if (mx >= cardX_rect_start && mx <= cardX_rect_start + cardWidth &&
          my >= handY - cardHeight/2 && my <= handY + cardHeight/2) {
        return i;
      }
    }
    return -1;
  }
}


// --- 遊戲物件基礎類別 ---
class GameObject {
  constructor(x, y, isFriendly, cardData = null) {
    this.pos = createVector(x, y);
    this.isFriendly = isFriendly; // true for player's, false for AI's
    this.id = Symbol(); // 唯一ID
    this.isDestroyed = false;
    this.cardData = cardData; // The card that spawned this object
    this.movementType = cardData ? cardData.movementType : "ground"; // "ground" or "air"
  }

  update(dt, matchContext) { /* 抽象方法 */ }
  draw() { /* 抽象方法 */ }
  takeDamage(amount) { /* 抽象方法 */ }
}

// --- 單位 (Troop) ---
class Unit extends GameObject {
  constructor(x, y, isFriendly, unitProps, cardData) { // unitProps from UNIT_TEMPLATES or cardData
    super(x, y, isFriendly, cardData); // Pass cardData to GameObject constructor
    
    this.name = unitProps.name;
    this.maxHp = unitProps.hp;
    this.hp = unitProps.hp;
    this.dmg = unitProps.dmg;
    this.speed = unitProps.speed || SPEED_MAP["medium"]; // px/sec
    this.attackRange = unitProps.attackRange;
    this.targetType = unitProps.targetType; // "ground", "air", "any", "buildings"
    this.movementType = unitProps.movementType; // "ground", "air"
    this.splashRadius = unitProps.splashRadius || 0;
    this.special = unitProps.special || ""; // e.g. "charge", "kamikaze"

    this.visual = unitProps.visual || { // Default visual if not in unitProps
        size: this.movementType === 'air' ? TILE_SIZE * 0.7 : TILE_SIZE * 0.8,
        color: this.movementType === 'air' ? COLOR_AIR_UNIT : COLOR_GROUND_UNIT
    };
    if (this.isFriendly) this.visual.color = lerpColor(color(this.visual.color), color(COLOR_PLAYER), 0.3);
    else this.visual.color = lerpColor(color(this.visual.color), color(COLOR_AI), 0.3);


    this.target = null;
    this.attackCooldown = 0;
    this.attackSpeed = 1.5; // attacks per second (default, can be card-specific)

    if (this.special === "charge" && this.cardData.name === "Prince") {
        this.chargeSpeedBonus = 2.0; // Prince charges faster
        this.chargeDamageBonus = 2.0;
        this.isCharging = true;
        this.chargeDistance = TILE_SIZE * 3.5; // Min distance to start charge
        this.originalSpeed = this.speed;
    }
    if (this.special === "shield_to_building" && this.cardData.name === "加農車 Cannon Cart") {
        this.shieldHp = unitProps.hp; // First HP bar is shield
        this.baseHp = 700; // HP after shield breaks (example)
        this.isShielded = true;
    }
     if (this.special === "kamikaze" && this.cardData.name === "精靈 Spirit") {
        this.attackSpeed = 0.5; // Fast attack for kamikaze
    }
  }

  update(dt, match) {
    if (this.hp <= 0) {
      this.isDestroyed = true;
      return;
    }

    if (this.attackCooldown > 0) {
      this.attackCooldown -= dt;
    }

    // 特殊邏輯: Prince charge
    if (this.special === "charge" && this.isCharging) {
        this.speed = this.originalSpeed * this.chargeSpeedBonus;
    } else if (this.special === "charge") {
        this.speed = this.originalSpeed;
    }


    // 尋找目標
    if (!this.target || this.target.hp <= 0 || this.target.isDestroyed) {
      this.target = match.findTargets(this);
      if (this.target && this.special === "charge") this.isCharging = true; // Start charging if new target
    }

    if (this.target) {
      const distToTarget = p5.Vector.dist(this.pos, this.target.pos);
      if (distToTarget <= this.attackRange) {
        // 在攻擊範圍內，停止移動並攻擊
        if (this.special === "charge" && this.isCharging) { // Prince charge attack
            this.attack(this.target, match, this.dmg * this.chargeDamageBonus);
            this.isCharging = false; // Charge used
        } else {
            this.attack(this.target, match, this.dmg);
        }
         if (this.special === "kamikaze") { // Kamikaze units die on attack
            this.hp = 0; 
        }

      } else {
        // 移動向目標
        let moveDir = p5.Vector.sub(this.target.pos, this.pos);
        moveDir.normalize();
        // Avoid collision with own towers when moving (simple check)
        let collisionAvoid = false;
        const friendlyPlayer = match.players[this.isFriendly ? 0 : 1];
        friendlyPlayer.towers.forEach(tower => {
            if (p5.Vector.dist(this.pos, tower.pos) < TILE_SIZE * 0.8) { // Close to own tower
                if (moveDir.dot(p5.Vector.sub(this.pos, tower.pos)) > 0) { // Moving towards own tower center
                    // Try to move around it, very simplified: slightly alter direction
                    // This is a very naive avoidance, real pathfinding is complex
                    // moveDir.rotate(this.isFriendly ? PI/8 : -PI/8); 
                }
            }
        });
        
        this.pos.add(moveDir.mult(this.speed * dt));
        if (this.special === "charge" && this.isCharging && distToTarget < this.chargeDistance / 2) {
            // If gets very close without attacking (e.g. target moved), might stop charge
            // this.isCharging = false; 
        }
      }
    } else {
      // 沒有目標，向對方國王塔移動 (推進)
      const opponentKingTower = match.players[this.isFriendly ? 1 : 0].towers.find(t => t.isKing);
      if (opponentKingTower && opponentKingTower.hp > 0) {
        let moveDir = p5.Vector.sub(opponentKingTower.pos, this.pos);
        moveDir.normalize();
        this.pos.add(moveDir.mult(this.speed * dt));
      }
    }
  }

  attack(target, match, damageOverride = null) {
    if (this.attackCooldown <= 0) {
      const actualDamage = damageOverride !== null ? damageOverride : this.dmg;

      // 判斷是否為遠程攻擊 (攻擊範圍大於近戰閾值)
      // 1.2 * TILE_SIZE 是多數近戰的範圍，所以比它大的都算遠程
      const isRangedAttack = this.attackRange > 1.7 * TILE_SIZE; // 可微調此閾值

      if (isRangedAttack && this.cardData.type !== "spell" && this.dmg > 0) {
        let projectileSpeed = 10; // 基礎速度係數
        let visualOptions = {
            type: 'ellipse',
            size: 8,
            color: this.isFriendly ? [200,200,255,200] : [255,200,200,200]
        };

        // 特定單位的投射物外觀 (例如弓箭手)
        if (this.cardData.name.includes("Archer") || this.cardData.name.includes("弓箭手") || this.cardData.name.includes("女弓")) {
            visualOptions.type = 'rect';
            visualOptions.size = 12; // 箭長
            visualOptions.color = [220, 180, 100];
        } else if (this.cardData.name.includes("電法")) {
            visualOptions.color = [100, 100, 255];
            visualOptions.size = 10;
        }

        const projectile = new Projectile(this.pos.x, this.pos.y, target, projectileSpeed, actualDamage, this.isFriendly, visualOptions, this.cardData);
        match.gameObjects.push(projectile);
        // playSound('arrow_shot'); // 播放發射音效，需要定義
      } else { // 近戰或特殊攻擊 (如範圍濺射), 或傷害為0的單位(如純召喚)
        if (this.splashRadius > 0 && actualDamage > 0) {
          match.gameObjects.forEach(obj => {
            if (obj.isFriendly !== this.isFriendly && obj.hp > 0 && p5.Vector.dist(this.pos, obj.pos) <= this.splashRadius + (obj.visual ? obj.visual.size*0.5 : TILE_SIZE*0.4)) { // 濺射也考慮目標大小
              obj.takeDamage(actualDamage);
              match.spawnParticleEffect(obj.pos, 3, [255,150,0], 'hit_splash');
            }
          });
          match.players[this.isFriendly ? 1 : 0].towers.forEach(tower => {
              if (tower.hp > 0 && p5.Vector.dist(this.pos, tower.pos) <= this.splashRadius + tower.size*0.4) {
                  tower.takeDamage(actualDamage);
                  match.spawnParticleEffect(tower.pos, 3, [255,150,0], 'hit_splash');
              }
          });
           playSound('hit'); // 濺射命中音效
        } else if (actualDamage > 0) { // 單體近戰
          target.takeDamage(actualDamage);
          match.spawnParticleEffect(target.pos, 5, [255,255,0], 'hit');
          playSound('hit');
        }
      }

      this.attackCooldown = 1 / this.attackSpeed;

      if (this.special === "kamikaze" && actualDamage > 0) {
        this.hp = 0;
      }
      if (this.special === "stun_split_attack" && target.attackCooldown !== undefined) {
        target.attackCooldown = Math.max(target.attackCooldown, 0.5);
      }
    }
  }

  takeDamage(amount) {
    if (this.special === "shield_to_building" && this.isShielded) {
        this.shieldHp -= amount;
        if(this.shieldHp <=0) {
            this.isShielded = false;
            this.hp = this.baseHp; // Switch to base HP
            this.maxHp = this.baseHp;
            // Convert to building (simplified: become immobile, different stats maybe)
            // For simplicity, we'll just change its behavior slightly rather than full class swap
            this.speed = 0; 
            this.movementType = "building_like"; // Cannot move
            this.name = "Cannon (Cart Remains)";
            this.visual.color = COLOR_BUILDING;
        }
    } else {
        this.hp -= amount;
    }
    if (this.hp <= 0) {
      this.isDestroyed = true;
      // Death effects like Balloon bomb are handled in Match update's destruction check
    }
  }

  draw() {
    push();
    translate(this.pos.x, this.pos.y);
    
    // 根據陣營和類型選擇顏色
    let unitColor = this.visual.color;
    
    fill(unitColor);
    if (this.movementType === "air") {
      ellipse(0, 0, this.visual.size, this.visual.size * 0.7); // 空中單位用橢圓
      // 簡易陰影
      fill(0,0,0,50);
      ellipse(0, this.visual.size * 0.5, this.visual.size, this.visual.size * 0.2);
    } else {
      rect(0, 0, this.visual.size, this.visual.size); // 地面單位用矩形
    }
    
    // 繪製血條
    const hpBarWidth = this.visual.size;
    const hpBarHeight = 5;
    const hpBarY = -this.visual.size / 2 - 10;
    fill(50);
    rect(0, hpBarY, hpBarWidth, hpBarHeight);
    let currentHp = this.hp;
    let currentMaxHp = this.maxHp;
    if (this.special === "shield_to_building" && this.isShielded) {
        currentHp = this.shieldHp;
        currentMaxHp = this.cardData.hp; // Original card HP as shield HP
        fill(180,180,255); // Shield color
    } else {
       fill(0, 255, 0); // HP color
    }
    rect(- (hpBarWidth - (hpBarWidth * (currentHp / currentMaxHp))) / 2, hpBarY, hpBarWidth * (currentHp / currentMaxHp), hpBarHeight);

    
        // *** 新增：繪製單位名稱 ***
    fill(255); // 白色文字
    textSize(10);
    textAlign(CENTER, BOTTOM); // 文字在血條上方
    let displayName = this.cardData && this.cardData.name ? this.cardData.name : this.name;
    // 對於召喚多個子單位的卡牌，顯示子單位的名稱
    if (this.cardData && this.cardData.spawnCount > 1 && UNIT_TEMPLATES[this.cardData.spawnUnitId]) {
        displayName = UNIT_TEMPLATES[this.cardData.spawnUnitId].name;
    } else if (this.cardData && this.name !== this.cardData.name && this.name === "Skeleton" ) { // Handle Graveyard Skeletons using template name
        displayName = UNIT_TEMPLATES.skeleton_basic.name;
    }
    text(displayName, 0, hpBarY - hpBarHeight / 2 - 2); // 調整Y軸位置，使其在血條之上

    
    // Debug: show name
    // fill(255); textSize(10); textAlign(CENTER, CENTER); text(this.name, 0, 0);

    pop();
  }
}

// --- 建築 (Building & Towers) ---
class Building extends GameObject {
  constructor(x, y, isFriendly, cardData) {
    super(x, y, isFriendly, cardData);
    this.maxHp = cardData.hp;
    this.hp = cardData.hp;
    this.dmg = cardData.dmg;
    this.attackRange = cardData.attackRange;
    this.targetType = cardData.targetType; // "ground", "air", "any"
    this.splashRadius = cardData.splashRadius || 0;
    this.special = cardData.special || "";
    
    this.attackCooldown = 0;
    this.attackSpeed = 1; // Default attacks per second, can be card-specific (e.g. XBow, Inferno)
    this.target = null;
    this.size = TILE_SIZE * 1.5;
    
    this.color = this.isFriendly ? lerpColor(color(COLOR_BUILDING), color(COLOR_PLAYER), 0.3) : lerpColor(color(COLOR_BUILDING), color(COLOR_AI), 0.3);

    if (this.special === "ramping_damage" && this.cardData.name === "火塔 Inferno Tower") {
        this.rampDmgStages = [cardData.dmg, cardData.dmg * 4, cardData.dmg * 20]; // Example stages
        this.currentRampStage = 0;
        this.timeOnTarget = 0;
        this.rampUpTime = 2; // Seconds to reach next stage
        this.attackSpeed = 4; // Inferno Tower attacks faster
    }
    if (this.special === "fast_attack_rate" && this.cardData.name === "X 砲 X-Bow") {
        this.attackSpeed = 3.33; // X-Bow fast attack rate
    }
  }
  
  // Towers are a special type of BuildingUnit for gameplay logic but share Building class for now
  // Use this constructor for player/AI main towers
  static 塔樓(x, y, isFriendly, hp, dmg, range, isKing, typeName) {
      const cardDataLike = { // Mock cardData for towers
          hp: hp, dmg: dmg, attackRange: range,
          targetType: "any", // Towers typically hit ground and air
          type: "building", name: typeName,
          movementType: "n/a" // Not a standard card field, but useful
      };
      let tower = new Building(x, y, isFriendly, cardDataLike);
      tower.isTower = true;
      tower.isKing = isKing;
      tower.size = isKing ? TILE_SIZE * 2.5 : TILE_SIZE * 2;
      tower.color = isFriendly ? COLOR_PLAYER : COLOR_AI; // Towers have distinct colors
      if(isKing) tower.attackSpeed = 1; else tower.attackSpeed = 1/0.8; // King tower slower, Princess faster
      return tower;
  }


  update(dt, match) {
    if (this.hp <= 0) {
      if (this.isDestroyed) return; // Already processed
      this.isDestroyed = true;
      playSound('explosion');
      match.spawnParticleEffect(this.pos, 50, this.color, 'explosion');
      // King tower destruction handled by Match logic for win condition
      return;
    }

    if (this.attackCooldown > 0) {
      this.attackCooldown -= dt;
    }

    // 特斯拉隱藏邏輯
    if (this.special === "hide_until_attack" && this.cardData.name === "特斯拉 Tesla") {
        if (!this.target && (!this.isHiddenExplicitly || this.isHiddenExplicitly === undefined) ) { // If no target, hide. isHiddenExplicitly might be used for manual unhide.
            // Don't draw or be targetable if hidden. This logic is tricky.
            // For now, assume it's always visible once placed until simpler hide logic.
        }
    }

    // 尋找目標
    if (!this.target || this.target.hp <= 0 || this.target.isDestroyed) {
      this.target = this.findBuildingTarget(match);
      if (this.target && this.special === "ramping_damage") { // Reset ramp if target changes
          this.currentRampStage = 0;
          this.timeOnTarget = 0;
      }
    }
    
    if (this.target) {
      const distToTarget = p5.Vector.dist(this.pos, this.target.pos);
      if (distToTarget <= this.attackRange) {
        let currentDmg = this.dmg;
        if (this.special === "ramping_damage") {
            this.timeOnTarget += dt;
            if (this.timeOnTarget >= this.rampUpTime && this.currentRampStage < this.rampDmgStages.length -1) {
                this.currentRampStage++;
                this.timeOnTarget = 0; // Reset time for next stage
            }
            currentDmg = this.rampDmgStages[this.currentRampStage];
        }
        this.attack(this.target, match, currentDmg);
      } else {
        this.target = null; // Target out of range
        if (this.special === "ramping_damage") { // Reset ramp if target lost
            this.currentRampStage = 0;
            this.timeOnTarget = 0;
        }
      }
    }
  }

  findBuildingTarget(match) {
    let potentialTargets = [];
    const opponentPlayer = match.players[this.isFriendly ? 1 : 0];

    // 1. 收集敵方單位
    match.gameObjects.forEach(obj => {
      if (obj.isFriendly !== this.isFriendly && obj.hp > 0 && obj instanceof Unit) {
        let canTargetThisType = false; // 建築卡牌設定是否能打此物件類型
        if (this.targetType === "any") canTargetThisType = true;
        else if (this.targetType === obj.movementType) canTargetThisType = true;
        // 建築物通常不會有 "buildings" targetType，而是 "ground", "air", "any"
        
        if (canTargetThisType) {
          potentialTargets.push(obj);
        }
      }
    });

    // 2. 收集敵方建築物 (包括塔樓)
    // 只有某些建築會主動攻擊敵方建築 (例如 X-Bow)
    // 塔樓之間是否互相攻擊，可以根據遊戲平衡決定。這裡我們先允許它們在沒有單位時互相攻擊。
    let canAttackEnemyBuildings = false;
    if (this.cardData && (this.cardData.name === "X 砲 X-Bow" || this.cardData.name === "皇家巨人 Royal Giant")) { // 皇家巨人也是打建築的單位，但他不是Building類
      canAttackEnemyBuildings = true; // X-Bow 明確攻擊建築
    }
    if (this.isTower) { // 如果自身是塔樓
        canAttackEnemyBuildings = true; // 允許塔樓攻擊敵方塔樓或建築
    }
    // 你也可以根據 cardData.targetType 來決定，例如如果 targetType 包含 "buildings"
    if (this.targetType === "any" || this.targetType === "ground" || this.targetType === "buildings" ) { // 若建築能打地面或任何目標，也應考慮敵方建築
         canAttackEnemyBuildings = true;
    }


    if (canAttackEnemyBuildings) {
      // 敵方玩家放置的建築物
      match.gameObjects.forEach(obj => {
        if (obj.isFriendly !== this.isFriendly && obj.hp > 0 && obj instanceof Building && !obj.isTower) { // 非塔樓的普通建築
           // 確保我方建築可以攻擊此類型的建築 (通常建築是地面目標)
           if (this.targetType === "any" || this.targetType === "ground") {
               potentialTargets.push(obj);
           }
        }
      });
      // 敵方塔樓
      opponentPlayer.towers.forEach(tower => {
        if (tower.hp > 0) {
          // 確保我方建築可以攻擊塔樓 (通常視為地面目標)
          if (this.targetType === "any" || this.targetType === "ground") {
            potentialTargets.push(tower);
          }
        }
      });
    }

    if (potentialTargets.length === 0) return null;

    // 排序目標：
    // 優先級：
    // 1. 最近的敵方單位 (如果建築可以打單位)
    // 2. 然後是最近的敵方建築 (如果可以打建築，例如X-Bow)
    // 3. 然後是最近的敵方公主塔
    // 4. 最後是最近的敵方國王塔

    potentialTargets.sort((a, b) => {
      let distA = p5.Vector.dist(this.pos, a.pos);
      let distB = p5.Vector.dist(this.pos, b.pos);

      let priorityA = 0; // 0: Unit, 1: Building, 2: Princess Tower, 3: King Tower
      let priorityB = 0;

      if (a instanceof Unit) priorityA = 0;
      else if (a instanceof Building && !a.isTower) priorityA = 1;
      else if (a.isTower && !a.isKing) priorityA = 2;
      else if (a.isTower && a.isKing) priorityA = 3;

      if (b instanceof Unit) priorityB = 0;
      else if (b instanceof Building && !b.isTower) priorityB = 1;
      else if (b.isTower && !b.isKing) priorityB = 2;
      else if (b.isTower && b.isKing) priorityB = 3;
      
      // X-Bow 的特殊邏輯: 它優先打建築物，尤其是塔
      if (this.cardData && this.cardData.name === "X 砲 X-Bow") {
          let xbowPriorityA = (a.isTower ? (a.isKing ? 1 : 2) : (a instanceof Building ? 3 : 4)); // 1 King, 2 Princess, 3 Building, 4 Unit
          let xbowPriorityB = (b.isTower ? (b.isKing ? 1 : 2) : (b instanceof Building ? 3 : 4));
          if (xbowPriorityA !== xbowPriorityB) return xbowPriorityA - xbowPriorityB; // 數字小的優先
          return distA - distB;
      }


      // 預設排序: 單位 > 普通建築 > 公主塔 > 國王塔 (數字小的優先)
      if (priorityA !== priorityB) {
        return priorityA - priorityB;
      }

      // 同優先級，距離近的優先
      return distA - distB;
    });
    
    // 最後再檢查一次，選出的目標是否真的是此建築能攻擊的類型 (ground/air)
    // 例如，如果排序後最近的是空軍，但此建築只能打地面，則不能選它。
    const finalTarget = potentialTargets.find(target => {
        if (target.movementType === 'air') { // 假設建築攻擊的目標是 Unit
            return this.targetType === 'any' || this.targetType === 'air';
        }
        // 其他 (Unit ground, Building, Tower) 都視為地面目標
        return this.targetType === 'any' || this.targetType === 'ground';
    });

    return finalTarget || null;
  }

  attack(target, match, damageToDeal) {
    if (this.attackCooldown <= 0 && this.dmg > 0) { // 只有傷害大於0的建築才發射
      let projectileSpeed = 12;
      let visualOptions = {
          type: 'ellipse',
          size: (this.isTower && this.isKing) ? 10 : 8, // 國王塔子彈大一點
          color: this.isFriendly ? [100,150,255] : [255,100,100]
      };

      if (this.special === "ramping_damage") { // Inferno Tower 特效
         visualOptions.color = [255, Math.max(50, 150 - this.currentRampStage * 40) , 0]; // 顏色隨階段變深
         visualOptions.size = 6 + this.currentRampStage * 2;
         projectileSpeed = 15; // 光束快
      } else if (this.cardData.name === "X 砲 X-Bow") {
          visualOptions.size = 6;
          visualOptions.color = [200,200,200];
          projectileSpeed = 18; // XBow 射速快，子彈也快
      } else if (this.cardData.name.includes("加農砲") || this.cardData.name.includes("Cannon")) {
          visualOptions.size = 10;
          visualOptions.color = [120,120,120];
      }


      // 投射物起始位置略微調整，使其看起來從塔/建築的 "砲口" 發射
      let startOffset = createVector(0, -this.size * 0.3); // 默認向上
      if (this.cardData.name === "X 砲 X-Bow" || this.cardData.name.includes("加農砲")) { // XBow和加農砲可能水平發射
          let dirToTarget = p5.Vector.sub(target.pos, this.pos).normalize();
          startOffset = dirToTarget.mult(this.size * 0.4);
      }
      let projectileStartX = this.pos.x + startOffset.x;
      let projectileStartY = this.pos.y + startOffset.y;


      const projectile = new Projectile(projectileStartX, projectileStartY, target, projectileSpeed, damageToDeal, this.isFriendly, visualOptions, this.cardData);
      match.gameObjects.push(projectile);
      // playSound('tower_shot'); // 塔攻擊音效

      this.attackCooldown = 1 / this.attackSpeed;
    }
  }

  takeDamage(amount) {
    this.hp -= amount;
    if (this.hp <= 0) {
      this.hp = 0; // Ensure HP doesn't go negative for display
      // Destruction handled in update for effects
    }
  }

  draw() {
    push();
    translate(this.pos.x, this.pos.y);
    
    fill(this.color);
    if (this.isTower) {
        if (this.isKing) {
            quad(-this.size/3, this.size/2, this.size/3, this.size/2, this.size/2, -this.size/2, -this.size/2, -this.size/2); // Trapezoid shape for King
        } else {
            rect(0,0, this.size*0.7, this.size); // Princess towers taller
        }
    } else {
         rect(0, 0, this.size, this.size * 0.8); // Non-tower buildings
    }

    // 血條
    const hpBarWidth = this.size * 0.8;
    const hpBarHeight = 8;
    const hpBarYOffset = this.isTower ? -this.size/2 - 15 : -this.size*0.4 -10;
    fill(50);
    rect(0, hpBarYOffset, hpBarWidth, hpBarHeight);
    fill(0, 255, 0);
    rect(-(hpBarWidth - (hpBarWidth * (this.hp / this.maxHp)))/2, hpBarYOffset, hpBarWidth * (this.hp / this.maxHp), hpBarHeight);
    
        if (this.attackRange > 0 && this.hp > 0) {
      push();
      noFill();
      stroke(255, 255, 0, 70); // 黃色半透明
      strokeWeight(1);
      // drawDashedEllipse 的 x,y 是相對於 translate(this.pos.x, this.pos.y) 後的 (0,0)
      // attackRange 是半徑
      drawDashedEllipse(0, 0, this.attackRange, this.attackRange, 24, 0.5);
      pop();
    }

    
    // Debug: show HP
    // fill(255); textSize(12); textAlign(CENTER,CENTER); text(Math.ceil(this.hp), 0, hpBarYOffset - 10);

    pop();
  }
}
// Factory function for towers, because `BuildingUnit` was used in Player class before Building class defined.
// This acts like a static method of Building, but defined after to resolve order issues.
BuildingUnit = Building.塔樓;


// --- 法術 (Spell) ---
class Spell extends GameObject {
  constructor(x, y, isFriendly, cardData, spellDmg, spellRange, spellSplashRadius) {
    super(x, y, isFriendly, cardData); // Pass cardData
    this.dmg = spellDmg; // cardData.dmg might be 0 if it's a spawner spell
    this.radius = spellRange; // For targeting or effect area (cardData.attackRange)
    this.splashRadius = spellSplashRadius || this.radius; // Actual damage area (cardData.splashRadius)
    
    this.duration = 0.5; // Spells are mostly instant, this is for visual effect
    this.applied = false;
    
    // Spell specific properties
    if (this.cardData.special === "linear_pushback" && this.cardData.name === "滾木 The Log") {
        this.logSpeed = TILE_SIZE * 8; // Log rolls fast
        this.logWidth = TILE_SIZE * 0.8; // Log visual width
        this.logTravelDistance = this.radius; // attackRange is used as travel distance for log
        this.distanceTraveled = 0;
        this.direction = this.isFriendly ? createVector(0, -1) : createVector(0, 1); // Player log rolls up, AI log rolls down
        this.pos.y += this.isFriendly ? this.logTravelDistance/2 : -this.logTravelDistance/2; // Start behind target point and roll through
        this.duration = this.logTravelDistance / this.logSpeed; // Duration based on travel
        this.hitUnits = new Set(); // Track units hit by this log instance
    }
    if (this.cardData.special === "area_spawn_over_time" && this.cardData.name === "墓園 Graveyard") {
        this.spawnInterval = 0.5; // seconds
        this.skeletonsToSpawn = 10; // Example: Graveyard spawns 10 skeletons over its duration
        this.duration = this.spawnInterval * this.skeletonsToSpawn;
        this.spawnTimer = 0;
    }
    if (this.cardData.special === "freeze" && this.cardData.name === "冰凍 Freeze") {
        this.freezeDuration = 4.0; // seconds
        this.duration = this.freezeDuration + 0.5; // Visual effect + freeze time
    }
  }

  update(dt, match) {
    this.duration -= dt;

    if (!this.applied && this.cardData.special !== "linear_pushback" && this.cardData.special !== "area_spawn_over_time") { // Apply non-DOT/traveling spells once
        this.applyEffect(match);
        this.applied = true;
    }
    
    // Specific spell updates
    if (this.cardData.special === "linear_pushback" && this.cardData.name === "滾木 The Log") {
        const moveAmount = this.logSpeed * dt;
        this.pos.add(this.direction.copy().mult(moveAmount));
        this.distanceTraveled += moveAmount;
        this.applyLogEffect(match); // Apply effect continuously as it travels
        if (this.distanceTraveled >= this.logTravelDistance) this.duration = 0; // Log finished
    }
    if (this.cardData.special === "area_spawn_over_time" && this.cardData.name === "墓園 Graveyard") {
        this.spawnTimer -= dt;
        if (this.spawnTimer <=0 && this.skeletonsToSpawn > 0) {
            this.spawnGraveyardSkeleton(match);
            this.skeletonsToSpawn--;
            this.spawnTimer = this.spawnInterval;
        }
    }
    
    if (this.duration <= 0) {
        this.isDestroyed = true; // Will be removed by match update
    }
  }
  
  applyLogEffect(match) {
      // Log hits units in a rectangular area as it moves
      const logRect = {
          x: this.pos.x - this.splashRadius / 2, // splashRadius used as Log's width
          y: this.pos.y - this.logWidth / 2,
          w: this.splashRadius,
          h: this.logWidth,
      };

      const opponentPlayerIndex = this.isFriendly ? 1 : 0;
      const targets = [...match.gameObjects, ...match.players[opponentPlayerIndex].towers];

      targets.forEach(obj => {
          if (obj.isFriendly !== this.isFriendly && obj.hp > 0 && obj.movementType === "ground" && !this.hitUnits.has(obj.id)) {
              // Check collision with log's current position (simplified rect check)
              if (obj.pos.x > logRect.x && obj.pos.x < logRect.x + logRect.w &&
                  obj.pos.y > logRect.y && obj.pos.y < logRect.y + logRect.h) {
                  obj.takeDamage(this.dmg);
                  this.hitUnits.add(obj.id);
                  // Pushback effect (simplified: small stun or brief target reset)
                  if(obj.attackCooldown !== undefined) obj.attackCooldown = Math.max(obj.attackCooldown, 0.2);
                  if(obj.target) obj.target = null; // Force retarget
              }
          }
      });
  }

  spawnGraveyardSkeleton(match) {
    const casterPlayer = match.players[this.isFriendly ? 0 : 1];
    const randomOffset = p5.Vector.random2D().mult(random(this.radius * 0.8));
    const spawnPos = p5.Vector.add(this.pos, randomOffset);
    
    const skeletonProps = UNIT_TEMPLATES.skeleton_basic; // Uses predefined skeleton
    const newSkeleton = new Unit(spawnPos.x, spawnPos.y, this.isFriendly, skeletonProps, this.cardData); // Pass Graveyard cardData for context
    match.gameObjects.push(newSkeleton);
    match.spawnParticleEffect(spawnPos, 5, [150,255,150], 'spawn');
  }


  applyEffect(match) {
    // Common targeting logic
    const opponentPlayerIndex = this.isFriendly ? 1 : 0;
    let targets = [...match.gameObjects, ...match.players[opponentPlayerIndex].towers];
    
    if (this.cardData.special === "multi_target_3" && this.cardData.name === "雷擊 Lightning") {
        let validTargets = targets.filter(obj => 
            obj.isFriendly !== this.isFriendly && obj.hp > 0 &&
            p5.Vector.dist(this.pos, obj.pos) <= this.radius &&
            (this.cardData.targetType === "any" || this.cardData.targetType === obj.movementType || (this.cardData.targetType === "buildings" && obj.isTower))
        );
        validTargets.sort((a,b) => b.hp - a.hp); // Prioritize higher HP targets
        for(let i=0; i < Math.min(3, validTargets.length); i++) {
            validTargets[i].takeDamage(this.dmg);
            match.spawnParticleEffect(validTargets[i].pos, 15, [255,255,0], 'lightning_bolt', this.pos);
        }
    } else { // Standard Area of Effect
        targets.forEach(obj => {
            if (obj.isFriendly !== this.isFriendly && obj.hp > 0 &&
                p5.Vector.dist(this.pos, obj.pos) <= this.splashRadius &&
                (this.cardData.targetType === "any" || this.cardData.targetType === obj.movementType || (this.cardData.targetType === "buildings" && obj.isTower) || (obj.isTower && this.cardData.targetType !== "airOnlyExample"))) { // Basic type check
                
                obj.takeDamage(this.dmg);
                if (this.cardData.special === "freeze") {
                    if (obj.attackCooldown !== undefined) obj.attackCooldown = Math.max(obj.attackCooldown, this.freezeDuration);
                    if (obj.speed !== undefined) { // Freeze movement
                        obj.originalSpeedFrozen = obj.originalSpeedFrozen !== undefined ? obj.originalSpeedFrozen : obj.speed;
                        obj.speed = 0;
                        setTimeout(() => { // Unfreeze after duration
                            if(obj.originalSpeedFrozen !== undefined) obj.speed = obj.originalSpeedFrozen;
                            obj.originalSpeedFrozen = undefined;
                        }, this.freezeDuration * 1000);
                    }
                }
            }
        });
    }
  }

  draw() { // Visual effect for the spell
    push();
    translate(this.pos.x, this.pos.y);
    let spellColor = color(COLOR_SPELL_EFFECT);
    spellColor.setAlpha(map(this.duration, 0.5, 0, 150, 0)); // Fade out

    if (this.cardData.special === "linear_pushback" && this.cardData.name === "滾木 The Log") {
        fill(139,69,19, spellColor.levels[3]); // Brown color for log
        rect(0, 0, this.splashRadius, this.logWidth, this.logWidth/2); // Log is wide (splashRadius) and short (logWidth)
    } else if (this.cardData.special === "area_spawn_over_time" && this.cardData.name === "墓園 Graveyard") {
        strokeWeight(3);
        stroke(50,200,50, spellColor.levels[3]);
        noFill();
        ellipse(0,0, this.radius * 2, this.radius * 2);
        fill(50,200,50, spellColor.levels[3] / 3);
        ellipse(0,0, this.radius * 2, this.radius * 2);
    } else if (this.cardData.special === "freeze" && this.cardData.name === "冰凍 Freeze") {
        fill(100,150,255, spellColor.levels[3] / 2);
        stroke(200,220,255, spellColor.levels[3]);
        strokeWeight(4);
        ellipse(0,0, this.splashRadius * 2, this.splashRadius * 2);
    } else { // Default circular explosion for Fireball, Arrows etc.
        fill(spellColor);
        noStroke();
        ellipse(0, 0, this.splashRadius * 2, this.splashRadius * 2);
    }
    pop();
  }
}

// --- 粒子效果 ---
class Particle {
  constructor(x, y, pColor, type = 'explosion', targetPos = null) {
    this.pos = createVector(x, y);
    if (type === 'explosion' || type === 'death' || type === 'spawn') {
        this.vel = p5.Vector.random2D().mult(random(1, 5));
    } else if (type === 'hit' || type === 'hit_splash') {
        this.vel = p5.Vector.random2D().mult(random(0.5, 2));
    } else if (type === 'line' || type === 'lightning_bolt') {
        if (targetPos) {
            this.vel = p5.Vector.sub(targetPos, this.pos).normalize().mult(random(10,20)); // Fast for line
        } else {
            this.vel = createVector(0,0); // Static if no target
        }
    } else {
        this.vel = createVector(random(-1,1), random(-1,1));
    }
    
    this.lifespan = type === 'line' || type === 'lightning_bolt' ? 30 : random(30, 60); // frames
    this.pColor = pColor;
    this.size = random(3, 8);
    this.type = type;
  }

  update(dt) { // dt not used here, lifespan is frame-based for simplicity
    this.pos.add(this.vel);
    this.lifespan--;
    if (this.type === 'explosion' || this.type === 'death') {
        this.vel.mult(0.95); // Slow down explosion particles
    }
  }

  isFinished() {
    return this.lifespan <= 0;
  }

  draw() {
    push();
    translate(this.pos.x, this.pos.y);
    let particleColor = color(this.pColor);
    particleColor.setAlpha(map(this.lifespan, 0, 60, 0, 255));
    fill(particleColor);
    noStroke();
    if (this.type === 'line' || this.type === 'lightning_bolt') {
        ellipse(0, 0, this.size * 1.5, this.size * 0.5); // Streaky particle
    } else {
        ellipse(0, 0, this.size, this.size);
    }
    pop();
  }
}

class Projectile extends GameObject {
  constructor(startX, startY, targetObject, speed, damage, isFriendly, visualOptions = {}, shooterCardData = null) {
    super(startX, startY, isFriendly, shooterCardData);
    this.target = targetObject;
    this.speed = speed * TILE_SIZE; // speed 是一個係數, 例如 8-15
    this.damage = damage;
    
    this.visual = {
      type: visualOptions.type || 'ellipse', // 'ellipse', 'rect' (for arrows)
      size: visualOptions.size || 8,
      color: visualOptions.color || (isFriendly ? [180,180,255] : [255,180,180]),
      rotation: 0, // For arrows
    };

    this.pos = createVector(startX, startY);
    this.vel = createVector(0,0);
    this.arrived = false;
    this.movementType = "projectile"; // 用於可能的特殊處理

    // 計算初始方向和旋轉 (主要給箭矢用)
    if (this.target) {
        let dirToTarget = p5.Vector.sub(this.target.pos, this.pos);
        this.visual.rotation = dirToTarget.heading(); // P5 heading gives angle in radians
    }
  }

  update(dt, match) {
    if (this.arrived || !this.target || this.target.hp <= 0 || this.target.isDestroyed) {
      this.isDestroyed = true;
      return;
    }

    let dir = p5.Vector.sub(this.target.pos, this.pos);
    let distToTarget = dir.mag();

    // 簡易碰撞檢測：當投射物非常接近目標中心時
    // 目標的大小也應該考慮進去
    let targetRadius = (this.target.visual ? this.target.visual.size / 2 : (this.target.size ? this.target.size / 2 : TILE_SIZE / 3));
    if (distToTarget < targetRadius) {
      this.arrived = true;
      this.target.takeDamage(this.damage);
      match.spawnParticleEffect(this.target.pos, 5, this.visual.color, 'hit'); // 在目標位置產生命中效果
      // playSound('hit'); // 可以在 Match 中統一處理 Projectile 命中音效
      this.isDestroyed = true;
    } else {
      this.vel = dir.normalize().mult(this.speed * dt);
      this.pos.add(this.vel);
      // 更新箭矢方向 (如果目標移動)
      if (this.visual.type === 'rect') {
         this.visual.rotation = this.vel.heading();
      }
    }
  }

  draw() {
    push();
    translate(this.pos.x, this.pos.y);
    rotate(this.visual.rotation); // Apply rotation
    fill(this.visual.color);
    noStroke();

    if (this.visual.type === 'ellipse') {
      ellipse(0, 0, this.visual.size, this.visual.size);
    } else if (this.visual.type === 'rect') { // For arrows
      rect(0, 0, this.visual.size, this.visual.size / 3); // 箭的長度和寬度
    }
    pop();
  }

  takeDamage(amount) { /* 通常投射物不受傷 */ }
}

function drawCardInfoBox(card) {
  if (!card) return; // 如果沒有卡片被懸停，則不執行

  const boxX = 30;        // 資訊框左上角 X 座標
  const boxY = 100;       // 資訊框左上角 Y 座標
  const boxW = 280;       // 資訊框寬度
  let boxH = 120;       // 資訊框初始高度，會根據內容自動調整
  const lineH = 18;       // 每行文字的高度
  const padding = 10;     // 內部邊距

  let infoLines = []; // 用來儲存要顯示的每一行資訊

  // 收集卡片資訊
  infoLines.push(`名稱: ${card.name}`);
  infoLines.push(`聖水: ${card.elixir === "+1" ? "複製上一張+1費" : card.elixir}`); // 特殊處理鏡像聖水
  infoLines.push(`稀有度: ${card.rarity}`);
  infoLines.push(`類型: ${card.type}`);
  
  if (card.hp > 0) infoLines.push(`生命值: ${card.hp}`);
  if (card.dmg > 0) infoLines.push(`傷害: ${card.dmg}`);
  if (card.speed && card.speed !== "n/a") infoLines.push(`速度: ${card.speed}`);
  
  // 攻擊範圍轉換為 "格"
  let attackRangeDisplay = card.attackRange;
  if (typeof card.attackRange === 'number' && card.attackRange > 0 && card.type !== "spell") {
      attackRangeDisplay = (card.attackRange / TILE_SIZE).toFixed(1) + " 格";
  } else if (card.type === "spell" && card.attackRange > 0) {
      attackRangeDisplay = `法術半徑: ${(card.attackRange / TILE_SIZE).toFixed(1)} 格`;
  } else if (card.attackRange === "n/a" || card.attackRange === 0) {
      attackRangeDisplay = "近戰/無";
  }
  // 鏡像卡本身沒有攻擊範圍
  if (card.special !== "mirror_last_card") {
      infoLines.push(`攻擊範圍: ${attackRangeDisplay}`);
  }


  if (card.movementType && card.movementType !== "n/a") {
      infoLines.push(`移動類型: ${card.movementType === "ground" ? "地面" : (card.movementType === "air" ? "空中" : card.movementType)}`);
  }
  if (card.targetType && card.targetType !== "n/a") {
    let targetDesc = card.targetType;
    if (targetDesc === "any") targetDesc = "任何";
    else if (targetDesc === "ground") targetDesc = "地面";
    else if (targetDesc === "air") targetDesc = "空中";
    else if (targetDesc === "buildings") targetDesc = "建築";
    infoLines.push(`目標類型: ${targetDesc}`);
  }

  if (card.spawnCount > 0 && card.spawnUnitId && UNIT_TEMPLATES[card.spawnUnitId]) {
      infoLines.push(`召喚數量: ${card.spawnCount} (${UNIT_TEMPLATES[card.spawnUnitId].name})`);
  } else if (card.spawnCount > 0) {
      infoLines.push(`召喚數量: ${card.spawnCount}`);
  }

  if (card.splashRadius > 0) {
      infoLines.push(`濺射半徑: ${(card.splashRadius / TILE_SIZE).toFixed(1)} 格`);
  }
  
  if (card.special && card.special !== "") {
      infoLines.push(`特殊能力: ${card.special}`);
  }
  
  infoLines.push(` `); // 加一個空行
  infoLines.push(`說明:`);
  // 卡片描述會另外處理換行

  // 根據行數和描述長度估算總高度
  // 假設描述最多佔用 3-4 行的高度
  boxH = padding * 2 + infoLines.length * lineH + (card.description ? Math.ceil(card.description.length / (boxW / 7)) * lineH + padding : 0) ; // 7是估計每個字的寬度
  boxH = Math.max(boxH, 120); // 最小高度

  // 繪製背景框
  push(); // 保存當前繪圖狀態
  rectMode(CORNER); // 為了方便定位，暫時切換到 CORNER 模式
  fill(30, 30, 40, 220); // 深色半透明背景
  stroke(150, 150, 180);    // 邊框顏色
  strokeWeight(1);
  rect(boxX, boxY, boxW, boxH, 8); // 圓角矩形
  noStroke();

  // 繪製文字
  fill(230, 230, 240); // 文字顏色
  textSize(14);
  textAlign(LEFT, TOP); // 文字左上對齊
  let currentTextY = boxY + padding;
  for (const line of infoLines) {
    text(line, boxX + padding, currentTextY);
    currentTextY += lineH;
  }
  
  // 繪製描述 (帶換行)
  if (card.description) {
    text(card.description, boxX + padding, currentTextY, boxW - padding * 2); // p5 text函數會自動處理maxWidth內的換行
  }
  pop(); // 恢復之前的繪圖狀態 (包括 rectMode)
}


function drawDashedEllipse(centerX, centerY, radiusW, radiusH, segments = 20, dashLenRatio = 0.6) {
  // centerX, centerY 是 ellipse 模式為 CENTER 時的圓心
  // radiusW, radiusH 是半徑 (不是直徑)
  push();
  // noFill(); // 由調用者決定是否填充
  // stroke(...); // 由調用者設定顏色和粗細
  // strokeWeight(...);

  let angleStep = TWO_PI / segments;
  for (let i = 0; i < segments; i++) {
    let angle1 = i * angleStep;
    let angle2 = angle1 + angleStep * dashLenRatio;

    // 根據 p5.js ellipse() 的參數，它是用直徑，所以這裡 radiusW, radiusH 是半徑
    // 但我們的函數接收的是半徑，所以直接用
    let x1 = centerX + radiusW * cos(angle1);
    let y1 = centerY + radiusH * sin(angle1);
    let x2 = centerX + radiusW * cos(angle2);
    let y2 = centerY + radiusH * sin(angle2);

    line(x1, y1, x2, y2);
  }
  pop();
}


// --- 勝負後統計畫面 ---
function renderPostGameScreen() {
  fill(0, 0, 0, 150); // 半透明背景
  rect(CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2, CANVAS_WIDTH, CANVAS_HEIGHT);

  textAlign(CENTER, CENTER);
  textSize(64);
  if (currentMatch && currentMatch.winner === "TIE") {
    fill(200, 200, 0);
    text("平手!", CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3);
  } else if (currentMatch && currentMatch.players[currentMatch.winner].isHuman) {
    fill(0, 255, 0);
    text("勝利!", CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3);
  } else if (currentMatch) {
    fill(255, 0, 0);
    text("失敗", CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3);
  } else {
    fill(255); text("遊戲結束", CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3); // Fallback
  }

  if (currentMatch && currentMatch.gameOverMessage) {
    textSize(24);
    fill(220);
    text(currentMatch.gameOverMessage, CANVAS_WIDTH / 2, CANVAS_HEIGHT / 3 + 70);
  }
  
  textSize(20);
  fill(200);
  if (currentMatch) {
      const playerStats = currentMatch.players[0];
      const aiStats = currentMatch.players[1];
      let playerTowerHp = playerStats.towers.reduce((sum,t) => sum + Math.max(0, t.hp),0);
      let aiTowerHp = aiStats.towers.reduce((sum,t) => sum + Math.max(0, t.hp),0);

      text(`我方剩餘塔血: ${playerTowerHp}`, CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2 + 20);
      text(`敵方剩餘塔血: ${aiTowerHp}`, CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2 + 50);
      text(`我方出牌次數: ${currentMatch.cardsPlayedCount[0]}`, CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2 + 80);
      text(`敵方出牌次數: ${currentMatch.cardsPlayedCount[1]}`, CANVAS_WIDTH / 2, CANVAS_HEIGHT / 2 + 110);
  }

  textSize(28);
  fill(255);
  text("按任意鍵或點擊返回主選單", CANVAS_WIDTH / 2, CANVAS_HEIGHT * 2 / 3 + 50);
}

// --- Helper 函式 ---
function getRarityColor(rarity, alpha = 255) {
  switch (rarity) {
    case "common": return color(200, 200, 200, alpha);
    case "rare": return color(255, 165, 0, alpha); //橘色
    case "epic": return color(180, 0, 255, alpha);   //紫色
    case "legendary": return color(0, 255, 255, alpha); //青色 (彩虹色難做，用亮色代替)
    default: return color(150, 150, 150, alpha);
  }
}

function generateAIRandomDeck() {
    let aiDeck = [];
    let availableCards = [...CARD_POOL];
    // AI should not use Mirror as it's complex for current AI logic
    availableCards = availableCards.filter(c => c.special !== "mirror_last_card");

    while(aiDeck.length < 8 && availableCards.length > 0) {
        let randomIndex = Math.floor(Math.random() * availableCards.length);
        aiDeck.push(availableCards.splice(randomIndex, 1)[0]);
    }
    return aiDeck;
}

// --- 音效輔助函式 ---
function createSineOscillator(freq, ampVal, attackTime, releaseTime, type = 'sine') {
  if (!soundEnabled || typeof p5.Oscillator === 'undefined') return null;
  let osc = new p5.Oscillator(type);
  osc.freq(freq);
  osc.amp(0); // Start silent
  // Return an object that can play the sound
  return {
    play: () => {
      if (!soundEnabled) return;
      osc.start();
      osc.amp(ampVal, attackTime);
      // Schedule stop
      setTimeout(() => { // This is a simplified way, p5.env attack/release is better
          osc.amp(0, releaseTime);
          // p5.Oscillator doesn't auto-stop after amp goes to 0 with this method.
          // A more robust approach would use an Envelope.
          // For now, we'll just let it run at 0 amp or stop it after a delay.
          setTimeout(() => osc.stop(), (releaseTime + 0.1) * 1000); 
      }, (attackTime + 0.05) * 1000); // Hold for a very short time
    }
  };
}

function createFanfareOscillator(ampVal) {
    if (!soundEnabled || typeof p5.Oscillator === 'undefined') return null;
    // A sequence of notes for fanfare
    const notes = [
        { freq: 523.25, duration: 0.2 }, // C5
        { freq: 659.25, duration: 0.2 }, // E5
        { freq: 783.99, duration: 0.4 }, // G5
    ];
    let oscs = notes.map(note => {
        let o = new p5.Oscillator('triangle');
        o.freq(note.freq);
        o.amp(0);
        return {osc: o, duration: note.duration};
    });
    
    return {
        play: () => {
            if (!soundEnabled) return;
            let cumulativeDelay = 0;
            oscs.forEach(item => {
                setTimeout(() => {
                    item.osc.start();
                    item.osc.amp(ampVal, 0.01);
                    setTimeout(() => {
                        item.osc.amp(0, 0.1);
                        setTimeout(() => item.osc.stop(), 150);
                    }, item.duration * 1000 - 100);
                }, cumulativeDelay * 1000);
                cumulativeDelay += item.duration;
            });
        }
    };
}

function playSound(soundName) {
  if (soundEnabled && sounds[soundName] && sounds[soundName].play) {
    sounds[soundName].play();
  }
}

// --- 本地儲存 ---
function saveLastUsedDeck(deckNames) {
    if (typeof(Storage) !== "undefined") {
        localStorage.setItem("clashP5_lastDeck", JSON.stringify(deckNames));
    }
}

function loadLastUsedDeck() {
    if (typeof(Storage) !== "undefined") {
        const savedDeck = localStorage.getItem("clashP5_lastDeck");
        if (savedDeck) {
            lastUsedDeck = JSON.parse(savedDeck);
        } else {
            lastUsedDeck = [];
        }
    }
}


// --- JSON 匯出介面示例 ---
/*
async function loadCardDataFromJSON(filePath = 'cards.json') {
  try {
    const response = await fetch(filePath);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const externalCardPool = await response.json();
    // CARD_POOL = externalCardPool; // 在實際應用中，會用這個數據替換內建的 CARD_POOL
    console.log("Card data loaded from JSON:", externalCardPool);
    return externalCardPool;
  } catch (error) {
    console.error("Could not load card data from JSON:", error);
    return null; // 或返回預設的 CARD_POOL
  }
}

// 使用示例 (例如在 setup 中):
// async function setup() {
//   ...
//   const externalCards = await loadCardDataFromJSON();
//   if (externalCards) {
//      // CARD_POOL = externalCards; // 如果要覆蓋
//      // deckBuilder = new DeckBuilder(externalCards);
//   } else {
//      // deckBuilder = new DeckBuilder(CARD_POOL); // 使用內建
//   }
//   ...
// }

// cards.json 檔案內容示例:
// [
//   {
//     "id": 1,
//     "name": "Giant",
//     "type": "troop",
//     "elixir": 5,
//     // ... 其他欄位 ...
//     "description": "外部載入的巨人敘述"
//   },
//   // ... 更多卡牌 ...
// ]
*/
