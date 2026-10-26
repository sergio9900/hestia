create table expenses (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references expense_groups(id),
  paid_id       uuid not null references members(id),
  category_id   uuid references categories(id),
  amount_cents  bigint not null check (amount_cents > 0),
  description   text not null check (length(trim(description)) > 0),
  expense_date  date not null default current_date,
  created_at    timestamptz not null default now()
);

alter table expenses enable row level security;
