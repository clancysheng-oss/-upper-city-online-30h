-- Reset encounter-limited resources on an explicit paid wipe recovery.
-- Ongoing battles and durable non-combat check records are preserved.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure);
 if position('encounter_retry_count' in definition)=0 then
  if position($anchor$v_log:='队伍败退并重整：$anchor$ in definition)=0 then raise exception 'RETRY_PATCH_TARGET_MISSING'; end if;
  definition:=replace(definition,$anchor$v_log:='队伍败退并重整：$anchor$,$patch$v_combat:=jsonb_set(jsonb_set(v_combat,'{racial_uses}','{}'::jsonb),'{wards}','{}'::jsonb);
  v_combat:=jsonb_set(v_combat,'{environment}',coalesce((select jsonb_agg(jsonb_set(e.value,'{used}','false'::jsonb) order by e.ord) from jsonb_array_elements(coalesce(v_combat->'environment','[]'::jsonb)) with ordinality e(value,ord)),'[]'::jsonb));
  v_combat:=v_combat||jsonb_build_object('encounter_retry_count',coalesce((v_combat->>'encounter_retry_count')::integer,0)+1);
  v_state:=jsonb_set(v_state,'{combat}',v_combat);
  v_log:='队伍败退并重整：$patch$);
  execute definition;
 end if;
end $$;

-- Solo side quests keep every authored enemy, but adjust HP and damage to one action per round.
-- Joining/leaving mid-fight never changes enemy stats; an explicit restart can recalculate.
create or replace function public.campaign_v413_sidequest_size() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare prior jsonb:=old.state->'combat'; combat jsonb:=new.state->'combat'; count_members integer; foes jsonb:='[]'::jsonb; foe jsonb; max_health integer;
begin
 if combat is null or combat='null'::jsonb or combat->>'side_quest' is null or coalesce((combat->>'hp')::integer,0)<=0 then return new; end if;
 if coalesce((prior->>'hp')::integer,0)>0 and coalesce((combat->>'encounter_retry_count')::integer,0)<=coalesce((prior->>'encounter_retry_count')::integer,0) then return new; end if;
 if combat ? 'sidequest_party_size' then return new; end if;
 select count(*) into count_members from public.players p where p.room_code=new.room_code and p.hp>0 and p.death_failures<3 and
 (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds')) and
 not coalesce(combat->'refusing','[]'::jsonb) @> jsonb_build_array(p.id);
 if count_members=1 then
  for foe in select value from jsonb_array_elements(combat->'enemies') loop
   max_health:=greatest(1,ceil((foe->>'max_hp')::integer*0.35)::integer);
   foe:=foe||jsonb_build_object('hp',max_health,'max_hp',max_health,'damage_min',greatest(1,ceil((foe->>'damage_min')::integer*0.4)::integer),'damage_die',greatest(1,ceil((foe->>'damage_die')::integer*0.4)::integer));
   foes:=foes||jsonb_build_array(foe);
  end loop;
  combat:=combat||jsonb_build_object('enemies',foes,'hp',public.campaign_enemy_hp(foes),'max_hp',public.campaign_enemy_hp(foes));
 end if;
 new.state:=jsonb_set(new.state,'{combat}',combat||jsonb_build_object('sidequest_party_size',count_members));
 return new;
end $$;
revoke all on function public.campaign_v413_sidequest_size() from public,anon,authenticated;
drop trigger if exists campaign_v413_sidequest_size on public.game_states;
create trigger campaign_v413_sidequest_size before update of state on public.game_states for each row execute function public.campaign_v413_sidequest_size();
