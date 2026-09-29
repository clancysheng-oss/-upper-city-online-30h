import {chapters,classes} from './campaign.js';
import {esc,button} from './views.js';

export function saveSelection(slots,legacy,error,confirmDelete=null){
 return `<section class="save-select"><h2>选择冒险存档</h2><p class="muted">每个存档拥有独立队伍与世界。点击继续后可邀请好友加入。</p><div class="save-grid">${[1,2,3].map(n=>{
  const s=slots.find(item=>item.slot===n);
  return `<article class="card save-card"><small>THE THIRTEENTH BELL</small><h3>存档 ${n}</h3>${s?`<p><strong>${esc(s.name)}</strong> · ${esc(s.class_name)} · ${s.level} 级 ${s.completed?'<span class="good">✓ 已通关</span>':''}</p><p>第 ${s.chapter+1} 章 · ${esc(chapters[s.chapter]?.title||'终幕')}</p><p>区域：${esc(s.area)}</p><p>游戏时间：${Math.floor(s.play_seconds/3600)} 小时 ${Math.floor(s.play_seconds%3600/60)} 分钟</p><p class="muted">最后保存：${s.saved_at?new Date(s.saved_at).toLocaleString('zh-CN'):'尚未手动保存'}</p>${button('继续游戏','slot_enter',false,`data-slot="${n}"`)} ${button('删除存档','slot_delete',false,`data-slot="${n}" class="danger"`)}`:`<p>空存档</p>${button('开始新冒险','slot_new',false,`data-slot="${n}"`)}`}</article>`}).join('')}</div>${confirmDelete?`<section class="card save-confirm" role="alertdialog" aria-label="删除存档确认"><h3>删除存档 ${confirmDelete}</h3><p>确定要删除这个存档吗？<br>删除后无法恢复。</p><div class="row">${button('取消','slot_cancel_delete')} ${button('确认删除','slot_confirm_delete',false,`data-slot="${confirmDelete}" class="danger"`)}</div></section>`:''}${legacy?`<section class="card"><h3>最近的队伍</h3><p>房间 ${esc(legacy)} · 曾受邀的玩家可恢复自己的角色；房主可以导入空槽位。</p><div class="row">${button('继续最近的队伍','slot_resume')}${[1,2,3].filter(n=>!slots.some(s=>s.slot===n)).map(n=>button(`导入至存档 ${n}`,'slot_adopt',false,`data-slot="${n}"`)).join('')}</div></section>`:''}<p class="error">${esc(error)}</p></section>`;
}
export function newSlotForm(slot,name,cls,error){
 return `<section class="card hero"><h2>存档 ${slot} · 新冒险</h2><label>角色名<input id="name" value="${esc(name)}" maxlength="32" placeholder="至少两个字符"></label><label>职业<select id="class">${Object.keys(classes).map(c=>`<option ${c===cls?'selected':''}>${c}</option>`).join('')}</select></label><div class="row">${button('创建并进入','slot_create')}${button('返回存档','slot_back')}</div><p class="error">${esc(error)}</p></section>`;
}
