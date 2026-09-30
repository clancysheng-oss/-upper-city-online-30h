-- Reward faction relationships when existing quests and story choices resolve.
create or replace function public.campaign_v4_reputation() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_quest text; v_faction text; v_delta integer; v_flags jsonb; v_flag text;
begin
 if new.state->'side_quests' is distinct from old.state->'side_quests' then
  for v_quest,v_faction,v_delta in
   select * from (values ('star','gond',8),('medicine','merchant',8),('gate','guard',10),('ledger','hall',10),('signal','guard',8),('hearth','gond',12)) f(quest,faction,delta)
  loop
   if new.state#>>array['side_quests',v_quest,'status']='已完成'
    and coalesce(old.state#>>array['side_quests',v_quest,'status'],'')<>'已完成' then
    update public.players set reputation=jsonb_set(reputation,array[v_faction],to_jsonb(least(100,coalesce((reputation->>v_faction)::integer,0)+v_delta)))
      where room_code=new.room_code and user_id is not null;
   end if;
  end loop;
 end if;
 v_flags:=coalesce(new.state->'flags','[]'::jsonb);
 for v_flag,v_faction in select * from (values ('council','hall'),('autonomy','underground'),('defector','guard')) f(flag,faction) loop
  if v_flags ? v_flag and not coalesce(old.state->'flags','[]'::jsonb) ? v_flag then
   update public.players set reputation=jsonb_set(reputation,array[v_faction],to_jsonb(least(100,coalesce((reputation->>v_faction)::integer,0)+10)))
     where room_code=new.room_code and user_id is not null;
  end if;
 end loop;
 return new;
end $$;
drop trigger if exists campaign_v4_reputation on public.game_states;
create trigger campaign_v4_reputation before update of state on public.game_states for each row execute function public.campaign_v4_reputation();
