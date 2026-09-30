-- Recover a paused encounter after the last player leaves and later reconnects.
create or replace function public.campaign_v412_resume_turn(p_code text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare s jsonb; c jsonb; next_id bigint;
begin
 select state into s from public.game_states where room_code=p_code for update;c:=s->'combat';
 if coalesce((c->>'hp')::integer,0)<=0 or c->>'turn' is not null then return;end if;
 select p.id into next_id from jsonb_array_elements(coalesce(c->'initiative','[]'::jsonb)) with ordinality e(value,ord)
 join public.players p on p.id=(e.value->>'id')::bigint
 where p.room_code=p_code and p.hp>0 and p.death_failures<3 and not coalesce(c->'refusing','[]'::jsonb) @> to_jsonb(array[p.id]) and (p.is_companion or (p.is_online and p.last_seen>=now()-interval '90 seconds')) order by e.ord limit 1;
 if next_id is not null then update public.game_states set state=jsonb_set(s,'{combat,turn}',to_jsonb(next_id)),updated_at=now() where room_code=p_code;end if;
end $$;
revoke all on function public.campaign_v412_resume_turn(text) from public,anon,authenticated;
do $$ declare d text;begin
 select pg_get_functiondef('public.party_snapshot_v31_core(text)'::regprocedure) into d;
 if position('perform public.party_v31_next_turn' in d)=0 then raise exception 'SNAPSHOT_ANCHOR_MISSING';end if;
 d:=replace(d,'perform public.party_v31_next_turn','perform public.campaign_v412_resume_turn(v_code); perform public.party_v31_next_turn');execute d;
end $$;
