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

-- Direct deposit form uploads.
-- Bucket 'forms' is created in storage; see storage policies below.
insert into storage.buckets (id, name, public)
values ('forms', 'forms', false)
on conflict (id) do nothing;

drop policy if exists "admins manage forms bucket" on storage.objects;
create policy "admins manage forms bucket" on storage.objects
    for all
    using (bucket_id = 'forms' and public.is_admin())
    with check (bucket_id = 'forms' and public.is_admin());

drop policy if exists "users read blanks and own submissions" on storage.objects;
create policy "users read blanks and own submissions" on storage.objects
    for select using (
        bucket_id = 'forms'
        and (
            name like 'blank/%'
            or name like ('submitted/' || auth.uid()::text || '/%')
        )
    );

drop policy if exists "users upload own submissions" on storage.objects;
create policy "users upload own submissions" on storage.objects
    for insert with check (
        bucket_id = 'forms'
        and name like ('submitted/' || auth.uid()::text || '/%')
    );

drop policy if exists "users update own submissions" on storage.objects;
create policy "users update own submissions" on storage.objects
    for update
    using (bucket_id = 'forms' and name like ('submitted/' || auth.uid()::text || '/%'))
    with check (bucket_id = 'forms' and name like ('submitted/' || auth.uid()::text || '/%'));

create table if not exists public.direct_deposit_forms (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
    title text not null,
    blank_file_path text not null,
    is_broadcast boolean not null default true,
    created_at timestamptz not null default now()
);

create table if not exists public.direct_deposit_submissions (
    id uuid primary key default gen_random_uuid(),
    form_id uuid not null references public.direct_deposit_forms(id) on delete cascade,
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    submitted_file_path text not null,
    submitted_at timestamptz not null default now(),
    unique (form_id, user_id)
);

alter table public.direct_deposit_forms enable row level security;
alter table public.direct_deposit_submissions enable row level security;

drop policy if exists "admins manage forms" on public.direct_deposit_forms;
create policy "admins manage forms" on public.direct_deposit_forms
    for all using (public.is_admin()) with check (public.is_admin());

create table if not exists public.form_recipients (
    form_id uuid not null references public.direct_deposit_forms(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    primary key (form_id, user_id)
);

create index if not exists form_recipients_user_idx on public.form_recipients (user_id);

alter table public.form_recipients enable row level security;

drop policy if exists "admins manage form recipients" on public.form_recipients;
create policy "admins manage form recipients" on public.form_recipients
    for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "users see own form recipient rows" on public.form_recipients;
create policy "users see own form recipient rows" on public.form_recipients
    for select using (user_id = auth.uid());

drop policy if exists "users see broadcast forms" on public.direct_deposit_forms;
drop policy if exists "users see assigned or broadcast forms" on public.direct_deposit_forms;
create policy "users see assigned or broadcast forms" on public.direct_deposit_forms
    for select using (
        is_broadcast
        or exists (
            select 1 from public.form_recipients fr
            where fr.form_id = direct_deposit_forms.id and fr.user_id = auth.uid()
        )
    );

drop policy if exists "admins see all submissions" on public.direct_deposit_submissions;
create policy "admins see all submissions" on public.direct_deposit_submissions
    for select using (public.is_admin());

drop policy if exists "users manage own submissions" on public.direct_deposit_submissions;
create policy "users manage own submissions" on public.direct_deposit_submissions
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Admin: forms with per-user completion info.
drop function if exists public.admin_forms_status();
create or replace function public.admin_forms_status()
returns table (
    form_id uuid,
    title text,
    blank_file_path text,
    is_broadcast boolean,
    created_at timestamptz,
    total_assigned int,
    submitted_count int,
    pending_emails text[]
)
security definer
set search_path = public, auth
language sql stable
as $$
    with assigned as (
        select
            f.id as form_id,
            case when f.is_broadcast then
                array(select au.id from auth.users au
                      where not exists (select 1 from public.admins a where a.user_id = au.id))
            else
                array(select fr.user_id from public.form_recipients fr where fr.form_id = f.id)
            end as recipient_ids
        from public.direct_deposit_forms f
    )
    select
        f.id,
        f.title,
        f.blank_file_path,
        f.is_broadcast,
        f.created_at,
        coalesce(array_length(a.recipient_ids, 1), 0)::int as total_assigned,
        (select count(*)::int from public.direct_deposit_submissions s
         where s.form_id = f.id and s.user_id = any(a.recipient_ids)) as submitted_count,
        array(
            select au.email::text from auth.users au
            where au.id = any(a.recipient_ids)
              and not exists (
                select 1 from public.direct_deposit_submissions s
                where s.form_id = f.id and s.user_id = au.id
              )
            order by au.email
        ) as pending_emails
    from public.direct_deposit_forms f
    join assigned a on a.form_id = f.id
    where exists (select 1 from public.admins where user_id = auth.uid())
    order by f.created_at desc;
$$;
grant execute on function public.admin_forms_status() to authenticated;

-- Per-form detail: who's assigned + their submission timestamp (null if not submitted).
create or replace function public.admin_form_status(form_uuid uuid)
returns table (
    user_id uuid,
    email text,
    submitted_at timestamptz
)
security definer
set search_path = public, auth
language sql stable
as $$
    with the_form as (
        select id, is_broadcast from public.direct_deposit_forms where id = form_uuid
    ),
    assigned as (
        select
            case when tf.is_broadcast then
                array(select au.id from auth.users au
                      where not exists (select 1 from public.admins a where a.user_id = au.id))
            else
                array(select fr.user_id from public.form_recipients fr where fr.form_id = tf.id)
            end as recipient_ids
        from the_form tf
    )
    select
        u.id,
        u.email::text,
        s.submitted_at
    from auth.users u
    left join public.direct_deposit_submissions s
        on s.user_id = u.id and s.form_id = form_uuid
    cross join assigned a
    where u.id = any(a.recipient_ids)
      and exists (select 1 from public.admins where user_id = auth.uid())
    order by s.submitted_at desc nulls last, u.email;
$$;
grant execute on function public.admin_form_status(uuid) to authenticated;

-- Messaging: 1:1 direct messages with read receipts.
create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    recipient_id uuid not null references auth.users(id) on delete cascade,
    body text not null,
    created_at timestamptz not null default now(),
    read_at timestamptz
);

