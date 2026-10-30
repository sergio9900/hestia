# public.members

## Description

Una persona dentro de un grupo. Se enlaza con la cuenta de login de Supabase.

## Columns

| Name         | Type                     | Default           | Nullable | Children                                                                                                                                                                                                                                                                                                            | Parents                                           | Comment                                                           |
| ------------ | ------------------------ | ----------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------------- |
| created_at   | timestamp with time zone | now()             | false    |                                                                                                                                                                                                                                                                                                                     |                                                   |                                                                   |
| display_name | text                     |                   | false    |                                                                                                                                                                                                                                                                                                                     |                                                   | Nombre que se muestra en el grupo.                                |
| group_id     | uuid                     |                   | false    | [public.expense_splits](public.expense_splits.md) [public.expenses](public.expenses.md) [public.group_invites](public.group_invites.md) [public.recurring_expense_splits](public.recurring_expense_splits.md) [public.recurring_expenses](public.recurring_expenses.md) [public.settlements](public.settlements.md) | [public.expense_groups](public.expense_groups.md) |                                                                   |
| id           | uuid                     | gen_random_uuid() | false    | [public.expense_splits](public.expense_splits.md) [public.expenses](public.expenses.md) [public.group_invites](public.group_invites.md) [public.recurring_expense_splits](public.recurring_expense_splits.md) [public.recurring_expenses](public.recurring_expenses.md) [public.settlements](public.settlements.md) |                                                   |                                                                   |
| updated_at   | timestamp with time zone | now()             | false    |                                                                                                                                                                                                                                                                                                                     |                                                   | Se actualiza sola con un trigger. Sirve para sincronizar cambios. |
| user_id      | uuid                     |                   | false    |                                                                                                                                                                                                                                                                                                                     | [auth.users](auth.users.md)                       | Cuenta de login (auth.users) de esta persona.                     |

## Constraints

| Name                         | Type        | Definition                                           |
| ---------------------------- | ----------- | ---------------------------------------------------- |
| members_display_name_check   | CHECK       | CHECK ((length(TRIM(BOTH FROM display_name)) > 0))   |
| members_group_id_fkey        | FOREIGN KEY | FOREIGN KEY (group_id) REFERENCES expense_groups(id) |
| members_group_id_user_id_key | UNIQUE      | UNIQUE (group_id, user_id)                           |
| members_id_group_id_key      | UNIQUE      | UNIQUE (id, group_id)                                |
| members_pkey                 | PRIMARY KEY | PRIMARY KEY (id)                                     |
| members_user_id_fkey         | FOREIGN KEY | FOREIGN KEY (user_id) REFERENCES auth.users(id)      |

## Indexes

| Name                         | Definition                                                                                         |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| members_group_id_user_id_key | CREATE UNIQUE INDEX members_group_id_user_id_key ON public.members USING btree (group_id, user_id) |
| members_group_updated_idx    | CREATE INDEX members_group_updated_idx ON public.members USING btree (group_id, updated_at)        |
| members_id_group_id_key      | CREATE UNIQUE INDEX members_id_group_id_key ON public.members USING btree (id, group_id)           |
| members_pkey                 | CREATE UNIQUE INDEX members_pkey ON public.members USING btree (id)                                |

## Triggers

| Name           | Definition                                                                                                   |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| set_updated_at | CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.members FOR EACH ROW EXECUTE FUNCTION set_updated_at() |

## Relations

```mermaid
erDiagram

"public.members" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.expense_splits" }o--|| "public.members" : "FOREIGN KEY (member_id, group_id) REFERENCES members(id, group_id)"
"public.expenses" }o--|| "public.members" : "FOREIGN KEY (paid_id, group_id) REFERENCES members(id, group_id)"
"public.group_invites" }o--|| "public.members" : "FOREIGN KEY (created_by, group_id) REFERENCES members(id, group_id)"
"public.recurring_expense_splits" }o--|| "public.members" : "FOREIGN KEY (member_id, group_id) REFERENCES members(id, group_id)"
"public.recurring_expenses" }o--|| "public.members" : "FOREIGN KEY (paid_id, group_id) REFERENCES members(id, group_id)"
"public.settlements" }o--|| "public.members" : "FOREIGN KEY (from_member_id, group_id) REFERENCES members(id, group_id)"
"public.settlements" }o--|| "public.members" : "FOREIGN KEY (to_member_id, group_id) REFERENCES members(id, group_id)"
"public.group_invites" }o--o| "public.members" : "FOREIGN KEY (used_by) REFERENCES members(id)"
"public.members" }o--|| "auth.users" : "FOREIGN KEY (user_id) REFERENCES auth.users(id)"

"public.members" {
  timestamp_with_time_zone created_at
  text display_name
  uuid group_id FK
  uuid id
  timestamp_with_time_zone updated_at
  uuid user_id FK
}
"public.expense_groups" {
  timestamp_with_time_zone created_at
  uuid id
  text name
  timestamp_with_time_zone updated_at
}
"public.expense_splits" {
  timestamp_with_time_zone created_at
  uuid expense_id FK
  uuid group_id FK
  uuid id
  uuid member_id FK
  bigint share_cents
}
"public.expenses" {
  bigint amount_cents
  uuid category_id FK
  timestamp_with_time_zone created_at
  timestamp_with_time_zone deleted_at
  text description
  date expense_date
  uuid group_id FK
  uuid id
  uuid paid_id FK
  uuid recurring_expense_id FK
  timestamp_with_time_zone updated_at
}
"public.group_invites" {
  text code
  timestamp_with_time_zone created_at
  uuid created_by FK
  timestamp_with_time_zone expires_at
  uuid group_id FK
  uuid id
  timestamp_with_time_zone used_at
  uuid used_by FK
}
"public.recurring_expense_splits" {
  timestamp_with_time_zone created_at
  uuid group_id FK
  uuid id
  uuid member_id FK
  uuid recurring_expense_id FK
  bigint share_cents
}
"public.recurring_expenses" {
  bigint amount_cents
  uuid category_id FK
  timestamp_with_time_zone created_at
  smallint day_of_month
  text description
  uuid group_id FK
  uuid id
  boolean is_active
  date next_run_on
  uuid paid_id FK
  timestamp_with_time_zone updated_at
}
"public.settlements" {
  bigint amount_cents
  timestamp_with_time_zone created_at
  timestamp_with_time_zone deleted_at
  uuid from_member_id FK
  uuid group_id FK
  uuid id
  date settlements_date
  uuid to_member_id FK
  timestamp_with_time_zone updated_at
}
"auth.users" {
  uuid id
}
```

---

> Generated by [tbls](https://github.com/k1LoW/tbls)
