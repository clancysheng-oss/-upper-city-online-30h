import {button,esc,character} from './views.js';
import {canReroll,inspiration} from './checks.js';
import {wondersGoods,companionProfile,secondCompanionProfile} from './areas.js';
const feats=[
 ['强韧','最大 HP +5，倒地前承受更多伤害'],
 ['武器大师','近战攻击伤害提升'],
 ['神射手','远程攻击命中与伤害提升'],
 ['奥术增幅','攻击法术伤害提升'],
 ['专注大师','维持专注时豁免更稳'],
 ['技能专家','关键调查、察觉、潜行与交涉检定 +2'],
 ['迅捷步伐','逃跑和移动相关检定更强'],
 ['属性训练','职业主属性 +2（上限 20）']
];
export function buildView(mine){
 const points=mine.build?.points||0;
 if(!points)return '';
 return `<section class="card level-up"><p class="muted">角色成长 · 选择保存在当前角色</p><h2>LEVEL UP · ${esc(mine.name)}</h2><p>可用构筑点：${points}。同职业可以选择不同专长；每项仅能选一次。</p><div class="feat-grid">${feats.map(([name,text])=>`<article><strong>${name}</strong><p>${text}</p>${button(mine.build?.feats?.includes(name)?'已选择':'选择此专长','v4_world',mine.build?.feats?.includes(name),`data-kind="build" data-choice="${name}"`)}</article>`).join('')}</div></section>`;
}
export function campView(data){
 const mine=data.players.find(p=>p.id===data.me),s=data.state;
 const companions=data.players.filter(p=>p.is_companion);
 const gear=mine.inventory.filter(item=>wondersGoods.some(g=>g.name===item&&['weapon','armor','offhand'].includes(g.slot)));
 return `<section class="card camp-scene"><p class="muted">CAMP · 第 ${(s.chapter||0)+1} 章</p><h2>营地 · 帐篷与篝火</h2><p>这里可以整理装备、与伙伴谈话，或在安全时休息。重要剧情后的谈话会随章节变化。</p><div class="row">${button('返回上城区','v4_world',!mine.is_host,'data-kind="camp_leave"')}${mine.is_host?button('短休 · 部分恢复','v4_world',s.v4_short_chapter===s.chapter,'data-kind="short_rest"'):''}${mine.is_host?button('长休 · 恢复资源','v4_world',s.rested_chapter===s.chapter,'data-kind="long_rest"'):''}</div><div class="companion-camp">${companions.map(p=>{const profile=p.name==='亚岚·铜脉'?secondCompanionProfile:companionProfile;return `<article class="card">${character(p)}<p>${esc(profile.background)}</p><p>${esc(profile.active)} · ${esc(profile.passive)}</p><p>对你的态度：${s.deep?.companionApproval?.[p.id]||0}</p>${['过去','近期剧情','未来计划'].map(topic=>button(topic,'v4_world',false,`data-kind="camp_talk" data-companion="${p.id}" data-choice="${topic}"`)).join('')}${gear.length?`<label>赠予装备<select id="companionGear-${p.id}">${gear.map(item=>`<option>${esc(item)}</option>`).join('')}</select></label>${button('装备伙伴','v4_world',false,`data-kind="companion_equip" data-companion="${p.id}"`)}`:''}</article>`}).join('')||'<p>目前尚未有可交谈的伙伴。</p>'}</div><h3>最近的营地对话</h3>${data.messages.filter(m=>m.kind==='v4').slice(-4).map(m=>`<p class="camp-line">${esc(m.body)}</p>`).join('')||'<p class="muted">篝火边还很安静。</p>'}<h3>营地背包</h3><p>${esc(mine.inventory?.join('、')||'空')}</p></section>`;
}
export function worldPanel(data){
 const p=data.players.find(actor=>actor.id===data.me);
 const factions=[['hall','至高大厅'],['guard','城市守卫'],['gond','奇迹高堂'],['merchant','上城区商人'],['underground','地下势力']];
 const jailed=Boolean(p.conditions?.jailed);
 const area=data.state.current_area||'city',target={city:['城门补给商',13,8,'治疗药水','盾牌','城门长剑'],kegs:['酒馆信使',14,12,'酒馆客房钥匙','银线药水','护盾卷轴'],wonders:['高堂修复师',17,24,'高堂封存柜钥匙','星火卷轴','刻度护符'],hall:['书记官',20,40,'书记官密信','护盾卷轴','审计官胸针'],walls:['卫队军需官',18,30,'军需仓钥匙','军令破咒卷轴','夜巡长弓']}[area];
 return `<section class="card world-status"><h3>城市与你的关系</h3><p>${esc(p.race)} · ${esc(p.class_name)} · 通缉 ${p.wanted||0}/5 ${jailed?'· ⛓️ 城市监狱':''}</p><div class="faction-grid">${factions.map(([id,label])=>`<span>${label} <strong>${p.reputation?.[id]||0}</strong></span>`).join('')}</div>${jailed?`<h4>城市监狱</h4><p>接受逮捕并非游戏结束。可以缴纳罚款、服刑，或冒险寻找出路。</p>${['缴纳罚款','服刑','游说守卫','欺骗守卫','寻找钥匙','撬锁','秘密出口'].map(choice=>button(choice,'v4_world',false,`data-kind="prison" data-choice="${choice}"`)).join('')}`:`<details data-detail="crime"><summary>城市行动与法律</summary><p>犯罪不一定被发现；守卫会依据当时的位置、潜行检定和目击作出反应。高价值目标更难，失败后通缉与声望损失更高。扒窃、偷取财物、宝箱和暗路的收益各不相同；每个目标为队伍共享机会。</p><p>当前目标：${esc(target?.[0]||'区域目标')} · 扒窃 DC ${target?.[1]} / ${target?.[2]} 金币 + ${esc(target?.[3])}；偷取 DC ${(target?.[1]||0)+2} / ${esc(target?.[4])}；撬锁 DC ${(target?.[1]||0)+1} / ${esc(target?.[5])} + 线索。</p>${[['pickpocket','扒窃'],['theft','偷取财物'],['lockpick','非法撬锁'],['trespass','闯入限制区'],['vandalism','破坏设施']].map(([kind,label])=>button(label,'v4_world',false,`data-kind="crime" data-choice="${kind}"`)).join('')}<h4>与区域交易者交涉</h4><p>共享一次谈判机会：游说获 15% 折扣；欺骗取货并留下谎言；威吓获金币但降低声望。</p>${['说服','欺骗','威吓'].map(choice=>button(choice,'v4_world',false,`data-kind="social" data-choice="${choice}"`)).join('')}${['酒馆客房钥匙','高堂封存柜钥匙','军需仓钥匙'].some(key=>p.inventory.includes(key))?button('使用区域钥匙打开隐藏房间','v4_world',false,'data-kind="use_key"'):''}${p.is_host&&data.state.combat?.hp>0&&(data.state.combat.round||1)===1&&data.state.chapter!==28&&!data.state.combat.side_quest&&Object.keys(data.state.v41_access||{}).some(area=>!data.state.v41_access_used?.[area])?button('使用已发现的暗路避开本场冲突','v4_world',false,'data-kind="use_secret"'):''}${p.wanted>0?`<h4>守卫正在盘问你</h4>${['说服','欺骗','威吓','缴纳罚款','贿赂','逃跑','接受逮捕','拒捕'].map(choice=>button(choice,'v4_world',false,`data-kind="guard" data-choice="${choice}"`)).join('')}`:''}</details>`}</section>`;
}

