-- 1. Restricciones únicas que permiten las claves compuestas
alter table categories
  add constraint categories_id_group_id_key unique (id, group_id);
alter table expenses
  add constraint expenses_id_group_id_key unique (id, group_id);
alter table recurring_expenses
  add constraint recurring_expenses_id_group_id_key unique (id, group_id);

-- 2. expenses
alter table expenses
  drop constraint expenses_paid_id_fkey,
  drop constraint expenses_category_id_fkey,
  drop constraint expenses_recurring_expense_id_fkey,
  add foreign key (paid_id, group_id)
    references members (id, group_id),
  add foreign key (category_id, group_id)
    references categories (id, group_id) on delete set null (category_id),
  add foreign key (recurring_expense_id, group_id)
    references recurring_expenses (id, group_id) on delete set null (recurring_expense_id);

-- 3. recurring_expenses
alter table recurring_expenses
  drop constraint recurring_expenses_paid_id_fkey,
  drop constraint recurring_expenses_category_id_fkey,
  add foreign key (paid_id, group_id)
    references members (id, group_id),
  add foreign key (category_id, group_id)
    references categories (id, group_id) on delete set null (category_id);

-- 4. expense_splits
alter table expense_splits
  add column group_id uuid not null references expense_groups(id);
alter table expense_splits
  drop constraint expense_splits_expense_id_fkey,
  drop constraint expense_splits_member_id_fkey,
  add foreign key (expense_id, group_id)
    references expenses (id, group_id) on delete cascade,
  add foreign key (member_id, group_id)
    references members (id, group_id);

-- 5. recurring_expense_splits
alter table recurring_expense_splits
  add column group_id uuid not null references expense_groups(id);
alter table recurring_expense_splits
  drop constraint recurring_expense_splits_recurring_expense_id_fkey,
  drop constraint recurring_expense_splits_member_id_fkey,
  add foreign key (recurring_expense_id, group_id)
    references recurring_expenses (id, group_id) on delete cascade,
  add foreign key (member_id, group_id)
    references members (id, group_id);
