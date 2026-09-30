-- NPC companions do not have a network heartbeat; snapshots must preserve their turn.
do $$ declare d text; old_predicate text:='and (not p.is_online or p.last_seen<now()-interval ''90 seconds'')'; begin
 select pg_get_functiondef('public.party_snapshot_v31_core(text)'::regprocedure) into d;
 if position('and not p.is_companion '||old_predicate in d)>0 then return; end if;
 if position(old_predicate in d)=0 then raise exception 'PRESENCE_ANCHOR_MISSING'; end if;
 d:=replace(d,old_predicate,'and not p.is_companion '||old_predicate);
 execute d;
end $$;
