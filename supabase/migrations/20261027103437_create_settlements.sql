alter table members add constraint members_id_group_id_key unique (id, group_id);

create table settlements(
id                  uuid primary key default gen_random_uuid(),
group_id            uuid references expense_groups(id) not null,
from_member_id      uuid not null,
to_member_id        uuid not null,
amount_cents        bigint not null check (amount_cents > 0),
settlements_date    date not null default current_date,
deleted_at          timestamptz,
created_at          timestamptz not null default now(),
foreign key (from_member_id, group_id) references members(id, group_id),
foreign key (to_member_id, group_id) references members(id, group_id),
check (from_member_id != to_member_id)
);

alter table settlements enable row level security;
