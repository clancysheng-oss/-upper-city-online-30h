import {canReroll,inspiration} from './checks.js';
import {button,esc} from './views.js';

export const races=[
 {name:'龙裔',icon:'🐉',description:'选择龙族血统，获得对应抗性与范围龙息。'},
 {name:'提夫林',icon:'😈',description:'抵抗火焰，随着成长唤醒地狱血统的魔法。'},
 {name:'人类',icon:'👤',description:'灵活适应不同职业与不熟练的检定。'},
 {name:'矮人',icon:'⛏️',description:'坚韧耐久，擅长辨认石工与古老锻造痕迹。'},
 {name:'精灵',icon:'🧝',description:'敏锐的感知、黑暗视觉与古代传统。'}
];
export const ancestries=['火焰','闪电','寒冷','毒素','酸液'];
export function raceUpdateView(mine){
 return `<section class="card identity-choice"><p class="muted">V4.0 角色更新 · 保留原角色与所有进度</p><h2>${esc(mine.name)}，请选择你的种族</h2><p>此选择会永久保存到当前角色。种族与职业独立；龙裔还须选择血统。</p><div class="race-grid">${races.map(r=>`<label class="race-card"><input type="radio" name="race" value="${r.name}" ${r.name==='人类'?'checked':''}><span class="race-icon">${r.icon}</span><strong>${r.name}</strong><small>${r.description}</small></label>`).join('')}</div><label>龙裔血统（仅龙裔生效）<select id="ancestry">${ancestries.map(a=>`<option>${a}</option>`).join('')}</select></label>${button('确认种族，继续冒险','v4_race')}<p class="muted">旧存档无需重开；不会改变等级、职业、装备或章节。</p></section>`;
}
export function diceOverlay(roll,record,player,error){
 if(!roll)return '';
 const natural=roll.natural===20?'nat20':roll.natural===1?'nat1':'';
 return `<div class="dice-backdrop"><section class="dice-result ${natural}" role="dialog" aria-label="D20检定结果"><p class="muted">${esc(roll.actor)} · ${esc(roll.skill)}${roll.save?'豁免':'检定'} · DC ${roll.dc}</p><div class="rolling-die" aria-label="D20 ${roll.d20}">D20<span>${roll.d20}</span></div><p class="dice-math">🎲 ${roll.d20}　+ 属性 ${roll.attribute}　+ 熟练 ${roll.proficiency}　+ 其他 ${roll.other}</p><h2>TOTAL ${roll.total} · ${roll.natural===20?'NATURAL 20':roll.natural===1?'NATURAL 1':roll.success?'SUCCESS':'FAILURE'}</h2><p>${roll.mode==='advantage'?'优势':roll.mode==='disadvantage'?'劣势':'普通'} · ${esc(roll.dice.filter(n=>n!==null).join(' / '))}</p>${record?`<p class="finding">${esc(record.consequence||'结果已记录')}</p><p class="muted">${record.scope==='party'?'Party共享机会':'个人机会'} · 第 ${record.attempts}/2 次 · Inspiration ${inspiration(player)}/4</p>`:''}${canReroll(record,player)?button('使用 Inspiration · 1 点','v41_reroll',false,`data-check="${esc(record.check_id)}"`):''}${button(record&&!record.resolved&&record.attempted_by===player?.id?'接受结果':'继续冒险','v4_dice_close')}${error?`<p role="alert" class="error">${esc(error)}</p>`:''}</section></div>`;
}
