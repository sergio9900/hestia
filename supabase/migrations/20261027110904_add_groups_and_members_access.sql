grant select, update (name) on table expense_groups to authenticated;

create policy "Group members can view their group"
  on expense_groups
  for select
  to authenticated
  using ( is_group_member(id) );

create policy "Group members can rename their group"
  on expense_groups
  for update
  to authenticated
  using ( is_group_member(id) )
  with check ( is_group_member(id) );

grant select, update (display_name) on table members to authenticated;

create policy "Group members can view members of their group"
  on members
  for select
  to authenticated
  using ( is_group_member(group_id) );

create policy "Members can edit their own profile"
  on members
  for update
  to authenticated
  using ( user_id = (select auth.uid()) )
  with check ( user_id = (select auth.uid()) );
