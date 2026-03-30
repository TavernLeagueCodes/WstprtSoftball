-- ================================================================
-- Little League Manager — Supabase Setup
-- Run this entire script in the Supabase SQL Editor once.
-- Dashboard → SQL Editor → New Query → paste → Run
-- ================================================================

-- 1. Tables -------------------------------------------------------

create table if not exists llm_config (
  id           text primary key default 'default',
  pin          text not null default '1234',
  games_played integer not null default 0,
  updated_at   timestamptz default now()
);
insert into llm_config (id) values ('default') on conflict do nothing;

create table if not exists llm_players (
  id         serial primary key,
  name       text not null,
  jersey     text,
  song_url   text,
  sort_order integer not null default 0
);

create table if not exists llm_schedule (
  id         serial primary key,
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
  player_name text primary key,
  counts      integer[] not null default '{0,0,0,0,0,0,0,0,0,0}'
);

create table if not exists llm_season_batting (
  player_name text primary key,
  h   integer default 0,
  o   integer default 0,
  w   integer default 0,
  rbi integer default 0,
  r   integer default 0
);

create table if not exists llm_game_history (
  id           serial primary key,
  game_num     integer,
  opp          text,
  game_date    text,
  batting      jsonb,
  mvps         text[],
  completed_at timestamptz default now()
);

-- 2. Row Level Security -------------------------------------------

alter table llm_config         enable row level security;
alter table llm_players        enable row level security;
alter table llm_schedule       enable row level security;
alter table llm_stats          enable row level security;
alter table llm_season_batting enable row level security;
alter table llm_game_history   enable row level security;

-- Anyone (parents with PIN, anon key) can read all tables
create policy "public read" on llm_config         for select using (true);
create policy "public read" on llm_players        for select using (true);
create policy "public read" on llm_schedule       for select using (true);
create policy "public read" on llm_stats          for select using (true);
create policy "public read" on llm_season_batting for select using (true);
create policy "public read" on llm_game_history   for select using (true);

-- Only authenticated coaches can write
create policy "coach write" on llm_config         for all to authenticated using (true) with check (true);
create policy "coach write" on llm_players        for all to authenticated using (true) with check (true);
create policy "coach write" on llm_schedule       for all to authenticated using (true) with check (true);
create policy "coach write" on llm_stats          for all to authenticated using (true) with check (true);
create policy "coach write" on llm_season_batting for all to authenticated using (true) with check (true);
create policy "coach write" on llm_game_history   for all to authenticated using (true) with check (true);

-- ================================================================
-- After running this script:
-- 1. Go to Authentication → Users → Add User and create a coach account
-- 2. Go to Authentication → Providers → Email and DISABLE "Confirm email"
--    (otherwise the coach login will fail on first sign-in)
-- 3. Copy your Project URL and anon public key from Settings → API
-- 4. In Netlify dashboard → Site Settings → Environment Variables, add:
--    SUPABASE_URL  = https://xxxx.supabase.co
--    SUPABASE_ANON_KEY = eyJ...
-- 5. Trigger a new Netlify deploy (push a commit or click "Deploy site")
-- ================================================================
