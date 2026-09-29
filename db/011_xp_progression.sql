-- Experience is earned by the existing quest actions. Story milestones remain a floor;
-- each XP threshold is applied exactly once on top of the current level, up to level 12.
alter table public.players add column if not exists xp_tier_applied smallint not null default 0;
create or replace function public.campaign_xp_bonus(p_experience integer)
returns integer language sql immutable set search_path=public,pg_temp as $$
 select case when greatest(0,coalesce(p_experience,0))>=300 then 3
             when greatest(0,coalesce(p_experience,0))>=150 then 2
             when greatest(0,coalesce(p_experience,0))>=50 then 1 else 0 end
$$;
create or replace function public.campaign_total_level(p_chapter integer,p_experience integer)
returns integer language sql immutable set search_path=public,pg_temp as $$
 select least(12,public.campaign_level(coalesce(p_chapter,0))+public.campaign_xp_bonus(p_experience))
$$;

-- A quest reward or an extra decision bonus updates the character in the same transaction.
create or replace function public.campaign_xp_levelup()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_chapter integer; v_level integer; v_gain integer; v_tier integer;
begin
 if new.experience<old.experience then return new; end if;
 select coalesce((state->>'chapter')::integer,0) into v_chapter from public.game_states where room_code=new.room_code;
 v_tier:=public.campaign_xp_bonus(new.experience);
 v_level:=least(12,greatest(new.level,public.campaign_level(v_chapter))+greatest(0,v_tier-old.xp_tier_applied));
 new.xp_tier_applied:=greatest(old.xp_tier_applied,v_tier);
 v_gain:=v_level-new.level;
 if v_gain>0 then
  v_gain:=v_gain*case new.class_name when '战士' then 6 when '圣武士' then 6 when '法师' then 4 else 5 end;
  new.max_hp:=new.max_hp+v_gain;
  if new.hp>0 then new.hp:=new.hp+v_gain; end if;
  new.level:=v_level;
  new.spell_slots:=public.campaign_slots(v_level);
  new.ability_charges:=2;
 end if;
 return new;
end $$;
drop trigger if exists players_xp_levelup on public.players;
create trigger players_xp_levelup before update of experience on public.players
for each row execute function public.campaign_xp_levelup();

-- Chapter changes apply the milestone plus the player's already earned XP bonus.
-- The existing party_command still handles its original milestone behavior.
create or replace function public.campaign_chapter_xp_levelup()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 update public.players p set
  max_hp=p.max_hp+(public.campaign_total_level((new.state->>'chapter')::integer,p.experience)-p.level)*case p.class_name when '战士' then 6 when '圣武士' then 6 when '法师' then 4 else 5 end,
  hp=case when p.hp>0 then p.hp+(public.campaign_total_level((new.state->>'chapter')::integer,p.experience)-p.level)*case p.class_name when '战士' then 6 when '圣武士' then 6 when '法师' then 4 else 5 end else 0 end,
  level=public.campaign_total_level((new.state->>'chapter')::integer,p.experience),
  spell_slots=public.campaign_slots(public.campaign_total_level((new.state->>'chapter')::integer,p.experience)),
  ability_charges=2
 where p.room_code=new.room_code and (p.user_id is not null or p.is_companion)
   and p.level<public.campaign_total_level((new.state->>'chapter')::integer,p.experience);
 return new;
end $$;
drop trigger if exists game_states_chapter_xp_levelup on public.game_states;
create trigger game_states_chapter_xp_levelup after update of state on public.game_states
for each row when ((new.state->>'chapter') is distinct from (old.state->>'chapter'))
execute function public.campaign_chapter_xp_levelup();

-- Credit XP earned before this migration without resetting characters or combat states.
-- The tier column makes this backfill idempotent on repeated runs.
update public.players set experience=experience where experience>0 and user_id is not null;
revoke all on function public.campaign_xp_bonus(integer),public.campaign_total_level(integer,integer),
 public.campaign_xp_levelup(),public.campaign_chapter_xp_levelup() from public,anon,authenticated;
