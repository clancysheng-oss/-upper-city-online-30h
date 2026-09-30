import {novelEpilogue} from './novel-epilogues.js';
import {esc,button} from './views.js';

const art='/images/v4-final-victory.webp';
const finalParty=data=>(data.state.final_party||data.state.final_victory?.party||data.players.map(p=>p.name)).join(' · ');
export function finaleView(data,step='ending'){
 const s=data.state,mine=data.players.find(p=>p.id===data.me),party=finalParty(data);
 let title='',body='',details='',actions='';
 if(step==='victory'){
  title='最终战胜利';
  body='议会雇佣兵首领倒在散落的证据之间。钟声终于停下，厅门外的人群等着你们说出真相。';
  actions=button('查看战后','finale_next');
 }else if(step==='aftermath'){
  title='黎明之前';
  body='证人走进曾经紧闭的大厅。Upper City 的未来尚未写定，最后一章将由你们的调查与抉择收束。';
  details=companionEpilogue(data);
  actions=button('继续第 30 章','finale_story');
 }else if(step==='ending'){
  title=s.ending||'艰难的黎明';
  body=endingConsequences(data);
  details=companionEpilogue(data);
  actions=button('查看冒险结算','finale_next');
 }else if(step==='summary'){
  title='ADVENTURE COMPLETE';
  body=`${esc(s.ending||'Upper City迎来新的一天')} · 主线已完成`;
  details=`<div class="finale-stats"><div>角色<br><strong>${esc(mine?.name)}</strong></div><div>最终等级<br><strong>Lv.${mine?.level||1}</strong></div><div>主线<br><strong>Chapter 30 / 30</strong></div><div>游戏时间<br><strong>${Math.floor((s.final_play_seconds||0)/3600)} 小时 ${Math.floor(((s.final_play_seconds||0)%3600)/60)} 分钟</strong></div><div>完成任务<br><strong>${(s.completed_quests||[]).length+(Object.values(s.side_quests||{}).filter(q=>q.status==='已完成').length)}</strong></div><div>最终 Party<br><strong>${esc(party)}</strong></div></div>`;
  actions=button('保存纪念 PNG','finale_download')+button('前往终幕','finale_next');
 }else{
  title='THE END';
  body='这段冒险已经结束，但你的故事仍可以继续。';
  actions=button('保存纪念 PNG','finale_download')+button('继续探索','finale_explore')+button('返回主菜单','finale_menu');
 }
 return `<section class="finale" id="finale"><img src="${art}" alt="Upper City 破晓后的胜利景象"><div class="finale-copy"><p class="muted">UPPER CITY · THE THIRTEENTH BELL</p><h2 class="${step==='the_end'?'the-end':''}">${esc(title)}</h2><p>${body}</p>${details}<p class="muted">${esc(party)}</p><div class="row">${actions}</div></div></section>`;
}

function endingConsequences(data){return novelEpilogue(data.state).map(esc).join('<br><br>');}

function companionEpilogue(data){const s=data.state;return `<div class="companion-epilogue">${data.players.filter(p=>p.is_companion).map(p=>{const score=s.deep?.companionApproval?.[p.id]||0;const line=p.name==='亚岚·铜脉'?score<0?'“我们对很多事意见不同。但伤员回来了，我会留下修好那道门。”':'“我把每个活着回来的人都写进名册。明天还有墙要修，我跟你们一起去。”':score<0?'“这不是我会选择的每一步。至少今天，证人还能自己说话。”':'“当初我拒绝伪造巡逻表时，以为这座城再也不会听真话。你们让我改了主意。”';return `<blockquote><strong>${esc(p.name)}</strong><p>${esc(line)}</p></blockquote>`}).join('')}</div>`;}

export async function downloadFinale(data){
 const canvas=document.createElement('canvas');canvas.width=1600;canvas.height=1000;
 const ctx=canvas.getContext('2d');const img=new Image();img.src=art;await img.decode();
 ctx.drawImage(img,0,0,1600,900);
 const shade=ctx.createLinearGradient(0,320,0,1000);shade.addColorStop(0,'#12152000');shade.addColorStop(.55,'#121520cc');shade.addColorStop(1,'#121520');ctx.fillStyle=shade;ctx.fillRect(0,0,1600,1000);
 const mine=data.players.find(p=>p.id===data.me);const s=data.state;
 ctx.textAlign='center';ctx.fillStyle='#f4deaf';ctx.font='bold 38px Georgia, serif';ctx.fillText('UPPER CITY · THE THIRTEENTH BELL',800,650);
 ctx.fillStyle='#fff5de';ctx.font='bold 72px Georgia, serif';ctx.fillText('ADVENTURE COMPLETE',800,745);
 ctx.font='32px Georgia, serif';ctx.fillText(`${mine?.name||'冒险者'} · Lv.${mine?.level||1} · Chapter 30 / 30`,800,820);
 ctx.font='27px Georgia, serif';ctx.fillText((data.state.final_party||data.state.final_victory?.party||data.players.map(p=>p.name)).join(' · ').slice(0,65),800,875);
 ctx.font='25px Georgia, serif';ctx.fillText(s.ending||'Upper City',800,930);
 const blob=await new Promise((resolve,reject)=>canvas.toBlob(value=>value?resolve(value):reject(new Error('纪念图生成失败')),'image/png'));
 const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='Upper-City-Adventure-Complete.png';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(a.href),30000);
 return blob.size;
}
