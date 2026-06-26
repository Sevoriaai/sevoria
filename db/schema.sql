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

-- ---- migration guards: add any missing columns on pre-existing tables ----
-- (If you created conversations/messages from an earlier draft, CREATE TABLE
--  IF NOT EXISTS won't add new columns — these ALTERs do, idempotently.)
alter table public.conversations add column if not exists title      text        not null default 'New chat';
alter table public.conversations add column if not exists created_at timestamptz  not null default now();
alter table public.conversations add column if not exists updated_at timestamptz  not null default now();
alter table public.messages      add column if not exists user_id    uuid;
alter table public.messages      add column if not exists created_at timestamptz  not null default now();

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
  credits    integer not null default 1000,
  is_admin   boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists plan     text    not null default 'free';
alter table public.profiles add column if not exists credits  integer not null default 1000;
alter table public.profiles add column if not exists is_admin boolean not null default false;
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
--   update public.profiles set is_admin = true where email = 'YOUR_OWNER_EMAIL';

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

-- =====================================================================
-- GRANTS — REQUIRED because this project has "expose new tables" OFF, so
-- manually-created tables are NOT auto-granted to the API roles. Without
-- these, a logged-in user gets "permission denied for table" even though
-- RLS policies exist. RLS still restricts WHICH rows they can touch.
-- =====================================================================
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.conversations to authenticated;
grant select, insert, update, delete on public.messages      to authenticated;
grant select, update                 on public.profiles       to authenticated;
grant execute on function public.spend_credits(integer) to authenticated;
grant execute on function public.is_admin()             to authenticated;

-- =====================================================================
-- INVITE-ONLY BETA: referral codes. A user can't reach the chat until they
-- redeem a valid code (profiles.invited = true). Admins generate codes.
-- =====================================================================
alter table public.profiles add column if not exists invited boolean not null default false;
-- Admins are always considered invited.
update public.profiles set invited = true where is_admin = true;

create table if not exists public.referral_codes (
  code       text primary key,
  created_by uuid references auth.users(id) on delete set null,
  used_by    uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  used_at    timestamptz
);
alter table public.referral_codes enable row level security;

-- Only admins can see / create codes directly.
drop policy if exists "referral admin" on public.referral_codes;
create policy "referral admin" on public.referral_codes
  for all using (public.is_admin()) with check (public.is_admin());

-- Redeem a code: marks it used by the caller and flips their invited flag.
-- SECURITY DEFINER so a normal (not-yet-invited) user can run it even though
-- they can't read the table. Returns true on success, false if invalid/used.
create or replace function public.redeem_referral(p_code text) returns boolean
  language plpgsql security definer set search_path = public as $$
declare ok boolean;
begin
  update public.referral_codes
     set used_by = auth.uid(), used_at = now()
   where code = p_code and used_by is null
  returning true into ok;
  if ok then
    update public.profiles set invited = true, updated_at = now() where id = auth.uid();
    return true;
  end if;
  return false;
end; $$;

grant select, insert, update, delete on public.referral_codes to authenticated;
grant execute on function public.redeem_referral(text) to authenticated;

-- =====================================================================
-- INSTALL BONUS: +300 credits, once, when a user opens the installed app.
-- =====================================================================
alter table public.profiles add column if not exists install_bonus_claimed boolean not null default false;

create or replace function public.claim_install_bonus() returns integer
  language plpgsql security definer set search_path = public as $$
declare newbal integer;
begin
  update public.profiles
     set credits = credits + 300, install_bonus_claimed = true, updated_at = now()
   where id = auth.uid() and install_bonus_claimed = false
  returning credits into newbal;
  return newbal;  -- null if it was already claimed
end; $$;

grant execute on function public.claim_install_bonus() to authenticated;
