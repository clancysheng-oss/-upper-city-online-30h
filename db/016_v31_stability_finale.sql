-- V3.1: Durable characters and live party presence stay separate.
alter table public.players add column if not exists is_online boolean not null default false;
update public.players set is_online=(user_id is not null and last_seen>now()-interval '90 seconds') where not is_companion;
create index if not exists players_live_room_idx on public.players(room_code,last_seen) where user_id is not null and is_online;

create or replace function public.party_v31_next_turn(p_code text,p_actor bigint) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_state jsonb; v_combat jsonb; v_next bigint;
begin
 if p_actor is null then return; end if;
 select state into v_state from public.game_states where room_code=p_code for update;
 v_combat:=v_state->'combat';
 if coalesce((v_combat->>'hp')::int,0)<=0 or coalesce((v_combat->>'turn')::bigint,-1)<>p_actor then return; end if;
 select p.id into v_next from jsonb_array_elements(coalesce(v_combat->'initiative','[]'::jsonb)) with ordinality e(value,ord)
 join public.players p on p.id=(e.value->>'id')::bigint where p.room_code=p_code and p.hp>0 and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds'))
 order by e.ord limit 1;
 update public.game_states set state=jsonb_set(v_state,'{combat,turn}',coalesce(to_jsonb(v_next),'null'::jsonb)) where room_code=p_code;
end $$;

create or replace function public.campaign_finish_turn(p_code text,p_combat jsonb,p_actor bigint) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_combat jsonb:=p_combat; v_ord bigint; v_next bigint; v_foe jsonb; v_target public.players%rowtype; v_roll int; v_dmg int; v_log text:=''; v_ward int;
begin
 if public.campaign_enemy_hp(v_combat->'enemies')=0 then
  update public.players set gold=gold+12+coalesce((select (state->>'chapter')::int/5 from public.game_states where room_code=p_code),0)*3 where room_code=p_code and user_id is not null;
  return jsonb_build_object('combat',v_combat,'log','；敌方全灭，队员获得战利品金币');
 end if;
 select ord into v_ord from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) where (item->>'id')::bigint=p_actor;
 select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) join public.players p on p.id=(item->>'id')::bigint where e.ord>v_ord and p.hp>0 and p.death_failures<3 and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord limit 1;
 if v_next is null then
  for v_foe in select value from jsonb_array_elements(v_combat->'enemies') where (value->>'hp')::int>0 loop
   select * into v_target from public.players where room_code=p_code and (is_companion or (user_id is not null and is_online and last_seen>=now()-interval '90 seconds')) and hp>0 and death_failures<3 and not coalesce(v_combat->'refusing','[]'::jsonb) @> jsonb_build_array(id) order by case when (v_foe->>'special') like '齐射%' then ac else floor(random()*20)::int end limit 1;
   exit when not found;
   v_roll:=floor(random()*20)::int+1;
   v_ward:=coalesce((v_combat->'wards'->>v_target.id::text)::int,0);
   if v_roll=20 or (v_roll<>1 and v_roll+(v_foe->>'attack_bonus')::int>=v_target.ac+v_ward) then
    v_dmg:=floor(random()*(v_foe->>'damage_die')::int)::int+(v_foe->>'damage_min')::int+case when (v_foe->>'special') like '火油%' or (v_foe->>'special') like '投火%' then 2 else 0 end;
    update public.players set hp=greatest(0,hp-v_dmg) where id=v_target.id;
    v_log:=v_log||'；'||(v_foe->>'name')||case when v_foe ? 'special' then '〔'||(v_foe->>'special')||'〕' else '' end||'攻击'||v_target.name||'，伤害 '||v_dmg;
   else v_log:=v_log||'；'||(v_foe->>'name')||'未命中'; end if;
   v_combat:=jsonb_set(v_combat,'{wards}',coalesce(v_combat->'wards','{}'::jsonb)-v_target.id::text);
  end loop;
  select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) join public.players p on p.id=(item->>'id')::bigint where p.hp>0 and p.death_failures<3 and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord limit 1;
  v_combat:=jsonb_set(v_combat,'{round}',to_jsonb((v_combat->>'round')::int+1));
 end if;
 v_combat:=jsonb_set(v_combat,'{turn}',coalesce(to_jsonb(v_next),'null'::jsonb));
 if v_next is null then v_log:=v_log||'；队伍全员倒地。房主可以重整队伍并重试本场战斗'; end if;
 return jsonb_build_object('combat',v_combat,'log',v_log);
