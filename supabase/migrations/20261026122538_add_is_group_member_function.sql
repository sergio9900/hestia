create function is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.members
    where group_id = p_group_id
      and user_id = (select auth.uid())
  );
$$;
