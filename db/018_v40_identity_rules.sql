-- V4.0 character identity and shared dice foundation. Existing characters keep null race
-- until their owner makes the one-time choice; no saved world state is rewritten.
alter table public.players add column if not exists race text;
alter table public.players add column if not exists ancestry text;
alter table public.players add column if not exists build jsonb not null default '{"feats":[],"choices":[],"pending":[]}'::jsonb;
alter table public.players add column if not exists conditions jsonb not null default '{}'::jsonb;
alter table public.players add column if not exists wanted integer not null default 0;
alter table public.players add column if not exists reputation jsonb not null default '{"hall":0,"guard":0,"gond":0,"merchant":0,"underground":0}'::jsonb;
alter table public.players add constraint players_v40_race_check check (race is null or race in ('龙裔','提夫林','人类','矮人','精灵')) not valid;
alter table public.players add constraint players_v40_ancestry_check check (ancestry is null or ancestry in ('火焰','闪电','寒冷','毒素','酸液')) not valid;
alter table public.players add constraint players_v40_wanted_check check (wanted between 0 and 5) not valid;

create or replace function public.campaign_v4_proficiency(p_level integer)
returns integer language sql immutable set search_path=public,pg_temp as $$
 select least(6,2+(greatest(1,p_level)-1)/4)
$$;

