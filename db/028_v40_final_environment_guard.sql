-- Environmental actions can reduce all foes to zero without calling the turn resolver.
-- Phase I/II must still transition before the V3.1 final-victory trigger runs.
create or replace function public.campaign_v4_final_zero() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_combat jsonb; v_foes jsonb; v_boss jsonb; v_phase integer; v_hp integer;
begin
 if coalesce((new.state->>'chapter')::integer,-1)<>28 or new.state ? 'final_victory'
  or coalesce((old.state#>>'{combat,hp}')::integer,0)<=0 or coalesce((new.state#>>'{combat,hp}')::integer,-1)<>0 then return new; end if;
 v_combat:=new.state->'combat';
 if v_combat ? 'side_quest' then return new; end if;
 v_phase:=coalesce((v_combat->>'final_phase')::integer,1);
 if v_phase>=3 then return new; end if;
 v_phase:=v_phase+1;
 v_boss:=v_combat->'enemies'->0;
 v_hp:=case v_phase when 2 then 42 else 52 end;
 v_boss:=jsonb_set(jsonb_set(v_boss,'{hp}',to_jsonb(v_hp)),'{max_hp}',to_jsonb(v_hp));
 v_boss:=jsonb_set(v_boss,'{attack_bonus}',to_jsonb((v_boss->>'attack_bonus')::integer+2));
 v_boss:=jsonb_set(v_boss,'{damage_min}',to_jsonb((v_boss->>'damage_min')::integer+2));
 v_boss:=jsonb_set(v_boss,'{special}',to_jsonb(case v_phase when 2 then '齐射：瞄准施法者' else '齐射：崩落的厅柱' end));
 v_foes:=jsonb_set(v_combat->'enemies','{0}',v_boss);
 v_foes:=v_foes||jsonb_build_array(case v_phase when 2 then
  jsonb_build_object('name','钟厅增援弩手','hp',24,'max_hp',24,'ac',15,'attack_bonus',6,'damage_min',3,'damage_die',7,'special','齐射：从侧门加入')
  else jsonb_build_object('name','誓死焚证者','hp',28,'max_hp',28,'ac',16,'attack_bonus',7,'damage_min',4,'damage_die',8,'special','投火：灼烧证据与队伍') end);
 v_combat:=v_combat||jsonb_build_object('enemies',v_foes,'hp',public.campaign_enemy_hp(v_foes),'final_phase',v_phase,
  'phase_notice',case v_phase when 2 then 'PHASE II · 焚证令' else 'FINAL PHASE · 第十三声钟' end,
  'mechanic',case v_phase when 2 then '侧门援军逼近；关闭闸轮可阻断敌人。' else '厅柱崩落；利用地形发动最后一击。' end);
 new.state:=jsonb_set(new.state,'{combat}',v_combat);
 new.state:=jsonb_set(new.state,'{deep,combat,28}',jsonb_build_object('combat_required',true,'combat_resolved',false,'combat_skipped',false),true);
 return new;
end $$;
drop trigger if exists campaign_v40_final_zero on public.game_states;
create trigger campaign_v40_final_zero before update of state on public.game_states for each row execute function public.campaign_v4_final_zero();
