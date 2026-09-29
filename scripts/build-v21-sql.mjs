import fs from 'node:fs';
import {dialogues} from '../src/dialogues.js';
const source=fs.readFileSync('db/007_upper_city_areas.sql','utf8');
function fn(name){const start=source.indexOf(`create or replace function public.${name}(`);const end=source.indexOf('end $$;',start)+7;if(start<0||end<7)throw Error(name);return source.slice(start,end)}
function replaceOnce(s,old,updated){if(!s.includes(old))throw Error('Missing SQL segment: '+old.slice(0,70));return s.replace(old,updated)}
let finish=fn('campaign_finish_turn');
finish=replaceOnce(finish,"if v_next is null then v_log:=v_log||'；队伍全员倒地'; end if;","if v_next is null then v_log:=v_log||'；队伍全员倒地。房主可以重整队伍并重试本场战斗'; end if;");
let command=fn('party_command');
command=replaceOnce(command,"elsif p_action='attack' then",`elsif p_action='retry' then
  if not v_host then raise exception 'HOST_ONLY'; end if;
  v_combat:=v_state->'combat';
  if v_combat is null or v_combat='null'::jsonb or coalesce((v_combat->>'hp')::int,0)<=0 or v_combat->>'turn' is not null then raise exception 'NOT_DEFEATED'; end if;
  if exists(select 1 from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0) then raise exception 'PARTY_STILL_STANDING'; end if;
  update public.players set hp=greatest(1,ceil(max_hp/2.0)::int),death_failures=0,death_successes=0,
    spell_slots=public.campaign_slots(level),ability_charges=2,gold=greatest(0,gold-10)
    where room_code=v_code and (user_id is not null or is_companion);
  select jsonb_agg(jsonb_set(e.value,'{hp}',e.value->'max_hp') order by e.ord) into v_enemies
    from jsonb_array_elements(v_combat->'enemies') with ordinality e(value,ord);
  v_combat:=jsonb_set(jsonb_set(v_combat,'{enemies}',v_enemies),'{hp}',to_jsonb(public.campaign_enemy_hp(v_enemies)));
  select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1]
    into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0) i;
  v_combat:=jsonb_set(jsonb_set(jsonb_set(v_combat,'{initiative}',v_init),'{turn}',to_jsonb(v_turn)),'{round}','1'::jsonb);
  v_state:=jsonb_set(v_state,'{combat}',v_combat);
  v_log:='队伍败退并重整：全员恢复半数生命与战斗资源，每名玩家最多损失 10 金币；本场战斗重新开始。';
 elsif p_action='attack' then`);
command=replaceOnce(command,"   v_log:=v_scene->>'success';\n  else v_log:=v_scene->>'failure'; end if;", "   v_log:=v_scene->>'success';\n  else v_log:=v_scene->>'failure'; end if;\n  v_state:=jsonb_set(v_state,'{exploration_history}',coalesce(v_state->'exploration_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('chapter',(v_state->>'chapter')::int,'label',v_scene->>'label','result',v_log,'clue',case when v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then v_scene->>'clue' else null end)));");
command=replaceOnce(command,"if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_id)); end if;\n  elsif v_roll=1", "if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb and exists(select 1 from public.players where room_code=v_code and hp>0 and id<>v_id) then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_id)); end if;\n  elsif v_roll=1");
let power=fn('party_power');
power=replaceOnce(power,"   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then\n     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);\n     v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');\n     v_log:=v_log||coalesce(v_result->>'log','');\n   end if;", "   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then\n     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);\n     v_combat:=v_result->'combat';\n     v_log:=v_log||coalesce(v_result->>'log','');\n   elsif v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int=0 and v_power.kind='damage' then\n     update public.players set gold=gold+12+coalesce((v_state->>'chapter')::int/5,0)*3 where room_code=v_code and user_id is not null;\n     v_log:=v_log||'；敌方全灭，队员获得战利品金币';\n   end if;\n   if v_combat is not null and v_combat<>'null'::jsonb then v_state:=jsonb_set(v_state,'{combat}',v_combat); end if;");
const q=s=>`'${String(s).replaceAll("'","''")}'`;
let sql='-- Upper City 2.1: shared combat resolution, wipe recovery and authored chapter dialogue.\n'+finish+'\n'+command+'\n'+power+'\n';
sql+='insert into public.campaign_dialogues(chapter_id,speaker,role,beats) values\n'+dialogues.map(d=>`(${d.chapter},${q(d.name)},${q(d.role)},${q(JSON.stringify(d.beats))}::jsonb)`).join(',\n')+'\non conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;\n';
sql+='revoke all on function public.campaign_finish_turn(text,jsonb,bigint),public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) from public,anon,authenticated;\n';
sql+='grant execute on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) to authenticated;\n';
fs.writeFileSync('db/008_v21_combat_story.sql',sql);
console.log(`Built db/008_v21_combat_story.sql (${sql.length} bytes)`);
