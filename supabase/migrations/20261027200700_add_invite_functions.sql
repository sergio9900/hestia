create function create_invite(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_code      text := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
begin
  select id into v_member_id
  from public.members
  where group_id = p_group_id
    and user_id = auth.uid();

  if v_member_id is null then
    raise exception 'not a member of this group';
  end if;

  insert into public.group_invites (group_id, code, created_by, expires_at)
  values (p_group_id, v_code, v_member_id, now() + interval '7 days');

  return v_code;
end;
$$;

create function join_group(p_code text, p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := auth.uid();
  v_invite    public.group_invites%rowtype;
  v_member_id uuid;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select * into v_invite
  from public.group_invites
  where code = upper(trim(p_code))
    and used_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'invalid or expired invite';
  end if;

  insert into public.members (group_id, user_id, display_name)
  values (v_invite.group_id, v_user_id, p_display_name)
  returning id into v_member_id;

  update public.group_invites
  set used_at = now(), used_by = v_member_id
  where id = v_invite.id;

  return v_invite.group_id;
end;
$$;

revoke execute on function create_invite(uuid) from public, anon;
grant execute on function create_invite(uuid) to authenticated;
revoke execute on function join_group(text, text) from public, anon;
grant execute on function join_group(text, text) to authenticated;
