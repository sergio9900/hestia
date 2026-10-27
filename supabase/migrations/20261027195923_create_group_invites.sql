create table group_invites (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references expense_groups(id) on delete cascade,
  code        text not null unique check (length(trim(code)) > 0),
  created_by  uuid not null,
  expires_at  timestamptz not null,
  used_at     timestamptz,
  used_by     uuid references members(id),
  created_at  timestamptz not null default now(),
  foreign key (created_by, group_id) references members (id, group_id)
);

alter table group_invites enable row level security;
