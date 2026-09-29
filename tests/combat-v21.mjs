import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {dialogues} from '../src/dialogues.js';
import {encounters} from '../src/encounters.js';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const file of ['supabase.sql','upgrade.sql','db/002_secure_campaign.sql','db/003_encounters.sql','db/004_campaign_battles.sql','db/005_classes_spells.sql','db/006_deeper_campaign.sql','db/007_upper_city_areas.sql','db/008_v21_combat_story.sql','db/009_v21_dialogue_polish.sql'])await db.exec(fs.readFileSync(file,'utf8').replace('create extension if not exists pgcrypto;',''));
const ids=['00000000-0000-0000-0000-000000000051','00000000-0000-0000-0000-000000000052'];
async function auth(i){await db.query('select set_config($1,$2,false)',['app.uid',ids[i]])}
async function command(i,code,action,payload={}){await auth(i);return (await db.query('select public.party_command($1,$2,$3::jsonb) s',[code,action,JSON.stringify(payload)])).rows[0].s}
async function cast(i,code,id,target,slot=0){await auth(i);return (await db.query('select public.party_power($1,$2,$3,$4) s',[code,id,target,slot])).rows[0].s}
let s=await command(0,'','create',{name:'Irel',class:'法师'}),code=s.room;
await command(1,code,'join',{name:'Mira',class:'牧师'});
await command(0,code,'ready');await command(1,code,'ready');s=await command(0,code,'start');
const [a,b]=s.players;
const enemy=(hp)=>({name:'测试铁卫',hp,max_hp:hp,ac:8,attack_bonus:99,damage_min:20,damage_die:1});
async function combat(foes,initiative=[a.id,b.id]){const body={name:'回归战斗',enemies:foes,hp:foes.reduce((n,e)=>n+e.hp,0),round:1,turn:initiative[0],initiative:initiative.map((id,i)=>({id,roll:20-i}))};await db.query("update public.game_states set state=jsonb_set(state,'{combat}',$2::jsonb) where room_code=$1",[code,JSON.stringify(body)])}
for(let attempt=0;attempt<30;attempt++){
 await combat([enemy(40),enemy(40)]);
 await db.query('update public.players set ability_charges=2 where id=$1',[a.id]);
 s=await cast(0,code,'wizard_bolt',-1);
 if(s.state.combat.enemies[0].hp<40)break;
}
assert.equal(s.state.combat.turn,b.id,'nonlethal spell hands over turn');
assert(s.state.combat.enemies[0].hp<40&&s.state.combat.enemies[1].hp===40,'spell damages selected enemy');
assert(s.messages.some(m=>m.kind==='power'&&m.body.includes('D20=')),'spell result is stored for main panel');
await db.query('update public.players set hp=1 where room_code=$1 and user_id=$2',[code,ids[1]]);
await db.query('update public.players set hp=100,max_hp=100 where room_code=$1 and user_id=$2',[code,ids[0]]);
await db.query('update public.players set ac=30 where room_code=$1 and user_id=$2',[code,ids[0]]);
await db.query('update public.players set ac=1 where room_code=$1 and user_id=$2',[code,ids[1]]);
await db.query("update public.game_states set state=jsonb_set(jsonb_set(state,'{combat,enemies,0,special}','\"齐射\"'::jsonb),'{combat,enemies,1,special}','\"齐射\"'::jsonb) where room_code=$1",[code]);
s=await cast(1,code,'cleric_light',-2);
assert.equal(s.players.find(p=>p.id===b.id).hp,0,'enemy turn can down the acting player');
assert.equal(s.state.combat.turn,a.id,'next round skips the downed player');
assert(s.state.combat.enemies[0].hp<40,'second spell does not overwrite the first enemy');
for(let attempt=0;attempt<30;attempt++){
 await combat([enemy(1)]);
 await db.query('update public.players set ability_charges=2 where id=$1',[a.id]);
 s=await cast(0,code,'wizard_bolt',-1);
 if(s.state.combat.hp===0)break;
}
assert.equal(s.state.combat.hp,0,'lethal spell persists victory in shared state');
assert.equal(s.state.combat.enemies[0].hp,0);
assert(s.messages.some(m=>m.kind==='power'&&m.body.includes('敌方全灭')));
await db.query('update public.players set hp=1 where room_code=$1',[code]);
await db.query('update public.players set hp=0 where id=$1',[b.id]);
await db.query('update public.players set ability_charges=2 where id=$1',[a.id]);
await combat([{...enemy(60),ac:30}],[a.id]);
s=await cast(0,code,'wizard_focus',a.id);
assert(s.state.combat.hp>0&&s.state.combat.turn===null,'party wipe is an explicit combat state');
await assert.rejects(command(1,code,'retry'),/HOST_ONLY/);
s=await command(0,code,'retry');
assert(s.state.combat.hp===60&&s.state.combat.round===1&&s.state.combat.turn!==null,'host retry resets same fight and initiative');
assert(s.players.every(p=>p.hp>0),'retry restores half HP for all players');
assert(s.messages.some(m=>m.kind==='retry'&&m.body.includes('重整')));
assert.equal(dialogues.length,30);assert.equal(new Set(dialogues.map(d=>d.beats[0].text)).size,30);
assert(!dialogues.some(d=>d.beats.some(b=>b.text.includes('摊开地图')||b.text.includes('在现场等你们'))));
assert(encounters.length===30&&new Set(encounters.flat().map(e=>e[6])).size===60);
console.log('V2.1 PASS: targeted spells, lethal victory, downed turn skip, wipe retry, unique dialogue and clues');
