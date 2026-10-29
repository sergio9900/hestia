-- Simula lo mínimo de Supabase que necesitan las migraciones (solo para generar la documentación).
-- No se usa nunca contra la base de datos real.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

-- La migración de tiempo real publica tablas en esta publicación
create publication supabase_realtime;

-- Simula pg_cron: las migraciones programan tareas con cron.schedule, y aquí no se ejecuta nada
create schema if not exists cron;
create or replace function cron.schedule(job_name text, schedule text, command text)
returns bigint
language sql
as $$ select 1::bigint $$;
