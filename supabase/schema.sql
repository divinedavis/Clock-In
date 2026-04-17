-- Clock In schema. Run this once in the Supabase SQL editor.
-- Re-running is safe (idempotent guards where possible).

create table if not exists public.time_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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

-- Ensure existing tables (pre-default) get the default applied idempotently.
alter table public.time_entries alter column user_id set default auth.uid();

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

-- Admin allow-list keyed by immutable user_id (email kept for reference only).
create table if not exists public.admins (
    user_id uuid primary key references auth.users(id) on delete cascade,
    email text,
    created_at timestamptz not null default now()
);

create unique index if not exists admins_email_key on public.admins(email);

alter table public.admins enable row level security;
-- No public policies: only security-definer functions access this table.

-- Seed initial admin by email lookup (idempotent).
insert into public.admins (user_id, email)
    select id, email from auth.users where email = 'mr.halls@me.com'
    on conflict (user_id) do nothing;

-- Is the calling user an admin? Checked by user_id so email changes can't
-- elevate privileges even if Supabase email-change policy is loosened.
create or replace function public.is_admin()
returns boolean
security definer
set search_path = public
language sql stable
as $$
    select exists (
        select 1 from public.admins where user_id = auth.uid()
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
    where exists (select 1 from public.admins where user_id = auth.uid())
    order by te.clock_in_at desc;
$$;

grant execute on function public.admin_time_entries() to authenticated;

-- Jobs: admins create assignments (with location + time), users receive them.
create table if not exists public.jobs (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
    title text not null,
    address text,
    location_lat double precision,
    location_lng double precision,
    scheduled_at timestamptz not null,
    notes text,
    is_broadcast boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists jobs_scheduled_at_idx on public.jobs (scheduled_at desc);

create table if not exists public.job_recipients (
    job_id uuid not null references public.jobs(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    primary key (job_id, user_id)
);

create index if not exists job_recipients_user_idx on public.job_recipients (user_id);

alter table public.jobs enable row level security;
alter table public.job_recipients enable row level security;

drop policy if exists "admins manage jobs" on public.jobs;
create policy "admins manage jobs"
    on public.jobs for all
    using (public.is_admin())
    with check (public.is_admin());

drop policy if exists "users see assigned or broadcast jobs" on public.jobs;
create policy "users see assigned or broadcast jobs"
    on public.jobs for select
    using (
        is_broadcast
        or exists (
            select 1 from public.job_recipients jr
            where jr.job_id = jobs.id and jr.user_id = auth.uid()
        )
    );

drop policy if exists "admins manage recipients" on public.job_recipients;
create policy "admins manage recipients"
    on public.job_recipients for all
    using (public.is_admin())
    with check (public.is_admin());

drop policy if exists "users see own recipient rows" on public.job_recipients;
create policy "users see own recipient rows"
    on public.job_recipients for select
    using (user_id = auth.uid());

-- Admin-only: list every user, for the recipient picker.
create or replace function public.admin_list_users()
returns table (user_id uuid, email text)
security definer
set search_path = public, auth
language sql stable
as $$
    select u.id as user_id, u.email::text
    from auth.users u
    where exists (select 1 from public.admins where user_id = auth.uid())
    order by u.email;
$$;
grant execute on function public.admin_list_users() to authenticated;

-- Jobs list with recipient emails (for admin calendar view).
create or replace function public.admin_jobs_with_recipients()
returns table (
    id uuid,
    title text,
    address text,
    location_lat double precision,
    location_lng double precision,
    scheduled_at timestamptz,
    notes text,
    is_broadcast boolean,
    recipient_emails text[]
)
security definer
set search_path = public, auth
language sql stable
as $$
    select
        j.id,
        j.title,
        j.address,
        j.location_lat,
        j.location_lng,
        j.scheduled_at,
        j.notes,
        j.is_broadcast,
        case when j.is_broadcast then array['* all users *']
             else coalesce(
                array(
                    select u.email::text from public.job_recipients jr
                    join auth.users u on u.id = jr.user_id
                    where jr.job_id = j.id
                    order by u.email
                ),
                array[]::text[])
        end as recipient_emails
    from public.jobs j
    where exists (select 1 from public.admins where user_id = auth.uid())
    order by j.scheduled_at;
$$;
grant execute on function public.admin_jobs_with_recipients() to authenticated;
