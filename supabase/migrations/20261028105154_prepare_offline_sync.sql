-- ============================================================
-- A. updated_at automático (para sincronizar "lo que cambió desde...")
-- ============================================================
create function set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

alter table expense_groups     add column updated_at timestamptz not null default now();
alter table members            add column updated_at timestamptz not null default now();
alter table categories         add column updated_at timestamptz not null default now();
alter table expenses           add column updated_at timestamptz not null default now();
alter table settlements        add column updated_at timestamptz not null default now();
alter table recurring_expenses add column updated_at timestamptz not null default now();

create trigger set_updated_at before update on expense_groups
  for each row execute function set_updated_at();
create trigger set_updated_at before update on members
  for each row execute function set_updated_at();
create trigger set_updated_at before update on categories
  for each row execute function set_updated_at();
create trigger set_updated_at before update on expenses
  for each row execute function set_updated_at();
create trigger set_updated_at before update on settlements
  for each row execute function set_updated_at();
create trigger set_updated_at before update on recurring_expenses
  for each row execute function set_updated_at();

create index members_group_updated_idx            on members (group_id, updated_at);
create index categories_group_updated_idx         on categories (group_id, updated_at);
create index expenses_group_updated_idx           on expenses (group_id, updated_at);
create index settlements_group_updated_idx        on settlements (group_id, updated_at);
create index recurring_expenses_group_updated_idx on recurring_expenses (group_id, updated_at);
create index expense_splits_group_created_idx     on expense_splits (group_id, created_at);
create index recurring_splits_group_created_idx   on recurring_expense_splits (group_id, created_at);

-- ============================================================
-- B. Categorías: borrado suave (un borrado real no llega a un móvil sin conexión)
-- ============================================================
alter table categories add column deleted_at timestamptz;

alter table categories drop constraint categories_group_id_category_name_key;
create unique index categories_group_name_active_key
  on categories (group_id, category_name)
  where deleted_at is null;

revoke insert, update, delete on table categories from authenticated;
grant insert (id, group_id, category_name) on table categories to authenticated;
grant update (category_name, deleted_at) on table categories to authenticated;

-- ============================================================
-- C. Pagos: el móvil genera el id (necesario para reintentos y para crear sin conexión)
-- ============================================================
grant insert (id) on table settlements to authenticated;

-- ============================================================
-- D. create_expense: el móvil genera el id y los reintentos no duplican
-- ============================================================
drop function create_expense(uuid, uuid, bigint, text, jsonb, uuid, date);

create function create_expense(
  p_id            uuid,
  p_group_id      uuid,
  p_paid_id       uuid,
  p_amount_cents  bigint,
  p_description   text,
  p_splits        jsonb,
  p_category_id   uuid default null,
  p_expense_date  date default current_date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric;
begin
  if p_id is null then
    raise exception 'id is required';
  end if;

  if not public.is_group_member(p_group_id) then
    raise exception 'not a member of this group';
  end if;

  -- Reintento del mismo gasto: no se duplica, se devuelve el existente
  if exists (select 1 from public.expenses where id = p_id) then
    if exists (select 1 from public.expenses where id = p_id and group_id = p_group_id) then
      return p_id;
    end if;
    raise exception 'id already in use';
  end if;

  if p_splits is null
     or jsonb_typeof(p_splits) <> 'array'
     or jsonb_array_length(p_splits) = 0 then
    raise exception 'splits must be a non-empty array';
  end if;

  select coalesce(sum((s ->> 'share_cents')::bigint), 0)
    into v_total
  from jsonb_array_elements(p_splits) as s;

  if v_total <> p_amount_cents then
    raise exception 'splits (%) must add up to the amount (%)', v_total, p_amount_cents;
  end if;

  insert into public.expenses
    (id, group_id, paid_id, category_id, amount_cents, description, expense_date)
  values
    (p_id, p_group_id, p_paid_id, p_category_id, p_amount_cents, p_description,
     coalesce(p_expense_date, current_date));

  insert into public.expense_splits (expense_id, group_id, member_id, share_cents)
  select p_id, p_group_id, (s ->> 'member_id')::uuid, (s ->> 'share_cents')::bigint
  from jsonb_array_elements(p_splits) as s;

  return p_id;
end;
$$;

revoke execute on function create_expense(uuid, uuid, uuid, bigint, text, jsonb, uuid, date)
  from public, anon;
grant execute on function create_expense(uuid, uuid, uuid, bigint, text, jsonb, uuid, date)
  to authenticated;
