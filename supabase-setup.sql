-- ================================================================
-- MinuteMen Softball — Supabase Setup
-- Run this entire script in the Supabase SQL Editor once.
-- Dashboard → SQL Editor → New Query → paste → Run
-- ================================================================

-- 1. App config ---------------------------------------------------
create table if not exists sb_config (
  key   text primary key,
  value text
);
insert into sb_config (key, value) values
  ('team_name',  'MinuteMen'),
  ('season',     '2026'),
  ('admin_pin',  '0000'),
  ('coach_pin',  '')
on conflict (key) do nothing;

-- 2. Players ------------------------------------------------------
create table if not exists sb_players (
  id         serial primary key,
  name       text not null,
  number     text,
  pin        text not null,
  active     boolean not null default true,
  created_at timestamptz default now()
);

-- 3. Games --------------------------------------------------------
-- status: scheduled | live | final | cancelled
create table if not exists sb_games (
  id          serial primary key,
  game_date   date not null,
  game_time   text,
  opponent    text not null,
  home_away   text not null default 'home',
  location    text,
  our_score   integer,
  opp_score   integer,
  status      text not null default 'scheduled',
  notes       text,
  created_at  timestamptz default now()
);

-- 4. Game players (who is playing in each game) -------------------
create table if not exists sb_game_players (
  game_id   integer not null references sb_games(id) on delete cascade,
  player_id integer not null references sb_players(id) on delete cascade,
  primary key (game_id, player_id)
);

-- 5. Lineups (batting order per game) -----------------------------
create table if not exists sb_lineups (
  id            serial primary key,
  game_id       integer not null references sb_games(id) on delete cascade,
  player_id     integer not null references sb_players(id) on delete cascade,
  batting_order integer not null,
  position      text,
  unique(game_id, batting_order),
  unique(game_id, player_id)
);

-- 6. At-bats ------------------------------------------------------
-- result: single | double | triple | hr | bb | k | sf | fc | out
create table if not exists sb_at_bats (
  id         serial primary key,
  game_id    integer not null references sb_games(id) on delete cascade,
  player_id  integer not null references sb_players(id) on delete cascade,
  inning     integer,
  result     text not null,
  rbi        integer not null default 0,
  created_at timestamptz default now()
);

-- 7. Row Level Security -------------------------------------------
alter table sb_config        enable row level security;
alter table sb_players       enable row level security;
alter table sb_games         enable row level security;
alter table sb_game_players  enable row level security;
alter table sb_lineups       enable row level security;
alter table sb_at_bats       enable row level security;

-- Public read on everything
create policy "public read config"       on sb_config       for select using (true);
create policy "public read players"      on sb_players      for select using (true);
create policy "public read games"        on sb_games        for select using (true);
create policy "public read game_players" on sb_game_players for select using (true);
create policy "public read lineups"      on sb_lineups      for select using (true);
create policy "public read at_bats"      on sb_at_bats      for select using (true);

-- Anon (PIN-based admin/players) can manage all tables
-- Security is enforced by PIN at the app level, not Supabase auth
create policy "anon manage config"   on sb_config  for all to anon using (true) with check (true);
create policy "anon manage players"  on sb_players for all to anon using (true) with check (true);
create policy "anon insert games"    on sb_games   for insert to anon with check (true);
create policy "anon delete games"    on sb_games   for delete to anon using (true);
create policy "anon manage lineups"  on sb_lineups for all to anon using (true) with check (true);

-- Anon (PIN users) can insert/delete at-bats ONLY during a live game
create policy "anon insert at_bats" on sb_at_bats for insert to anon
  with check (
    exists (select 1 from sb_games where id = game_id and status = 'live')
  );
create policy "anon delete at_bats" on sb_at_bats for delete to anon
  using (
    exists (select 1 from sb_games where id = game_id and status = 'live')
  );

-- Anon can update game status (to start/end live games)
create policy "anon update games" on sb_games for update to anon using (true) with check (true);

-- Anon can manage game players (who is playing in each game)
create policy "anon manage game_players" on sb_game_players for all to anon using (true) with check (true);

-- Authenticated (admin Supabase user) has full access to everything
create policy "auth manage config"       on sb_config       for all to authenticated using (true) with check (true);
create policy "auth manage players"      on sb_players      for all to authenticated using (true) with check (true);
create policy "auth manage games"        on sb_games        for all to authenticated using (true) with check (true);
create policy "auth manage game_players" on sb_game_players for all to authenticated using (true) with check (true);
create policy "auth manage lineups"      on sb_lineups      for all to authenticated using (true) with check (true);
create policy "auth manage at_bats"      on sb_at_bats      for all to authenticated using (true) with check (true);

-- ================================================================
-- After running this script:
-- 1. Authentication → Providers → Email → disable "Confirm email"
-- 2. Authentication → Users → Add User (your manager account)
-- 3. Change admin_pin:
--    UPDATE sb_config SET value = '1234' WHERE key = 'admin_pin';
-- ================================================================
