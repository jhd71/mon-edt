-- ============================================================
--  Emploi du temps — base de données Supabase
--  À coller dans : Supabase > SQL Editor > New query > Run
--
--  Rejouable sans risque : il ne touche ni aux codes ni aux données.
--  Les codes se règlent à part (voir §3, À NE PAS enregistrer ici).
-- ============================================================

-- ------------------------------------------------------------
-- 1. La table : une seule ligne, qui contient tout l'emploi du temps
-- ------------------------------------------------------------
create table if not exists public.edt_soleane (
  id          text primary key,
  courses     jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);
alter table public.edt_soleane add column if not exists devoirs jsonb not null default '[]'::jsonb;
alter table public.edt_soleane add column if not exists entete  jsonb;   -- titre, classe, établissement, note

alter table public.edt_soleane enable row level security;

-- AUCUNE lecture ni écriture directe : tout passe par edt_lire et
-- edt_sauver (§4), qui vérifient le code. Le contenu n'est donc
-- lisible par personne sans code, même avec la clé publique.
drop policy if exists "edt lecture"      on public.edt_soleane;
drop policy if exists "edt creation"     on public.edt_soleane;
drop policy if exists "edt modification" on public.edt_soleane;

-- Plus de temps réel (il exigeait une lecture ouverte à tous).
do $$
begin
  alter publication supabase_realtime drop table public.edt_soleane;
exception when others then null;
end $$;

-- ------------------------------------------------------------
-- 2. La table des codes : personne ne peut la lire depuis le web
-- ------------------------------------------------------------
create table if not exists public.edt_config (
  id           text primary key,
  code_hash    text not null,          -- code de MODIFICATION
  echecs       integer not null default 0,
  bloque_avant timestamptz
);
alter table public.edt_config add column if not exists code_lecture_hash text;  -- code d'ACCÈS
alter table public.edt_config enable row level security;
-- Aucune policy : seules les fonctions du §4 y accèdent.

-- ------------------------------------------------------------
-- 3. LES CODES — ne JAMAIS les écrire dans ce fichier (dépôt public).
--    Tapez ces lignes directement dans l'éditeur SQL de Supabase :
--
--    Code de modification :
--      update public.edt_config
--         set code_hash = encode(sha256(convert_to('NOUVEAU_CODE', 'UTF8')), 'hex')
--       where id = 'soleane';
--
--    Code d'accès (lecture seule) :
--      update public.edt_config
--         set code_lecture_hash = encode(sha256(convert_to('NOUVEAU_CODE', 'UTF8')), 'hex')
--       where id = 'soleane';
--
--    Le code de modification marche aussi comme code d'accès.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 4. Les fonctions
-- ------------------------------------------------------------

-- Vérification commune, avec freinage : 10 échecs => bloqué 15 minutes.
-- p_lecture = true : le code d'accès OU le code de modification sont acceptés.
-- p_lecture = false : seul le code de modification est accepté.
create or replace function public.edt_verif_code(p_id text, p_code text, p_lecture boolean)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  ligne public.edt_config%rowtype;
  h text;
begin
  select * into ligne from public.edt_config where id = p_id;
  if not found then
    return false;
  end if;

  if ligne.bloque_avant is not null and ligne.bloque_avant > now() then
    return false;
  end if;

  h := encode(sha256(convert_to(coalesce(p_code, ''), 'UTF8')), 'hex');

  if h = ligne.code_hash or (p_lecture and h = ligne.code_lecture_hash) then
    if ligne.echecs <> 0 or ligne.bloque_avant is not null then
      update public.edt_config set echecs = 0, bloque_avant = null where id = p_id;
    end if;
    return true;
  end if;

  if ligne.echecs + 1 >= 10 then
    update public.edt_config
       set echecs = 0, bloque_avant = now() + interval '15 minutes'
     where id = p_id;
  else
    update public.edt_config set echecs = ligne.echecs + 1 where id = p_id;
  end if;
  return false;
end;
$$;

-- L'ancienne vérification plantait sur un mauvais code (elle ne comptait
-- donc jamais les échecs). Elle passe maintenant par la nouvelle.
create or replace function public.edt_verif(p_id text, p_code text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.edt_verif_code(p_id, p_code, false);
end;
$$;

-- Lecture : renvoie tout l'emploi du temps, ou NULL si le code est faux.
create or replace function public.edt_lire(p_id text, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r jsonb;
begin
  if not public.edt_verif_code(p_id, p_code, true) then
    return null;
  end if;
  select jsonb_build_object('courses', courses, 'devoirs', devoirs, 'entete', entete)
    into r
    from public.edt_soleane
   where id = p_id;
  return coalesce(r, '{}'::jsonb);
end;
$$;

-- Enregistrement : renvoie true si c'est enregistré, false si le code est faux.
-- (Ne lève plus d'erreur, pour que les échecs soient bien comptés.)
create or replace function public.edt_sauver(p_id text, p_code text, p_courses jsonb, p_devoirs jsonb)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.edt_verif_code(p_id, p_code, false) then
    return false;
  end if;

  insert into public.edt_soleane (id, courses, devoirs, updated_at)
  values (p_id, p_courses, coalesce(p_devoirs, '[]'::jsonb), now())
  on conflict (id) do update
    set courses    = excluded.courses,
        devoirs    = coalesce(p_devoirs, public.edt_soleane.devoirs),
        updated_at = now();
  return true;
end;
$$;

revoke all on function public.edt_verif_code(text, text, boolean) from public, anon, authenticated;
revoke all on function public.edt_verif(text, text)                from public, anon, authenticated;
revoke all on function public.edt_lire(text, text)                  from public;
revoke all on function public.edt_sauver(text, text, jsonb, jsonb)  from public;
grant execute on function public.edt_lire(text, text)                 to anon, authenticated;
grant execute on function public.edt_sauver(text, text, jsonb, jsonb) to anon, authenticated;

-- Anciennes fonctions d'écriture : fermées (remplacées par edt_sauver).
do $$
begin
  revoke execute on function public.edt_enregistrer(text, text, jsonb)        from public, anon, authenticated;
  revoke execute on function public.edt_enregistrer(text, text, jsonb, jsonb) from public, anon, authenticated;
exception when undefined_function then null;
end $$;

-- Vérification du code de modification (bouton « Modifier »).
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
revoke all on function public.edt_code_ok(text, text) from public;
grant execute on function public.edt_code_ok(text, text) to anon, authenticated;