create or replace function public.campaign_v4_check(
 p_player bigint,p_skill text,p_dc integer,p_mode text default 'normal',p_bonus integer default 0,p_save boolean default false
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_actor public.players%rowtype; v_stat integer; v_modifier integer; v_prof integer:=0; v_racial integer:=0;
 v_one integer; v_two integer; v_die integer; v_total integer; v_success boolean; v_mode text;
begin
 select * into v_actor from public.players where id=p_player;
 if not found then raise exception 'INVALID_ACTOR'; end if;
 if p_skill not in ('力量','敏捷','体质','智力','感知','魅力','运动','潜行','巧手','调查','奥秘','洞悉','察觉','求生','说服','欺骗','威吓','表演','历史','自然','宗教','医药') then raise exception 'INVALID_SKILL'; end if;
 if p_mode not in ('normal','advantage','disadvantage') then raise exception 'INVALID_MODE'; end if;
 if p_dc not between 5 and 30 or p_bonus not between -10 and 10 then raise exception 'INVALID_DC_OR_BONUS'; end if;
 v_stat:=case p_skill when '力量' then 0 when '运动' then 0
  when '敏捷' then 1 when '潜行' then 1 when '巧手' then 1
  when '体质' then 2 when '智力' then 3 when '调查' then 3 when '奥秘' then 3 when '历史' then 3 when '自然' then 3 when '宗教' then 3
  when '感知' then 4 when '洞悉' then 4 when '察觉' then 4 when '求生' then 4 when '医药' then 4 else 5 end;
 v_modifier:=floor(((v_actor.stats->>v_stat)::integer-10)/2.0)::integer;
 if p_save then
  if (v_actor.class_name in ('战士','圣武士') and v_stat in (0,2))
    or (v_actor.class_name='游荡者' and v_stat in (1,3))
    or (v_actor.class_name='法师' and v_stat in (3,4))
    or (v_actor.class_name='牧师' and v_stat in (4,5))
    or (v_actor.class_name='游侠' and v_stat in (0,1))
    or (v_actor.class_name='吟游诗人' and v_stat in (1,5)) then v_prof:=public.campaign_v4_proficiency(v_actor.level); end if;
 else
  if (v_actor.class_name='战士' and p_skill='运动')
   or (v_actor.class_name='游荡者' and p_skill in ('调查','潜行','巧手'))
   or (v_actor.class_name='法师' and p_skill in ('奥秘','调查'))
   or (v_actor.class_name='牧师' and p_skill in ('洞悉','医药'))
   or (v_actor.class_name='游侠' and p_skill in ('求生','察觉'))
   or (v_actor.class_name='吟游诗人' and p_skill in ('说服','表演'))
   or (v_actor.class_name='圣武士' and p_skill in ('运动','说服')) then v_prof:=public.campaign_v4_proficiency(v_actor.level); end if;
 end if;
 if v_actor.race='人类' and v_prof=0 then v_racial:=1; end if;
 if v_actor.race='精灵' and p_skill='察觉' then v_racial:=v_racial+2; end if;
 if v_actor.race='矮人' and p_skill in ('历史','调查') then v_racial:=v_racial+1; end if;
 if v_actor.race='提夫林' and p_skill in ('奥秘','欺骗') then v_racial:=v_racial+1; end if;
 if v_actor.build->'feats' ? '技能专家' and p_skill in ('调查','察觉','说服','潜行') then v_racial:=v_racial+2; end if;
 if v_actor.build->'feats' ? '迅捷步伐' and p_skill in ('运动','潜行') then v_racial:=v_racial+2; end if;
 if v_actor.build->'feats' ? '专注大师' and p_save and p_skill='体质' and v_actor.conditions ? 'concentrating' then v_racial:=v_racial+2; end if;
 v_mode:=p_mode;
 if v_actor.race='矮人' and p_save and p_skill='体质' and v_actor.conditions ? 'poisoned' then v_mode:='advantage'; end if;
 if v_actor.race='精灵' and p_save and p_skill='感知' and v_actor.conditions ? 'charmed' then v_mode:='advantage'; end if;
 if v_actor.conditions ? 'disadvantage' then v_mode:='disadvantage'; end if;
 v_one:=floor(random()*20)::integer+1;
 v_two:=case when v_mode='normal' then null else floor(random()*20)::integer+1 end;
 v_die:=case v_mode when 'advantage' then greatest(v_one,v_two) when 'disadvantage' then least(v_one,v_two) else v_one end;
 v_total:=v_die+v_modifier+v_prof+v_racial+p_bonus;
 v_success:=v_die=20 or (v_die<>1 and v_total>=p_dc);
 return jsonb_build_object('skill',p_skill,'save',p_save,'mode',v_mode,'d20',v_die,'dice',jsonb_build_array(v_one,v_two),'attribute',v_modifier,'proficiency',v_prof,'other',v_racial+p_bonus,'total',v_total,'dc',p_dc,'success',v_success,'natural',case when v_die in (1,20) then v_die else null end);
end $$;
revoke all on function public.campaign_v4_check(bigint,text,integer,text,integer,boolean) from public,anon,authenticated;

-- Preserve the V3.1 online-only snapshot and append identity fields per visible character.
alter function public.party_snapshot(text) rename to party_snapshot_v40_core;
revoke all on function public.party_snapshot_v40_core(text) from public,anon,authenticated;
create or replace function public.party_snapshot(p_code text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_base jsonb; v_players jsonb;
begin
 v_base:=public.party_snapshot_v40_core(p_code);
 select coalesce(jsonb_agg(e.value||jsonb_build_object('race',p.race,'ancestry',p.ancestry,'build',p.build,'conditions',p.conditions,'wanted',p.wanted,'reputation',p.reputation) order by e.ord),'[]'::jsonb)
 into v_players from jsonb_array_elements(v_base->'players') with ordinality e(value,ord)
 join public.players p on p.id=(e.value->>'id')::bigint;
 return jsonb_set(v_base,'{players}',v_players);
end $$;
revoke all on function public.party_snapshot(text) from public,anon,authenticated;
grant execute on function public.party_snapshot(text) to authenticated;

-- This RPC owns V4 identity; the client never writes player columns directly.
create or replace function public.party_v4_identity(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_actor public.players%rowtype; v_race text; v_ancestry text; v_skill text; v_dc integer; v_mode text; v_result jsonb; v_log text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 if not found then raise exception 'NOT_MEMBER'; end if;
 if not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if p_action='race' then
  if v_actor.race is not null then raise exception 'RACE_ALREADY_CHOSEN'; end if;
  v_race:=p_payload->>'race';v_ancestry:=p_payload->>'ancestry';
  if v_race not in ('龙裔','提夫林','人类','矮人','精灵') or (v_race='龙裔' and v_ancestry not in ('火焰','闪电','寒冷','毒素','酸液')) then raise exception 'INVALID_RACE'; end if;
  update public.players set race=v_race,ancestry=case when v_race='龙裔' then v_ancestry else null end,
   max_hp=max_hp+case when v_race='矮人' then 3 else 0 end,
   hp=hp+case when v_race='矮人' then 3 else 0 end where id=v_actor.id;
  v_log:=v_actor.name||'选择种族：'||v_race||case when v_race='龙裔' then '（'||v_ancestry||'）' else '' end;
 elsif p_action='check' then
  v_skill:=p_payload->>'skill';v_dc:=coalesce((p_payload->>'dc')::integer,15);v_mode:=coalesce(p_payload->>'mode','normal');
  v_result:=public.campaign_v4_check(v_actor.id,v_skill,v_dc,v_mode,0,coalesce((p_payload->>'save')::boolean,false))||jsonb_build_object('at',clock_timestamp(),'actor',v_actor.name);
  update public.game_states set state=jsonb_set(state,'{last_roll}',v_result) where room_code=v_code;
  v_log:=v_actor.name||' · '||v_skill||' D20='||(v_result->>'d20')||' + 属性 '||(v_result->>'attribute')||' + 熟练 '||(v_result->>'proficiency')||' + 其他 '||(v_result->>'other')||' = '||(v_result->>'total')||' / DC '||v_dc||'：'||case when (v_result->>'success')::boolean then '成功' else '失败' end;
 else raise exception 'INVALID_V4_ACTION'; end if;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'v4');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_identity(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_v4_identity(text,text,jsonb) to authenticated;
