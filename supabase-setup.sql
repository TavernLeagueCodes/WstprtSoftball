-- ================================================================
-- Little League Manager — Supabase Setup (v2 multi-team)
-- Run this entire script in the Supabase SQL Editor once.
-- Dashboard → SQL Editor → New Query → paste → Run
--
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

-- 3. Core tables (now team-scoped) --------------------------------

create table if not exists llm_config (
  id           text not null default 'default',
  team_id      integer not null references teams(id) on delete cascade,
  pin          text not null default '1234',
  games_played integer not null default 0,
  updated_at   timestamptz default now(),
  primary key (id, team_id)
);

create table if not exists llm_players (
  id         serial primary key,
  team_id    integer not null references teams(id) on delete cascade,
  name       text not null,
  jersey     text,
  song_url   text,
  sort_order integer not null default 0
);

create table if not exists llm_schedule (
  id         serial primary key,
  team_id    integer not null references teams(id) on delete cascade,
  num        integer not null,
  opp        text not null,
  game_date  text,
  game_time  text default '10:00 AM',
  loc        text,
  ha         text default 'Home',
  status     text default 'upcoming',
  rainout    boolean default false
);

create table if not exists llm_stats (
  player_name text not null,
  team_id     integer not null references teams(id) on delete cascade,
  counts      integer[] not null default '{0,0,0,0,0,0,0,0,0,0}',
  primary key (player_name, team_id)
);

create table if not exists llm_season_batting (
  player_name text not null,
  team_id     integer not null references teams(id) on delete cascade,
  h   integer default 0,
  o   integer default 0,
  w   integer default 0,
  rbi integer default 0,
  r   integer default 0,
  primary key (player_name, team_id)
);

create table if not exists llm_game_history (
  id           serial primary key,
  team_id      integer not null references teams(id) on delete cascade,
  game_num     integer,
  opp          text,
  game_date    text,
  batting      jsonb,
  mvps         text[],
  completed_at timestamptz default now()
);

-- 4. Row Level Security ------------------------------------------

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

-- teams: any authenticated user can see teams they are assigned to
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

-- llm_config: anyone can read (parents via anon); only admins can write
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
-- 2. Disable email confirmation: Authentication → Providers → Email
--    → turn off "Confirm email"
-- 3. Insert your first team:
--    INSERT INTO teams (name, season) VALUES ('Team Name', '2025');
-- 4. Assign yourself as admin:
--    INSERT INTO coach_teams (user_id, team_id, is_admin)
--    VALUES ('<your-auth-user-uuid>', 1, true);
-- 5. Insert a default config row for the team:
--    INSERT INTO llm_config (team_id) VALUES (1);
-- 6. Add coaches via Authentication → Users, then assign them:
--    INSERT INTO coach_teams (user_id, team_id, is_admin)
--    VALUES ('<coach-uuid>', 1, false);
-- ================================================================
