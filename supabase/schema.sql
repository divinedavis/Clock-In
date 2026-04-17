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

-- Admin allow-list by email.
create table if not exists public.admins (
    email text primary key,
    created_at timestamptz not null default now()
);

alter table public.admins enable row level security;
-- No public policies: only security-definer functions access this table.

-- Seed initial admin (idempotent).
insert into public.admins (email) values ('mr.halls@me.com')
    on conflict (email) do nothing;

-- Is the calling user an admin?
create or replace function public.is_admin()
returns boolean
security definer
set search_path = public
language sql stable
as $$
    select exists (
        select 1 from public.admins where email = auth.email()
    );
$$;

grant execute on function public.is_admin() to authenticated;

-- Admins see every time_entry (in addition to the owner's own-row policy).
drop policy if exists "admins see all entries" on public.time_entries;
create policy "admins see all entries"
    on public.time_entries for select
    using (public.is_admin());

-- RPC returning every entry with the user's email, admin-only.
create or replace function public.admin_time_entries()
returns table (
    id uuid,
    user_id uuid,
    email text,
    clock_in_at timestamptz,
    clock_out_at timestamptz,
    clock_in_lat double precision,
    clock_in_lng double precision,
    clock_out_lat double precision,
    clock_out_lng double precision
)
security definer
set search_path = public, auth
language sql stable
as $$
    select
        te.id,
        te.user_id,
        u.email::text,
        te.clock_in_at,
        te.clock_out_at,
        te.clock_in_lat,
        te.clock_in_lng,
        te.clock_out_lat,
        te.clock_out_lng
    from public.time_entries te
    join auth.users u on u.id = te.user_id
    where exists (select 1 from public.admins where email = auth.email())
    order by te.clock_in_at desc;
$$;

grant execute on function public.admin_time_entries() to authenticated;
