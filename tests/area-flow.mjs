import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {areas,areaNpcs,areaQuests,areaBattles,wondersGoods} from '../src/areas.js';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const file of ['supabase.sql','upgrade.sql','db/002_secure_campaign.sql','db/003_encounters.sql','db/004_campaign_battles.sql','db/005_classes_spells.sql','db/006_deeper_campaign.sql','db/007_upper_city_areas.sql','db/008_v21_combat_story.sql','db/009_v21_dialogue_polish.sql'])await db.exec(fs.readFileSync(file,'utf8').replace('create extension if not exists pgcrypto;',''));
const ids=['00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000022'];
let code;
async function uid(i){await db.query('select set_config($1,$2,false)',['app.uid',ids[i]])}
async function cmd(i,action,payload={}){await uid(i);const {rows}=await db.query('select public.party_command($1,$2,$3::jsonb) r',[code||'',action,JSON.stringify(payload)]);return rows[0].r}
async function area(i,action,payload={}){await uid(i);const {rows}=await db.query('select public.party_area($1,$2,$3::jsonb) r',[code,action,JSON.stringify(payload)]);return rows[0].r}
async function deny(task,message){await assert.rejects(task(),new RegExp(message))}
function mine(s){return s.players.find(p=>p.id===s.me)}
assert.equal(areas.length,4);assert.equal(areaNpcs.length,12);assert.equal(areaQuests.length,5);assert.equal(areaBattles.length,2);
assert(areas.every(a=>areaNpcs.filter(n=>n.area===a.id).length===3&&areaNpcs.filter(n=>n.area===a.id).reduce((sum,n)=>sum+1+n.topics.reduce((x,t)=>x+1+t.options.length*2,0),0)>=20));
let s=await cmd(0,'create',{name:'Aster',class:'战士'});code=s.room;
await cmd(1,'join',{name:'Belle',class:'牧师'});await cmd(0,'ready');await cmd(1,'ready');s=await cmd(0,'start');
await deny(()=>area(0,'area_talk',{area:'hall',npc:'vessa',topic:0,choice:0}),'AREA_LOCKED');
s=await area(1,'area_talk',{area:'kegs',npc:'mara',topic:0,choice:0});assert(s.state.area_dialogue[0].reply.includes('蓝斗篷'));
await deny(()=>area(1,'area_talk',{area:'kegs',npc:'mara',topic:0,choice:4}),'INVALID_DIALOGUE_CHOICE');
await db.query('update public.players set hp=4 where room_code=$1 and user_id=$2',[code,ids[1]]);
s=await area(1,'area_eat',{area:'kegs'});assert.equal(mine(s).gold,9);assert.equal(mine(s).hp,mine(s).max_hp);
s=await area(0,'area_drink',{area:'kegs'});assert.equal(mine(s).gold,11);
await deny(()=>area(1,'area_eat',{area:'wonders'}),'TAVERN_ONLY');
await deny(()=>cmd(1,'buy',{item:'拱顶秘银剑'}),'ITEM_LOCKED');
await db.query('update public.players set gold=gold+200 where room_code=$1',[code]);
s=await cmd(1,'buy',{item:'护盾卷轴',price:0});assert.equal(mine(s).gold,185);
s=await cmd(1,'buy',{item:'银线药水'});assert(mine(s).inventory.includes('银线药水'));
await db.query('update public.players set hp=2 where room_code=$1 and user_id=$2',[code,ids[1]]);
s=await area(1,'area_use',{item:'银线药水'});assert.equal(mine(s).hp,mine(s).max_hp);assert(!mine(s).inventory.includes('银线药水'));
await deny(()=>area(1,'area_use',{item:'银线药水'}),'ITEM_NOT_IN_BAG');
await db.query("update public.game_states set state=jsonb_set(state,'{chapter}','16'::jsonb) where room_code=$1",[code]);
await db.query('update public.players set level=7,hp=150,max_hp=150,ac=20 where room_code=$1',[code]);
let before=await cmd(0,'heartbeat');assert.equal(before.state.chapter,16);
async function step(q,i){const stage=q.stages[i];if(stage.npc)await area(0,'area_talk',{area:stage.area,npc:stage.npc,topic:0,choice:0});let tries=0,last;while(++tries<60){last=await area(tries%2,'area_quest',{area:stage.area,quest:q.id,option:q.id==='gate'&&i===2?0:0});if(last.state.side_quests[q.id].step>i)return last;}throw Error('roll never succeeded '+q.id+' '+i)}
async function fight(q,i){let s=await area(0,'area_quest',{area:q.stages[i].area,quest:q.id});assert.equal(s.state.combat.side_quest,q.id);assert.equal(s.state.combat.enemies.length,4);let actions=0;while(s.state.combat.hp>0&&actions++<150){const actor=s.state.combat.turn;const idx=s.state.combat.enemies.findIndex(e=>e.hp>0);if(s.players.find(p=>p.id===actor)?.is_companion)s=await area(0,'companion_attack',{companion:actor,enemy:idx});else s=await cmd(s.players.find(p=>p.id===actor).name==='Aster'?0:1,'attack',{enemy:idx});}assert.equal(s.state.combat.hp,0);return area(0,'area_quest',{area:q.stages[i].area,quest:q.id})}
for(const id of ['star','medicine','gate','ledger','signal']){
 const q=areaQuests.find(x=>x.id===id);
 await area(0,'area_talk',{area:q.area,npc:q.giver,topic:0,choice:0});
 s=await area(0,'area_quest',{area:q.area,quest:q.id});assert.equal(s.state.side_quests[id].step,0);
 for(let i=0;i<q.stages.length-1;i++)s=q.stages[i].battle?await fight(q,i):await step(q,i);
 assert.equal(s.state.side_quests[id].status,'可交付');
 const gold=s.players.find(p=>p.name==='Aster').gold,xp=s.players.find(p=>p.name==='Aster').experience;
 s=await area(0,'area_quest',{area:q.stages.at(-1).area,quest:q.id});
 assert.equal(s.state.side_quests[id].status,'已完成');assert.equal(s.players.find(p=>p.name==='Aster').gold,gold+q.reward.gold);assert.equal(s.players.find(p=>p.name==='Aster').experience,xp+q.reward.xp);
 assert(s.players.find(p=>p.name==='Aster').inventory.includes(q.reward.item));
 await deny(()=>area(0,'area_quest',{area:q.area,quest:q.id}),'QUEST_COMPLETE');
 console.log('QUEST PASS',id);
}
assert(s.players.find(p=>p.is_companion)?.name==='伊莉娅·棱光');
assert(s.players.find(p=>p.is_companion)?.equipment.includes('夜巡长弓'));
const recovered=await cmd(1,'heartbeat');assert.equal(recovered.state.side_quests.signal.status,'已完成');assert.equal(recovered.players.filter(p=>p.is_companion).length,1);
await deny(()=>area(0,'area_quest',{area:'hall',quest:'gate'}),'QUEST_COMPLETE');
await uid(0);await db.exec('set role authenticated');
await assert.rejects(db.query("select * from public.uc_quests"),/permission denied/);
await db.exec('reset role');
console.log('AREA FLOW PASS: 4 areas, 12 NPCs, five staged quests, two fights, equipment, consumables, companion, persistence and access control');
