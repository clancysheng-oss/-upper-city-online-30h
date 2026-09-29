import { chapters, sideQuests, contextualText } from "./campaign.js";
import { encounters } from "./encounters.js";
import { dialogues } from "./dialogues.js";
import { merchants, items } from "./merchants.js";
import { battleByChapter } from "./battles.js";
import { powers, spellcasters } from "./powers.js";
import { wondersGoods, companionProfile } from "./areas.js";
import { mapView, areaView, questJournal, sideBattleArt } from "./areas-view.js";
export const esc = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export const button = (label, action, disabled = false, extra = "") =>
  `<button data-act="${action}" ${extra} ${disabled ? "disabled" : ""}>${label}</button>`;
export function character(p) {
  return `<strong>${p.is_companion ? "🤝 伙伴 · " : ""}${esc(p.name)} · ${esc(p.class_name)} · ${p.level || 1} 级</strong><p>HP ${p.hp}/${p.max_hp} · AC ${p.ac} · ${p.gold} 金币 · ${p.experience||0} XP</p><div class="stats">${["力量", "敏捷", "体质", "智力", "感知", "魅力"].map((s, i) => `<span>${s} ${p.stats[i]}</span>`).join("")}</div><p>装备：${esc(p.equipment.join("、"))}<br>背包：${esc(p.inventory.join("、") || "空")}</p>${p.hp === 0 ? `<p class="error">倒地 · 死亡豁免成功 ${p.death_successes}/3，失败 ${p.death_failures}/3 ${p.death_failures >= 3 ? "· 死亡" : ""}</p>` : ""}`;
}
function dialogueView(s) {
  const scene = dialogues[s.chapter],
    d =
      s.dialogue?.chapter === s.chapter ? s.dialogue : { step: 0, history: [] },
    done = d.step >= scene.beats.length;
  return `<section class="story-step"><div class="step-title"><span>01</span><h3>与 ${esc(scene.name)} 对话</h3><small>${esc(scene.role)}</small></div>${(d.history || []).map((h) => `<div class="dialogue-history"><p>队伍：${esc(h.choice)}</p><p>${esc(scene.name)}：${esc(h.reply)}</p></div>`).join("")}${done ? '<p class="good">对话结束 · 调查地点已开放</p>' : `<div class="npc-line"><strong>${esc(scene.name)}</strong><p>${esc(scene.beats[d.step].text)}</p></div><p class="muted">任何队员都可以选择回应，选择会同步给全队。</p>${scene.beats[d.step].options.map((o, i) => button(esc(o.label), "dialogue", false, `data-choice="${i}" class="choice"`)).join("")}`}</section>`;
}
function exploreView(s) {
  const ready = s.dialogue?.chapter === s.chapter && s.dialogue.step >= 3;
  return `<section class="story-step"><div class="step-title"><span>02</span><h3>探索与检定</h3></div><p class="muted">${ready ? "两处地点都可调查。队员各自行动，结果和线索同步保存。" : "先完成当前章节的 NPC 对话。"}</p><div class="explore-grid">${encounters[
    s.chapter
  ]
    .map((e, i) => {
      const done = (s.explored || []).includes(`${s.chapter}:${i}`);
      const finding=(s.exploration_history||[]).find(h=>h.chapter===s.chapter&&h.label===e[0]);
      return `<div class="encounter"><strong>${esc(e[0])}</strong><p>${esc(e[1])}</p><p class="muted">${esc(e[2])}检定 · DC ${e[3]}</p>${finding?`<p class="finding">调查结果：${esc(finding.result)}${finding.clue?`<br>获得线索：${esc(finding.clue)}`:''}</p>`:''}<button data-act="explore" data-index="${i}" ${done || !ready ? "disabled" : ""}>${done ? "已调查" : "进行检定"}</button></div>`;
    })
    .join("")}</div></section>`;
}
function choiceView(s, chapter, mine, combat) {
  const explored =
      (s.explored || []).filter((x) => x.startsWith(`${s.chapter}:`)).length >=
      2,
    chosen = s.chosen_chapter === s.chapter;
  return `<section class="story-step"><div class="step-title"><span>03</span><h3>队伍抉择</h3></div><p class="muted">${chosen ? "本章选择已记录。房主可以推进。" : explored ? "调查完成，选择你们将采取的方向。" : "完成对话和两处调查后开放。"}</p>${chapter.choices.map((c, i) => button(esc(c.label), "choice", chosen || !explored, `data-index="${i}" class="choice"`)).join("")}${mine.is_host ? button("👑 推进下一章", "advance", Boolean(combat && combat.hp > 0) || s.chapter >= 29 || !chosen) : ""}${s.ending ? `<h3>结局：${esc(s.ending)}</h3>` : ""}</section>`;
}
function battleView(s, players, mine, messages) {
  const c = s.combat;
  if (!c) return "";
  const sideArt=sideBattleArt(s);
  const art = sideArt?`/images/area-${sideArt.id.replaceAll('_','-')}.webp`:battleByChapter.get(s.chapter)?.art;
  const fighting = c.hp > 0;
  const defeated = fighting && c.turn == null && players.every(p=>p.hp<=0);
  const battleStart=messages.findLastIndex(m=>m.body?.includes(c.name)&&['advance','area_quest'].includes(m.kind));
  const latest = messages.slice(battleStart<0?0:battleStart+1).findLast(m=>['attack','power','companion_attack','companion_skill','heal','death_save','retry'].includes(m.kind));
  const foes = c.enemies || [
    { name: c.name, hp: c.hp, max_hp: c.max_hp, ac: c.ac },
  ];
  return `<section class="card battle-stage" id="battle"><div class="battle-heading"><p class="muted">⚔️ 第 ${c.round} 回合 · ${defeated?'队伍败退':fighting ? "战斗中" : "胜利"}</p><h2>${esc(c.name)}</h2><p>${esc(sideArt?.intro || battleByChapter.get(s.chapter)?.intro || "")}</p></div>${art ? `<img class="battle-banner" src="${art}" alt="${esc(c.name)}战斗场景">` : ""}<div class="enemy-grid">${foes.map((foe, i) => `<div class="enemy ${foe.hp <= 0 ? "defeated" : ""}"><strong>${esc(foe.name)}</strong><p>HP ${foe.hp}/${foe.max_hp} · AC ${foe.ac}</p><div class="hpbar"><span style="width:${Math.max(0, Math.min(100, (foe.hp / foe.max_hp) * 100))}%"></span></div>${foe.hp <= 0 ? "<small>已击倒</small>" : ""}</div>`).join("")}</div><p class="turn-indicator">${defeated?'队伍全员倒地。房主可以重整队伍，原战斗重新开始。':fighting ? `当前行动：${esc(players.find((p) => p.id === c.turn)?.name || "等待救援")}` : "敌方全灭，可以继续调查与推进"}</p>${latest?`<div class="battle-result" role="status"><strong>最近战斗结果 · ${esc(latest.sender)}</strong><p>${esc(latest.body)}</p></div>`:''}${defeated&&mine.is_host?button('👑 重整队伍并重试','retry'):''}${fighting&&!defeated?`${powersView(mine,s,c,players,true)}<div class="battle-actions"><label>攻击目标<select id="attackTarget">${foes.map((foe, i) => `<option value="${i}" ${foe.hp <= 0 ? "disabled" : ""}>${esc(foe.name)} · HP ${foe.hp}/${foe.max_hp}</option>`).join("")}</select></label>${button("⚔️ 攻击选中敌人", "attack", c.turn !== mine.id || mine.hp <= 0)}${players.filter(p=>p.is_companion).map(p=>`${button(`🏹 ${esc(p.name)}射击`,"companion_attack",c.turn!==p.id||p.hp<=0,`data-companion="${p.id}"`)}${button("✨ 棱光箭", "companion_skill",c.turn!==p.id||p.hp<=0||p.ability_charges<1,`data-companion="${p.id}"`)}`).join("")}<label>药水目标<select id="healTarget">${players.map((p) => `<option value="${p.id}" ${p.id === mine.id ? "selected" : ""}>${esc(p.name)} · HP ${p.hp}/${p.max_hp}</option>`).join("")}</select></label>${button("使用治疗药水", "heal", !mine.inventory.includes("治疗药水") || c.turn !== mine.id)}</div>`:''}</section>`;
}
function powersView(mine, s, combat, players, inBattle=false) {
  const known = powers.filter(
    (p) =>
      p.profession === mine.class_name &&
      (p.ring === 0 || (mine.level || 1) >= 2 * p.ring - 1),
  );
  const canAct =
    mine.hp > 0 && (!combat || combat.hp <= 0 || combat.turn === mine.id);
  const foes = combat?.enemies || [];
  return `<section class="${inBattle?'battle-powers':'card'}"><h3>职业技能与法术</h3><p>职业技能 ${mine.ability_charges ?? 2}/2 ${
    spellcasters.has(mine.class_name) && mine.spell_slots
      ? `· 法术位 ${mine.spell_slots
          .slice(1)
          .map((n, i) => `${i + 1}环:${n}`)
          .join(" ")}`
      : ""
  }</p><label>能力<select id="power">${known.map((p) => `<option value="${p.id}">${p.ring ? p.ring + " 环" : "职业"} · ${esc(p.name)} · ${esc(p.description)}</option>`).join("")}</select></label>${spellcasters.has(mine.class_name) ? `<label>法术位<select id="slot"><option value="0">职业技能</option>${[1, 2, 3, 4, 5, 6].map((n) => `<option value="${n}">${n} 环 · ${mine.spell_slots?.[n] || 0} 位</option>`).join("")}</select></label>` : ""}<label>盟友目标<select id="powerTarget">${players.map((p) => `<option value="${p.id}" ${p.id === mine.id ? "selected" : ""}>${esc(p.name)} · HP ${p.hp}/${p.max_hp}</option>`).join("")}</select></label>${foes.length ? `<label>敌人目标<select id="enemyTarget">${foes.map((e, i) => `<option value="${-i - 1}" ${e.hp <= 0 ? "disabled" : ""}>${esc(e.name)} · HP ${e.hp}/${e.max_hp}</option>`).join("")}</select></label>` : ""}${button("使用技能 / 施法", "power", !canAct || !known.length)}${mine.is_host ? button("👑 队伍长休", "rest", Boolean(combat && combat.hp > 0) || s.rested_chapter === s.chapter) : ""}</section>`;
}
function merchantView(mine, chapter, flags, fighting) {
  const unlocked = merchants.filter((m) => m.chapter <= chapter);
  const discount = flags.includes(`support_${chapter}_stay`);
  return `<section class="card"><h3>城中商人</h3><p>金币 ${mine.gold} · 商品随剧情开放；购买和装备由服务器核算。</p>${unlocked
    .map(
      (m) =>
        `<details class="merchant" ${m.chapter === Math.max(...unlocked.map((x) => x.chapter)) ? "open" : ""}><summary><strong>${esc(m.name)}</strong><small>${esc(m.description)}</small></summary>${items
          .filter((i) => i.merchant === m.id)
          .map(
            (i) =>
              `<div class="shop-item"><div><strong>${esc(i.name)}</strong><small>${esc(i.description)}</small></div>${button(`${discount ? Math.ceil(i.price * 0.9) : i.price} 金币 · 购买`, "buy", fighting || mine.gold < (discount ? Math.ceil(i.price * 0.9) : i.price) || (i.slot !== "consumable" && (mine.inventory.includes(i.name) || mine.equipment.includes(i.name))), `data-item="${esc(i.name)}"`)}</div>`,
          )
          .join("")}</details>`,
    )
    .join("")}<h4>背包装备</h4>${
    mine.inventory
      .filter((name) =>
        [...items,...wondersGoods].some((i) => i.name === name && i.slot !== "consumable"),
      )
      .map(
        (name) =>
          `<div class="shop-item"><span>${esc(name)}</span>${button("装备", "equip", false, `data-item="${esc(name)}"`)}</div>`,
      )
      .join("") || '<p class="muted">暂时没有可装备物品。</p>'
  }</section>`;
}
export function renderGame(data, error, selectedArea=null, savedRoom=false) {
  const s = data.state,
    mine = data.players.find((p) => p.id === data.me),
    chapter = chapters[Math.min(s.chapter || 0, 29)],
    flags = s.flags || [],
    combat = s.combat,
    prior=s.chapter>0?chapters[s.chapter-1]:null,
    priorChoice=prior?.choices.find(c=>flags.includes(c.flag));
  return `${battleView(s, data.players, mine, data.messages)}${combat?.hp>0&&error?`<p class="error" role="alert">${esc(error)}</p>`:''}${mapView(s,selectedArea)}${selectedArea&&error?`<p class="error">${esc(error)}</p>`:""}<div class="grid"><div>${selectedArea?areaView(data,selectedArea):`<section class="card story-card"><p class="muted">${esc(chapter.act)} · 第 ${chapter.id + 1}/30 章</p><h2>${esc(chapter.title)}</h2><p class="story-lead">${esc(chapter.lead)}</p>${prior?`<p class="story-recap">前情 · ${esc(prior.title)}：${esc(prior.text)}${priorChoice?`你们选择了「${esc(priorChoice.label)}」。`:''}</p>`:''}<p>${esc(contextualText(chapter, flags))}</p><p class="story-goal">本章目标：与${esc(dialogues[s.chapter].name)}交谈，调查「${esc(encounters[s.chapter][0][0])}」及「${esc(encounters[s.chapter][1][0])}」，再决定队伍的行动。</p>${dialogueView(s)}${exploreView(s)}${choiceView(s, chapter, mine, combat)}</section>`}<section class="card"><h3>自由行动与检定</h3><textarea id="chat" maxlength="500" placeholder="描述角色的行动、对白或计划"></textarea><div class="row">${button("发送行动", "chat")}<select id="skill" style="width:auto;margin:0">${["调查", "洞悉", "说服", "潜行", "运动", "奥秘", "求生"].map((x) => `<option>${x}</option>`).join("")}</select><input id="dc" type="number" value="15" min="5" max="30" title="难度 DC" style="width:72px;margin:0">${button("D20 检定", "roll")}</div></section><section class="card"><h3>队伍行动记录</h3><div class="log">${[
    ...data.messages,
  ]
    .reverse()
    .map((m) => `<p><strong>${esc(m.sender)}</strong>：${esc(m.body)}</p>`)
    .join(
      "",
    )}</div></section></div><aside><section class="card"><h3>队伍角色</h3>${data.players.map((p) => `<div class="member">${p.is_host ? "👑 " : ""}${character(p)}</div>`).join("")}${data.players.some(p=>p.is_companion)?`<p class="muted">${esc(companionProfile.race)} · ${esc(companionProfile.background)}<br>${esc(companionProfile.active)}<br>${esc(companionProfile.passive)}</p>`:""}<div class="row">${savedRoom?"":button("离开", "leave")}${savedRoom?"":button("接任离线房主", "claim")}</div></section><section class="card"><h3>任务与线索</h3><p>主线：${esc(chapter.title)}</p><p>已完成章节 ${(s.completed_quests || []).length}/30</p>${sideQuests
    .filter((q) => chapter.id >= q.from && chapter.id <= q.to)
    .map(
      (q) =>
        `<p>支线：${esc(q.title)} · ${flags.includes(q.flag) ? "已完成" : "待调查"}<br><small>${esc(q.reward)}</small></p>`,
    )
    .join(
      "",
    )}${(s.clues || []).map((c) => `<span class="tag">${esc(c)}</span>`).join("") || '<p class="muted">尚未发现线索</p>'}${questJournal(s)}</section>${combat?.hp>0?'':powersView(mine, s, combat, data.players)}${merchantView(mine, chapter.id, flags, combat?.hp > 0)}<p class="error">${esc(error)}</p></aside></div>`;
}
