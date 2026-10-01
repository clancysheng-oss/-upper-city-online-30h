-- Enrol late arrivals/reconnected players without rerolling or stealing a turn.
-- Called only by the authenticated snapshot path after its membership check.
create or replace function public.campaign_v501_sync_initiative(p_code text)
returns void language plpgsql security invoker set search_path=public,pg_temp as $$
declare s jsonb; c jsonb; queue jsonb; additions jsonb;
begin
 select state into s from public.game_states where room_code=p_code for update;
 c:=s->'combat';
 if coalesce((c->>'hp')::integer,0)<=0 then return; end if;
 queue:=coalesce(c->'initiative','[]'::jsonb);
 select jsonb_agg(jsonb_build_object('id',p.id,'roll',0) order by p.id) into additions
 from public.players p where p.room_code=p_code and p.hp>0 and p.death_failures<3
 and (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'))
 and not coalesce(c->'refusing','[]'::jsonb) @> jsonb_build_array(p.id)
 and not exists(select 1 from jsonb_array_elements(queue) e where (e->>'id')::bigint=p.id);
 if additions is not null then
  update public.game_states set state=jsonb_set(s,'{combat,initiative}',queue||additions),updated_at=now() where room_code=p_code;
 end if;
end $$;
revoke all on function public.campaign_v501_sync_initiative(text) from public,anon,authenticated;

do $$ declare d text; begin
 select pg_get_functiondef('public.party_snapshot_v31_core(text)'::regprocedure) into d;
 if position('perform public.campaign_v501_sync_initiative' in d)=0 then
  if position('perform public.campaign_v412_resume_turn' in d)=0 then raise exception 'QUEUE_SNAPSHOT_ANCHOR_MISSING'; end if;
  d:=replace(d,'perform public.campaign_v412_resume_turn','perform public.campaign_v501_sync_initiative(v_code); perform public.campaign_v412_resume_turn');
  execute d;
 end if;
end $$;

-- Leaving a turn skips forward in the existing queue, rather than back to its head.
create or replace function public.party_v31_next_turn(p_code text,p_actor bigint)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare s jsonb; c jsonb; next_id bigint; actor_ord bigint;
begin
 if p_actor is null then return; end if;
 select state into s from public.game_states where room_code=p_code for update;
 c:=s->'combat';
 if coalesce((c->>'hp')::integer,0)<=0 or coalesce((c->>'turn')::bigint,-1)<>p_actor then return; end if;
 select ord into actor_ord from jsonb_array_elements(coalesce(c->'initiative','[]'::jsonb)) with ordinality e(value,ord) where (e.value->>'id')::bigint=p_actor;
 select p.id into next_id from jsonb_array_elements(coalesce(c->'initiative','[]'::jsonb)) with ordinality e(value,ord)
 join public.players p on p.id=(e.value->>'id')::bigint
 where p.room_code=p_code and p.hp>0 and p.death_failures<3
 and (p.is_companion or (p.user_id is not null and p.is_online and p.last_seen>=now()-interval '90 seconds'))
 and not coalesce(c->'refusing','[]'::jsonb) @> jsonb_build_array(p.id)
 order by case when e.ord>coalesce(actor_ord,0) then 0 else 1 end,e.ord limit 1;
 update public.game_states set state=jsonb_set(s,'{combat,turn}',coalesce(to_jsonb(next_id),'null'::jsonb)),updated_at=now() where room_code=p_code;
end $$;
revoke all on function public.party_v31_next_turn(text,bigint) from public,anon,authenticated;