create index if not exists messages_pair_time_idx
    on public.messages (sender_id, recipient_id, created_at desc);
create index if not exists messages_recipient_unread_idx
    on public.messages (recipient_id)
    where read_at is null;

alter table public.messages enable row level security;

drop policy if exists "participants read messages" on public.messages;
create policy "participants read messages" on public.messages
    for select using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "sender insert messages" on public.messages;
create policy "sender insert messages" on public.messages
    for insert with check (sender_id = auth.uid());

drop policy if exists "recipient updates read_at" on public.messages;
create policy "recipient updates read_at" on public.messages
    for update
    using (recipient_id = auth.uid())
    with check (recipient_id = auth.uid());

create or replace function public.my_conversations()
returns table (
    partner_id uuid,
    partner_email text,
    last_body text,
    last_at timestamptz,
    unread_count int
)
security definer
set search_path = public, auth
language sql stable
as $$
    with mine as (
        select
            case when m.sender_id = auth.uid() then m.recipient_id else m.sender_id end as partner_id,
            m.body, m.created_at, m.read_at, m.recipient_id
        from public.messages m
        where m.sender_id = auth.uid() or m.recipient_id = auth.uid()
    ),
    last_per_partner as (
        select distinct on (partner_id) partner_id, body, created_at
        from mine
        order by partner_id, created_at desc
    ),
    unread as (
        select partner_id, count(*)::int as unread_count
        from mine
        where recipient_id = auth.uid() and read_at is null
        group by partner_id
    )
    select l.partner_id, u.email::text, l.body, l.created_at, coalesce(un.unread_count, 0)
    from last_per_partner l
    join auth.users u on u.id = l.partner_id
    left join unread un on un.partner_id = l.partner_id
    order by l.created_at desc;
$$;
grant execute on function public.my_conversations() to authenticated;

create or replace function public.list_messageable_users()
returns table (user_id uuid, email text)
security definer
set search_path = public, auth
language sql stable
as $$
    select u.id, u.email::text
    from auth.users u
    where u.id != auth.uid()
    order by u.email;
$$;
grant execute on function public.list_messageable_users() to authenticated;

-- User-uploaded credentials: OSHA 30, flagger card, etc.
create table if not exists public.credentials (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    kind text not null check (kind in ('osha_30', 'flagger_card')),
    file_path text not null,
    content_type text,
    uploaded_at timestamptz not null default now()
);

create index if not exists credentials_user_kind_idx
    on public.credentials (user_id, kind, uploaded_at desc);

alter table public.credentials enable row level security;

drop policy if exists "users manage own credentials" on public.credentials;
create policy "users manage own credentials" on public.credentials
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "admins read all credentials" on public.credentials;
create policy "admins read all credentials" on public.credentials
    for select using (public.is_admin());

-- Storage bucket for credential files (images + PDFs).
insert into storage.buckets (id, name, public)
values ('credentials', 'credentials', false)
on conflict (id) do nothing;

drop policy if exists "users manage own credential files" on storage.objects;
create policy "users manage own credential files" on storage.objects
    for all
    using (bucket_id = 'credentials' and name like (auth.uid()::text || '/%'))
    with check (bucket_id = 'credentials' and name like (auth.uid()::text || '/%'));

drop policy if exists "admins read all credential files" on storage.objects;
create policy "admins read all credential files" on storage.objects
    for select using (bucket_id = 'credentials' and public.is_admin());

-- Account deletion: wipes the user's storage objects then cascades via auth.users.
create or replace function public.delete_my_account()
returns void
security definer
set search_path = public, auth, storage
language plpgsql
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        raise exception 'not authenticated';
    end if;

    delete from storage.objects
    where bucket_id = 'credentials'
      and name like uid::text || '/%';

    delete from storage.objects
    where bucket_id = 'forms'
      and name like 'submitted/' || uid::text || '/%';

    delete from auth.users where id = uid;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
