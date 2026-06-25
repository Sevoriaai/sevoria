-- Sevoria — saved chat history schema.
-- Run this in the Supabase SQL Editor (project nnyomecbumnofqabvfmu).
-- Safe to re-run: uses IF NOT EXISTS / DROP POLICY IF EXISTS.
-- No secrets here; this file is fine to keep in the public repo.

-- ---- tables ----
create table if not exists public.conversations (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null default 'New chat',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  role            text not null check (role in ('user','assistant')),
  content         text not null,
  created_at      timestamptz not null default now()
);

-- ---- indexes (fast sidebar + fast message load) ----
create index if not exists conversations_user_updated_idx
  on public.conversations (user_id, updated_at desc);
create index if not exists messages_convo_created_idx
  on public.messages (conversation_id, created_at);

-- ---- row level security: a user can only ever touch their own rows ----
alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

drop policy if exists "own conversations" on public.conversations;
create policy "own conversations" on public.conversations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own messages" on public.messages;
create policy "own messages" on public.messages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =====================================================================
-- profiles: one row per user — plan, credit balance, admin flag.
-- Rows are created by a trigger (never by the client), so users can't
-- mint themselves credits. Only admins can change plan/credits.
-- =====================================================================
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  plan       text    not null default 'free',
  credits    integer not null default 120,
  is_admin   boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- SECURITY DEFINER helper avoids policy recursion when checking admin.
create or replace function public.is_admin() returns boolean
  language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

drop policy if exists "profiles read own or admin" on public.profiles;
create policy "profiles read own or admin" on public.profiles
  for select using (id = auth.uid() or public.is_admin());

-- Only admins may change plan / credits / is_admin. Users never self-update.
drop policy if exists "profiles update admin only" on public.profiles;
create policy "profiles update admin only" on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());

-- Auto-create a profile whenever a new auth user is created.
create or replace function public.handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for anyone who signed up before this ran.
insert into public.profiles (id, email)
  select id, email from auth.users on conflict (id) do nothing;

-- AFTER the owner account exists, make it an admin (run once):
--   update public.profiles set is_admin = true where email = 'richyrachfansgmial@gmail.com';

-- Spend credits: lets a signed-in user decrement THEIR OWN balance (never below
-- zero) and returns the new balance. SECURITY DEFINER so it can update the row
-- even though direct updates are admin-only — but it only ever touches the
-- caller's row, so a user can spend but can never give themselves credits.
create or replace function public.spend_credits(cost integer) returns integer
  language plpgsql security definer set search_path = public as $$
declare newbal integer;
begin
  update public.profiles
     set credits = greatest(credits - greatest(cost, 0), 0), updated_at = now()
   where id = auth.uid()
   returning credits into newbal;
  return coalesce(newbal, 0);
end; $$;
