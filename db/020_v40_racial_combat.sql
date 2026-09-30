-- Racial actions join the existing encounter and turn engine.
create or replace function public.party_v4_racial(p_code text,p_action text,p_target integer default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_actor public.players%rowtype; v_state jsonb; v_combat jsonb;
 v_foe jsonb; v_result jsonb; v_log text; v_index integer; v_roll integer; v_dc integer; v_damage integer; v_total integer:=0;
 v_element text; v_die integer; v_uses jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 if not found or not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 v_combat:=v_state->'combat';
 if v_actor.conditions ? 'jailed' then raise exception 'JAILED'; end if;
 if v_combat is null or coalesce((v_combat->>'hp')::integer,0)<=0 then raise exception 'NO_COMBAT'; end if;
 if (v_combat->>'turn')::bigint<>v_actor.id or v_actor.hp<=0 or v_actor.death_failures>=3 then raise exception 'NOT_YOUR_TURN'; end if;
 v_uses:=coalesce(v_combat->'racial_uses','{}'::jsonb);
 if v_uses ? v_actor.id::text then raise exception 'RACIAL_ABILITY_USED'; end if;
 if p_action='breath' and v_actor.race='龙裔' then
  v_element:=v_actor.ancestry;
  if v_element not in ('火焰','闪电','寒冷','毒素','酸液') then raise exception 'INVALID_ANCESTRY'; end if;
  v_dc:=8+public.campaign_v4_proficiency(v_actor.level)+floor(((v_actor.stats->>2)::integer-10)/2.0)::integer;
  v_log:=v_actor.name||'喷吐'||v_element||'龙息（DEX 豁免 DC '||v_dc||'）：';
  for v_index in 0..jsonb_array_length(v_combat->'enemies')-1 loop
   v_foe:=v_combat->'enemies'->v_index;
   if (v_foe->>'hp')::integer>0 then
    v_roll:=floor(random()*20)::integer+1;
    v_die:=floor(random()*6)::integer+1+floor(random()*6)::integer+1+greatest(0,(v_actor.level-1)/4)*2;
    v_damage:=case when v_roll+greatest(0,((v_foe->>'attack_bonus')::integer-2)/2)>=v_dc then v_die/2 else v_die end;
    if coalesce(v_foe->'resistances' ? v_element,false) then v_damage:=v_damage/2; end if;
    if coalesce(v_foe->'immunities' ? v_element,false) then v_damage:=0; end if;
    v_combat:=jsonb_set(v_combat,array['enemies',v_index::text,'hp'],to_jsonb(greatest(0,(v_foe->>'hp')::integer-v_damage)));
    v_log:=v_log||' '||(v_foe->>'name')||' D20='||v_roll||'，伤害 '||v_damage||'；';
    v_total:=v_total+v_damage;
   end if;
  end loop;
 elsif p_action='infernal' and v_actor.race='提夫林' and v_actor.level>=3 then
  v_index:=public.campaign_enemy_index(v_combat->'enemies',-p_target-1);
  v_foe:=v_combat->'enemies'->v_index;
  v_roll:=floor(random()*20)::integer+1;
  v_dc:=floor(((v_actor.stats->>5)::integer-10)/2.0)::integer+public.campaign_v4_proficiency(v_actor.level);
  v_damage:=case when v_roll=1 or (v_roll<>20 and v_roll+v_dc<(v_foe->>'ac')::integer) then 0
    else floor(random()*8)::integer+1+floor(random()*8)::integer+1+v_actor.level/4+case when v_roll=20 then 8 else 0 end end;
  if coalesce(v_foe->'resistances' ? '火焰',false) then v_damage:=v_damage/2; end if;
  if coalesce(v_foe->'immunities' ? '火焰',false) then v_damage:=0; end if;
  v_combat:=jsonb_set(v_combat,array['enemies',v_index::text,'hp'],to_jsonb(greatest(0,(v_foe->>'hp')::integer-v_damage)));
  v_log:=v_actor.name||'释放地狱烈焰 → '||(v_foe->>'name')||' D20='||v_roll||'，伤害 '||v_damage;
 else raise exception 'RACIAL_ACTION_UNAVAILABLE'; end if;
 v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
 v_combat:=jsonb_set(v_combat,'{racial_uses}',v_uses||jsonb_build_object(v_actor.id::text,true));
 v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);
 v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::integer,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log||coalesce(v_result->>'log',''),'power');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_racial(text,text,integer) from public,anon,authenticated;
grant execute on function public.party_v4_racial(text,text,integer) to authenticated;
