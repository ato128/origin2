-- ============================================================================
-- Updo — Block & Report (App Store Guideline 1.2 / UGC güvenliği)
-- Supabase → SQL Editor'de bir kez çalıştır.
-- ============================================================================

-- 1) Engellenen kullanıcılar --------------------------------------------------
create table if not exists public.blocked_users (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references auth.users(id) on delete cascade,
  blocked_id  uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id)
);

create index if not exists blocked_users_blocker_idx on public.blocked_users (blocker_id);

alter table public.blocked_users enable row level security;

drop policy if exists "block: select own" on public.blocked_users;
create policy "block: select own"
  on public.blocked_users for select
  using (auth.uid() = blocker_id);

drop policy if exists "block: insert own" on public.blocked_users;
create policy "block: insert own"
  on public.blocked_users for insert
  with check (auth.uid() = blocker_id);

drop policy if exists "block: delete own" on public.blocked_users;
create policy "block: delete own"
  on public.blocked_users for delete
  using (auth.uid() = blocker_id);


-- 2) İçerik/kullanıcı şikayetleri --------------------------------------------
create table if not exists public.content_reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid not null references auth.users(id) on delete cascade,
  reported_user_id  uuid not null references auth.users(id) on delete cascade,
  context           text not null,               -- 'friend_chat' | 'crew_chat'
  conversation_id   text,
  message_id        text,
  content_snapshot  text not null default '',
  reason            text,
  status            text not null default 'open', -- 'open' | 'reviewed' | 'actioned'
  created_at        timestamptz not null default now()
);

create index if not exists content_reports_status_idx on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;

-- Kullanıcı yalnızca kendi şikayetini oluşturabilir ve görebilir.
drop policy if exists "report: insert own" on public.content_reports;
create policy "report: insert own"
  on public.content_reports for insert
  with check (auth.uid() = reporter_id);

drop policy if exists "report: select own" on public.content_reports;
create policy "report: select own"
  on public.content_reports for select
  using (auth.uid() = reporter_id);
-- Not: Şikayetleri incelemek için Supabase Dashboard → Table Editor →
-- content_reports (service role tüm satırları görür).
