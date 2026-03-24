-- ============================================================
-- Lift AI — Supabase Schema
-- Tables, indexes, RLS policies, triggers, realtime
-- ============================================================

-- Users (public profiles, linked to auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  email text,
  profile_photo_url text,
  is_premium boolean default false,
  fitness_goal text,
  xp integer default 0,
  level integer default 1,
  follower_count integer default 0,
  following_count integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Posts
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles(id) on delete cascade not null,
  author_name text not null,
  author_username text not null,
  caption text,
  workout_type text,
  duration integer,
  set_count integer,
  exercise_highlight text,
  song_title text,
  artist_name text,
  media_urls text[] default '{}',
  like_count integer default 0,
  comment_count integer default 0,
  is_deleted boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Comments (with reply threading)
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  author_name text not null,
  author_username text not null,
  content text not null,
  parent_comment_id uuid references public.comments(id),
  like_count integer default 0,
  created_at timestamptz default now()
);

-- Likes (one per user per post)
create table public.likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  user_name text not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

-- Reactions
create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  user_username text not null,
  target_type text not null,
  target_id uuid not null,
  reaction_type text not null,
  created_at timestamptz default now(),
  unique(user_id, target_id, target_type)
);

-- Follows
create table public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(follower_id, following_id)
);

-- Squads
create table public.squads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  creator_id uuid references public.profiles(id) not null,
  member_ids uuid[] default '{}',
  invite_code text unique,
  streak_weeks integer default 0,
  xp_multiplier double precision default 1.0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Pods
create table public.pods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  creator_id uuid references public.profiles(id) not null,
  member_ids uuid[] default '{}',
  invite_code text unique,
  level text default 'beginner',
  lifecycle text default 'forming',
  max_members integer default 6,
  weekly_workout_target integer default 3,
  streak_weeks integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Clubs
create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  location text,
  creator_id uuid references public.profiles(id) not null,
  admin_ids uuid[] default '{}',
  member_ids uuid[] default '{}',
  join_type text default 'open',
  category text,
  member_count integer default 0,
  is_verified boolean default false,
  image_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Club Posts
create table public.club_posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid references public.clubs(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  author_name text not null,
  author_username text not null,
  content text,
  photo_url text,
  like_count integer default 0,
  comment_count integer default 0,
  created_at timestamptz default now()
);

-- In-app Notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  type text not null,
  from_id uuid references public.profiles(id),
  from_name text,
  from_username text,
  target_id uuid,
  target_type text,
  message text,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- Analytics Events
create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  event_type text not null,
  metadata jsonb,
  created_at timestamptz default now()
);

-- ============================================================
-- Indexes
-- ============================================================
create index idx_posts_author on public.posts(author_id);
create index idx_posts_created on public.posts(created_at desc);
create index idx_comments_post on public.comments(post_id);
create index idx_likes_post on public.likes(post_id);
create index idx_follows_follower on public.follows(follower_id);
create index idx_follows_following on public.follows(following_id);
create index idx_notifications_user on public.notifications(user_id, created_at desc);
create index idx_squads_invite on public.squads(invite_code);
create index idx_pods_invite on public.pods(invite_code);
create index idx_analytics_user on public.analytics_events(user_id, created_at desc);

-- ============================================================
-- Triggers: auto-update counters
-- ============================================================

create or replace function update_post_like_count() returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set like_count = like_count + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set like_count = like_count - 1 where id = OLD.post_id;
  end if;
  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger on_like_change
  after insert or delete on public.likes
  for each row execute function update_post_like_count();

create or replace function update_post_comment_count() returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set comment_count = comment_count + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set comment_count = comment_count - 1 where id = OLD.post_id;
  end if;
  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger on_comment_change
  after insert or delete on public.comments
  for each row execute function update_post_comment_count();

create or replace function update_follow_counts() returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.profiles set following_count = following_count + 1 where id = NEW.follower_id;
    update public.profiles set follower_count = follower_count + 1 where id = NEW.following_id;
  elsif TG_OP = 'DELETE' then
    update public.profiles set following_count = following_count - 1 where id = OLD.follower_id;
    update public.profiles set follower_count = follower_count - 1 where id = OLD.following_id;
  end if;
  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger on_follow_change
  after insert or delete on public.follows
  for each row execute function update_follow_counts();

create or replace function handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, username, display_name, email)
  values (
    NEW.id,
    coalesce(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    coalesce(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.reactions enable row level security;
alter table public.follows enable row level security;
alter table public.squads enable row level security;
alter table public.pods enable row level security;
alter table public.clubs enable row level security;
alter table public.club_posts enable row level security;
alter table public.notifications enable row level security;
alter table public.analytics_events enable row level security;

create policy "profiles_read" on public.profiles for select using (auth.role() = 'authenticated');
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

create policy "posts_read" on public.posts for select using (auth.role() = 'authenticated');
create policy "posts_insert" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_update" on public.posts for update using (auth.uid() = author_id);
create policy "posts_delete" on public.posts for delete using (auth.uid() = author_id);

create policy "comments_read" on public.comments for select using (auth.role() = 'authenticated');
create policy "comments_insert" on public.comments for insert with check (auth.role() = 'authenticated');
create policy "comments_update" on public.comments for update using (auth.uid() = author_id);
create policy "comments_delete" on public.comments for delete using (auth.uid() = author_id);

create policy "likes_read" on public.likes for select using (auth.role() = 'authenticated');
create policy "likes_insert" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes for delete using (auth.uid() = user_id);

create policy "reactions_read" on public.reactions for select using (auth.role() = 'authenticated');
create policy "reactions_insert" on public.reactions for insert with check (auth.uid() = user_id);
create policy "reactions_delete" on public.reactions for delete using (auth.uid() = user_id);

create policy "follows_read" on public.follows for select using (auth.role() = 'authenticated');
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

create policy "squads_read" on public.squads for select using (auth.role() = 'authenticated');
create policy "squads_insert" on public.squads for insert with check (auth.role() = 'authenticated');
create policy "squads_update" on public.squads for update using (auth.uid() = any(member_ids));

create policy "pods_read" on public.pods for select using (auth.role() = 'authenticated');
create policy "pods_insert" on public.pods for insert with check (auth.role() = 'authenticated');
create policy "pods_update" on public.pods for update using (auth.uid() = any(member_ids));

create policy "clubs_read" on public.clubs for select using (auth.role() = 'authenticated');
create policy "clubs_insert" on public.clubs for insert with check (auth.role() = 'authenticated');
create policy "clubs_update" on public.clubs for update using (auth.uid() = any(admin_ids));

create policy "club_posts_read" on public.club_posts for select using (auth.role() = 'authenticated');
create policy "club_posts_insert" on public.club_posts for insert with check (auth.role() = 'authenticated');

create policy "notif_read" on public.notifications for select using (auth.uid() = user_id);
create policy "notif_insert" on public.notifications for insert with check (auth.role() = 'authenticated');
create policy "notif_delete" on public.notifications for delete using (auth.uid() = user_id);

create policy "analytics_insert" on public.analytics_events for insert with check (auth.role() = 'authenticated');
create policy "analytics_read" on public.analytics_events for select using (auth.uid() = user_id);

-- ============================================================
-- Realtime
-- ============================================================
alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.notifications;
