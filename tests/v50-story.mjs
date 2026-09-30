import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {novelChapters} from '../src/novel-story.js';
import {chapters} from '../src/campaign.js';
import {renderGame} from '../src/views.js';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
for(const file of ['supabase.sql','upgrade.sql',...fs.readdirSync('db').filter(f=>/^\d{3}_.*\.sql$/.test(f)).sort().map(f=>'db/'+f)]) await db.exec(fs.readFileSync(file,'utf8').replace('create extension if not exists pgcrypto;',''));
await db.exec(fs.readFileSync('db/037_v50_novel_campaign.sql','utf8')); // Idempotent application.
const ids=['00000000-0000-0000-0000-0000000000e1','00000000-0000-0000-0000-0000000000e2'];
for(const id of ids)await db.query('insert into auth.users(id) values($1)',[id]);
await db.exec('begin');
async function as(i,sql,args=[]){await db.query("select set_config('app.uid',$1,false)",[ids[i]]);await db.exec('savepoint rpc');try{const v=(await db.query(sql,args)).rows[0]?.v;await db.exec('release rpc');return v;}catch(error){await db.exec('rollback to rpc;release rpc');throw error;}}
let room=(await as(0,"select public.party_save_slot('create',2,null,'小说诗人','吟游诗人') v")).room;
const cmd=(i,a,p={})=>as(i,'select public.party_command($1,$2,$3::jsonb) v',[room,a,JSON.stringify(p)]);
const snap=()=>as(0,'select public.party_snapshot($1) v',[room]);
await cmd(1,'join',{name:'小说法师',class:'法师'});
await as(0,"select public.party_v4_identity($1,'race','{\"race\":\"人类\"}') v",[room]);
await as(1,"select public.party_v4_identity($1,'race','{\"race\":\"精灵\"}') v",[room]);
await cmd(0,'ready');await cmd(1,'ready');await cmd(0,'start');
assert.equal(novelChapters.length,30);
assert.equal(novelChapters.flatMap(c=>c.beats.flatMap(b=>b.options)).length,462);
assert.equal(chapters.flatMap(c=>c.choices).length,120);
for(const c of novelChapters){assert(c.text.length>100);assert(c.beats.every(b=>b.options.length>=4));assert.equal(new Set(c.beats.flatMap(b=>b.options.map(o=>o.reply))).size,c.beats.flatMap(b=>b.options).length);}
await assert.rejects(cmd(0,'dialogue',{choice:99}),/INVALID_DIALOGUE_CHOICE/);
await assert.rejects(cmd(0,'dialogue',{choice:6}),/CLASS_DIALOGUE_ONLY/);
await assert.rejects(cmd(0,'choice',{index:3}),/EXPLORE_BEFORE_CHOICE|DIALOGUE_FIRST/);
await cmd(0,'dialogue',{choice:5}); // Sixth option, previously forbidden by server.
let s=(await snap()).state;assert.equal(s.story_version,5);assert.equal(s.dialogue.step,1);
assert.equal(s.dialogue.history[0].reply,novelChapters[0].beats[0].options[5].reply);
await cmd(1,'dialogue',{choice:0});await cmd(0,'dialogue',{choice:0});
s=(await snap()).state;assert.equal(s.dialogue.step,3);assert(s.narrative.relationships['0']>=3);
await cmd(1,'choice',{index:3});s=(await snap()).state;
assert.equal(s.chosen_chapter,0);assert.equal(s.narrative.decisions['0'].index,3);assert.equal(s.last_choice_reply,chapters[0].choices[3].outcome);
assert.deepEqual(s.clues,[]);await assert.rejects(cmd(0,'choice',{index:0}),/CHOICE_ALREADY_MADE/);
await cmd(0,'advance');
// Every chapter and option round-trip from SQL without corrupting saved history.
const seeded=(await db.query('select chapter_id,beats from public.campaign_dialogues order by chapter_id')).rows;
assert.deepEqual(seeded.map(d=>d.beats),novelChapters.map(c=>c.beats));
// Force RNG only in isolated test DB. Check successful and failed authored branches.
const savedDice=(await db.query("select pg_get_functiondef('public.campaign_v41_dice_core(bigint,text,integer,text,integer,boolean)'::regprocedure) src")).rows[0].src;
for(const success of [true,false]){
 await db.exec(`create or replace function public.campaign_v41_dice_core(p_player bigint,p_skill text,p_dc integer,p_mode text default 'normal',p_bonus integer default 0,p_save boolean default false) returns jsonb language sql as $$select jsonb_build_object('success',${success},'die',${success?20:1},'total',${success?25:1},'skill',$2,'dc',$3,'bonus',$5)$$`);
 const chapter=novelChapters.find(c=>c.beats[0].options.some(o=>o.skill));const ix=chapter.beats[0].options.findIndex(o=>o.skill);const option=chapter.beats[0].options[ix];
 await db.query("update game_states set state=state||jsonb_build_object('chapter',$2::int,'dialogue',null,'combat',null,'chosen_chapter',-1) where room_code=$1",[room,chapter.id]);
 await cmd(0,'dialogue',{choice:ix});s=(await snap()).state;
 assert.equal(s.dialogue.history[0].reply,success?option.reply:option.failure);assert.equal(s.last_roll.success,success);
 assert.equal(s.last_roll.actor_id,(await snap()).me);assert(s.dialogue.history[0].reaction);
}
await db.exec(savedDice);
await db.query("update game_states set state=state||jsonb_build_object('chapter',0,'dialogue',jsonb_build_object('chapter',0,'step',3,'history','[]'::jsonb),'combat',jsonb_build_object('hp',4),'chosen_chapter',-1) where room_code=$1",[room]);
await assert.rejects(cmd(0,'choice',{index:2}),/COMBAT_ACTIVE/);
await db.query("update game_states set state=state||jsonb_build_object('dialogue',null) where room_code=$1",[room]);
await assert.rejects(cmd(0,'dialogue',{choice:0}),/COMBAT_ACTIVE/);
for(const [index,ending] of [[2,'限期监督改革'],[3,'各区共同新约']]){
 await db.query("update game_states set state=state||jsonb_build_object('chapter',28,'dialogue',jsonb_build_object('chapter',28,'step',3,'history','[]'::jsonb),'combat',null,'chosen_chapter',-1,'flags','[]'::jsonb,'final_victory',true) where room_code=$1",[room]);
 await cmd(0,'choice',{index});
 await db.query("update game_states set state=state||jsonb_build_object('chapter',29,'dialogue',jsonb_build_object('chapter',29,'step',3,'history','[]'::jsonb),'chosen_chapter',-1) where room_code=$1",[room]);
 await cmd(0,'choice',{index:2});s=(await snap()).state;assert.equal(s.ending,ending);
}
const outsider=ids[1];await db.query("select set_config('app.uid',$1,false)",[outsider]);
await db.exec('set local role authenticated');
await assert.rejects(db.query("select public.campaign_novel_dialogue(1,'{}','{}',0)"),/permission denied/);
await db.exec('rollback');await db.close();console.log('v50 novel campaign: 30 chapters / 462 dialogue options / 120 decisions; multiplayer, authored dice branches, optional clues, four outcomes, combat guards, permissions, idempotence passed');
