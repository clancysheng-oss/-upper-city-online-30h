import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
const src=fs.readFileSync('db/002_secure_campaign.sql','utf8').replace('create extension if not exists pgcrypto;','');
const old=fs.readFileSync('supabase.sql','utf8');
const upgrade=fs.readFileSync('upgrade.sql','utf8');
await db.exec(old);await db.exec(upgrade);await db.exec(src);await db.exec(fs.readFileSync('db/003_encounters.sql','utf8'));await db.exec(fs.readFileSync('db/004_campaign_battles.sql','utf8'));await db.exec(fs.readFileSync('db/005_classes_spells.sql','utf8'));
const ids=['00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003'];
async function act(i,code,action,payload={}){await db.query('select set_config($1,$2,false)',['app.uid',ids[i]]);const {rows}=await db.query('select public.party_command($1,$2,$3::jsonb) as result',[code,action,JSON.stringify(payload)]);return rows[0].result}
async function power(i,code,id,target=null,slot=0){await db.query('select set_config($1,$2,false)',['app.uid',ids[i]]);const {rows}=await db.query('select public.party_power($1,$2,$3,$4) as result',[code,id,target,slot]);return rows[0].result}
function ok(cond,why){if(!cond)throw Error(why);console.log('OK',why)}
const a=await act(0,'','create',{name:'Aldren',class:'战士'}),code=a.room;
ok(code.length===5&&a.players[0].is_host,'host creation and five-character code');
const b=await act(1,code,'join',{name:'Bria',class:'牧师'});
ok(b.players.length===2&&b.players.some(p=>p.name==='Bria'),'separate identity joins');
try{await act(1,code,'start');throw Error('NON_HOST_STARTED')}catch(e){ok(String(e.message).includes('HOST_ONLY'),'non-host start rejected')}
await act(0,code,'ready');await act(1,code,'ready');const started=await act(0,code,'start');ok(started.state.started,'both ready and host starts');
const rolled=await act(1,code,'roll',{skill:'洞悉',bonus:10,dc:15});ok(rolled.messages.some(m=>m.body.includes('D20=')&&m.body.includes('加值 5')),'server computes roll bonus from character');
try{await act(0,code,'choice',{index:0});throw Error('CHOICE_WITHOUT_INVESTIGATION')}catch(e){ok(String(e.message).includes('EXPLORE_BEFORE_CHOICE'),'investigation gates story choice')}
const explored=await act(1,code,'explore',{index:0,skill:'说服',dc:5,flag:'forged'});ok(explored.state.explored.includes('0:0')&&explored.messages.some(m=>m.body.includes('核对夜间车册')&&m.body.includes('调查')&&m.body.includes('DC 12')),'authored encounter and server-owned check');
try{await act(1,code,'explore',{index:0});throw Error('REPEAT_EXPLORE')}catch(e){ok(String(e.message).includes('ALREADY_EXPLORED'),'encounter cannot be farmed')}
await act(0,code,'explore',{index:1});
await act(0,code,'choice',{index:0,flag:'forged',clue:'fake'});const check=await act(1,code,'heartbeat');ok(check.state.flags.includes('ash')&&!check.state.flags.includes('forged'),'server rejects forged choice effects');
try{await act(1,code,'advance');throw Error('NON_HOST_ADVANCED')}catch(e){ok(String(e.message).includes('HOST_ONLY'),'non-host advance rejected')}
const catalog=await db.query('select chapter_id,details from public.campaign_battles order by chapter_id');
ok(catalog.rows.length===10&&catalog.rows.every(r=>r.details.hp>0&&r.details.die>0),'ten original server-owned battles');
for(let i=0;i<17;i++){
 if(i>0&&catalog.rows.some(r=>r.chapter_id===i)){
  if(i===2){
   const first=await act(1,code,'heartbeat');
   ok(first.state.combat.name==='雨瓦追猎者'&&first.state.combat.max_hp===14,'earlier clue weakens first battle');
   try{await act(0,code,'advance');throw Error('SKIPPED_FIGHT')}catch(e){ok(String(e.message).includes('COMBAT_ACTIVE'),'active battle blocks advancement')}
   const who=first.state.combat.turn===first.me?1:0;
   const fought=await act(who,code,'attack');ok(fought.state.combat.round>=1&&fought.messages.some(m=>m.body.includes('攻击 D20=')),'battle attack uses server dice');
  }
  // Set up the next chapter without depending on random combat outcomes in this progression test.
  await db.query("update public.game_states set state=jsonb_set(state,'{combat,hp}','0'::jsonb) where room_code=$1",[code]);
 }
 await act(0,code,'advance');await act(0,code,'explore',{index:0});await act(1,code,'explore',{index:1});await act(0,code,'choice',{index:0});
}const combat=await act(1,code,'heartbeat');ok(combat.state.chapter===17&&combat.state.combat.hp===35&&combat.state.combat.initiative.length===2,'combat and initiative synchronize');
const actor=combat.state.combat.turn===combat.me?1:0;await act(actor,code,'attack');const fresh=await act(1,code,'heartbeat');ok(fresh.state.version>combat.state.version,'attack persists for refreshed player');
await db.exec('set role authenticated');
try{await db.query('update public.players set is_host=true where name=$1',['Bria']);throw Error('DIRECT_WRITE_ALLOWED')}catch(e){ok(String(e.message).includes('permission denied'),'direct table writes denied')}
await db.exec('reset role');
const beforeShop=await act(1,code,'heartbeat');const bought=await act(1,code,'buy',{item:'治疗药水'});ok(bought.players.find(p=>p.id===bought.me).gold===beforeShop.players.find(p=>p.id===beforeShop.me).gold-10,'shop deducts gold');
try{await act(2,code,'heartbeat');throw Error('UNAUTHORIZED_JOIN')}catch(e){ok(String(e.message).includes('NOT_MEMBER'),'outsider cannot read room')}
await act(0,code,'leave');const succession=await act(1,code,'heartbeat');ok(succession.players.find(p=>p.id===succession.me).is_host,'host departure transfers ownership');
const pal=await act(0,'','create',{name:'Seren',class:'圣武士'}),palCode=pal.room;
const wiz=await act(1,palCode,'join',{name:'Iriel',class:'法师'});
ok(pal.players[0].ac===16&&pal.players[0].level===1&&wiz.players.length===2,'paladin creation, independent wizard and level 1 character cards');
await act(0,palCode,'ready');await act(1,palCode,'ready');await act(0,palCode,'start');
try{await power(1,palCode,'rest');throw Error('REST_NOT_HOST')}catch(e){ok(String(e.message).includes('HOST_ONLY'),'only host can long rest')}
try{await power(0,palCode,'wizard_1',null,1);throw Error('FOREIGN_CLASS')}catch(e){ok(String(e.message).includes('POWER_NOT_KNOWN'),'cannot invoke another class spell')}
try{await power(0,palCode,'paladin_6',null,6);throw Error('EARLY_SPELL')}catch(e){ok(String(e.message).includes('SPELL_CIRCLE_LOCKED'),'circle 6 is gated by level')}
const helped=await power(0,palCode,'paladin_hands',wiz.me);
ok(helped.players.find(p=>p.id===helped.me).ability_charges===1,'class skill consumes a server-owned charge');
await power(0,palCode,'rest');
try{await power(0,palCode,'rest');throw Error('DOUBLE_REST')}catch(e){ok(String(e.message).includes('ALREADY_RESTED'),'long rest cannot be repeated in a chapter')}
for(let i=0;i<26;i++){
 if(i>0&&catalog.rows.some(r=>r.chapter_id===i))await db.query("update public.game_states set state=jsonb_set(state,'{combat,hp}','0'::jsonb) where room_code=$1",[palCode]);
 await act(0,palCode,'explore',{index:0});await act(1,palCode,'explore',{index:1});await act(0,palCode,'choice',{index:0});await act(0,palCode,'advance');
}
const high=await act(1,palCode,'heartbeat');ok(high.players.every(p=>p.level===11&&p.spell_slots[6]===1),'chapter milestones unlock circle 6 and refresh resources');
const active=high.state.combat;ok(active.hp>0,'late battle active');
const caster=active.turn===high.me?1:0,spell=caster===0?'paladin_6':'wizard_6';
const cast=await power(caster,palCode,spell,null,6);
ok(cast.players.find(p=>p.id===cast.me).spell_slots[6]===0&&cast.messages.some(m=>m.kind==='power'&&m.body.includes('D20=')),'circle 6 spell consumes one slot and rolls on server');
try{await power(caster,palCode,spell,null,6);throw Error('DUPLICATE_CAST')}catch(e){ok(/NO_SPELL_SLOT|NOT_YOUR_TURN/.test(String(e.message)),'cannot reuse a spent circle 6 slot or steal a turn')}
try{await power(2,palCode,'paladin_hands');throw Error('OUTSIDER_POWER')}catch(e){ok(String(e.message).includes('NOT_MEMBER'),'outsider cannot invoke party powers')}
console.log('FLOW PASS',code);
