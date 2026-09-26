-- Upper City 30H Party upgrade
alter table players add column if not exists is_host boolean not null default false;
alter table players add column if not exists is_ready boolean not null default false;

create table if not exists game_states (
  room_code text primary key references rooms(code) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table game_states enable row level security;
drop policy if exists "game_states public demo" on game_states;
create policy "game_states public demo" on game_states for all using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table game_states;
exception when duplicate_object then null;
end $$;
