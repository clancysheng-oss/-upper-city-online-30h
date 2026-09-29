import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const file of ['supabase.sql','upgrade.sql','db/002_secure_campaign.sql','db/003_encounters.sql','db/004_campaign_battles.sql','db/005_classes_spells.sql','db/006_deeper_campaign.sql','db/007_upper_city_areas.sql','db/008_v21_combat_story.sql','db/009_v21_dialogue_polish.sql','db/010_v22_save_slots.sql'])await db.exec(fs.readFileSync(file,'utf8').replace('create extension if not exists pgcrypto;',''));
const users=['00000000-0000-0000-0000-000000000071','00000000-0000-0000-0000-000000000072'];
for(const id of users)await db.query('insert into auth.users(id) values($1)',[id]);
async function uid(i){await db.query('select set_config($1,$2,false)',['app.uid',users[i]])}
async function slot(i,action,n=null,room=null,name=null,cls=null){await uid(i);return (await db.query('select public.party_save_slot($1,$2,$3,$4,$5) v',[action,n,room,name,cls])).rows[0].v}
async function cmd(i,room,action,payload={}){await uid(i);return (await db.query('select public.party_command($1,$2,$3::jsonb) v',[room,action,JSON.stringify(payload)])).rows[0].v}
async function region(i,room,area){await uid(i);return (await db.query('select public.party_region($1,$2) v',[room,area])).rows[0].v}
const one=await slot(0,'create',1,null,'璃亚','战士'),two=await slot(0,'create',2,null,'艾宁','法师'),three=await slot(0,'create',3,null,'阿弥','牧师');
assert.equal(new Set([one.room,two.room,three.room]).size,3);
assert.equal((await slot(0,'list')).length,3);
await assert.rejects(slot(0,'create',1,null,'覆盖','法师'),/SLOT_OCCUPIED/);
await assert.rejects(slot(1,'save',1),/EMPTY_SLOT/);
await cmd(0,one.room,'ready');await cmd(0,one.room,'start');
await region(0,one.room,'kegs');
await assert.rejects(region(0,one.room,'hall'),/AREA_LOCKED/);
await cmd(1,one.room,'join',{name:'米娅',class:'牧师'});
let s=await slot(0,'enter',1);assert.equal(s.players.length,2);
await cmd(1,one.room,'roll',{skill:'调查',dc:15});
await assert.rejects(slot(1,'save',1),/EMPTY_SLOT/);
await assert.rejects(cmd(1,one.room,'claim_host'),/SAVE_OWNER_ONLY/);
await slot(0,'save',1);
let details=await slot(0,'list');assert(details[0].saved_at&&details[0].room===one.room&&details[0].area==='三只旧酒桶');
let raw=(await db.query('select saved_state,saved_players from public.save_slots where owner_id=$1 and slot=1',[users[0]])).rows[0];assert.equal(raw.saved_state.current_area,'kegs');assert.equal(raw.saved_players.length,2);
await cmd(0,one.room,'leave');s=await slot(0,'enter',1);assert.equal(s.players.find(p=>p.id===one.me).name,'璃亚');
assert.equal(s.state.current_area,'kegs');assert.equal(s.messages.some(m=>m.kind==='roll'),true);
assert.equal((await slot(0,'enter',2)).players[0].name,'艾宁');
assert.equal((await slot(0,'enter',3)).players[0].name,'阿弥');
assert.equal((await slot(0,'list'))[1].saved_at!==null,true);
console.log('V2.2 PASS: three isolated slots, solo start, late invite, owner-only checkpoint, area persistence, character re-entry');
