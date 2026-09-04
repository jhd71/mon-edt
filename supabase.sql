-- ============================================================
--  Emploi du temps de Soleane — base de données
--  À coller dans : Supabase > SQL Editor > New query > Run
--
--  Ce fichier est rejouable : vous pouvez le relancer autant de
--  fois que nécessaire, il remet simplement tout en ordre.
--  C'est aussi ici qu'on change le code de modification (§4).
-- ============================================================

-- ------------------------------------------------------------
-- 1. La table : une seule ligne, qui contient tout l'emploi du temps
-- ------------------------------------------------------------
create table if not exists public.edt_soleane (
  id          text primary key,
  courses     jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.edt_soleane enable row level security;

-- Lecture ouverte : la page doit pouvoir afficher l'emploi du temps
-- sans que personne se connecte.
drop policy if exists "edt lecture" on public.edt_soleane;
create policy "edt lecture"
  on public.edt_soleane for select
  using (true);

-- Écriture directe INTERDITE. On passe obligatoirement par la
-- fonction du §5, qui vérifie le code. Ces deux lignes suppriment
-- les anciennes autorisations si elles existent encore.
drop policy if exists "edt creation" on public.edt_soleane;
drop policy if exists "edt modification" on public.edt_soleane;

-- ------------------------------------------------------------
-- 2. Temps réel : la page se met à jour toute seule
-- ------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.edt_soleane;
exception when others then null;   -- déjà ajoutée : on ignore
end $$;

-- ------------------------------------------------------------
-- 3. La table du code : personne ne peut la lire depuis le web
-- ------------------------------------------------------------
create table if not exists public.edt_config (
  id           text primary key,
  code_hash    text not null,
  echecs       integer not null default 0,
  bloque_avant timestamptz
);

alter table public.edt_config enable row level security;
-- Aucune policy : donc aucune lecture ni écriture possible avec la
-- clé publique. Seules les fonctions du §5 y accèdent.

-- ------------------------------------------------------------
-- 4. LE CODE DE MODIFICATION
--
--    ATTENTION : n'écrivez JAMAIS le vrai code dans ce fichier.
--    Il partirait dans le dépôt GitHub, qui est public.
--
--    Marche à suivre : collez ce fichier dans l'éditeur SQL de
--    Supabase, remplacez ICI_LE_CODE par le vrai code juste avant
--    de cliquer sur Run, et ne réenregistrez pas le fichier.
--    Postgres ne range que l'empreinte, jamais le code lui-même.
-- ------------------------------------------------------------
insert into public.edt_config (id, code_hash)
values ('soleane', encode(sha256(convert_to('ICI_LE_CODE', 'UTF8')), 'hex'))
on conflict (id) do update set code_hash = excluded.code_hash;

-- ------------------------------------------------------------
-- 5. Les deux fonctions : vérifier le code, puis enregistrer
-- ------------------------------------------------------------

-- Vérification interne, avec freinage en cas d'essais répétés.
create or replace function public.edt_verif(p_id text, p_code text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  ligne public.edt_config%rowtype;
begin
  select * into ligne from public.edt_config where id = p_id;
  if not found then
    return false;
  end if;

  -- Après 10 échecs, on bloque 15 minutes. De quoi rendre un essai
  -- systématique des 10 000 codes très long.
  if ligne.bloque_avant is not null and ligne.bloque_avant > now() then
    return false;
  end if;

  if encode(sha256(convert_to(p_code, 'UTF8')), 'hex') = ligne.code_hash then
    update public.edt_config
       set echecs = 0, bloque_avant = null
     where id = p_id;
    return true;
  end if;

  update public.edt_config
     set echecs = ligne.echecs + 1,
         bloque_avant = case when ligne.echecs + 1 >= 10
                             then now() + interval '15 minutes' else null end,
         echecs = case when ligne.echecs + 1 >= 10 then 0 else ligne.echecs + 1 end
   where id = p_id;
  return false;
end;
$$;

revoke all on function public.edt_verif(text, text) from public, anon, authenticated;

-- Appelée par la page quand on tape le code dans « Modifier ».
create or replace function public.edt_code_ok(p_id text, p_code text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.edt_verif(p_id, p_code);
end;
$$;

-- Appelée par la page à chaque enregistrement. Sans le bon code,
-- rien n'est écrit, même avec la clé publique en main.
create or replace function public.edt_enregistrer(p_id text, p_code text, p_courses jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.edt_verif(p_id, p_code) then
    raise exception 'Code de modification invalide';
  end if;

  insert into public.edt_soleane (id, courses, updated_at)
  values (p_id, p_courses, now())
  on conflict (id) do update
    set courses = excluded.courses, updated_at = now();
end;
$$;

revoke all on function public.edt_code_ok(text, text) from public;
revoke all on function public.edt_enregistrer(text, text, jsonb) from public;
grant execute on function public.edt_code_ok(text, text) to anon, authenticated;
grant execute on function public.edt_enregistrer(text, text, jsonb) to anon, authenticated;
