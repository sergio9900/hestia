create table categories(
 id             uuid primary key default gen_random_uuid(),
 group_id       uuid references expense_groups(id) not null,
 category_name  text not null check (length(trim(category_name)) > 0),
 created_at      timestamptz not null default now(),
 unique (group_id, category_name)
);

alter table categories enable row level security;
