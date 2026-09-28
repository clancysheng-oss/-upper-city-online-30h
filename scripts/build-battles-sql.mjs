import fs from 'node:fs';
import {battles} from '../src/battles.js';

const source=fs.readFileSync(new URL('../db/002_secure_campaign.sql',import.meta.url),'utf8');
let fn=source.slice(source.indexOf('create or replace function public.party_command('),source.indexOf('create or replace function public.party_character('));
function replace(needle,replacement){if(!fn.includes(needle))throw Error(`SQL source changed: ${needle.slice(0,60)}`);fn=fn.replace(needle,replacement)}
replace('v_scene jsonb; v_key text; v_skill text;','v_scene jsonb; v_key text; v_skill text; v_enemy jsonb; v_aid boolean;');
const begin=fn.indexOf('  if v_idx in (17,28) then');
const end=fn.indexOf('  if v_idx=29 then',begin);
if(begin<0||end<0)throw Error('Cannot find encounter initialization');
fn=fn.slice(0,begin)+`  -- A completed fight grants a camp rest before the next scene. Downed allies need healing first.
  if coalesce((v_state#>>'{combat,hp}')::int,-1)=0 then
   update public.players set hp=max_hp where room_code=v_code and user_id is not null and hp>0;
  end if;
  select details into v_enemy from public.campaign_battles where chapter_id=v_idx;
  if v_enemy is not null then
   select count(*) into v_players from public.players where room_code=v_code and user_id is not null;
   v_aid:=coalesce(v_state->'flags','[]'::jsonb) ? (v_enemy->>'aid');
   v_enemy_hp:=(v_enemy->>'hp')::int+greatest(0,v_players-2)*7-case when v_aid then 5 else 0 end;
   select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1] into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and user_id is not null and hp>0) i;
   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_enemy->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_enemy->>'attack')::int,'damage_min',(v_enemy->>'min')::int,'damage_die',(v_enemy->>'die')::int,'turn',v_turn,'initiative',v_init,'round',1));
  else v_state:=jsonb_set(v_state,'{combat}','null'::jsonb); end if;
`+fn.slice(end);
replace("v_log:='推进至第 '||(v_idx+1)||' 章。'||case when v_idx%5=0 then ' 队员各获 10 金币。' else '' end;", "v_log:='推进至第 '||(v_idx+1)||' 章。'||case when v_idx%5=0 then ' 队员各获 10 金币。' else '' end||case when v_enemy is not null then ' 遭遇：'||(v_enemy->>'name')||'。'||case when v_aid then v_enemy->>'aidText' else '' end else '' end;");
replace("if v_roll=20 or (v_roll<>1 and v_roll+4>=v_ac) then", "if v_roll=20 or (v_roll<>1 and v_roll+coalesce((v_combat->>'attack_bonus')::int,4)>=v_ac) then");
replace('v_dmg:=floor(random()*6)::int+3;',"v_dmg:=floor(random()*coalesce((v_combat->>'damage_die')::int,6))::int+coalesce((v_combat->>'damage_min')::int,3);");
replace("else v_log:=v_log||'；敌人倒下'; end if;", "else update public.players set gold=gold+5 where room_code=v_code and user_id is not null; v_log:=v_log||'；敌人倒下，队员各获得 5 金币'; end if;");
const rows=battles.map(({art,...b})=>`(${b.chapter},'${JSON.stringify(b).replaceAll("'","''")}')`).join(',\n');
const sql=`-- Authored combat catalog. Existing rooms retain their active fight; later chapters use this catalog.
create table if not exists public.campaign_battles (chapter_id integer primary key references public.campaign_chapters(id), details jsonb not null);
alter table public.campaign_battles enable row level security;
revoke all on public.campaign_battles from public,anon,authenticated;
insert into public.campaign_battles(chapter_id,details) values\n${rows}\non conflict(chapter_id) do update set details=excluded.details;

${fn}revoke all on function public.party_command(text,text,jsonb) from public,anon;
grant execute on function public.party_command(text,text,jsonb) to authenticated;
revoke all on function public.party_notify() from public,anon,authenticated;
`;
fs.writeFileSync(new URL('../db/004_campaign_battles.sql',import.meta.url),sql);
console.log(`Generated ${battles.length} battles and secured command function`);
