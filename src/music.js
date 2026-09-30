// Original game cues. A single audio element prevents overlapping main tracks.
const tracks={idle:'idle',kegs:'tavern',wonders:'hall_of_wonders',hall:'high_hall',walls:'upper_city_walls',final:'final_battle',victory:'victory',battleA:'battle_01',battleB:'battle_02'};
const clamp=value=>Math.max(0,Math.min(1,Number(value)||0));
const audio=typeof Audio==='undefined'?null:new Audio();
if(audio){audio.loop=true;audio.preload='none';}
let enabled=localStorage.getItem('uc_bgm_enabled')==='true',volume=clamp(localStorage.getItem('uc_bgm_volume')??'.55');
let unlocked=false,current='',wanted='idle',changing=0,transitionTarget='',lastBattle='battleB',combatKey='';
const path=id=>`/assets/music/${tracks[id]}.ogg`;
function fade(target,ms=440){if(!audio)return Promise.resolve();const start=audio.volume,at=performance.now();const token=++changing;return new Promise(resolve=>{const tick=()=>{if(token!==changing){resolve();return;}const progress=Math.min(1,(performance.now()-at)/ms);audio.volume=start+(target-start)*progress;if(progress<1)requestAnimationFrame(tick);else resolve();};tick();});}
async function change(track){if(!audio||!enabled||!unlocked||!tracks[track]||transitionTarget===track)return;if(current===track){if(audio.paused)audio.play().catch(()=>{});return;}const target=track;transitionTarget=target;await fade(0);if(target!==wanted||!enabled){transitionTarget='';return;}current=target;audio.src=path(target);audio.volume=0;try{await audio.play();await fade(volume);}catch{/* browser waits for user gesture */}finally{transitionTarget='';}}
export function unlockMusic(){unlocked=true;if(enabled)change(wanted);}
export function musicState(data,step){
 const s=data?.state;let next='idle';
 if(s){
  if(step||s.final_victory&&!s.postgame&&s.chapter===28||s.campaign_complete&&!s.postgame)next='victory';
  else if(s.combat?.hp>0){
   if(s.chapter===28&&!s.combat?.side_quest)next='final';
   else{
    const key=[data.room,s.chapter,s.combat?.side_quest,s.combat?.name,s.combat?.round===1?s.combat?.max_hp:''].join(':');
    if(!combatKey||!key.startsWith(combatKey.split(':').slice(0,4).join(':')))lastBattle=lastBattle==='battleA'?'battleB':'battleA';
    combatKey=key;next=lastBattle;
   }
  }else{combatKey='';if(!s.v4_camp)next=tracks[s.current_area]?s.current_area:'idle';}
 }
 wanted=next;
 if(enabled&&unlocked)change(next);
}
export function musicSettings(){return `<div class="music-settings"><label><input type="checkbox" id="bgmEnabled" ${enabled?'checked':''}> 🎵 BGM</label><label>音量 <input id="bgmVolume" type="range" min="0" max="100" value="${Math.round(volume*100)}" aria-label="背景音乐音量"></label></div>`;}
export function setMusicEnabled(value){enabled=Boolean(value);localStorage.setItem('uc_bgm_enabled',String(enabled));if(!enabled){++changing;transitionTarget='';audio?.pause();}else{unlocked=true;change(wanted);}}
export function setMusicVolume(value){volume=clamp(Number(value)/100);localStorage.setItem('uc_bgm_volume',String(volume));if(audio&&current===wanted)audio.volume=volume;}
