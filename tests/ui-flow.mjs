import { renderGame } from "../src/views.js";
import { dialogues } from "../src/dialogues.js";
import { battles } from "../src/battles.js";
import { items, merchants } from "../src/merchants.js";
import assert from "node:assert/strict";
const player = {
  id: 1,
  name: "测试战士",
  class_name: "战士",
  is_host: true,
  level: 1,
  hp: 14,
  max_hp: 14,
  ac: 16,
  gold: 50,
  stats: [16, 12, 14, 10, 10, 10],
  inventory: ["治疗药水"],
  equipment: ["基础武器"],
  ability_charges: 2,
  death_failures: 0,
  death_successes: 0,
};
const base = {
  room: "ABCDE",
  players: [player],
  me: 1,
  messages: [],
  state: {
    started: true,
    chapter: 0,
    flags: [],
    clues: [],
    explored: [],
    completed_quests: [],
    combat: null,
  },
};
let html = renderGame(base, "");
assert(html.includes("与 守门人哈罗 对话"));
assert(html.includes("先完成当前章节的 NPC 对话"));
assert(html.includes("城门补给商艾米"));
assert(!html.includes("灰市铁匠穆雷"));
assert(html.indexOf("story-card") > 0);
base.state.dialogue = { chapter: 0, step: 3, history: [] };
html = renderGame(base, "");
assert(html.includes("对话结束 · 调查地点已开放"));
assert(!html.includes("先完成当前章节的 NPC 对话"));
base.state.chapter = 5;
base.state.dialogue = { chapter: 5, step: 3, history: [] };
base.state.combat = {
  name: "灰市收账人",
  round: 1,
  hp: 30,
  max_hp: 30,
  turn: 1,
  enemies: [
    { name: "收账人", hp: 18, max_hp: 18, ac: 13 },
    { name: "打手", hp: 12, max_hp: 12, ac: 12 },
  ],
};
html = renderGame(base, "");
assert(html.indexOf("battle-stage") < html.indexOf("story-card"));
assert(html.includes("攻击目标") && html.includes("打手 · HP 12/12"));
assert(html.includes("灰市铁匠穆雷"));
assert(html.includes('data-item="灰市长枪"'));
assert(
  dialogues.length === 30 &&
    dialogues.every(
      (d) =>
        d.beats.length === 3 && d.beats.every((b) => b.options.length === 2),
    ),
);
assert(
  battles.length === 10 && battles.every((b) => b.foes.length >= 2 && b.art),
);
assert(merchants.length === 6 && items.length >= 12);
console.log(
  "UI FLOW PASS: dialogue gates, main-screen squads, chapter merchants and artwork",
);