export function checksPanel(data){
 const p=data.players.find(p=>p.id===data.me),records=Object.values(data.state.checks||{}).sort((a,b)=>String(b.result.at).localeCompare(String(a.result.at))).slice(0,12);
 return `<section class="card check-ledger"><h3>关键检定与激励点</h3><p>Inspiration：${inspiration(p)} / 4 · 同一关键事件最多原始检定 + 重投各一次。刷新、换人或重进均保留记录。</p>${records.map(r=>`<article class="encounter"><strong>${esc(r.actor)} · ${esc(r.result.skill)} · ${r.result.success?'成功':r.resolved?'失败已接受':'检定失败'}</strong><p>${esc(r.consequence||'结果已记录')}</p><small>${r.scope==='party'?'Party共享':'个人'} · ${r.attempts}/2 次 · ${esc(r.check_id)}</small><div class="row">${canReroll(r,p)?button('使用 Inspiration · 1 点','v41_reroll',false,`data-check="${esc(r.check_id)}"`):''}${!r.resolved&&r.attempted_by===p.id?button('接受结果','v41_accept',false,`data-check="${esc(r.check_id)}"`):''}</div></article>`).join('')||'<p class="muted">探索秘密、身份专属路线、重要支线与剧情决定可获得激励点。重复犯罪和普通战斗不会发放。</p>'}</section>`;
}
