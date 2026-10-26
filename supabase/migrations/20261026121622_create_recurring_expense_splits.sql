create table recurring_expense_splits (
  id                    uuid primary key default gen_random_uuid(),
  recurring_expense_id  uuid not null references recurring_expenses(id) on delete cascade,
  member_id             uuid not null references members(id),
  share_cents           bigint not null check (share_cents > 0),
  created_at            timestamptz not null default now(),
  unique (recurring_expense_id, member_id)
);

alter table recurring_expense_splits enable row level security;
