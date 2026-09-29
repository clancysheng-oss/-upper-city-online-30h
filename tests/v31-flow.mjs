import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const f of ['supabase.sql','upgrade.sql','db/002_secure_campaign.sql','db/003_encounters.sql','db/004_campaign_battles.sql','db/005_classes_spells.sql','db/006_deeper_campaign.sql','db/007_upper_city_areas.sql','db/008_v21_combat_story.sql','db/009_v21_dialogue_polish.sql','db/010_v22_save_slots.sql','db/011_xp_progression.sql','db/012_v30_story_depth.sql','db/013_v30_battle_aftermath.sql','db/014_v30_followup_dialogue.sql','db/015_v30_encounter_routes.sql','db/016_v31_stability_finale.sql'])await db.exec(fs.readFileSync(f,'utf8').replace('create extension if not exists pgcrypto;',''));
const u=['00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000a3'];
for(const id of u)await db.query('insert into auth.users(id) values($1)',[id]);
async function as(i,sql,args=[]){await db.query("select set_config('app.uid',$1,false)",[u[i]]);return (await db.query(sql,args)).rows[0]?.v}
async function cmd(i,code,action,payload={}){return as(i,'select public.party_command($1,$2,$3::jsonb) v',[code,action,JSON.stringify(payload)])}
async function snap(i,code){return as(i,'select public.party_snapshot($1) v',[code])}
const a=await as(0,"select public.party_save_slot('create',1,null,'克兰西','战士') v");
const b=await as(0,"select public.party_save_slot('create',2,null,'法师伊恩','法师') v");
const room=a.room;
await cmd(1,room,'join',{name:'米娅',class:'牧师'});
await cmd(2,room,'join',{name:'洛安',class:'游侠'});
assert.equal((await snap(0,room)).players.length,3);
await cmd(1,room,'leave');
assert.deepEqual((await snap(0,room)).players.map(p=>p.name),['克兰西','洛安']);
assert.equal((await as(0,"select public.party_v31_slots() v")).length,2);
await cmd(1,room,'join',{name:'伪造新角色',class:'法师'});
assert.equal((await snap(0,room)).players.find(p=>p.id!==a.me&&p.name==='米娅')?.class_name,'牧师');
assert.equal((await as(0,'select count(*)::integer v from public.players where room_code=$1 and user_id=$2',[room,u[1]])),1);
await db.query("update public.players set last_seen=now()-interval '100 seconds' where room_code=$1 and user_id=$2",[room,u[2]]);
assert.equal((await snap(0,room)).players.filter(p=>!p.is_companion).length,2);
assert.equal((await as(0,'select is_online v from public.players where room_code=$1 and user_id=$2',[room,u[2]])),false);
await cmd(2,room,'heartbeat');
assert.equal((await snap(0,room)).players.length,3);
await cmd(0,room,'leave');
assert.equal((await snap(1,room)).players.some(p=>p.name==='克兰西'),false);
assert.equal((await as(0,'select public.party_enter_slot(1) v')).players.find(p=>p.name==='克兰西')?.is_host,true);
await assert.rejects(as(1,'select public.party_delete_slot(1) v'),/EMPTY_SLOT/);
await as(0,'select public.party_delete_slot(1) v');
assert.equal((await as(0,'select public.party_v31_slots() v')).length,1);
assert.equal((await as(0,'select count(*)::integer v from public.rooms where code=$1',[room])),0);
await assert.rejects(snap(1,room),/NOT_MEMBER/);
const replacement=await as(0,"select public.party_save_slot('create',1,null,'新开始','游荡者') v");
assert.notEqual(replacement.room,room);assert.equal(replacement.state.chapter,0);
assert.equal((await as(0,'select public.party_v31_slots() v'))[1].room,b.room);
// A real state transition to zero HP records victory for online characters, then Chapter 30 completion.
await db.query("update public.game_states set state=jsonb_build_object('chapter',28,'combat',jsonb_build_object('hp',8,'enemies',jsonb_build_array(jsonb_build_object('hp',8,'max_hp',8,'ac',15,'attack_bonus',4,'damage_min',2))),'started',true,'completed_quests','[]'::jsonb) where room_code=$1",[replacement.room]);
await db.query("update public.game_states set state=jsonb_set(state,'{combat,hp}','0'::jsonb) where room_code=$1",[replacement.room]);
assert.deepEqual((await snap(0,replacement.room)).state.final_victory.party,['新开始']);
await db.query("update public.game_states set state=state||jsonb_build_object('chapter',29,'ending','公民议会重建','chosen_chapter',29) where room_code=$1",[replacement.room]);
let end=await snap(0,replacement.room);assert.equal(end.state.campaign_complete,true);
assert.equal((await as(0,'select public.party_v31_slots() v')).find(s=>s.slot===1).completed,true);
end=await as(0,'select public.party_v31_explore($1) v',[replacement.room]);assert.equal(end.state.postgame,true);
assert.equal((await as(0,'select public.party_enter_slot(1) v')).state.postgame,true);
console.log('V3.1 PASS: slot isolation/deletion, live party, timeout/rejoin/host, victory, completion, postgame');
