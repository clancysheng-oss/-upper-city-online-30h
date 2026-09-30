import fs from 'node:fs';
import {identityRoutes} from '../src/dialogue-v4.js';
if(identityRoutes.length<12)throw Error('Insufficient authored class/race/faction dialogue');
const q=value=>`'${String(value).replaceAll("'","''")}'`;
let sql=`-- Character identity opens additional branches in the existing regional NPCs.
create table if not exists public.uc_v4_routes(id text primary key,area text not null references public.uc_areas(id),npc text not null references public.uc_npcs(id),required_race text,required_class text,required_faction text,minimum integer not null default 0,label text not null,reply text not null,clue text not null,benefit_faction text,skill text not null,dc integer not null);
alter table public.uc_v4_routes enable row level security;
revoke all on public.uc_v4_routes from public,anon,authenticated;
`;
for(const r of identityRoutes){sql+=`insert into public.uc_v4_routes values(${q(r.id)},${q(r.area)},${q(r.npc)},${r.race?q(r.race):'null'},${r.profession?q(r.profession):'null'},${r.minimum?q(r.faction):'null'},${r.minimum||0},${q(r.label)},${q(r.reply)},${q(r.clue)},${r.faction?q(r.faction):'null'},${q(r.skill)},${r.dc}) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;\n`}
sql+=`
create or replace function public.party_v4_dialogue(p_code text,p_route text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); v_actor public.players%rowtype; v_route public.uc_v4_routes%rowtype;
 v_state jsonb; v_result jsonb; v_key text; v_log text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 if not found or not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if v_actor.conditions ? 'jailed' then raise exception 'JAILED'; end if;
 select * into v_route from public.uc_v4_routes where id=p_route;
 if not found then raise exception 'INVALID_ROUTE'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) or v_state->>'current_area'<>v_route.area
  or (v_state->>'chapter')::integer<(select unlock_chapter from public.uc_areas where id=v_route.area)
  or coalesce((v_state#>>'{combat,hp}')::integer,0)>0 or coalesce((v_state->>'v4_camp')::boolean,false) then raise exception 'NPC_UNAVAILABLE'; end if;
 if v_route.required_race is not null and v_actor.race<>v_route.required_race
  or v_route.required_class is not null and v_actor.class_name<>v_route.required_class
  or v_route.required_faction is not null and coalesce((v_actor.reputation->>v_route.required_faction)::integer,0)<v_route.minimum then raise exception 'ROUTE_REQUIREMENT'; end if;
 v_key:=v_actor.id::text||':'||v_route.id;
 if coalesce(v_state->'v4_dialogue','{}'::jsonb) ? v_route.id then raise exception 'ROUTE_RESOLVED'; end if;
 if coalesce(v_state->'v4_dialogue_attempts','{}'::jsonb) ? v_key then raise exception 'ROUTE_ATTEMPTED'; end if;
 v_result:=public.campaign_v4_check(v_actor.id,v_route.skill,v_route.dc,'normal',0,false)||jsonb_build_object('at',clock_timestamp(),'actor',v_actor.name);
 v_state:=jsonb_set(v_state,'{last_roll}',v_result,true);
 v_state:=jsonb_set(v_state,'{v4_dialogue_attempts}',coalesce(v_state->'v4_dialogue_attempts','{}'::jsonb)||jsonb_build_object(v_key,true),true);
 if (v_result->>'success')::boolean then
  v_state:=jsonb_set(v_state,'{v4_dialogue}',coalesce(v_state->'v4_dialogue','{}'::jsonb)||jsonb_build_object(v_route.id,true),true);
  if not coalesce(v_state->'clues','[]'::jsonb) ? v_route.clue then
   v_state:=jsonb_set(v_state,'{clues}',coalesce(v_state->'clues','[]'::jsonb)||to_jsonb(v_route.clue),true);
  end if;
  v_state:=jsonb_set(v_state,'{area_attitudes}',jsonb_set(coalesce(v_state->'area_attitudes','{}'::jsonb),array[v_route.npc],to_jsonb(least(5,coalesce((v_state->'area_attitudes'->>v_route.npc)::integer,0)+1)),true),true);
  if v_route.benefit_faction is not null then
   update public.players set reputation=jsonb_set(reputation,array[v_route.benefit_faction],to_jsonb(least(100,coalesce((reputation->>v_route.benefit_faction)::integer,0)+4))) where id=v_actor.id;
  end if;
  v_log:=v_route.reply||' 获得线索：'||v_route.clue;
 else v_log:=v_actor.name||'尝试'||v_route.skill||'（DC '||v_route.dc||'），对方暂时不愿交出这条线索。'; end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::integer,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,(select name from public.uc_npcs where id=v_route.npc),v_log,'v4');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_dialogue(text,text) from public,anon,authenticated;
grant execute on function public.party_v4_dialogue(text,text) to authenticated;
`;
fs.writeFileSync('db/027_v40_identity_dialogue.sql',sql);
console.log('Built V4 dialogue migration',identityRoutes.length,sql.length);
