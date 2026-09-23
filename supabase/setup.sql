-- ForgeFit accounts & cloud save.
-- Run once in your Supabase project: SQL Editor -> New query -> paste this file -> Run.
-- It is safe to run again.
--
-- Each account gets one row holding its app data as JSON. Row level security makes
-- sure people can only read and write their own row.

create table if not exists public.user_data (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

drop policy if exists "Users read their own data" on public.user_data;
create policy "Users read their own data" on public.user_data
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users add their own data" on public.user_data;
create policy "Users add their own data" on public.user_data
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own data" on public.user_data;
create policy "Users update their own data" on public.user_data
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete their own data" on public.user_data;
create policy "Users delete their own data" on public.user_data
  for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.user_data to authenticated;
revoke all on public.user_data from anon;

-- Lets people delete their own account from the app. Their row above is removed
-- with it (on delete cascade).
create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
