-- Replace the prior turn resolver in place; player attacks/spells keep their existing path.
create or replace function public.campaign_finish_turn_v40_core(p_code text,p_combat jsonb,p_actor bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_combat jsonb:=p_combat; v_ord bigint; v_next bigint; v_foe jsonb; v_target public.players%rowtype;
 v_roll integer; v_dmg integer; v_log text:=''; v_ward integer; v_kind text; v_save jsonb; v_phase integer; v_concentration boolean;
begin
 if public.campaign_enemy_hp(v_combat->'enemies')=0 then
  update public.players set gold=gold+12+coalesce((select (state->>'chapter')::integer/5 from public.game_states where room_code=p_code),0)*3
   where room_code=p_code and user_id is not null;
  return jsonb_build_object('combat',v_combat,'log','；敌方全灭，队员获得战利品金币');
 end if;
 select ord into v_ord from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) where (item->>'id')::bigint=p_actor;
 select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord)
 join public.players p on p.id=(item->>'id')::bigint where e.ord>v_ord and p.hp>0 and p.death_failures<3
 and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord limit 1;
 if v_next is null then
  v_phase:=coalesce((v_combat->>'final_phase')::integer,0);
  for v_foe in select value from jsonb_array_elements(v_combat->'enemies') where (value->>'hp')::integer>0 loop
   select * into v_target from public.players p where room_code=p_code and
    (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'))
    and hp>0 and death_failures<3 and not coalesce(v_combat->'refusing','[]'::jsonb) @> jsonb_build_array(id)
    order by case
      when v_phase=3 then p.hp::numeric/greatest(1,p.max_hp)
      when v_phase=2 and (v_foe->>'special') like '齐射%' then case when p.class_name in ('法师','牧师','吟游诗人') or p.conditions ? 'concentrating' then 0 else 1 end
      when (v_foe->>'special') like '齐射%' then p.ac
      else random()*20 end,p.id limit 1;
   exit when not found;
   v_roll:=floor(random()*20)::integer+1;
   v_ward:=coalesce((v_combat->'wards'->>v_target.id::text)::integer,0);
   if v_roll=20 or (v_roll<>1 and v_roll+(v_foe->>'attack_bonus')::integer>=v_target.ac+v_ward) then
    v_dmg:=floor(random()*(v_foe->>'damage_die')::integer)::integer+(v_foe->>'damage_min')::integer;
    v_kind:=case when (v_foe->>'special') like '火油%' or (v_foe->>'special') like '投火%' then '火焰'
     when (v_foe->>'special') like '毒%' then '毒素' when (v_foe->>'special') like '闪电%' then '闪电' else '物理' end;
    if v_kind='火焰' then v_dmg:=v_dmg+2; end if;
    if v_kind=v_target.ancestry and v_target.race='龙裔' or v_kind='火焰' and v_target.race='提夫林' or v_kind='毒素' and v_target.race='矮人' then
     v_dmg:=ceil(v_dmg/2.0)::integer;
    end if;
    if v_target.conditions ? 'resistant' then v_dmg:=ceil(v_dmg/2.0)::integer; end if;
    if v_target.conditions ? 'vulnerable' then v_dmg:=v_dmg*2; end if;
    if v_target.conditions ? ('immune_'||v_kind) then v_dmg:=0; end if;
    update public.players set hp=greatest(0,hp-v_dmg) where id=v_target.id;
    v_log:=v_log||'；'||(v_foe->>'name')||case when v_foe ? 'special' then '〔'||(v_foe->>'special')||'〕' else '' end||'攻击'||v_target.name||' D20='||v_roll||'，'||v_kind||'伤害 '||v_dmg;
    if v_target.conditions ? 'concentrating' and v_dmg>0 then
     v_save:=public.campaign_v4_check(v_target.id,'体质',greatest(10,ceil(v_dmg/2.0)::integer),'normal',0,true);
     if not (v_save->>'success')::boolean then
      update public.players set conditions=conditions-'concentrating' where id=v_target.id;
      v_log:=v_log||'；专注豁免失败，效果中断';
     else v_log:=v_log||'；专注豁免成功'; end if;
    end if;
   else v_log:=v_log||'；'||(v_foe->>'name')||' D20='||v_roll||'，未命中'; end if;
   v_combat:=jsonb_set(v_combat,'{wards}',coalesce(v_combat->'wards','{}'::jsonb)-v_target.id::text);
  end loop;
  select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord)
   join public.players p on p.id=(item->>'id')::bigint where p.hp>0 and p.death_failures<3
   and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord limit 1;
  v_combat:=jsonb_set(v_combat,'{round}',to_jsonb((v_combat->>'round')::integer+1));
 end if;
 v_combat:=jsonb_set(v_combat,'{turn}',coalesce(to_jsonb(v_next),'null'::jsonb));
 if v_next is null then v_log:=v_log||'；队伍全员倒地。房主可以重整队伍并重试本场战斗'; end if;
 return jsonb_build_object('combat',v_combat,'log',v_log);
end $$;
