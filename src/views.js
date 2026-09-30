import { chapters, sideQuests, contextualText } from "./campaign.js";
import { encounters } from "./encounters.js";
import { dialogues } from "./dialogues.js";
import { merchants, items } from "./merchants.js";
import { battleByChapter } from "./battles.js";
import { powers, spellcasters } from "./powers.js";
import { wondersGoods, companionProfile } from "./areas.js";
import { mapView, areaView, questJournal, sideBattleArt } from "./areas-view.js";
import {experienceProgress} from './progression.js';
import {deepChapters,classRoutes,companionInterjections} from './deep-story.js';
import {battleAftermath} from './battle-aftermath.js';
import {deepFollowups} from './deep-followups.js';
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
const saveProficiencies={战士:'力量、体质',圣武士:'力量、体质',游荡者:'敏捷、智力',法师:'智力、感知',牧师:'感知、魅力',游侠:'力量、敏捷',吟游诗人:'敏捷、魅力'};
const racialFeatures={龙裔:'龙息（战斗范围）与血统抗性',提夫林:'火焰抗性；3级解锁地狱烈焰',人类:'不熟练检定 +1',矮人:'毒素抗性、石工调查与额外 HP',精灵:'敏锐察觉、黑暗视觉与抗魅惑'};
export function character(p) {
  return `<strong>${p.is_companion ? "🤝 伙伴 · " : ""}${esc(p.name)} · ${esc(p.race||'待选种族')} · ${esc(p.class_name)} · ${p.level || 1} 级</strong><p>HP ${p.hp}/${p.max_hp} · AC ${p.ac} · ${p.gold} 金币 · ${p.experience||0} XP<br><small>${experienceProgress(p.level||1,p.experience||0)}</small></p><div class="stats">${["力量", "敏捷", "体质", "智力", "感知", "魅力"].map((s, i) => `<span>${s} ${p.stats[i]}</span>`).join("")}</div><p>种族：${esc(p.race||'待选择')}${p.ancestry?` · ${esc(p.ancestry)}血统`:''} · 熟练加值 +${Math.min(6,2+Math.floor(((p.level||1)-1)/4))}<br>种族能力：${esc(racialFeatures[p.race]||'待选择')} · 豁免熟练：${esc(saveProficiencies[p.class_name]||'无')}<br>专长：${esc(p.build?.feats?.join('、')||'无')} · 通缉 ${p.wanted||0}<br>状态：${esc(Object.keys(p.conditions||{}).join('、')||'正常')}<br>声望：大厅 ${p.reputation?.hall||0} / 守卫 ${p.reputation?.guard||0} / 贡德 ${p.reputation?.gond||0} / 商人 ${p.reputation?.merchant||0} / 地下 ${p.reputation?.underground||0}<br>装备：${esc(p.equipment.join("、"))}<br>背包：${esc(p.inventory.join("、") || "空")}</p>${p.hp === 0 ? `<p class="error">倒地 · 死亡豁免成功 ${p.death_successes}/3，失败 ${p.death_failures}/3 ${p.death_failures >= 3 ? "· 死亡" : ""}</p>` : ""}`;
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
function deepView(s,mine,players){
 const c=deepChapters[s.chapter],d=s.deep||{},talk=d.talk?.[s.chapter]||[],inspected=d.inspected?.[s.chapter],route=d.route?.[s.chapter];
 const prior=[
  [3,0,'城门的驿夫贝伦认出你们，主动指明宴会后门；他记得你们听完了他的证词。'],
  [12,3,'封蜡匠绮恩带来的旧纹印证了图书馆被烫过的页角。'],
  [21,5,'灰市搬运工阿蒙兑现承诺，为你们指出断桥下的检修道。'],
  [26,18,'记录员丹缇保存的撤离名单让凯尔认出被删改的证人。']
 ].filter(([chapter,source])=>s.chapter===chapter&&d.storyFlags?.[`${source}_witness_0`]).map(([, ,text])=>`<p class="finding">先前决定的回响：${esc(text)}</p>`).join('');
 const interject=players.find(p=>p.is_companion)?.name;
 return `<section class="story-step deep-story"><div class="step-title"><span>新</span><h3>${esc(c.scene)} · ${esc(c.focus)}</h3></div><p>沿着本章线索来到另一处现场。可以先询问见证人，再检查遗留的物证。</p>${prior}
 <div class="npc-line"><strong>${esc(c.npc)} · ${esc(c.role)}</strong><p>${esc(c.lines[0])}</p></div>
 <p class="muted">主动询问不同问题；全队共享调查与回答。</p>
 ${c.questions.map((label,i)=>button(label,'deep_talk',talk.includes(String(i)),`data-choice="${i}" class="choice"`)).join('')}
 ${talk.map(i=>`<div class="dialogue-history"><p>${esc(c.npc)}：${esc(c.lines[Number(i)+1])}</p></div>`).join('')}
 ${talk.map(i=>button(`继续追问：${esc(c.questions[Number(i)])}`,'deep_followup',(d.followup?.[s.chapter]||[]).includes(String(i)),`data-choice="${i}" class="choice"`)).join('')}
 ${(d.followup?.[s.chapter]||[]).map(i=>`<div class="dialogue-history"><p>${esc(c.npc)}：${esc(deepFollowups[s.chapter][Number(i)])}</p></div>`).join('')}
 ${talk.length&&interject&&companionInterjections[s.chapter]?`<div class="finding"><strong>${esc(interject)}插话</strong><p>${esc(companionInterjections[s.chapter])}</p>${d.interjection?.[s.chapter]!==undefined?'<p>回应已记入队伍记录。</p>':[button('支持伙伴','deep_interject',false,'data-choice="0"'),button('提出异议','deep_interject',false,'data-choice="1"'),button('保持沉默','deep_interject',false,'data-choice="2"')].join('')}</div>`:''}
 <div class="encounter"><strong>探索 · ${esc(c.object)}</strong><p>仔细检查这里留下的物证；成功会解锁一条隐藏线索及更稳妥的谈判路线。</p><p class="muted">${esc(c.skill)}检定 · DC ${c.dc}</p>${button(inspected?'已调查':'调查物证','deep_inspect',Boolean(inspected))}</div>
 ${d.explorationFlags?.[`${s.chapter}_secret`]?`<p class="finding">隐藏发现：${esc(c.secret)}</p>`:''}
 ${inspected?`<h4>调查后的追问</h4>${['追查物证来历','比对另一份记录','商量下一步与证人安全'].map((label,i)=>button(label,'deep_debrief',(d.debrief?.[s.chapter]||[]).includes(String(i)),`data-choice="${i}" class="choice"`)).join('')}${(d.debrief?.[s.chapter]||[]).map(i=>`<div class="dialogue-history"><p>${esc(c.npc)}：${esc(deepFollowups[s.chapter][Number(i)+3])}</p></div>`).join('')}`:''}
 ${mine.is_host?`<div class="deep-routes"><h4>👑 队伍处理方式</h4><p>${route?`已记录：${esc(route)}。后续 NPC 和遭遇将读取这一决定。`:'证据与交涉可解决普通遭遇；失败时仍可按原路线继续。'}</p>
 ${button('以证据交涉 · D20','deep_route',Boolean(route), 'data-choice="0"')}
 ${button('正面突破','deep_route',Boolean(route),'data-choice="1"')}
 ${button(`[${esc(mine.class_name)}] ${esc(classRoutes[mine.class_name]?.[0]||'职业判断')} · D20`,'deep_route',Boolean(route),`data-choice="2" data-class="${esc(mine.class_name)}"`)}
 </div>`:''}</section>`;
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
  const aftermath=battleAftermath.find(a=>a.chapter===s.chapter&&a.chapter>=0);
  const sideArt=sideBattleArt(s);
  const art = s.chapter===28&&c.hp>0?'/images/v4-walls-siege.webp':sideArt?`/images/area-${sideArt.id.replaceAll('_','-')}.webp`:battleByChapter.get(s.chapter)?.art;
  const fighting = c.hp > 0;
  const defeated = fighting && c.turn == null && players.every(p=>p.hp<=0);
  const battleStart=messages.findLastIndex(m=>m.body?.includes(c.name)&&['advance','area_quest'].includes(m.kind));
  const latest = messages.slice(battleStart<0?0:battleStart+1).findLast(m=>['attack','power','companion_attack','companion_skill','heal','death_save','retry','deep'].includes(m.kind));
  const foes = c.enemies || [
    { name: c.name, hp: c.hp, max_hp: c.max_hp, ac: c.ac },
  ];
  const racialUsed=Boolean(c.racial_uses?.[mine.id]);
  const racialAction=mine.race==='龙裔'?button(`🐉 ${esc(mine.ancestry)}龙息 · 全体敌人`,'v4_racial',racialUsed||c.turn!==mine.id||mine.hp<=0,'data-kind="breath"'):mine.race==='提夫林'&&mine.level>=3?button('🔥 地狱烈焰 · 选中敌人','v4_racial',racialUsed||c.turn!==mine.id||mine.hp<=0,'data-kind="infernal"'):'';
  return `<section class="card battle-stage" id="battle"><div class="battle-heading"><p class="muted">⚔️ 第 ${c.round} 回合 · ${defeated?'队伍败退':fighting ? "战斗中" : "胜利"}</p><h2>${esc(c.name)}</h2>${c.final_phase?`<div class="final-boss-ui"><strong>${esc(c.phase_notice||`PHASE ${c.final_phase}`)}</strong><div class="hpbar"><span style="width:${Math.max(0,Math.min(100,c.enemies[0].hp/c.enemies[0].max_hp*100))}%"></span></div><p>${esc(c.mechanic||'')}</p></div>`:''}<p>${esc(sideArt?.intro || battleByChapter.get(s.chapter)?.intro || "")}</p></div>${art ? `<img class="battle-banner" src="${art}" alt="${esc(c.name)}战斗场景">` : ""}<div class="enemy-grid">${foes.map((foe, i) => `<div class="enemy ${foe.hp <= 0 ? "defeated" : ""}"><strong>${esc(foe.name)}</strong><p>HP ${foe.hp}/${foe.max_hp} · AC ${foe.ac}</p><div class="hpbar"><span style="width:${Math.max(0, Math.min(100, (foe.hp / foe.max_hp) * 100))}%"></span></div>${foe.hp <= 0 ? "<small>已击倒</small>" : ""}</div>`).join("")}</div><p class="turn-indicator">${defeated?'队伍全员倒地。房主可以重整队伍，原战斗重新开始。':fighting ? `当前行动：${esc(players.find((p) => p.id === c.turn)?.name || "等待救援")}` : "敌方全灭，可以继续调查与推进"}</p>${fighting&&c.environment?.length?`<div class="battle-environment"><h3>⚙️ 战场环境</h3>${c.environment.map((o,i)=>button(`${o.name} · ${o.kind==='blast'?`范围伤害 ${o.amount}`:o.kind==='cover'?`掩体 AC +${o.amount}`:o.kind==='push'?'推落边缘敌人 · 运动检定':'阻断敌方援军'}`,"deep_environment",o.used||c.turn!==mine.id||mine.hp<=0,`data-object="${i}"`)).join("")}</div>`:""}${c.refusing?.length?`<p class="finding">${players.filter(p=>c.refusing.includes(p.id)).map(p=>esc(p.name)).join("、")}拒绝参加本场战斗；战后仍留在队伍。</p>`:""}${latest?`<div class="battle-result" role="status"><strong>最近战斗结果 · ${esc(latest.sender)}</strong><p>${esc(latest.body)}</p></div>`:''}${!fighting&&aftermath&&!c.side_quest?`<div class="battle-result"><h3>战后调查 · ${esc(aftermath.object)}</h3><p>${s.deep?.aftermath?.[s.chapter]?esc(aftermath.text):'搜查战场、询问幸存者，并带走通往下一章的证据。'}</p>${button(s.deep?.aftermath?.[s.chapter]?'证据已收集':'搜查战场并领取线索与经验','deep_aftermath',Boolean(s.deep?.aftermath?.[s.chapter]))}</div>`:''}${defeated&&mine.is_host?button('👑 重整队伍并重试','retry'):''}${fighting&&!defeated?`${powersView(mine,s,c,players,true)}${racialAction?`<div class="racial-actions"><strong>种族战斗能力</strong>${racialAction}<small>每场战斗一次，计入本回合行动。</small></div>`:''}<div class="battle-actions"><label>攻击目标<select id="attackTarget">${foes.map((foe, i) => `<option value="${i}" ${foe.hp <= 0 ? "disabled" : ""}>${esc(foe.name)} · HP ${foe.hp}/${foe.max_hp}</option>`).join("")}</select></label>${button("⚔️ 攻击选中敌人", "attack", c.turn !== mine.id || mine.hp <= 0)}${players.filter(p=>p.is_companion).map(p=>p.name==='亚岚·铜脉'?`${button(`🔨 ${esc(p.name)}战锤`,"v4_companion",c.turn!==p.id||p.hp<=0,`data-companion="${p.id}" data-kind="attack"`)}${button("⚡ 符文震击","v4_companion",c.turn!==p.id||p.hp<=0||p.ability_charges<1,`data-companion="${p.id}" data-kind="shock"`)}${button("✚ 战地祈祷","v4_companion",c.turn!==p.id||p.hp<=0||p.ability_charges<1,`data-companion="${p.id}" data-kind="prayer"`)}`:`${button(`🏹 ${esc(p.name)}射击`,"companion_attack",c.turn!==p.id||p.hp<=0,`data-companion="${p.id}"`)}${button("✨ 棱光箭", "companion_skill",c.turn!==p.id||p.hp<=0||p.ability_charges<1,`data-companion="${p.id}"`)}`).join("")}<label>药水目标<select id="healTarget">${players.map((p) => `<option value="${p.id}" ${p.id === mine.id ? "selected" : ""}>${esc(p.name)} · HP ${p.hp}/${p.max_hp}</option>`).join("")}</select></label>${button("使用治疗药水", "heal", !mine.inventory.includes("治疗药水") || c.turn !== mine.id)}</div>`:''}</section>`;
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
  }</p><label>能力<select id="power">${known.map((p) => `<option value="${p.id}">${p.ring ? p.ring + " 环" : "职业"} · ${esc(p.name)} · ${esc(p.description)}</option>`).join("")}</select></label>${spellcasters.has(mine.class_name) ? `<label>法术位<select id="slot"><option value="0">职业技能</option>${[1, 2, 3, 4, 5, 6].map((n) => `<option value="${n}">${n} 环 · ${mine.spell_slots?.[n] || 0} 位</option>`).join("")}</select></label>` : ""}<label>盟友目标<select id="powerTarget">${players.map((p) => `<option value="${p.id}" ${p.id === mine.id ? "selected" : ""}>${esc(p.name)} · HP ${p.hp}/${p.max_hp}</option>`).join("")}</select></label>${foes.length ? `<label>敌人目标<select id="enemyTarget">${foes.map((e, i) => `<option value="${-i - 1}" ${e.hp <= 0 ? "disabled" : ""}>${esc(e.name)} · HP ${e.hp}/${e.max_hp}</option>`).join("")}</select></label>` : ""}${button("使用技能 / 施法", "power", !canAct || !known.length)}${mine.is_host ? button("🏕️ 营地休息", "v4_world", Boolean(combat && combat.hp > 0), 'data-kind="camp_enter"') : ""}</section>`;
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
  if(s.postgame)return `${mapView(s,selectedArea)}<div class="grid"><div>${selectedArea?areaView(data,selectedArea):`<section class="card story-card"><p class="muted">CHAPTER 30 / 30 · ADVENTURE COMPLETE</p><h2>主线已完成 · ${esc(s.ending||'Upper City 的黎明')}</h2><p>最终敌人已被击败。城市仍有传闻、支线和未探明的角落；你们可以继续探索已开放区域。</p></section>`}<section class="card"><h3>队伍行动记录</h3><div class="log">${data.messages.map(m=>`<p><strong>${esc(m.sender)}</strong>：${esc(m.body)}</p>`).join('')}</div></section></div><aside><section class="card"><h3>当前在线 Party</h3>${data.players.map(p=>`<div class="member">${p.is_host?'👑 ':''}${character(p)}</div>`).join('')}</section><section class="card"><h3>任务与线索</h3>${questJournal(s)}</section>${merchantView(mine,chapter.id,flags,false)}</aside></div>`;
  return `${battleView(s, data.players, mine, data.messages)}${combat?.hp>0&&error?`<p class="error" role="alert">${esc(error)}</p>`:''}${mapView(s,selectedArea)}${selectedArea&&error?`<p class="error">${esc(error)}</p>`:""}<div class="grid"><div>${selectedArea?areaView(data,selectedArea):`<section class="card story-card"><p class="muted">${esc(chapter.act)} · 第 ${chapter.id + 1}/30 章</p><h2>${esc(chapter.title)}</h2><p class="story-lead">${esc(chapter.lead)}</p>${prior?`<p class="story-recap">前情 · ${esc(prior.title)}：${esc(prior.text)}${priorChoice?`你们选择了「${esc(priorChoice.label)}」。`:''}</p>`:''}<p>${esc(contextualText(chapter, flags))}</p><p class="story-goal">本章目标：与${esc(dialogues[s.chapter].name)}交谈，调查「${esc(encounters[s.chapter][0][0])}」及「${esc(encounters[s.chapter][1][0])}」，再决定队伍的行动。</p>${dialogueView(s)}${exploreView(s)}${deepView(s,mine,data.players)}${choiceView(s, chapter, mine, combat)}</section>`}<section class="card"><h3>自由行动与检定</h3><textarea id="chat" maxlength="500" placeholder="描述角色的行动、对白或计划"></textarea><div class="row">${button("发送行动", "chat")}<select id="skill" style="width:auto;margin:0">${["力量", "敏捷", "体质", "智力", "感知", "魅力", "调查", "洞悉", "说服", "潜行", "运动", "奥秘", "求生", "巧手", "察觉", "欺骗", "威吓", "表演", "历史", "自然", "宗教", "医药"].map((x) => `<option>${x}</option>`).join("")}</select><input id="dc" type="number" value="15" min="5" max="30" title="难度 DC" style="width:72px;margin:0">${button("D20 检定", "roll")}</div></section><section class="card"><h3>队伍行动记录</h3><div class="log">${[
    ...data.messages,
  ]
    .reverse()
    .map((m) => `<p><strong>${esc(m.sender)}</strong>：${esc(m.body)}</p>`)
    .join(
      "",
    )}</div></section></div><aside><section class="card"><h3>队伍角色</h3>${data.players.map((p) => `<div class="member">${p.is_host ? "👑 " : ""}${character(p)}${p.is_companion?`<p class="muted">伙伴态度 ${s.deep?.companionApproval?.[p.id]??0} · ${((s.deep?.companionApproval?.[p.id]??0)<0)?"对某些残酷行动会提出异议":"愿意讨论队伍抉择"}</p>`:""}</div>`).join("")}${data.players.some(p=>p.is_companion)?`<p class="muted">${esc(companionProfile.race)} · ${esc(companionProfile.background)}<br>${esc(companionProfile.active)}<br>${esc(companionProfile.passive)}</p>`:""}<div class="row">${savedRoom?"":button("离开", "leave")}${savedRoom?"":button("接任离线房主", "claim")}</div></section><section class="card"><h3>任务与线索</h3><p>主线：${esc(chapter.title)}</p><p>已完成章节 ${(s.completed_quests || []).length}/30</p>${sideQuests
    .filter((q) => chapter.id >= q.from && chapter.id <= q.to)
    .map(
      (q) =>
        `<p>支线：${esc(q.title)} · ${flags.includes(q.flag) ? "已完成" : "待调查"}<br><small>${esc(q.reward)}</small></p>`,
    )
    .join(
      "",
    )}${(s.clues || []).map((c) => `<span class="tag">${esc(c)}</span>`).join("") || '<p class="muted">尚未发现线索</p>'}${questJournal(s)}</section>${combat?.hp>0?'':powersView(mine, s, combat, data.players)}${merchantView(mine, chapter.id, flags, combat?.hp > 0)}<p class="error">${esc(error)}</p></aside></div>`;
}
