-- ================================================================
-- Little League Manager — Supabase Setup (v2 multi-team)
-- Run this entire script in the Supabase SQL Editor once.
-- Dashboard → SQL Editor → New Query → paste → Run
--
-- Safe to run on an existing v1 database — uses ALTER TABLE
-- to add team_id to existing tables rather than recreating them.
-- To revert to v1 single-team, run supabase-setup-v1-backup.sql
-- ================================================================

-- 1. Teams --------------------------------------------------------

create table if not exists teams (
  id          serial primary key,
  name        text not null,
  season      text,
  created_at  timestamptz default now()
);

-- 2. Coach → Team assignments ------------------------------------
-- Links a Supabase auth user (coach) to one or more teams.
-- is_admin = true means the user has full Settings access.

create table if not exists coach_teams (
  id         serial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  team_id    integer not null references teams(id) on delete cascade,
  is_admin   boolean not null default false,
  unique(user_id, team_id)
);

-- 3. Add team_id to existing tables (safe if already added) -------

alter table llm_config
  add column if not exists team_id integer references teams(id) on delete cascade;

alter table llm_players
  add column if not exists team_id integer references teams(id) on delete cascade;

alter table llm_schedule
  add column if not exists team_id integer references teams(id) on delete cascade;

alter table llm_stats
  add column if not exists team_id integer references teams(id) on delete cascade;

alter table llm_season_batting
  add column if not exists team_id integer references teams(id) on delete cascade;

alter table llm_game_history
  add column if not exists team_id integer references teams(id) on delete cascade;

-- 4. Update primary keys to include team_id -----------------------
-- llm_config: old PK was just (id), new PK is (id, team_id)
alter table llm_config drop constraint if exists llm_config_pkey;
alter table llm_config add primary key (id, team_id);

-- llm_stats: old PK was just (player_name), new PK is (player_name, team_id)
alter table llm_stats drop constraint if exists llm_stats_pkey;
alter table llm_stats add primary key (player_name, team_id);

-- llm_season_batting: old PK was just (player_name)
alter table llm_season_batting drop constraint if exists llm_season_batting_pkey;
alter table llm_season_batting add primary key (player_name, team_id);

-- 5. Row Level Security ------------------------------------------

alter table teams                enable row level security;
alter table coach_teams          enable row level security;
alter table llm_config           enable row level security;
alter table llm_players          enable row level security;
alter table llm_schedule         enable row level security;
alter table llm_stats            enable row level security;
alter table llm_season_batting   enable row level security;
alter table llm_game_history     enable row level security;

-- Helper: is the current user assigned to a given team?
create or replace function user_has_team(tid integer)
returns boolean language sql security definer as $$
  select exists (
    select 1 from coach_teams
    where user_id = auth.uid() and team_id = tid
  );
$$;

-- Helper: is the current user an admin for a given team?
create or replace function user_is_admin(tid integer)
returns boolean language sql security definer as $$
  select exists (
    select 1 from coach_teams
    where user_id = auth.uid() and team_id = tid and is_admin = true
  );
$$;

-- Drop existing policies before recreating (avoids conflicts)
drop policy if exists "public read" on llm_config;
drop policy if exists "coach write" on llm_config;
drop policy if exists "public read" on llm_players;
drop policy if exists "coach write" on llm_players;
drop policy if exists "public read" on llm_schedule;
drop policy if exists "coach write" on llm_schedule;
drop policy if exists "public read" on llm_stats;
drop policy if exists "coach write" on llm_stats;
drop policy if exists "public read" on llm_season_batting;
drop policy if exists "coach write" on llm_season_batting;
drop policy if exists "public read" on llm_game_history;
drop policy if exists "coach write" on llm_game_history;

-- teams: authenticated users can see teams they are assigned to
create policy "coach read own teams"  on teams for select to authenticated
  using (exists (select 1 from coach_teams where user_id = auth.uid() and team_id = teams.id));
create policy "admin insert teams"    on teams for insert to authenticated with check (true);
create policy "admin update teams"    on teams for update to authenticated
  using (user_is_admin(id));
create policy "admin delete teams"    on teams for delete to authenticated
  using (user_is_admin(id));

-- coach_teams: coaches can see their own assignments; only admins can manage
create policy "read own assignments"  on coach_teams for select to authenticated
  using (user_id = auth.uid() or user_is_admin(team_id));
create policy "admin manage coaches"  on coach_teams for all to authenticated
  using (user_is_admin(team_id)) with check (user_is_admin(team_id));

-- llm_config: anyone can read; only admins can write
create policy "public read config"    on llm_config for select using (true);
create policy "admin write config"    on llm_config for all to authenticated
  using (user_is_admin(team_id)) with check (user_is_admin(team_id));

-- llm_players: anyone can read; only admins can write
create policy "public read players"   on llm_players for select using (true);
create policy "admin write players"   on llm_players for all to authenticated
  using (user_is_admin(team_id)) with check (user_is_admin(team_id));

-- llm_schedule: anyone can read; only admins can write
create policy "public read schedule"  on llm_schedule for select using (true);
create policy "admin write schedule"  on llm_schedule for all to authenticated
  using (user_is_admin(team_id)) with check (user_is_admin(team_id));

-- llm_stats: anyone can read; coaches and admins can write
create policy "public read stats"     on llm_stats for select using (true);
create policy "coach write stats"     on llm_stats for all to authenticated
  using (user_has_team(team_id)) with check (user_has_team(team_id));

-- llm_season_batting: anyone can read; coaches and admins can write
create policy "public read batting"   on llm_season_batting for select using (true);
create policy "coach write batting"   on llm_season_batting for all to authenticated
  using (user_has_team(team_id)) with check (user_has_team(team_id));

-- llm_game_history: anyone can read; coaches and admins can write
create policy "public read history"   on llm_game_history for select using (true);
create policy "coach write history"   on llm_game_history for all to authenticated
  using (user_has_team(team_id)) with check (user_has_team(team_id));

-- ================================================================
-- After running this script:
-- 1. Create your admin user: Authentication → Users → Add User
--    (skip if you already have one from v1)
-- 2. Disable email confirmation: Authentication → Providers → Email
--    → turn off "Confirm email"
-- 3. Insert your first team:
--    INSERT INTO teams (name, season) VALUES ('Team Name', '2025');
-- 4. Assign yourself as admin (get your UUID from Authentication → Users):
--    INSERT INTO coach_teams (user_id, team_id, is_admin)
--    VALUES ('<your-auth-user-uuid>', 1, true);
-- 5. Update existing data to belong to your team:
--    UPDATE llm_config SET team_id = 1;
--    UPDATE llm_players SET team_id = 1;
--    UPDATE llm_schedule SET team_id = 1;
--    UPDATE llm_stats SET team_id = 1;
--    UPDATE llm_season_batting SET team_id = 1;
--    UPDATE llm_game_history SET team_id = 1;
-- 6. Add coaches via Authentication → Users, then assign them:
--    INSERT INTO coach_teams (user_id, team_id, is_admin)
--    VALUES ('<coach-uuid>', 1, false);
-- ================================================================
