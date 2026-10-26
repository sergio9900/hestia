create table expense_splits(
 id             uuid primary key default gen_random_uuid(),
 expense_id     uuid references expenses(id) on delete cascade not null,
 member_id      uuid references members(id) not null,
 share_cents    bigint not null check (share_cents > 0),
 created_at    timestamptz not null default now(),
 unique (expense_id, member_id)
);

alter table expense_splits enable row level security;
