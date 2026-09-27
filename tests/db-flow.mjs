import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
const db=new PGlite();
await db.exec("create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$ select current_setting('app.uid',true)::uuid $$;create publication supabase_realtime;create function gen_random_bytes(int) returns bytea language sql as $$ select decode(substr(md5(random()::text),1,$1*2),'hex') $$;");
const src=fs.readFileSync('db/002_secure_campaign.sql','utf8').replace('create extension if not exists pgcrypto;','');
const old=fs.readFileSync('supabase.sql','utf8');
const upgrade=fs.readFileSync('upgrade.sql','utf8');
await db.exec(old);await db.exec(upgrade);await db.exec(src);await db.exec(fs.readFileSync('db/003_encounters.sql','utf8'));await db.exec(fs.readFileSync('db/004_campaign_battles.sql','utf8'));
const ids=['00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003'];
async function act(i,code,action,payload={}){await db.query('select set_config($1,$2,false)',['app.uid',ids[i]]);const {rows}=await db.query('select public.party_command($1,$2,$3::jsonb) as result',[code,action,JSON.stringify(payload)]);return rows[0].result}
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
console.log('FLOW PASS',code);
