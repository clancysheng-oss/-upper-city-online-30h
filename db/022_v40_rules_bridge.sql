-- Keep the V3 attack/spell/area engines. These guards and modifiers operate on their results.
create or replace function public.campaign_v4_assert_free(p_code text,p_rest boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_player public.players%rowtype; v_state jsonb;
begin
 select * into v_player from public.players where room_code=upper(trim(p_code)) and user_id=auth.uid();
 if not found then raise exception 'NOT_MEMBER'; end if;
 if v_player.conditions ? 'jailed' then raise exception 'JAILED'; end if;
 select state into v_state from public.game_states where room_code=upper(trim(p_code));
 if p_rest and not coalesce((v_state->>'v4_camp')::boolean,false) then raise exception 'REST_REQUIRES_CAMP'; end if;
 if not p_rest and coalesce((v_state->>'v4_camp')::boolean,false) then raise exception 'LEAVE_CAMP_FIRST'; end if;
end $$;
revoke all on function public.campaign_v4_assert_free(text,boolean) from public,anon,authenticated;

create or replace function public.campaign_v4_feat_damage(p_code text,p_actor bigint,p_before integer,p_target integer,p_kind text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_player public.players%rowtype; v_state jsonb; v_enemy jsonb; v_bonus integer:=0; v_ranged boolean;
begin
 select * into v_player from public.players where id=p_actor and room_code=p_code;
 select state into v_state from public.game_states where room_code=p_code for update;
 if v_state->'combat' is null or not (v_state->'combat' ? 'enemies') then return false; end if;
 if p_target<0 or p_target>=jsonb_array_length(v_state#>'{combat,enemies}') then return false; end if;
 v_enemy:=v_state#>array['combat','enemies',p_target::text];
 if p_before<=coalesce((v_enemy->>'hp')::integer,0) then return false; end if;
 if p_kind='spell' and v_player.build->'feats' ? '奥术增幅' then v_bonus:=3;
 elsif p_kind='attack' then
  v_ranged:=exists(select 1 from jsonb_array_elements_text(v_player.equipment) item where item like '%弓%' or item like '%弩%');
  if v_ranged and v_player.build->'feats' ? '神射手' then v_bonus:=3; end if;
  if not v_ranged and v_player.build->'feats' ? '武器大师' then v_bonus:=3; end if;
 end if;
 if v_bonus=0 then return false; end if;
 v_state:=jsonb_set(v_state,array['combat','enemies',p_target::text,'hp'],to_jsonb(greatest(0,(v_enemy->>'hp')::integer-v_bonus)));
 v_state:=jsonb_set(v_state,'{combat,hp}',to_jsonb(public.campaign_enemy_hp(v_state#>'{combat,enemies}')));
 update public.game_states set state=v_state where room_code=p_code;
 insert into public.messages(room_code,sender,body,kind) values(p_code,v_player.name,'专长加成：'||p_kind||'额外造成 '||least(v_bonus,(v_enemy->>'hp')::integer)||' 点伤害。','power');
 return true;
end $$;
revoke all on function public.campaign_v4_feat_damage(text,bigint,integer,integer,text) from public,anon,authenticated;

alter function public.party_command(text,text,jsonb) rename to party_command_v40_core;
revoke all on function public.party_command_v40_core(text,text,jsonb) from public,anon,authenticated;
create or replace function public.party_command(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); v_actor public.players%rowtype; v_before integer; v_index integer; v_result jsonb; v_item public.campaign_items%rowtype; v_delta integer:=0;
begin
 if p_action not in ('create','join','heartbeat','leave') then
  perform public.campaign_v4_assert_free(v_code,false);
 end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid();
 if p_action='attack' then
  v_index:=coalesce((p_payload->>'enemy')::integer,-1);
  select (state#>>array['combat','enemies',v_index::text,'hp'])::integer into v_before from public.game_states where room_code=v_code;
 elsif p_action='buy' then
  select * into v_item from public.campaign_items where name=p_payload->>'item';
  if found and v_actor.id is not null then
   v_delta:=case when coalesce((v_actor.reputation->>'merchant')::integer,0)>=25 or v_item.merchant='wonders' and coalesce((v_actor.reputation->>'gond')::integer,0)>=25 then -ceil(v_item.price*.1)::integer
    when coalesce((v_actor.reputation->>'merchant')::integer,0)<=-25 then ceil(v_item.price*.1)::integer else 0 end;
   if v_delta>0 and v_actor.gold<v_item.price+v_delta then raise exception 'NOT_ENOUGH_GOLD'; end if;
  end if;
 end if;
 v_result:=public.party_command_v40_core(p_code,p_action,p_payload);
 if p_action='attack' and v_before is not null and v_index>=0 then
  if public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'attack') then return public.party_snapshot(v_code); end if;
 elsif p_action='buy' and v_delta<>0 then
  update public.players set gold=gold-v_delta where id=v_actor.id;
  return public.party_snapshot(v_code);
 end if;
 return v_result;
end $$;
revoke all on function public.party_command(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_command(text,text,jsonb) to authenticated;

alter function public.party_power(text,text,bigint,integer) rename to party_power_v40_core;
revoke all on function public.party_power_v40_core(text,text,bigint,integer) from public,anon,authenticated;
create or replace function public.party_power(p_code text,p_id text,p_target bigint default null,p_slot integer default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); v_actor public.players%rowtype; v_before integer; v_index integer; v_result jsonb; v_kind text;
begin
 perform public.campaign_v4_assert_free(v_code,p_id='rest');
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid();
 select kind into v_kind from public.campaign_powers where id=p_id and profession=v_actor.class_name;
 if v_kind='damage' and p_target is not null and p_target<0 then
  v_index:=(-p_target-1)::integer;
  select (state#>>array['combat','enemies',v_index::text,'hp'])::integer into v_before from public.game_states where room_code=v_code;
 end if;
 v_result:=public.party_power_v40_core(p_code,p_id,p_target,p_slot);
 if v_kind='ward' then
  update public.players set conditions=conditions||'{"concentrating":true}'::jsonb where id=v_actor.id;
  return public.party_snapshot(v_code);
 end if;
 if v_before is not null and v_index>=0 and public.campaign_v4_feat_damage(v_code,v_actor.id,v_before,v_index,'spell') then return public.party_snapshot(v_code); end if;
 return v_result;
end $$;
revoke all on function public.party_power(text,text,bigint,integer) from public,anon,authenticated;
grant execute on function public.party_power(text,text,bigint,integer) to authenticated;

create or replace function public.party_deep(p_code text,p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);perform public.campaign_v4_assert_free(p_code,false);return public.party_deep_v30_core(p_code,p_action,p_payload);end $$;
create or replace function public.party_area(p_code text,p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);perform public.campaign_v4_assert_free(p_code,false);return public.party_area_v30_core(p_code,p_action,p_payload);end $$;
create or replace function public.party_region(p_code text,p_area text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.party_v31_assert_online(p_code);perform public.campaign_v4_assert_free(p_code,false);return public.party_region_v30_core(p_code,p_area);end $$;
