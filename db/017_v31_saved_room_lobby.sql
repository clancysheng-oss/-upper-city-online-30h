-- Expose whether this is an owner-controlled save, so guests never see an unusable host-claim control.
alter function public.party_snapshot(text) rename to party_snapshot_v31_core;
revoke all on function public.party_snapshot_v31_core(text) from public,anon,authenticated;
create or replace function public.party_snapshot(p_code text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_data jsonb;
begin
 v_data:=public.party_snapshot_v31_core(p_code);
 return v_data||jsonb_build_object('saved_room',exists(select 1 from public.save_slots where room_code=upper(trim(coalesce(p_code,'')))));
end $$;
revoke all on function public.party_snapshot(text) from public,anon,authenticated;
grant execute on function public.party_snapshot(text) to authenticated;
