-- Clock In schema. Run this once in the Supabase SQL editor.
-- Re-running is safe (idempotent guards where possible).

create table if not exists public.time_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    clock_in_at timestamptz not null,
    clock_out_at timestamptz,
    clock_in_lat double precision,
    clock_in_lng double precision,
    clock_out_lat double precision,
    clock_out_lng double precision,
    created_at timestamptz not null default now()
);

create index if not exists time_entries_user_id_idx
    on public.time_entries (user_id, clock_in_at desc);

alter table public.time_entries enable row level security;

drop policy if exists "users see own entries" on public.time_entries;
create policy "users see own entries"
    on public.time_entries for select
    using (auth.uid() = user_id);

drop policy if exists "users insert own entries" on public.time_entries;
create policy "users insert own entries"
    on public.time_entries for insert
    with check (auth.uid() = user_id);

drop policy if exists "users update own entries" on public.time_entries;
create policy "users update own entries"
    on public.time_entries for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "users delete own entries" on public.time_entries;
create policy "users delete own entries"
    on public.time_entries for delete
    using (auth.uid() = user_id);
