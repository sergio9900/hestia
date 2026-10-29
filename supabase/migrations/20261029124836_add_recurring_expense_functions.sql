-- Primera fecha igual o posterior a p_from que cae en el día p_day del mes
create function next_occurrence(p_day smallint, p_from date)
returns date
language sql
immutable
set search_path = ''
as $$
  select case
    when make_date(extract(year from p_from)::int, extract(month from p_from)::int, p_day) >= p_from
      then make_date(extract(year from p_from)::int, extract(month from p_from)::int, p_day)
    else (make_date(extract(year from p_from)::int, extract(month from p_from)::int, p_day)
          + interval '1 month')::date
  end
$$;

-- Crear una plantilla con su reparto, de forma atómica
create function create_recurring_expense(
  p_id            uuid,
  p_group_id      uuid,
  p_paid_id       uuid,
  p_amount_cents  bigint,
  p_description   text,
  p_day_of_month  smallint,
  p_splits        jsonb,
  p_category_id   uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric;
  v_today date := (now() at time zone 'Europe/Madrid')::date;
begin
  if p_id is null then
    raise exception 'id is required';
  end if;

  if not public.is_group_member(p_group_id) then
    raise exception 'not a member of this group';
  end if;

  -- Reintento de la misma plantilla: se devuelve la existente
  if exists (select 1 from public.recurring_expenses where id = p_id) then
    if exists (select 1 from public.recurring_expenses where id = p_id and group_id = p_group_id) then
      return p_id;
    end if;
    raise exception 'id already in use';
  end if;

  if p_day_of_month is null or p_day_of_month not between 1 and 28 then
    raise exception 'day_of_month must be between 1 and 28';
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

  insert into public.recurring_expenses
    (id, group_id, paid_id, category_id, amount_cents, description, day_of_month, next_run_on)
  values
    (p_id, p_group_id, p_paid_id, p_category_id, p_amount_cents, p_description, p_day_of_month,
     public.next_occurrence(p_day_of_month, v_today));

  insert into public.recurring_expense_splits (recurring_expense_id, group_id, member_id, share_cents)
  select p_id, p_group_id, (s ->> 'member_id')::uuid, (s ->> 'share_cents')::bigint
  from jsonb_array_elements(p_splits) as s;

  return p_id;
end;
$$;

-- Pausar o reactivar una plantilla. Al reactivar se salta lo que pasó mientras estuvo pausada.
create function set_recurring_expense_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group uuid;
  v_day   smallint;
  v_today date := (now() at time zone 'Europe/Madrid')::date;
begin
  select group_id, day_of_month into v_group, v_day
  from public.recurring_expenses
  where id = p_id;

  if v_group is null or not public.is_group_member(v_group) then
    raise exception 'recurring expense not found';
  end if;

  if p_active then
    update public.recurring_expenses
    set is_active = true,
        next_run_on = public.next_occurrence(v_day, v_today)
    where id = p_id and not is_active;
  else
    update public.recurring_expenses
    set is_active = false
    where id = p_id and is_active;
  end if;
end;
$$;

-- Genera los gastos que tocan. La ejecuta solo la tarea programada.
create function generate_recurring_expenses()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today      date := (now() at time zone 'Europe/Madrid')::date;
  r            record;
  v_date       date;
  v_expense_id uuid;
  v_count      integer := 0;
begin
  for r in
    select *
    from public.recurring_expenses
    where is_active and next_run_on <= v_today
    for update skip locked
  loop
    v_date := r.next_run_on;

    while v_date <= v_today loop
      v_expense_id := null;

      insert into public.expenses
        (group_id, paid_id, category_id, amount_cents, description, expense_date, recurring_expense_id)
      values
        (r.group_id, r.paid_id, r.category_id, r.amount_cents, r.description, v_date, r.id)
      on conflict (recurring_expense_id, expense_date) where recurring_expense_id is not null
      do nothing
      returning id into v_expense_id;

      if v_expense_id is not null then
        insert into public.expense_splits (expense_id, group_id, member_id, share_cents)
        select v_expense_id, s.group_id, s.member_id, s.share_cents
        from public.recurring_expense_splits s
        where s.recurring_expense_id = r.id;

        v_count := v_count + 1;
      end if;

      v_date := (v_date + interval '1 month')::date;
    end loop;

    update public.recurring_expenses set next_run_on = v_date where id = r.id;
  end loop;

  return v_count;
end;
$$;

revoke execute on function next_occurrence(smallint, date) from public, anon, authenticated;
revoke execute on function generate_recurring_expenses() from public, anon, authenticated;

revoke execute on function create_recurring_expense(uuid, uuid, uuid, bigint, text, smallint, jsonb, uuid)
  from public, anon;
grant execute on function create_recurring_expense(uuid, uuid, uuid, bigint, text, smallint, jsonb, uuid)
  to authenticated;

revoke execute on function set_recurring_expense_active(uuid, boolean) from public, anon;
grant execute on function set_recurring_expense_active(uuid, boolean) to authenticated;

comment on function generate_recurring_expenses() is
  'Crea los gastos reales de las plantillas activas que ya tocan. Solo la ejecuta la tarea programada.';
comment on function create_recurring_expense(uuid, uuid, uuid, bigint, text, smallint, jsonb, uuid) is
  'Crea una plantilla recurrente con su reparto de forma atómica. Es idempotente por id.';
comment on function set_recurring_expense_active(uuid, boolean) is
  'Pausa o reactiva una plantilla. Al reactivar recalcula la próxima fecha para no generar lo atrasado.';
