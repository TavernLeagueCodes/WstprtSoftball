-- ================================================================
-- MinuteMen Softball — Supabase Setup
-- Run this entire script in the Supabase SQL Editor once.
-- Dashboard → SQL Editor → New Query → paste → Run
-- ================================================================

-- 1. App config (team name, season, admin PIN) --------------------
create table if not exists sb_config (
  key   text primary key,
  value text
);

insert into sb_config (key, value) values
  ('team_name',  'MinuteMen'),
  ('season',     '2026'),
  ('admin_pin',  '0000')
on conflict (key) do nothing;

-- 2. Players (roster) ---------------------------------------------
create table if not exists sb_players (
  id         serial primary key,
  name       text not null,
  number     text,
  pin        text not null,
  active     boolean not null default true,
  created_at timestamptz default now()
);

-- 3. Games (schedule) ---------------------------------------------
create table if not exists sb_games (
  id          serial primary key,
  game_date   date not null,
  opponent    text not null,
  home_away   text not null default 'home',
  location    text,
  our_score   integer,
  opp_score   integer,
  status      text not null default 'scheduled',  -- scheduled | final | cancelled
  notes       text,
  created_at  timestamptz default now()
);

-- 4. Lineups (batting order per game) -----------------------------
create table if not exists sb_lineups (
  id            serial primary key,
  game_id       integer not null references sb_games(id) on delete cascade,
  player_id     integer not null references sb_players(id) on delete cascade,
  batting_order integer not null,
  position      text,
  unique(game_id, batting_order),
  unique(game_id, player_id)
);

-- 5. At-bats (core stats record) ----------------------------------
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

-- 6. Row Level Security -------------------------------------------

alter table sb_config     enable row level security;
alter table sb_players    enable row level security;
alter table sb_games      enable row level security;
alter table sb_lineups    enable row level security;
alter table sb_at_bats    enable row level security;

-- Everyone can read all tables (PIN check is handled in JS)
create policy "public read config"    on sb_config   for select using (true);
create policy "public read players"   on sb_players  for select using (true);
create policy "public read games"     on sb_games    for select using (true);
create policy "public read lineups"   on sb_lineups  for select using (true);
create policy "public read at_bats"   on sb_at_bats  for select using (true);

-- Players (anon) can insert and delete their own at-bats
create policy "anon insert at_bats"   on sb_at_bats  for insert to anon with check (true);
create policy "anon delete at_bats"   on sb_at_bats  for delete to anon using (true);

-- Admin (authenticated Supabase user) has full access
create policy "auth manage config"    on sb_config   for all to authenticated using (true) with check (true);
create policy "auth manage players"   on sb_players  for all to authenticated using (true) with check (true);
create policy "auth manage games"     on sb_games    for all to authenticated using (true) with check (true);
create policy "auth manage lineups"   on sb_lineups  for all to authenticated using (true) with check (true);
create policy "auth manage at_bats"   on sb_at_bats  for all to authenticated using (true) with check (true);

-- ================================================================
-- After running this script:
-- 1. Authentication → Providers → Email → disable "Confirm email"
-- 2. Authentication → Users → Add User (this is the manager account)
-- 3. Change admin_pin from '0000' to your desired 4-digit PIN:
--    UPDATE sb_config SET value = '1234' WHERE key = 'admin_pin';
-- 4. Add players via the app's admin panel, or via SQL:
--    INSERT INTO sb_players (name, number, pin) VALUES ('John Smith', '7', '4321');
-- ================================================================
