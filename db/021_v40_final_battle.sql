-- Keep the Chapter 29 encounter and victory trigger. Extend that encounter in place.
create or replace function public.campaign_v4_final_start() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_combat jsonb; v_boss jsonb; v_flags jsonb; v_hall integer; v_guard integer; v_max integer; v_aid integer:=0;
begin
 if coalesce((new.state->>'chapter')::integer,-1)<>28 or new.state ? 'final_victory' then return new; end if;
 v_combat:=new.state->'combat';
 if v_combat is null or v_combat='null'::jsonb or v_combat ? 'side_quest' or coalesce((v_combat->>'hp')::integer,0)<=0 or v_combat ? 'final_phase' then return new; end if;
 if coalesce((old.state->>'chapter')::integer,-1)=28 and coalesce((old.state#>>'{combat,hp}')::integer,0)>0 then return new; end if;
 v_flags:=coalesce(new.state->'flags','[]'::jsonb);
 select coalesce(max((p.reputation->>'hall')::integer),0),coalesce(max((p.reputation->>'guard')::integer),0)
 into v_hall,v_guard from public.players p where p.room_code=new.room_code and p.user_id is not null;
 v_aid:=case when v_flags ? 'defector' then 5 else 0 end+case when v_guard>=25 then 6 else 0 end+case when v_hall>=25 then 4 else 0 end;
 v_boss:=v_combat->'enemies'->0;
 v_max:=greatest(52,(v_boss->>'max_hp')::integer+18)-v_aid;
 v_boss:=jsonb_set(jsonb_set(v_boss,'{hp}',to_jsonb(v_max)),'{max_hp}',to_jsonb(v_max));
 v_boss:=jsonb_set(v_boss,'{special}',to_jsonb('铁令：压制持有证据的队员'::text));
 v_combat:=jsonb_set(v_combat,'{enemies}',jsonb_set(v_combat->'enemies','{0}',v_boss));
 v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
 v_combat:=v_combat||jsonb_build_object('final_phase',1,'phase_notice','PHASE I · 铁令围城','historical_aid',v_aid,'mechanic','护住证据；可利用掩体和闸轮阻断侧翼。');
 new.state:=jsonb_set(new.state,'{combat}',v_combat);
 return new;
end $$;
drop trigger if exists campaign_v40_final_start on public.game_states;
create trigger campaign_v40_final_start before update of state on public.game_states for each row execute function public.campaign_v4_final_start();

alter function public.campaign_finish_turn(text,jsonb,bigint) rename to campaign_finish_turn_v40_core;
revoke all on function public.campaign_finish_turn_v40_core(text,jsonb,bigint) from public,anon,authenticated;
create or replace function public.campaign_finish_turn(p_code text,p_combat jsonb,p_actor bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ch integer; v_combat jsonb:=p_combat; v_boss jsonb; v_foes jsonb; v_phase integer; v_next integer; v_hp integer;
 v_message text:=''; v_old_hp integer; v_result jsonb; v_guard integer; v_flags jsonb;
begin
 select (state->>'chapter')::integer,coalesce(state->'flags','[]'::jsonb) into v_ch,v_flags from public.game_states where room_code=p_code;
 if v_ch<>28 or v_combat ? 'side_quest' then return public.campaign_finish_turn_v40_core(p_code,p_combat,p_actor); end if;
 v_phase:=coalesce((v_combat->>'final_phase')::integer,1);
 v_boss:=v_combat->'enemies'->0;
 if v_boss is null then return public.campaign_finish_turn_v40_core(p_code,p_combat,p_actor); end if;
 v_old_hp:=(v_boss->>'hp')::integer;
 if v_phase<3 and v_old_hp<=(case when v_phase=1 then greatest(1,(v_boss->>'max_hp')::integer/2) else greatest(1,(v_boss->>'max_hp')::integer/3) end) then
  v_next:=v_phase+1;
  v_hp:=case v_next when 2 then 42 else 52 end+greatest(0,coalesce((select floor(avg(level))::integer from public.players where room_code=p_code and user_id is not null),1)-8)*3;
  v_boss:=jsonb_set(jsonb_set(v_boss,'{hp}',to_jsonb(v_hp)),'{max_hp}',to_jsonb(v_hp));
  v_boss:=jsonb_set(v_boss,'{attack_bonus}',to_jsonb((v_boss->>'attack_bonus')::integer+2));
  v_boss:=jsonb_set(v_boss,'{damage_min}',to_jsonb((v_boss->>'damage_min')::integer+2));
  v_boss:=jsonb_set(v_boss,'{special}',to_jsonb(case v_next when 2 then '齐射：瞄准没有掩护的施法者' else '齐射：崩落的厅柱与最后冲锋' end));
  v_foes:=jsonb_set(v_combat->'enemies','{0}',v_boss);
  if v_next=2 then
   v_foes:=v_foes||jsonb_build_array(jsonb_build_object('name','钟厅增援弩手','hp',24,'max_hp',24,'ac',15,'attack_bonus',6,'damage_min',3,'damage_die',7,'special','齐射：从侧门加入'));
  else
   v_foes:=v_foes||jsonb_build_array(jsonb_build_object('name','誓死焚证者','hp',28,'max_hp',28,'ac',16,'attack_bonus',7,'damage_min',4,'damage_die',8,'special','投火：灼烧证据与队伍'));
  end if;
  v_combat:=jsonb_set(v_combat,'{enemies}',v_foes);
  v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_foes)));
  v_combat:=v_combat||jsonb_build_object('final_phase',v_next,'phase_notice',case v_next when 2 then 'PHASE II · 焚证令' else 'FINAL PHASE · 第十三声钟' end,
   'mechanic',case v_next when 2 then '侧门援军逼近；关闭城门闸轮可阻断援军。' else '崩落的厅柱暴露新的危险地面；尽快结束战斗。' end);
  v_message:=case v_next when 2 then '；PHASE II：首领撕掉军令，弩手从侧门闯入。' else '；FINAL PHASE：首领以最后的钟声召来焚证者，厅柱开始崩落。' end;
 end if;
 v_result:=public.campaign_finish_turn_v40_core(p_code,v_combat,p_actor);
 return jsonb_set(v_result,'{log}',to_jsonb(v_message||coalesce(v_result->>'log','')));
end $$;
revoke all on function public.campaign_finish_turn(text,jsonb,bigint) from public,anon,authenticated;
