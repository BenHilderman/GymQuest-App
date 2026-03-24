-- Workouts
create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  workout_type text not null,
  title text,
  duration integer default 0,
  total_volume double precision default 0,
  set_count integer default 0,
  exercise_count integer default 0,
  calories_burned integer,
  notes text,
  started_at timestamptz not null,
  completed_at timestamptz,
  created_at timestamptz default now()
);

-- Exercises within a workout
create table public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid references public.workouts(id) on delete cascade not null,
  name text not null,
  muscle_group text,
  exercise_order integer default 0,
  notes text
);

-- Sets within an exercise
create table public.exercise_sets (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid references public.workout_exercises(id) on delete cascade not null,
  set_order integer default 0,
  reps integer default 0,
  weight double precision default 0,
  is_completed boolean default true,
  rpe integer,
  created_at timestamptz default now()
);

-- Indexes
create index idx_workouts_user on public.workouts(user_id, created_at desc);
create index idx_exercises_workout on public.workout_exercises(workout_id);
create index idx_sets_exercise on public.exercise_sets(exercise_id);

-- RLS
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.exercise_sets enable row level security;

create policy "workouts_read" on public.workouts for select using (auth.uid() = user_id);
create policy "workouts_insert" on public.workouts for insert with check (auth.uid() = user_id);
create policy "workouts_update" on public.workouts for update using (auth.uid() = user_id);
create policy "workouts_delete" on public.workouts for delete using (auth.uid() = user_id);

-- Exercises inherit access from workout ownership
create policy "exercises_read" on public.workout_exercises for select using (
  exists (select 1 from public.workouts where id = workout_id and user_id = auth.uid())
);
create policy "exercises_insert" on public.workout_exercises for insert with check (
  exists (select 1 from public.workouts where id = workout_id and user_id = auth.uid())
);
create policy "exercises_delete" on public.workout_exercises for delete using (
  exists (select 1 from public.workouts where id = workout_id and user_id = auth.uid())
);

-- Sets inherit access from exercise/workout ownership
create policy "sets_read" on public.exercise_sets for select using (
  exists (select 1 from public.workout_exercises we join public.workouts w on we.workout_id = w.id where we.id = exercise_id and w.user_id = auth.uid())
);
create policy "sets_insert" on public.exercise_sets for insert with check (
  exists (select 1 from public.workout_exercises we join public.workouts w on we.workout_id = w.id where we.id = exercise_id and w.user_id = auth.uid())
);
create policy "sets_delete" on public.exercise_sets for delete using (
  exists (select 1 from public.workout_exercises we join public.workouts w on we.workout_id = w.id where we.id = exercise_id and w.user_id = auth.uid())
);
