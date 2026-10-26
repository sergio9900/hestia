create table recurring_expenses(
 id             uuid primary key default gen_random_uuid(),
 group_id       uuid references expense_groups(id) not null,
 paid_id        uuid references members(id) not null,
 category_id    uuid references categories(id),
 amount_cents   bigint not null check (amount_cents > 0),
 description    text not null check (length(trim(description)) > 0),
 day_of_month   smallint not null check (day_of_month between 1 and 28),
 is_active      boolean not null default(true),
 created_at    timestamptz not null default now()
);

alter table recurring_expenses enable row level security;
