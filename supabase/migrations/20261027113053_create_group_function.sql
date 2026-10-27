create function create_group(p_name text, p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id  uuid := auth.uid();
  v_group_id uuid;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  insert into public.expense_groups (name)
  values (p_name)
  returning id into v_group_id;

  insert into public.members (group_id, user_id, display_name)
  values (v_group_id, v_user_id, p_display_name);

  return v_group_id;
end;
$$;

revoke execute on function create_group(text, text) from public, anon;
grant execute on function create_group(text, text) to authenticated;
