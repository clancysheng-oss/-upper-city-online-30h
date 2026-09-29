import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {deepChapters} from '../src/deep-story.js';
import {deepFollowups} from '../src/deep-followups.js';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const f of ['supabase.sql','upgrade.sql','db/002_secure_campaign.sql','db/003_encounters.sql','db/004_campaign_battles.sql','db/005_classes_spells.sql','db/006_deeper_campaign.sql','db/007_upper_city_areas.sql','db/008_v21_combat_story.sql','db/009_v21_dialogue_polish.sql','db/010_v22_save_slots.sql','db/011_xp_progression.sql','db/012_v30_story_depth.sql','db/013_v30_battle_aftermath.sql','db/014_v30_followup_dialogue.sql','db/015_v30_encounter_routes.sql','db/016_v31_stability_finale.sql','db/017_v31_saved_room_lobby.sql'])await db.exec(fs.readFileSync(f,'utf8').replace('create extension if not exists pgcrypto;',''));
const a='00000000-0000-0000-0000-000000000091',b='00000000-0000-0000-0000-000000000092';
await db.query('insert into auth.users(id) values($1),($2)',[a,b]);
async function as(uid,sql,args=[]){await db.query("select set_config('app.uid',$1,false)",[uid]);return (await db.query(sql,args)).rows[0]?.v}
const created=await as(a,"select public.party_save_slot('create',1,null,'城门见证者','法师') v");const code=created.room;
await as(b,"select public.party_command($1,'join',$2::jsonb) v",[code,JSON.stringify({name:'屋顶旅人',class:'战士'})]);
await as(a,"select public.party_command($1,'ready') v",[code]);
await as(b,"select public.party_command($1,'ready') v",[code]);
await as(a,"select public.party_command($1,'start') v",[code]);
let state=await as(a,"select public.party_snapshot($1) v",[code]);
assert.equal(state.players.length,2);
let fights=0,skipped=0,environmentHits=0,aftermaths=0;
async function cmd(uid,action,payload={}){return as(uid,'select public.party_command($1,$2,$3::jsonb) v',[code,action,JSON.stringify(payload)])}
async function deep(uid,action,payload={}){return as(uid,'select public.party_deep($1,$2,$3::jsonb) v',[code,action,JSON.stringify(payload)])}
async function battle(snapshot){
 let turns=0,used=false;
 while(snapshot.state.combat?.hp>0){
  if(++turns>150)throw Error('combat stalled '+snapshot.state.chapter);
  let actor=snapshot.players.find(p=>p.id===snapshot.state.combat.turn);
  if(!actor)throw Error('invalid initiative');
  let uid=actor.name==='城门见证者'?a:b;
  if(!used&&snapshot.state.combat.environment?.[0]&&!snapshot.state.combat.environment[0].used){
   const before=snapshot.state.combat.hp;
   snapshot=await deep(uid,'environment',{object:0});used=true;
   if(snapshot.state.combat.hp<before)environmentHits++;
  }else{
   const index=snapshot.state.combat.enemies.findIndex(e=>e.hp>0);
   snapshot=await cmd(uid,'attack',{enemy:index});
  }
 }
 return snapshot;
}
// Combat and exploration remain real RPC calls; test characters have enough HP to finish a 30-chapter regression.
await db.query('update public.players set hp=500,max_hp=500,ac=35,gold=300,level=12 where room_code=$1',[code]);
for(let chapter=0;chapter<30;chapter++){
 state=await as(a,'select public.party_snapshot($1) v',[code]);
 assert.equal(state.state.chapter,chapter);
 assert.equal(deepChapters[chapter].id,chapter);
 const witness=await deep(chapter%2?b:a,'talk',{choice:0});
 assert(witness.messages.some(m=>m.body.includes(deepChapters[chapter].lines[1])),'first answer differs from greeting');
 for(let i=1;i<3;i++)await deep(i%2?a:b,'talk',{choice:i});
 assert.equal(deepFollowups[chapter].length,6);
 for(let i=0;i<3;i++){
  const result=await deep(i%2?b:a,'followup',{choice:i});
  assert(result.messages.some(m=>m.body.includes(deepFollowups[chapter][i])));
 }
 state=await deep(chapter%2?a:b,'inspect');
 assert.equal(state.state.deep.inspected[chapter],true);
 for(let i=0;i<3;i++){
  state=await deep(i%2?a:b,'debrief',{choice:i});
  assert(state.messages.some(m=>m.body.includes(deepFollowups[chapter][i+3])));
 }
 if(chapter===0){
  await assert.rejects(()=>deep(b,'route',{choice:1}),/HOST_ONLY/);
 }
 const beforeRoute=state.state.combat?.enemies?.[0]?.attack_bonus;
 state=await deep(a,'route',{choice:chapter===1?1:0});
 if(state.state.deep.combat?.[chapter]?.combat_skipped)skipped++;
 if(chapter===17&&state.state.deep.route[chapter]==='peace')assert(state.state.deep.combat[chapter].combat_skipped,'successful deep-well bypass resolves the encounter');
 if(chapter===28){
  assert(state.state.combat?.hp>0,'council boss remains mandatory');
  if(state.state.deep.route[chapter]==='peace')assert(state.state.combat.enemies[0].attack_bonus<beforeRoute,'negotiation weakens mandatory boss');
 }
 if(state.state.combat?.hp>0){
  fights++;state=await battle(state);
  if(chapter===28)assert.deepEqual(state.state.final_victory.party,['城门见证者','屋顶旅人']);
  state=await deep(a,'aftermath');
  aftermaths++;
  assert(state.state.deep.aftermath[chapter]);
  await assert.rejects(()=>deep(a,'aftermath'),/ALREADY_COLLECTED/);
 }
 for(let i=0;i<3;i++)state=await cmd(i%2?a:b,'dialogue',{choice:0});
 for(let i=0;i<2;i++)state=await cmd(i%2?b:a,'explore',{index:i});
 state=await cmd(a,'choice',{index:0});
 if(chapter<29)state=await cmd(a,'advance');
}
assert.equal(state.state.chapter,29);
assert(state.state.ending);
assert.equal(state.state.completed_quests.length,30);
assert.equal(state.state.campaign_complete,true);
assert(state.state.deep.storyFlags['0_witness_0']);
assert(state.state.deep.storyFlags['1_force']);
assert(fights>=2 && skipped>=1 && environmentHits>=2 && aftermaths===fights);
await as(a,"select public.party_save_slot('save',1) v");
const saved=(await db.query('select saved_state from public.save_slots where room_code=$1',[code])).rows[0].saved_state;
assert.deepEqual(saved.deep,state.state.deep);
const reconnect=await as(b,'select public.party_snapshot($1) v',[code]);
assert.deepEqual(reconnect.state.deep,state.state.deep);
const wizard=reconnect.players.find(p=>p.name==='城门见证者');
await cmd(a,'buy',{item:'奥术回响法杖'});
await cmd(a,'equip',{item:'奥术回响法杖'});
await cmd(a,'buy',{item:'星穹织法长袍'});
await cmd(a,'equip',{item:'星穹织法长袍'});
let gear=await as(a,'select public.party_snapshot($1) v',[code]);
assert(gear.players.find(p=>p.id===wizard.id).equipment.includes('奥术回响法杖'));
assert(gear.players.find(p=>p.id===wizard.id).equipment.includes('星穹织法长袍'));
const injectCombat=async(extra={})=>{
 const fight={name:'迁移回归遭遇',enemies:[{name:'训练用铁卫',hp:180,max_hp:180,ac:1,attack_bonus:0,damage_min:0,damage_die:1}],hp:180,max_hp:180,turn:wizard.id,initiative:[{id:wizard.id,roll:20}],round:1,wards:{},...extra};
 await db.query("update public.game_states set state=jsonb_set(state,'{combat}',$2::jsonb) where room_code=$1",[code,JSON.stringify(fight)]);
 return as(a,'select public.party_snapshot($1) v',[code]);
};
await injectCombat();
let firstHit=false,echoBefore=0;
for(let i=0;i<3;i++){
 const result=await as(a,'select public.party_power($1,$2,$3,$4) v',[code,'wizard_1',-1,1]);
 if(result.state.combat.arcane_echo_used?.[wizard.id]){firstHit=true;echoBefore=result.state.combat.enemies[0].hp;break;}
}
assert(firstHit,'equipped staff marks first successful spell in shared combat state');
const second=await as(a,'select public.party_power($1,$2,$3,$4) v',[code,'wizard_bolt',-1,0]);
assert.equal(second.state.combat.arcane_echo_used[wizard.id],true);
assert(second.state.combat.enemies[0].hp<=echoBefore);
await db.query("update public.game_states set state=jsonb_set(state,'{combat}','null'::jsonb) where room_code=$1",[code]);
await db.query("insert into public.players(room_code,name,class_name,is_companion,hp,max_hp,ac,stats,inventory,equipment,gold,level,ability_charges) values($1,'伊莉娅·棱光','游侠',true,28,28,15,'[12,17,14,13,15,12]'::jsonb,'[]'::jsonb,$2::jsonb,0,12,2)",[code,JSON.stringify(['夜巡长弓'])]);
const companion=(await db.query("select id from public.players where room_code=$1 and is_companion",[code])).rows[0].id;
await db.query("update public.game_states set state=jsonb_set(jsonb_set(state,array['deep','storyFlags','28_force'],'true'::jsonb,true),array['deep','companionApproval',$2],'-20'::jsonb,true) where room_code=$1",[code,String(companion)]);
gear=await injectCombat({initiative:[{id:companion,roll:25},{id:wizard.id,roll:20}],turn:companion});
assert(gear.state.combat.refusing.includes(companion));
assert(!gear.state.combat.initiative.some(x=>x.id===companion));
assert(gear.players.some(p=>p.id===companion),'refusal retains companion in party');
await db.query("update public.game_states set state=jsonb_set(state,'{combat}','null'::jsonb) where room_code=$1",[code]);
assert((await as(b,'select public.party_snapshot($1) v',[code])).players.some(p=>p.id===companion));
await db.query("update public.game_states set state=jsonb_set(state,'{chapter}','28'::jsonb) where room_code=$1",[code]);
const beforeApproval=(await as(a,'select public.party_snapshot($1) v',[code])).state.deep.companionApproval[companion];
const comment=await deep(b,'interject',{choice:0});
assert.equal(comment.state.deep.companionApproval[companion],beforeApproval+5);
assert(comment.players.some(p=>p.id===companion));
await db.query("update public.game_states set state=state-'deep' where room_code=$1",[code]);
const legacy=await deep(a,'talk',{choice:1});
assert(legacy.state.deep.storyFlags['28_witness_1'],'legacy state without new fields is upgraded on demand');
console.log(`V3.0 PASS: 30 chapters, ${fights} real battles and aftermaths, ${skipped} skipped encounters, ${environmentHits} environment hits, wizard equipment, companion refusal/interjection, save and second-player reconnect`);
