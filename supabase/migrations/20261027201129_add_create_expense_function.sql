create function create_expense(
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
  v_expense_id uuid;
  v_total      numeric;
begin
  if not public.is_group_member(p_group_id) then
    raise exception 'not a member of this group';
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
    (group_id, paid_id, category_id, amount_cents, description, expense_date)
  values
    (p_group_id, p_paid_id, p_category_id, p_amount_cents, p_description,
     coalesce(p_expense_date, current_date))
  returning id into v_expense_id;

  insert into public.expense_splits (expense_id, group_id, member_id, share_cents)
  select v_expense_id, p_group_id, (s ->> 'member_id')::uuid, (s ->> 'share_cents')::bigint
  from jsonb_array_elements(p_splits) as s;

  return v_expense_id;
end;
$$;

revoke execute on function create_expense(uuid, uuid, bigint, text, jsonb, uuid, date)
  from public, anon;
grant execute on function create_expense(uuid, uuid, bigint, text, jsonb, uuid, date)
  to authenticated;
