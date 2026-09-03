-- ============================================================
--  Emploi du temps de Soleane — table Supabase
--  À coller dans : Supabase > SQL Editor > New query > Run
-- ============================================================

-- 1. La table (une seule ligne, qui contient tout l'emploi du temps)
create table if not exists public.edt_soleane (
  id          text primary key,
  courses     jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

-- 2. Sécurité : lecture et modification autorisées pour tout le monde
--    (la protection réelle est le code à 4 chiffres dans la page)
alter table public.edt_soleane enable row level security;

drop policy if exists "edt lecture" on public.edt_soleane;
create policy "edt lecture"
  on public.edt_soleane for select
  using (true);

drop policy if exists "edt creation" on public.edt_soleane;
create policy "edt creation"
  on public.edt_soleane for insert
  with check (true);

drop policy if exists "edt modification" on public.edt_soleane;
create policy "edt modification"
  on public.edt_soleane for update
  using (true) with check (true);

-- 3. Temps réel : la page se met à jour toute seule quand l'autre modifie
alter publication supabase_realtime add table public.edt_soleane;
