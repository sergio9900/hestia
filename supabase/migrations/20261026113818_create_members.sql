create table members(
 id             uuid primary key default gen_random_uuid(),
 group_id       uuid references expense_groups(id) not null,
 user_id        uuid references auth.users(id) not null,
 display_name   text not null check (length(trim(display_name)) > 0),
 created_at     timestamptz not null default now(),
 unique (group_id, user_id)
);

alter table members enable row level security;
