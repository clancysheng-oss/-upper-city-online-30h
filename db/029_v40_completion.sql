-- V4 completion: patch existing engines in place, preserving all authored content.
-- Apply after 028. Each patch verifies its anchor and runs atomically.
create or replace function public.campaign_v4_damage(p_actor bigint,p_enemy jsonb,p_damage integer,p_kind text,p_element text default '物理')
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_actor public.players%rowtype; v_damage integer:=greatest(0,p_damage); v_ranged boolean;
begin
 if v_damage=0 then return 0; end if;
 select * into v_actor from public.players where id=p_actor;
 v_ranged:=exists(select 1 from jsonb_array_elements_text(v_actor.equipment) e(item) where item like '%弓%' or item like '%弩%');
 if p_kind='attack' and ((v_ranged and v_actor.build->'feats' ? '神射手') or (not v_ranged and v_actor.build->'feats' ? '武器大师')) then v_damage:=v_damage+3; end if;
 if p_kind='spell' and v_actor.build->'feats' ? '奥术增幅' then v_damage:=v_damage+3; end if;
 if coalesce(p_enemy->'immunities' ? p_element,false) then return 0; end if;
 if coalesce(p_enemy->'resistances' ? p_element,false) then v_damage:=v_damage/2; end if;
 if coalesce(p_enemy->'vulnerabilities' ? p_element,false) then v_damage:=v_damage*2; end if;
 return v_damage;
