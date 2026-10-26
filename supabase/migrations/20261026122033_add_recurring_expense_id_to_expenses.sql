alter table expenses add recurring_expense_id uuid references recurring_expenses(id) on delete set null;
