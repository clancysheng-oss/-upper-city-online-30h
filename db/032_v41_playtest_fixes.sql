-- Add an explicit costly alternative after failed mandatory side-quest checks.
-- Existing dice history and saved rooms are retained.
alter function public.party_area(text,text,jsonb) rename to party_area_v412_core;
revoke all on function public.party_area_v412_core(text,text,jsonb) from public,anon,authenticated;
create or replace function public.party_area(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); actor public.players%rowtype; s jsonb; q public.uc_quests%rowtype; record jsonb; stage jsonb; check_record jsonb; key text; step integer; cost text;
begin
 if p_action<>'area_quest_fallback' then return public.party_area_v412_core(p_code,p_action,p_payload);end if;
 perform public.party_v31_assert_online(v_code);
 perform 1 from public.rooms where rooms.code=v_code for update;
 select * into actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 select state into s from public.game_states where room_code=v_code for update;
 if actor.hp<=0 or actor.race is null or actor.conditions ? 'jailed' or coalesce((s->>'v4_camp')::boolean,false) or coalesce((s#>>'{combat,hp}')::integer,0)>0 then raise exception 'ACTION_UNAVAILABLE';end if;
 select * into q from public.uc_quests where id=p_payload->>'quest';
 record:=s#>array['side_quests',q.id];step:=(record->>'step')::integer;stage:=q.stages->step;
 key:='quest:'||q.id||':'||step||':continue';check_record:=s#>array['checks',key];
 if record->>'status'<>'进行中' or stage is null or not(stage ? 'skill') or stage ? 'options' or stage ? 'battle' or stage ? 'finish' or stage->>'area'<>coalesce(s->>'current_area','city') or stage->>'area'<>p_payload->>'area' or check_record is null or coalesce((check_record#>>'{result,success}')::boolean,true) or not coalesce((check_record->>'resolved')::boolean,false) then raise exception 'QUEST_FALLBACK_UNAVAILABLE';end if;
 if actor.gold>=6 then update public.players set gold=gold-6 where id=actor.id;cost:='支付 6 金币雇人核对旁证';
 else update public.players set hp=greatest(1,hp-2) where id=actor.id;cost:='亲自奔走，失去最多 2 HP（不会因此倒地）';end if;
 record:=record||jsonb_build_object('step',step+1,'fallbacks',coalesce(record->'fallbacks','[]'::jsonb)||to_jsonb(step));
 if coalesce((q.stages->(step+1)->>'finish')::boolean,false) then record:=record||jsonb_build_object('status','可交付');end if;
 s:=jsonb_set(s,array['side_quests',q.id],record,true);
 s:=jsonb_set(s,'{clues}',coalesce(s->'clues','[]'::jsonb)||jsonb_build_array(q.name||' · 旁证：'||(stage->>'text')),true);
 update public.game_states set state=s||jsonb_build_object('version',coalesce((s->>'version')::integer,0)+1),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,actor.name,'旁证调查：'||cost||'。绕开已失败的「'||(stage->>'label')||'」，沿货运记录继续追踪。原检定结果保留，不重投、不发放额外奖励。','area_quest');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_area(text,text,jsonb) from public,anon;
grant execute on function public.party_area(text,text,jsonb) to authenticated;
-- Merchant negotiations should not arbitrarily damage relations with guards.
do $$ declare d text;begin
 select pg_get_functiondef('public.campaign_v41_failure(text,jsonb)'::regprocedure) into d;
 d:=replace(d,$old$elsif action in ('guard','prison','social') then$old$,$new$elsif action='social' then
  msg:='本次谈判机会失去；仍可按原价购买。';
 elsif action in ('guard','prison') then$new$);
 execute d;
end $$;