end $$;
revoke all on function public.campaign_v4_damage(bigint,jsonb,integer,text,text) from public,anon,authenticated;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure);
 if position($old$v_bonus:=v_bonus+v_dc;$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_command_v30_core(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$v_bonus:=v_bonus+v_dc;$old$,$new$v_bonus:=v_bonus+v_dc+case when exists(select 1 from public.players p where p.id=v_id and p.build->'feats' ? '神射手' and exists(select 1 from jsonb_array_elements_text(p.equipment) e(item) where item like '%弓%' or item like '%弩%')) then 2 else 0 end;$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure);
 if position($old$v_enemy_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_command_v30_core(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$v_enemy_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$old$,$new$v_dmg:=public.campaign_v4_damage(v_id,v_foe,v_dmg,'attack');
  v_enemy_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure);
 if position($old$v_roll:=floor(random()*20)::int+1;
  v_state:=jsonb_set(v_state,'{explored}'$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_command_v30_core(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$v_roll:=floor(random()*20)::int+1;
  v_state:=jsonb_set(v_state,'{explored}'$old$,$new$v_result:=public.campaign_v4_check(v_id,v_skill,v_dc);
  v_roll:=(v_result->>'d20')::integer; v_bonus:=(v_result->>'total')::integer-v_roll;
  v_state:=jsonb_set(v_state,'{last_roll}',v_result||jsonb_build_object('actor',v_name,'at',clock_timestamp()));
  v_state:=jsonb_set(v_state,'{explored}'$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_power_v30_core(text,text,bigint,integer)'::regprocedure);
 if position($old$v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_power_v30_core(text,text,bigint,integer)'; end if;
 execute replace(v_definition,$old$v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$old$,$new$v_dmg:=public.campaign_v4_damage(v_actor.id,v_foe,v_dmg,case when v_power.ring>0 or v_actor.class_name in ('法师','牧师','吟游诗人') then 'spell' else 'attack' end,
      case p_id when 'wizard_1' then '火焰' when 'wizard_3' then '闪电' when 'wizard_5' then '火焰' when 'wizard_6' then '火焰' when 'paladin_1' then '火焰' when 'cleric_2' then '火焰' else '物理' end);
     v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_command(text,text,jsonb)'::regprocedure);
 if position($old$if public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'attack') then return public.party_snapshot(v_code); end if;$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_command(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$if public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'attack') then return public.party_snapshot(v_code); end if;$old$,$new$null; -- damage has already been resolved in the attack engine$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_power(text,text,bigint,integer)'::regprocedure);
 if position($old$if v_before is not null and v_index>=0 and public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'spell') then return public.party_snapshot(v_code); end if;$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_power(text,text,bigint,integer)'; end if;
 execute replace(v_definition,$old$if v_before is not null and v_index>=0 and public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'spell') then return public.party_snapshot(v_code); end if;$old$,$new$null; -- damage has already been resolved in the spell engine$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_power_v30_core(text,text,bigint,integer)'::regprocedure);
 if position($old$elsif v_power.kind='ward' then$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_power_v30_core(text,text,bigint,integer)'; end if;
 execute replace(v_definition,$old$elsif v_power.kind='ward' then$old$,$new$elsif v_power.kind='ward' then
     update public.players set conditions=conditions||jsonb_build_object('concentrating',true,'concentration_target',v_target.id) where id=v_actor.id;$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_power(text,text,bigint,integer)'::regprocedure);
 if position($old$update public.players set conditions=conditions||'{"concentrating":true}'::jsonb where id=v_actor.id;$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_power(text,text,bigint,integer)'; end if;
 execute replace(v_definition,$old$update public.players set conditions=conditions||'{"concentrating":true}'::jsonb where id=v_actor.id;$old$,$new$null; -- concentration starts inside the casting turn, never after retaliation$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.campaign_finish_turn_v40_core(text,jsonb,bigint)'::regprocedure);
 if position($old$if not (v_save->>'success')::boolean then$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: campaign_finish_turn_v40_core(text,jsonb,bigint)'; end if;
 execute replace(v_definition,$old$if not (v_save->>'success')::boolean then$old$,$new$if not (v_save->>'success')::boolean or (select hp=0 from public.players where id=v_target.id) then
      v_combat:=jsonb_set(v_combat,'{wards}',coalesce(v_combat->'wards','{}'::jsonb)-coalesce(v_target.conditions->>'concentration_target',v_target.id::text));$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.campaign_finish_turn_v40_core(text,jsonb,bigint)'::regprocedure);
 if position($old$conditions=conditions-'concentrating'$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: campaign_finish_turn_v40_core(text,jsonb,bigint)'; end if;
 execute replace(v_definition,$old$conditions=conditions-'concentrating'$old$,$new$conditions=conditions-'concentrating'-'concentration_target'$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.campaign_v4_check(bigint,text,integer,text,integer,boolean)'::regprocedure);
 if position($old$ v_mode:=p_mode;
 if v_actor.race='矮人' and p_save and p_skill='体质' and v_actor.conditions ? 'poisoned' then v_mode:='advantage'; end if;
 if v_actor.race='精灵' and p_save and p_skill='感知' and v_actor.conditions ? 'charmed' then v_mode:='advantage'; end if;
 if v_actor.conditions ? 'disadvantage' then v_mode:='disadvantage'; end if;
$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: campaign_v4_check(bigint,text,integer,text,integer,boolean)'; end if;
 execute replace(v_definition,$old$ v_mode:=p_mode;
 if v_actor.race='矮人' and p_save and p_skill='体质' and v_actor.conditions ? 'poisoned' then v_mode:='advantage'; end if;
 if v_actor.race='精灵' and p_save and p_skill='感知' and v_actor.conditions ? 'charmed' then v_mode:='advantage'; end if;
 if v_actor.conditions ? 'disadvantage' then v_mode:='disadvantage'; end if;
$old$,$new$ v_mode:=p_mode;
 if (v_actor.race='矮人' and p_save and p_skill='体质' and coalesce((v_actor.conditions->>'poisoned')::boolean,false))
  or (v_actor.race='精灵' and p_save and p_skill='感知' and coalesce((v_actor.conditions->>'charmed')::boolean,false)) then
  v_mode:=case when p_mode='disadvantage' then 'normal' else 'advantage' end;
 end if;
 if coalesce((v_actor.conditions->>'disadvantage')::boolean,false) then
  v_mode:=case when v_mode='advantage' then 'normal' else 'disadvantage' end;
 end if;
$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_v4_identity(text,text,jsonb)'::regprocedure);
 if position($old$if v_race not in ('龙裔','提夫林','人类','矮人','精灵') or (v_race='龙裔' and v_ancestry not in ('火焰','闪电','寒冷','毒素','酸液'))$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_v4_identity(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$if v_race not in ('龙裔','提夫林','人类','矮人','精灵') or (v_race='龙裔' and v_ancestry not in ('火焰','闪电','寒冷','毒素','酸液'))$old$,$new$if v_race is null or v_race not in ('龙裔','提夫林','人类','矮人','精灵') or (v_race='龙裔' and (v_ancestry is null or v_ancestry not in ('火焰','闪电','寒冷','毒素','酸液')))$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_v4_world(text,text,jsonb)'::regprocedure);
 if position($old$if p_action='build' then$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_v4_world(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$if p_action='build' then$old$,$new$if v_actor.conditions ? 'jailed' and p_action<>'prison' then raise exception 'JAILED'; end if;
 if v_danger and p_action in ('build','guard','prison','camp_talk') then raise exception 'COMBAT_ACTIVE'; end if;
 if coalesce((v_state->>'v4_camp')::boolean,false) and p_action in ('crime','guard') then raise exception 'LEAVE_CAMP_FIRST'; end if;
 if p_action='build' then$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_v4_world(text,text,jsonb)'::regprocedure);
 if position($old$conditions=conditions-'poisoned'-'frightened'$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_v4_world(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$conditions=conditions-'poisoned'-'frightened'$old$,$new$conditions=conditions-'poisoned'-'frightened'-'concentrating'-'concentration_target'$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.party_command(text,text,jsonb)'::regprocedure);
 if position($old$if p_action not in ('create','join','heartbeat','leave') then$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: party_command(text,text,jsonb)'; end if;
 execute replace(v_definition,$old$if p_action not in ('create','join','heartbeat','leave') then$old$,$new$if p_action='roll' then return public.party_v4_identity(v_code,'check',p_payload); end if;
 if p_action not in ('create','join','heartbeat','leave') then$new$);
end $patch$;

do $patch$ declare v_definition text; begin
 v_definition:=pg_get_functiondef('public.campaign_finish_turn_v40_core(text,jsonb,bigint)'::regprocedure);
 if position($old$and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord$old$ in v_definition)=0 then raise exception 'V4_PATCH_ANCHOR_MISSING: campaign_finish_turn_v40_core(text,jsonb,bigint)'; end if;
 execute replace(v_definition,$old$and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord$old$,$new$and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) and not coalesce(v_combat->'refusing','[]'::jsonb) @> jsonb_build_array(p.id) order by e.ord$new$);
end $patch$;