end $$;

create or replace function public.party_snapshot(p_code text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid();
begin
 if v_uid is null or not exists(select 1 from public.players where room_code=v_code and user_id=v_uid) then raise exception 'NOT_MEMBER'; end if;
 perform public.party_v31_next_turn(v_code,(select (state#>>'{combat,turn}')::bigint from public.game_states where room_code=v_code and exists(select 1 from public.players p where p.id=(state#>>'{combat,turn}')::bigint and (not p.is_online or p.last_seen<now()-interval '90 seconds'))));
 update public.players set is_online=false,is_ready=false where room_code=v_code and user_id is not null and is_online and last_seen<now()-interval '90 seconds';
 select jsonb_build_object('room',r.code,
  'players',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'class_name',p.class_name,'is_host',p.is_host,'is_ready',p.is_ready,'hp',p.hp,'max_hp',p.max_hp,'ac',p.ac,'stats',p.stats,'inventory',p.inventory,'equipment',p.equipment,'gold',p.gold,'death_failures',p.death_failures,'death_successes',p.death_successes,'last_seen',p.last_seen,'level',p.level,'spell_slots',p.spell_slots,'ability_charges',p.ability_charges,'is_companion',p.is_companion,'experience',p.experience) order by p.created_at,p.id) from public.players p where p.room_code=r.code and (p.is_companion or p.user_id=v_uid or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'))),'[]'::jsonb),
  'me',(select p.id from public.players p where p.room_code=r.code and p.user_id=v_uid),
  'state',coalesce(g.state,'{}'::jsonb),
  'messages',coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from (select id,sender,body,kind,created_at from public.messages where room_code=r.code order by id desc limit 100) m),'[]'::jsonb)) into result
 from public.rooms r left join public.game_states g on g.room_code=r.code where r.code=v_code;
 return result;
end $$;

-- The existing battle and story functions remain in place; intercept room lifecycle only.
alter function public.party_command(text,text,jsonb) rename to party_command_v30_core;
revoke all on function public.party_command_v30_core(text,text,jsonb) from public,anon,authenticated;
create or replace function public.party_command(p_code text,p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid(); v_actor public.players%rowtype; v_result jsonb; v_owner uuid; v_state jsonb; v_next bigint; v_combat jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_action='create' then
  v_result:=public.party_command_v30_core(p_code,p_action,p_payload);
  update public.players set is_online=true,last_seen=now() where id=(v_result->>'me')::bigint;
  return public.party_snapshot(v_result->>'room');
 end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=v_uid for update;
 if p_action='join' then
  if v_actor.id is not null then
   update public.players set is_online=true,last_seen=now() where id=v_actor.id;
   return public.party_snapshot(v_code);
  end if;
  if (select count(*) from public.players where room_code=v_code and user_id is not null and is_online and last_seen>=now()-interval '90 seconds')>=5 then raise exception 'ROOM_FULL'; end if;
  if length(trim(coalesce(p_payload->>'name','')))<2 or p_payload->>'class' not in ('战士','游荡者','法师','牧师','游侠','吟游诗人','圣武士') then raise exception 'INVALID_CHARACTER'; end if;
  if exists(select 1 from public.game_states where room_code=v_code and (state->>'started')::boolean) and not exists(select 1 from public.save_slots where room_code=v_code) then raise exception 'GAME_STARTED'; end if;
  perform public.party_character(v_code,v_uid,left(trim(p_payload->>'name'),32),p_payload->>'class',false);
  update public.players set is_online=true,last_seen=now() where room_code=v_code and user_id=v_uid;
  return public.party_snapshot(v_code);
 end if;
 if v_actor.id is null then raise exception 'NOT_MEMBER'; end if;
 if p_action='leave' then
  update public.players set is_online=false,is_ready=false,last_seen=now()-interval '91 seconds' where id=v_actor.id;
  perform public.party_v31_next_turn(v_code,v_actor.id);
  insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_actor.name||'已离开队伍。','player_left');
  if not exists(select 1 from public.save_slots where room_code=v_code) then
   update public.players set is_host=false where id=v_actor.id;
   if v_actor.is_host then update public.players set is_host=true,is_ready=false where id=(select id from public.players where room_code=v_code and user_id is not null and is_online order by created_at,id limit 1); end if;
  end if;
  return jsonb_build_object('left',true);
 end if;
 if p_action='heartbeat' then
  update public.players set is_online=true,last_seen=now() where id=v_actor.id;
  update public.save_slots set play_seconds=play_seconds+least(60,greatest(0,extract(epoch from now()-last_active_at)::integer)),last_active_at=now() where room_code=v_code and owner_id=v_uid;
  return public.party_snapshot(v_code);
 end if;
 if not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if p_action='claim_host' then
  if exists(select 1 from public.save_slots where room_code=v_code) then raise exception 'SAVE_OWNER_ONLY'; end if;
  if not exists(select 1 from public.players where room_code=v_code and is_host and is_online and last_seen>=now()-interval '90 seconds') then
   update public.players set is_host=false where room_code=v_code;
   update public.players set is_host=true,is_ready=false where id=(select id from public.players where room_code=v_code and user_id is not null and is_online and last_seen>=now()-interval '90 seconds' order by created_at,id limit 1);
  end if;
  return public.party_snapshot(v_code);
 end if;
 if p_action='start' then
  if not v_actor.is_host then raise exception 'HOST_ONLY'; end if;
  select state into v_state from public.game_states where room_code=v_code for update;
  if coalesce((v_state->>'started')::boolean,false) then raise exception 'ALREADY_STARTED'; end if;
  select count(*) into v_next from public.players where room_code=v_code and user_id is not null and is_online and last_seen>=now()-interval '90 seconds';
  if v_next<(case when exists(select 1 from public.save_slots where room_code=v_code) then 1 else 2 end) or v_next>5 or exists(select 1 from public.players where room_code=v_code and user_id is not null and is_online and last_seen>=now()-interval '90 seconds' and not is_ready) then raise exception 'PARTY_NOT_READY'; end if;
  update public.game_states set state=jsonb_set(v_state,'{started}','true'::jsonb) where room_code=v_code;
  insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,'冒险开始。','start');
  return public.party_snapshot(v_code);
 end if;
 v_result:=public.party_command_v30_core(p_code,p_action,p_payload);
 if p_action='advance' then
  select state into v_state from public.game_states where room_code=v_code for update;
  v_combat:=v_state->'combat';
  if v_combat is not null and v_combat<>'null'::jsonb and coalesce((v_combat->>'hp')::int,0)>0 then
   v_combat:=jsonb_set(v_combat,'{initiative}',coalesce((select jsonb_agg(entry.value order by entry.ord) from jsonb_array_elements(v_combat->'initiative') with ordinality entry(value,ord) join public.players p on p.id=(entry.value->>'id')::bigint where p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')),'[]'::jsonb));
   if not exists(select 1 from jsonb_array_elements(v_combat->'initiative') e where (e->>'id')::bigint=coalesce((v_combat->>'turn')::bigint,-1)) then v_combat:=jsonb_set(v_combat,'{turn}',coalesce(v_combat#>'{initiative,0,id}','null'::jsonb)); end if;
   update public.game_states set state=jsonb_set(v_state,'{combat}',v_combat) where room_code=v_code;
  end if;
  return public.party_snapshot(v_code);
 end if;
 return v_result;
end $$;
revoke all on function public.party_command(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_command(text,text,jsonb) to authenticated;

create or replace function public.party_v31_assert_online(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not exists(select 1 from public.players where room_code=upper(trim(coalesce(p_code,''))) and user_id=auth.uid() and is_online and last_seen>=now()-interval '90 seconds') then raise exception 'RECONNECT_FIRST'; end if;
end $$;
revoke all on function public.party_v31_assert_online(text) from public,anon,authenticated;
alter function public.party_power(text,text,bigint,integer) rename to party_power_v30_core;
alter function public.party_deep(text,text,jsonb) rename to party_deep_v30_core;
alter function public.party_area(text,text,jsonb) rename to party_area_v30_core;
alter function public.party_region(text,text) rename to party_region_v30_core;
revoke all on function public.party_power_v30_core(text,text,bigint,integer),public.party_deep_v30_core(text,text,jsonb),public.party_area_v30_core(text,text,jsonb),public.party_region_v30_core(text,text) from public,anon,authenticated;
create or replace function public.party_power(p_code text,p_id text,p_target bigint default null,p_slot integer default 0) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);return public.party_power_v30_core(p_code,p_id,p_target,p_slot);end $$;
create or replace function public.party_deep(p_code text,p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);return public.party_deep_v30_core(p_code,p_action,p_payload);end $$;
create or replace function public.party_area(p_code text,p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);return public.party_area_v30_core(p_code,p_action,p_payload);end $$;
create or replace function public.party_region(p_code text,p_area text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);return public.party_region_v30_core(p_code,p_area);end $$;
revoke all on function public.party_power(text,text,bigint,integer),public.party_deep(text,text,jsonb),public.party_area(text,text,jsonb),public.party_region(text,text) from public,anon,authenticated;
grant execute on function public.party_power(text,text,bigint,integer),public.party_deep(text,text,jsonb),public.party_area(text,text,jsonb),public.party_region(text,text) to authenticated;

-- Owner-only deletion by slot and room; all room-bound rows cascade through rooms(code).
create or replace function public.party_delete_slot(p_slot integer) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_code text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_slot not between 1 and 3 then raise exception 'INVALID_SLOT'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text,22));
 select room_code into v_code from public.save_slots where owner_id=v_uid and slot=p_slot for update;
 if v_code is null then raise exception 'EMPTY_SLOT'; end if;
 perform 1 from public.rooms where code=v_code for update;
 delete from public.rooms where code=v_code;
 return jsonb_build_object('deleted_slot',p_slot,'room',v_code);
end $$;
revoke all on function public.party_delete_slot(integer) from public,anon,authenticated;
grant execute on function public.party_delete_slot(integer) to authenticated;

-- A separate RPC reconnects the owner without reloading saved snapshots over live progress.
create or replace function public.party_enter_slot(p_slot integer) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_code text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_slot not between 1 and 3 then raise exception 'INVALID_SLOT'; end if;
 select room_code into v_code from public.save_slots where owner_id=v_uid and slot=p_slot;
 if v_code is null then raise exception 'EMPTY_SLOT'; end if;
 perform 1 from public.rooms where code=v_code for update;
 update public.players set is_host=(user_id=v_uid),is_online=case when user_id=v_uid then true else is_online end,last_seen=case when user_id=v_uid then now() else last_seen end where room_code=v_code and user_id is not null;
 update public.save_slots set last_active_at=now() where owner_id=v_uid and slot=p_slot;
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_enter_slot(integer) from public,anon,authenticated;
grant execute on function public.party_enter_slot(integer) to authenticated;

create or replace function public.party_v31_slots() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('slot',s.slot,'room',s.room_code,'saved_at',s.saved_at,'play_seconds',s.play_seconds,'chapter',coalesce((g.state->>'chapter')::int,0),'area',coalesce((select a.name from public.uc_areas a where a.id=g.state->>'current_area'),'上城区'),'name',p.name,'class_name',p.class_name,'level',p.level,'completed',coalesce((g.state->>'campaign_complete')::boolean,false)) order by s.slot)
  from public.save_slots s join public.game_states g on g.room_code=s.room_code join public.players p on p.room_code=s.room_code and p.user_id=v_uid and not p.is_companion where s.owner_id=v_uid),'[]'::jsonb);
end $$;
revoke all on function public.party_v31_slots() from public,anon,authenticated;
grant execute on function public.party_v31_slots() to authenticated;

create or replace function public.party_v31_state() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_party jsonb;
begin
 if coalesce((new.state->>'chapter')::int,-1)=28 and coalesce((old.state#>>'{combat,hp}')::int,-1)>0 and coalesce((new.state#>>'{combat,hp}')::int,-1)=0 and not (new.state ? 'final_victory') then
  select coalesce(jsonb_agg(p.name order by p.created_at,p.id),'[]'::jsonb) into v_party from public.players p where p.room_code=new.room_code and (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'));
  new.state:=jsonb_set(new.state,'{final_victory}',jsonb_build_object('at',now(),'party',v_party,'boss','议会雇佣兵首领'));
 end if;
 if coalesce((new.state->>'chapter')::int,-1)=29 and (new.state->>'ending') is not null and coalesce((new.state->>'chosen_chapter')::int,-1)=29 and not coalesce((new.state->>'campaign_complete')::boolean,false) then
  if not (new.state ? 'final_victory') then raise exception 'FINAL_BATTLE_REQUIRED'; end if;
  select coalesce(jsonb_agg(p.name order by p.created_at,p.id),'[]'::jsonb) into v_party from public.players p where p.room_code=new.room_code and (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'));
  new.state:=new.state||jsonb_build_object('campaign_complete',true,'final_party',v_party,'final_play_seconds',coalesce((select play_seconds from public.save_slots where room_code=new.room_code),0),'completed_quests',coalesce(new.state->'completed_quests','[]'::jsonb)||'29'::jsonb);
 end if;
 return new;
end $$;
drop trigger if exists party_v31_state_sync on public.game_states;
create trigger party_v31_state_sync before update of state on public.game_states for each row execute function public.party_v31_state();

create or replace function public.party_v31_checkpoint() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if coalesce((new.state->>'campaign_complete')::boolean,false) and not coalesce((old.state->>'campaign_complete')::boolean,false) then
  update public.save_slots set saved_state=new.state,saved_players=coalesce((select jsonb_agg(to_jsonb(p)) from public.players p where p.room_code=new.room_code),'[]'::jsonb),saved_at=now() where room_code=new.room_code;
 end if;
 return null;
end $$;
drop trigger if exists party_v31_checkpoint_sync on public.game_states;
create trigger party_v31_checkpoint_sync after update of state on public.game_states for each row execute function public.party_v31_checkpoint();

create or replace function public.party_v31_explore(p_code text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_state jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.players where room_code=v_code and user_id=auth.uid() and is_online and last_seen>=now()-interval '90 seconds') then raise exception 'NOT_ONLINE'; end if;
 perform 1 from public.rooms where code=v_code for update;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'campaign_complete')::boolean,false) then raise exception 'CAMPAIGN_NOT_COMPLETE'; end if;
 update public.game_states set state=jsonb_set(v_state,'{postgame}','true'::jsonb) where room_code=v_code;
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v31_explore(text) from public,anon,authenticated;
grant execute on function public.party_v31_explore(text) to authenticated;

-- Saves from before V3.1 which already finished the epilogue resume in free exploration.
update public.game_states g set state=g.state||jsonb_build_object('final_victory',jsonb_build_object('at',now(),'party',coalesce((select jsonb_agg(p.name order by p.created_at,p.id) from public.players p where p.room_code=g.room_code and p.user_id is not null),'[]'::jsonb),'boss','议会雇佣兵首领'),'final_party',coalesce((select jsonb_agg(p.name order by p.created_at,p.id) from public.players p where p.room_code=g.room_code and p.user_id is not null),'[]'::jsonb),'campaign_complete',true,'postgame',true,'final_play_seconds',coalesce((select s.play_seconds from public.save_slots s where s.room_code=g.room_code),0))
where coalesce((g.state->>'chapter')::int,-1)=29 and g.state->>'ending' is not null and coalesce((g.state#>>'{combat,hp}')::int,-1)=0 and not coalesce((g.state->>'campaign_complete')::boolean,false);
