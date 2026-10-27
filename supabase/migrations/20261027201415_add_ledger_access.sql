-- expenses: lectura, y edición solo de campos que no afectan al reparto
grant select on table expenses to authenticated;
grant update (description, category_id, expense_date, deleted_at)
  on table expenses to authenticated;

create policy "Group members can view expenses"
  on expenses
  for select
  to authenticated
  using ( is_group_member(group_id) );

create policy "Group members can edit expenses"
  on expenses
  for update
  to authenticated
  using ( is_group_member(group_id) )
  with check ( is_group_member(group_id) );

-- expense_splits: solo lectura
grant select on table expense_splits to authenticated;

create policy "Group members can view expense splits"
  on expense_splits
  for select
  to authenticated
  using ( is_group_member(group_id) );

-- settlements: lectura, alta y borrado suave
grant select on table settlements to authenticated;
grant insert (group_id, from_member_id, to_member_id, amount_cents, settlements_date)
  on table settlements to authenticated;
grant update (deleted_at) on table settlements to authenticated;

create policy "Group members can view settlements"
  on settlements
  for select
  to authenticated
  using ( is_group_member(group_id) );

create policy "Group members can create settlements"
  on settlements
  for insert
  to authenticated
  with check ( is_group_member(group_id) );

create policy "Group members can edit settlements"
  on settlements
  for update
  to authenticated
  using ( is_group_member(group_id) )
  with check ( is_group_member(group_id) );

-- recurring_expenses: solo lectura (se crearán con una función más adelante)
grant select on table recurring_expenses to authenticated;

create policy "Group members can view recurring expenses"
  on recurring_expenses
  for select
  to authenticated
  using ( is_group_member(group_id) );

-- recurring_expense_splits: solo lectura
grant select on table recurring_expense_splits to authenticated;

create policy "Group members can view recurring expense splits"
  on recurring_expense_splits
  for select
  to authenticated
  using ( is_group_member(group_id) );
