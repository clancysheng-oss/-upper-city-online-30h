import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
const migrations=['supabase.sql','upgrade.sql',...['002_secure_campaign','003_encounters','004_campaign_battles','005_classes_spells','006_deeper_campaign','007_upper_city_areas','008_v21_combat_story','009_v21_dialogue_polish','010_v22_save_slots','011_xp_progression','012_v30_story_depth','013_v30_battle_aftermath','014_v30_followup_dialogue','015_v30_encounter_routes','016_v31_stability_finale','017_v31_saved_room_lobby','018_v40_identity_rules','019_v40_world_build','020_v40_racial_combat','021_v40_final_battle','022_v40_rules_bridge','023_v40_companion','024_v40_companion_actions','025_v40_faction_reputation','026_v40_enemy_ai','027_v40_identity_dialogue','028_v40_final_environment_guard','029_v40_completion','030_v40_internal_permissions'].map(name=>`db/${name}.sql`)];
for(const file of migrations)await db.exec(fs.readFileSync(file,'utf8').replace('create extension if not exists pgcrypto;',''));
await db.exec(fs.readFileSync('db/031_v41_action_checks.sql','utf8'));
import {actionCheckKey,itemPrice,canReroll} from '../src/checks.js';
import {checksPanel} from '../src/world-view.js';
import {diceOverlay} from '../src/identity-view.js';
await db.exec(fs.readFileSync('db/032_v41_playtest_fixes.sql','utf8'));
await db.exec(fs.readFileSync('db/033_v41_resume_combat.sql','utf8'));
await db.exec(fs.readFileSync('db/034_v41_pending_evidence_dialogue.sql','utf8'));
await db.exec(fs.readFileSync('db/035_v41_retry_and_solo_sidequests.sql','utf8'));
await db.exec('begin');
const ids=['00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000b2'];
for(const id of ids)await db.query('insert into auth.users(id) values($1)',[id]);
async function as(i,sql,args=[]){await db.query("select set_config('app.uid',$1,false)",[ids[i]]);await db.exec('savepoint rpc');try{const v=(await db.query(sql,args)).rows[0]?.v;await db.exec('release rpc');return v;}catch(error){await db.exec('rollback to rpc;release rpc');throw error;}}
let room;
const command=(i,action,payload={})=>as(i,'select public.party_command($1,$2,$3::jsonb) v',[room,action,JSON.stringify(payload)]);
const world=(i,action,payload={})=>as(i,'select public.party_v4_world($1,$2,$3::jsonb) v',[room,action,JSON.stringify(payload)]);
const identity=(i,action,payload={})=>as(i,'select public.party_v4_identity($1,$2,$3::jsonb) v',[room,action,JSON.stringify(payload)]);
const retry=(i,key,action='reroll')=>as(i,'select public.party_v41_check($1,$2,$3) v',[room,key,action]);
const snapshot=(i=0)=>as(i,'select public.party_snapshot($1) v',[room]);
const a=await as(0,"select public.party_save_slot('create',1,null,'测试诗人','吟游诗人') v");room=a.room;
const b=await command(1,'join',{name:'测试游荡者',class:'游荡者'});
await identity(0,'race',{race:'人类'});await identity(1,'race',{race:'提夫林'});
await command(0,'ready');await command(1,'ready');await command(0,'start');
const mine=d=>d.players.find(p=>p.id===d.me);
async function context(area,chapter=0){await db.query("update public.game_states set state=state||jsonb_build_object('current_area',$2::text,'chapter',$3::integer,'combat',null,'v4_camp',false) where room_code=$1",[room,area,chapter]);}
// Search fixed seeds in a rollback-only test transaction, then retain one reproducible case.
async function outcome(fn,success){
 await db.exec('savepoint candidate');
 for(let n=0;n<100;n++){
  await db.exec('rollback to candidate');await db.query('select setseed($1)',[n/100]);
  const result=await fn();
  if(result.state.last_roll.success===success){await db.exec('release candidate');return result;}
 }
 throw new Error('No deterministic seed found');
}
let failed=await outcome(()=>world(0,'crime',{type:'theft'}),false);
let key=failed.state.last_roll.check_id;
assert.equal(key,'crime:city:theft');assert.equal(failed.state.checks[key].scope,'party');assert.equal(failed.state.checks[key].resolved,false);
assert.equal(mine(failed).wanted,0,'risk is pending until accepted');
await assert.rejects(world(0,'crime',{type:'theft'}),/CHECK_ALREADY_ATTEMPTED/);
await assert.rejects(world(1,'crime',{type:'theft'}),/CHECK_ALREADY_ATTEMPTED/);
await assert.rejects(retry(1,key),/CHECK_OWNER_ONLY/);
await assert.rejects(retry(0,key),/NO_INSPIRATION/);
assert.equal((await snapshot()).state.checks[key].attempts,1);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'test_source']);
let before=await snapshot();assert.equal(mine(before).build.inspiration,1);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'test_source']);assert.equal(mine(await snapshot()).build.inspiration,1);
let rerolled=await outcome(()=>retry(0,key),true);
assert.equal(mine(rerolled).build.inspiration,0);assert.equal(rerolled.state.checks[key].attempts,2);
assert.equal(rerolled.state.checks[key].history.length,2);assert.equal(rerolled.state.checks[key].reroll_used,true);assert.equal(rerolled.state.checks[key].resolved,true);
assert.equal(mine(rerolled).gold,mine(before).gold+8);assert.ok(mine(rerolled).inventory.includes('盾牌'));assert.equal(mine(rerolled).wanted,0);
await assert.rejects(retry(0,key),/REROLL_UNAVAILABLE/);
// Save stores receipts and ledger; leaving, heartbeat reconnect and re-enter preserve locks.
await as(0,"select public.party_save_slot('save',1) v");
const saved=(await db.query('select saved_state,saved_players from save_slots where room_code=$1',[room])).rows[0];
assert.equal(saved.saved_state.checks[key].attempts,2);assert.equal(saved.saved_players.find(p=>p.id===a.me).build.inspiration,0);
await command(0,'leave');await command(0,'heartbeat');await as(0,'select public.party_enter_slot(1) v');
await assert.rejects(world(1,'crime',{type:'theft'}),/CHECK_ALREADY_ATTEMPTED/);
// Failure reroll applies consequences exactly once and consumes only the actor's point.
failed=await outcome(()=>world(0,'crime',{type:'pickpocket'}),false);key=failed.state.last_roll.check_id;
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'test_failure']);
const wanted=mine(await snapshot()).wanted;
rerolled=await outcome(()=>retry(0,key),false);assert.equal(mine(rerolled).wanted,wanted+1);assert.equal(rerolled.state.checks[key].attempts,2);
await retry(0,key,'accept');assert.equal(mine(await snapshot()).wanted,wanted+1);
// Higher DC/high value target and area-specific loot.
await context('wonders');let loot=await outcome(()=>world(1,'crime',{type:'pickpocket'}),true);
assert.equal(loot.state.last_roll.dc,17);assert.ok(mine(loot).inventory.includes('高堂封存柜钥匙'));assert.equal(mine(loot).build.inspiration||0,0);
await world(1,'use_key');let opened=await snapshot(1);assert.equal(opened.state.v41_access.wonders,true);assert.equal(mine(opened).build.inspiration,1);
await assert.rejects(world(1,'use_key'),/KEY_UNAVAILABLE/);
await context('hall',15);loot=await outcome(()=>world(1,'crime',{type:'lockpick'}),true);
assert.equal(loot.state.last_roll.dc,21);assert.ok(mine(loot).inventory.includes('审计官胸针'));assert.ok(loot.state.clues.includes('双印卷宗中的秘密拨款'));
// Social skills produce distinct results, with one shared negotiation per location.
await context('city',0);let social=await outcome(()=>world(0,'social',{choice:'说服'}),true);
assert.equal(social.state.v41_discounts[`${a.me}:city`],15);
await assert.rejects(world(1,'social',{choice:'欺骗'}),/CHECK_ALREADY_ATTEMPTED/);
await db.query('update players set gold=8 where id=$1',[a.me]);let purchase=await command(0,'buy',{item:'治疗药水'});
assert.equal(mine(purchase).gold,0);assert.ok(mine(purchase).inventory.includes('治疗药水'));
assert.equal(itemPrice({price:10,merchant:'gate'},mine(social),social.state),8); // ceil discount is authoritative.
await context('kegs');social=await outcome(()=>world(1,'social',{choice:'欺骗'}),true);
assert.ok(mine(social).inventory.includes('护盾卷轴'));assert.ok(Object.values(social.state.v41_lies).some(l=>l.actor===b.me));
await context('walls',10);const priorGold=mine(await snapshot(1)).gold;
social=await outcome(()=>world(1,'social',{choice:'威吓'}),true);assert.equal(mine(social).gold,priorGold+12);assert.equal(mine(social).reputation.merchant,-8);
// Scarcity, cap and award receipt even when capped.
for(let i=0;i<6;i++)await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,`source_${i}`]);
assert.equal(mine(await snapshot()).build.inspiration,4);assert.equal(mine(await snapshot()).build.inspiration_awards.source_5,true);
// Identity and authored exploration keep their old outcomes and get shared durable locks.
await context('kegs',0);
await db.query("update game_states set state=state||jsonb_build_object('dialogue',jsonb_build_object('chapter',0,'step',3)) where room_code=$1",[room]);
failed=await outcome(()=>command(0,'explore',{index:0}),false);key=failed.state.last_roll.check_id;
assert.equal(key,'chapter:0:explore:0');await assert.rejects(command(1,'explore',{index:0}),/CHECK_ALREADY_ATTEMPTED/);
rerolled=await outcome(()=>retry(0,key),true);assert.ok(rerolled.state.exploration_history.some(h=>h.clue));assert.equal(rerolled.state.checks[key].attempts,2);
// Personal field check cannot be unlocked by changing DC, mode or skill.
let field=await outcome(()=>identity(0,'check',{skill:'调查',dc:5}),true);
assert.equal(field.state.last_roll.dc,14);assert.equal(field.state.checks[field.state.last_roll.check_id].scope,'personal');
await assert.rejects(identity(0,'check',{skill:'历史',dc:30,mode:'advantage'}),/CHECK_ALREADY_ATTEMPTED/);
await identity(1,'check',{skill:'奥秘'}); // Other player gets an independent personal check.
// Guard context has a single personal opportunity; method switching is not a reset.
await db.query('update players set wanted=2 where id=$1',[a.me]);
failed=await outcome(()=>world(0,'guard',{choice:'欺骗'}),false);key=failed.state.last_roll.check_id;
await assert.rejects(world(0,'guard',{choice:'说服'}),/CHECK_ALREADY_ATTEMPTED/);
await retry(0,key,'accept');await world(0,'guard',{choice:'接受逮捕'});
let jailed=await snapshot();assert.equal(mine(jailed).conditions.jailed,true);
failed=await outcome(()=>world(0,'prison',{choice:'撬锁'}),false);key=failed.state.last_roll.check_id;
await assert.rejects(world(0,'prison',{choice:'撬锁'}),/CHECK_ALREADY_ATTEMPTED/);
rerolled=await outcome(()=>retry(0,key),true);assert.equal(mine(rerolled).conditions.jailed,undefined);
// Real identity route failure followed by one Inspiration reroll; core attempt marker is surgical.
await context('kegs',0);
failed=await outcome(()=>as(0,'select public.party_v4_dialogue($1,$2) v',[room,'mara_bard']),false);key=failed.state.last_roll.check_id;
await assert.rejects(as(1,'select public.party_v4_dialogue($1,$2) v',[room,'mara_bard']),/CHECK_ALREADY_ATTEMPTED/);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'identity_test']);
rerolled=await outcome(()=>retry(0,key),true);assert.ok(rerolled.state.v4_dialogue.mara_bard);assert.ok(rerolled.state.clues.includes('酒馆第十三拍'));
assert.ok(mine(rerolled).build.inspiration_awards['identity:mara_bard']);
// Regional inspection and quest failures also lock the whole Party and support one replay.
await context('wonders',0);
failed=await outcome(()=>as(0,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_inspect',JSON.stringify({area:'wonders',place:0})]),false);key=failed.state.last_roll.check_id;
await assert.rejects(as(1,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_inspect',JSON.stringify({area:'wonders',place:0})]),/CHECK_ALREADY_ATTEMPTED/);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'area_test']);
rerolled=await outcome(()=>retry(0,key),true);assert.equal(rerolled.state.checks[key].attempts,2);assert.ok(rerolled.state.area_inspected.includes('wonders:0'));
// Deeper investigation and class route retain authored clue/reputation/combat effects.
await context('city',0);
failed=await outcome(()=>as(0,'select public.party_deep($1,$2,$3::jsonb) v',[room,'inspect','{}']),false);key=failed.state.last_roll.check_id;
await assert.rejects(as(1,'select public.party_deep($1,$2,$3::jsonb) v',[room,'inspect','{}']),/CHECK_ALREADY_ATTEMPTED/);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'deep_test']);
rerolled=await outcome(()=>retry(0,key),true);assert.equal(rerolled.state.checks[key].attempts,2);assert.equal(rerolled.state.deep.explorationFlags['0_secret'],true);
// Secret route is a real one-use bypass, never valid for the finale or side battles.
const encounter={name:'路线验收',hp:20,max_hp:20,round:1,enemies:[{name:'守备员',hp:20,max_hp:20,ac:12,attack_bonus:2,damage_min:1,damage_die:4}],initiative:[{id:a.me,roll:20},{id:b.me,roll:10}],turn:a.me};
await db.query("update game_states set state=jsonb_set(state,'{combat}',$2::jsonb,true) where room_code=$1",[room,JSON.stringify(encounter)]);
let bypass=await world(0,'use_secret');assert.equal(bypass.state.combat,null);assert.equal(bypass.state.deep.combat['0'].combat_skipped,true);assert.equal(Object.values(bypass.state.v41_access_used).includes(true),true);
await db.query("update game_states set state=state||jsonb_build_object('chapter',28,'combat',$2::jsonb) where room_code=$1",[room,JSON.stringify(encounter)]);
await assert.rejects(world(0,'use_secret'),/SECRET_ROUTE_UNAVAILABLE/);
await context('city',0);
// A chapter transition audits previously recorded lies once, with lasting wanted/reputation impact.
await db.query("update game_states set state=state||jsonb_build_object('chosen_chapter',0,'completed_quests',jsonb_build_array(0),'explored',jsonb_build_array('0:0','0:1')) where room_code=$1",[room]);
const lyingActor=mine(await snapshot(1));await command(0,'advance');let audited=await snapshot(1);
assert.equal(audited.state.chapter,1);assert.equal(mine(audited).wanted,Math.min(5,lyingActor.wanted+1));assert.ok(Object.values(audited.state.v41_lies).every(l=>l.exposed));
// Side quest and story sources are only granted on actual transitions.
await context('kegs',0);const q=(await db.query("select id,stages from uc_quests where id='star'")).rows[0];
assert.ok(q);
await context('kegs',0);await as(0,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_quest',JSON.stringify({area:'kegs',quest:'star'})]);await context('wonders',0);
failed=await outcome(()=>as(0,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_quest',JSON.stringify({area:'wonders',quest:'star'})]),false);key=failed.state.last_roll.check_id;
assert.equal(key,'quest:star:0:continue');
await assert.rejects(as(1,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_quest',JSON.stringify({area:'wonders',quest:'star'})]),/CHECK_ALREADY_ATTEMPTED/);
await as(0,'select public.campaign_v41_inspiration($1,$2)',[a.me,'quest_test']);
rerolled=await outcome(()=>retry(0,key),true);assert.equal(rerolled.state.side_quests.star.step,1);assert.equal(rerolled.state.checks[key].attempts,2);
// Complete the authored delivery stage, then verify the one-time party Inspiration receipts.
await context('kegs',0);
await db.query("update game_states set state=state||jsonb_build_object('side_quests',jsonb_build_object('star',jsonb_build_object('step',5,'status','可交付')),'area_dialogue',jsonb_build_array(jsonb_build_object('npc','mara'))) where room_code=$1",[room]);
const delivered=await as(0,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_quest',JSON.stringify({area:'kegs',quest:'star'})]);
assert.equal(delivered.state.side_quests.star.status,'已完成');assert.ok(delivered.players.filter(p=>!p.is_companion).every(p=>p.build.inspiration_awards['side_quest:star']));
await assert.rejects(as(0,'select public.party_area($1,$2,$3::jsonb) v',[room,'area_quest',JSON.stringify({area:'kegs',quest:'star'})]),/QUEST_COMPLETE/);
await context('city',4);
await db.query("update game_states set state=state||jsonb_build_object('dialogue',jsonb_build_object('chapter',4,'step',3),'explored',jsonb_build_array('4:0','4:1'),'chosen_chapter',-1) where room_code=$1",[room]);
const decided=await command(0,'choice',{index:0});assert.equal(mine(decided).build.inspiration_awards['story:4'],true);
await context('kegs',0);
rerolled=await snapshot();
assert.ok(checksPanel(rerolled).includes('Party共享'));assert.ok(diceOverlay(rerolled.state.checks['identity:mara_bard'].result,rerolled.state.checks['identity:mara_bard'],mine(rerolled)).includes('获得线索'));
assert.equal(canReroll(rerolled.state.checks[key],mine(rerolled)),false);
assert.equal(actionCheckKey('v4_world',{kind:'crime',choice:'theft'},rerolled.state,mine(rerolled)),'crime:kegs:theft');
assert.equal((await db.query("select has_function_privilege('anon','public.party_v41_check(text,text,text)','execute') allowed")).rows[0].allowed,false);
assert.equal((await db.query("select has_function_privilege('authenticated','public.campaign_v41_dispatch(text,text,text,jsonb,text)','execute') allowed")).rows[0].allowed,false);

// Real-play regression: mandatory quest failure used to leave a permanently locked stage.
await context('kegs',1);
await db.query("update game_states set state=state||jsonb_build_object('side_quests',jsonb_build_object('star',jsonb_build_object('step',1,'status','进行中')),'area_dialogue',jsonb_build_array(jsonb_build_object('npc','tobin')),'checks','{}'::jsonb) where room_code=$1",[room]);
const area=(i,action,payload)=>as(i,'select public.party_area($1,$2,$3::jsonb) v',[room,action,JSON.stringify(payload)]);
await assert.rejects(area(0,'area_quest_fallback',{area:'kegs',quest:'star'}),/QUEST_FALLBACK_UNAVAILABLE/);
failed=await outcome(()=>area(0,'area_quest',{area:'kegs',quest:'star'}),false);
key=failed.state.last_roll.check_id;
await assert.rejects(area(1,'area_quest_fallback',{area:'kegs',quest:'star'}),/QUEST_FALLBACK_UNAVAILABLE/);
await retry(0,key,'accept');
await db.query('update players set gold=10 where id=$1',[a.me]);
let fallback=await area(1,'area_quest_fallback',{area:'kegs',quest:'star'});
assert.equal(fallback.state.side_quests.star.step,2);
assert.equal(fallback.state.checks[key].result.success,false);
assert.equal(fallback.state.checks[key].attempts,1);
await assert.rejects(area(0,'area_quest_fallback',{area:'kegs',quest:'star'}),/QUEST_FALLBACK_UNAVAILABLE/);
assert.equal((await db.query("select has_function_privilege('authenticated','public.party_area_v412_core(text,text,jsonb)','execute') allowed")).rows[0].allowed,false);


// Actual-play regression: leave during single-player combat, resume with null turn.
await command(1,'leave');
await context('city',2);
await db.query("update game_states set state=jsonb_set(state,'{combat}',jsonb_build_object('hp',12,'round',1,'turn',$2::bigint,'enemies',jsonb_build_array(jsonb_build_object('name','追猎者','hp',12,'max_hp',12,'ac',5,'attack_bonus',0,'damage_min',1,'damage_die',1)),'initiative',jsonb_build_array(jsonb_build_object('id',$2::bigint,'roll',10)))) where room_code=$1",[room,a.me]);
await command(0,'leave');
assert.equal((await db.query("select state#>>'{combat,turn}' turn from game_states where room_code=$1",[room])).rows[0].turn,null);
const reconnected=await command(0,'heartbeat');assert.equal(reconnected.state.combat.turn,a.me);
const attacked=await command(0,'attack',{enemy:0});assert.ok(attacked.messages.some(m=>m.kind==='attack'));

// Regression: explicit wipe recovery resets combat-only uses, never durable checks.
await db.query("update players set hp=0 where room_code=$1",[room]);
await db.query("update game_states set state=jsonb_set(state,'{combat}',jsonb_build_object('hp',100,'max_hp',100,'side_quest','gate','round',4,'turn',null,'enemies',jsonb_build_array(jsonb_build_object('name','伏兵','hp',100,'max_hp',100,'ac',12,'attack_bonus',1,'damage_min',10,'damage_die',10)),'environment',jsonb_build_array(jsonb_build_object('name','火药桶','kind','blast','amount',8,'used',true)),'racial_uses',jsonb_build_object($2::text,true),'wards',jsonb_build_object($2::text,3),'initiative',jsonb_build_array(jsonb_build_object('id',$2::bigint,'roll',10)))) where room_code=$1",[room,a.me]);
const replayed=await command(0,'retry');
assert.equal(replayed.state.combat.environment[0].used,false);
assert.deepEqual(replayed.state.combat.racial_uses,{});
assert.deepEqual(replayed.state.combat.wards,{});
assert.equal(replayed.state.combat.encounter_retry_count,1);
assert.equal(replayed.state.combat.sidequest_party_size,1);
assert.equal(replayed.state.combat.enemies[0].max_hp,35);
assert.equal(replayed.state.combat.enemies[0].damage_min,4);
const unchanged=await command(0,'heartbeat');
assert.equal(unchanged.state.combat.enemies[0].max_hp,35);
assert.deepEqual(unchanged.state.checks,replayed.state.checks);
await db.exec('rollback');await db.close();console.log('V4.1 action rewards, multiplayer locks, Inspiration rerolls, risks, economy and persistence passed');
