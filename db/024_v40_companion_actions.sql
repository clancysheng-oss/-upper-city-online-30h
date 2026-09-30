-- The second companion acts in the same initiative/enemy state as all party members.
create or replace function public.party_v4_companion(p_code text,p_companion bigint,p_action text,p_target bigint default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); v_actor public.players%rowtype; v_comp public.players%rowtype; v_ally public.players%rowtype;
 v_state jsonb; v_combat jsonb; v_foe jsonb; v_index integer; v_roll integer; v_bonus integer; v_damage integer; v_hp integer; v_result jsonb; v_log text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid();
 if not found or not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if v_actor.conditions ? 'jailed' then raise exception 'JAILED'; end if;
 select * into v_comp from public.players where id=p_companion and room_code=v_code and is_companion and name='亚岚·铜脉' for update;
 if not found then raise exception 'INVALID_COMPANION'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 v_combat:=v_state->'combat';
 if v_combat is null or coalesce((v_combat->>'hp')::integer,0)<=0 or (v_combat->>'turn')::bigint<>v_comp.id then raise exception 'NOT_COMPANION_TURN'; end if;
 if v_comp.hp<=0 or v_comp.death_failures>=3 or coalesce(v_combat->'refusing','[]'::jsonb) @> jsonb_build_array(v_comp.id) then raise exception 'COMPANION_UNAVAILABLE'; end if;
 if p_action='prayer' then
  if v_comp.ability_charges<1 then raise exception 'NO_ABILITY_CHARGES'; end if;
  select * into v_ally from public.players where id=p_target and room_code=v_code and (is_companion or (user_id is not null and is_online));
  if not found or v_ally.death_failures>=3 then raise exception 'INVALID_TARGET'; end if;
  v_hp:=least(v_ally.max_hp,v_ally.hp+8+v_comp.level+floor(random()*6)::integer+1);
  update public.players set hp=v_hp,death_failures=0,death_successes=0 where id=v_ally.id;
  update public.players set ability_charges=ability_charges-1 where id=v_comp.id;
  v_log:=v_comp.name||'吟诵战地祈祷：'||v_ally.name||'恢复 '||(v_hp-v_ally.hp)||' HP。';
 elsif p_action in ('attack','shock') then
  if p_target is null then raise exception 'INVALID_ENEMY'; end if;
  v_index:=public.campaign_enemy_index(v_combat->'enemies',p_target);
  v_foe:=v_combat->'enemies'->v_index;
  if p_action='shock' then
   if v_comp.ability_charges<1 then raise exception 'NO_ABILITY_CHARGES'; end if;
   update public.players set ability_charges=ability_charges-1 where id=v_comp.id;
  end if;
  v_roll:=floor(random()*20)::integer+1;
  v_bonus:=floor(((v_comp.stats->>4)::integer-10)/2.0)::integer+public.campaign_v4_proficiency(v_comp.level)+case when p_action='shock' then 1 else 0 end;
  v_damage:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_foe->>'ac')::integer) then 0 else floor(random()*8)::integer+1+v_bonus+case when p_action='shock' then 8 else 2 end+case when v_roll=20 then floor(random()*8)::integer+1 else 0 end end;
  v_combat:=jsonb_set(v_combat,array['enemies',v_index::text,'hp'],to_jsonb(greatest(0,(v_foe->>'hp')::integer-v_damage)));
  v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
  v_log:=v_comp.name||case when p_action='shock' then '释放符文震击' else '挥动炉心战锤' end||' → '||(v_foe->>'name')||' D20='||v_roll||'，伤害 '||v_damage||'。';
 else raise exception 'INVALID_COMPANION_ACTION'; end if;
 v_result:=public.campaign_finish_turn(v_code,v_combat,v_comp.id);
 v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::integer,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_comp.name,v_log||coalesce(v_result->>'log',''),'companion_skill');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_companion(text,bigint,text,bigint) from public,anon,authenticated;
grant execute on function public.party_v4_companion(text,bigint,text,bigint) to authenticated;
