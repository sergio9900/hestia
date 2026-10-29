# Hestia

## Description

Esquema de la base de datos de Hestia. Se genera solo a partir de las migraciones; no se edita a mano.

## Tables

| Name                                                                  | Columns | Comment                                                                                                        | Type       |
| --------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------- | ---------- |
| [auth.users](auth.users.md)                                           | 1       |                                                                                                                | BASE TABLE |
| [public.categories](public.categories.md)                             | 6       | Tipos de gasto de cada grupo (supermercado, ocio...). Se borran de forma suave.                                | BASE TABLE |
| [public.expense_groups](public.expense_groups.md)                     | 4       | Una familia o grupo. Todo lo demás cuelga de un grupo.                                                         | BASE TABLE |
| [public.expense_splits](public.expense_splits.md)                     | 6       | Reparto de un gasto: una fila por miembro con la parte que le toca. Se crean junto al gasto y no se editan.    | BASE TABLE |
| [public.expenses](public.expenses.md)                                 | 11      | Hecho central: alguien pagó una cantidad por algo. El saldo no se guarda, se calcula a partir de estas filas.  | BASE TABLE |
| [public.group_invites](public.group_invites.md)                       | 8       | Códigos de invitación para entrar en un grupo. Caducan y son de un solo uso. Solo se tocan mediante funciones. | BASE TABLE |
| [public.members](public.members.md)                                   | 6       | Una persona dentro de un grupo. Se enlaza con la cuenta de login de Supabase.                                  | BASE TABLE |
| [public.recurring_expense_splits](public.recurring_expense_splits.md) | 6       | Reparto de una plantilla recurrente. Igual que expense_splits.                                                 | BASE TABLE |
| [public.recurring_expenses](public.recurring_expenses.md)             | 10      | Plantilla de un gasto que se repite cada mes. No es un gasto: genera uno real cada mes.                        | BASE TABLE |
| [public.settlements](public.settlements.md)                           | 9       | Pagos entre dos miembros para saldar deuda. No son gastos: no hay compra ni categoría.                         | BASE TABLE |

## Stored procedures and functions

| Name                   | ReturnType | Arguments                                                                                                                                                                              | Type     |
| ---------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| auth.uid               | uuid       |                                                                                                                                                                                        | FUNCTION |
| public.create_expense  | uuid       | p_id uuid, p_group_id uuid, p_paid_id uuid, p_amount_cents bigint, p_description text, p_splits jsonb, p_category_id uuid DEFAULT NULL::uuid, p_expense_date date DEFAULT CURRENT_DATE | FUNCTION |
| public.create_group    | uuid       | p_name text, p_display_name text                                                                                                                                                       | FUNCTION |
| public.create_invite   | text       | p_group_id uuid                                                                                                                                                                        | FUNCTION |
| public.is_group_member | bool       | p_group_id uuid                                                                                                                                                                        | FUNCTION |
| public.join_group      | uuid       | p_code text, p_display_name text                                                                                                                                                       | FUNCTION |
| public.set_updated_at  | trigger    |                                                                                                                                                                                        | FUNCTION |

## Relations

```mermaid
erDiagram

"public.categories" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.expense_splits" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.expense_splits" }o--|| "public.members" : "FOREIGN KEY (member_id, group_id) REFERENCES members(id, group_id)"
"public.expense_splits" }o--|| "public.expenses" : "FOREIGN KEY (expense_id, group_id) REFERENCES expenses(id, group_id) ON DELETE CASCADE"
"public.expenses" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.expenses" }o--|| "public.members" : "FOREIGN KEY (paid_id, group_id) REFERENCES members(id, group_id)"
"public.expenses" }o--|| "public.categories" : "FOREIGN KEY (category_id, group_id) REFERENCES categories(id, group_id) ON DELETE SET NULL (category_id)"
"public.expenses" }o--|| "public.recurring_expenses" : "FOREIGN KEY (recurring_expense_id, group_id) REFERENCES recurring_expenses(id, group_id) ON DELETE SET NULL (recurring_expense_id)"
"public.group_invites" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id) ON DELETE CASCADE"
"public.group_invites" }o--o| "public.members" : "FOREIGN KEY (used_by) REFERENCES members(id)"
"public.group_invites" }o--|| "public.members" : "FOREIGN KEY (created_by, group_id) REFERENCES members(id, group_id)"
"public.members" }o--|| "auth.users" : "FOREIGN KEY (user_id) REFERENCES auth.users(id)"
"public.members" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.recurring_expense_splits" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.recurring_expense_splits" }o--|| "public.members" : "FOREIGN KEY (member_id, group_id) REFERENCES members(id, group_id)"
"public.recurring_expense_splits" }o--|| "public.recurring_expenses" : "FOREIGN KEY (recurring_expense_id, group_id) REFERENCES recurring_expenses(id, group_id) ON DELETE CASCADE"
"public.recurring_expenses" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.recurring_expenses" }o--|| "public.members" : "FOREIGN KEY (paid_id, group_id) REFERENCES members(id, group_id)"
"public.recurring_expenses" }o--|| "public.categories" : "FOREIGN KEY (category_id, group_id) REFERENCES categories(id, group_id) ON DELETE SET NULL (category_id)"
"public.settlements" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.settlements" }o--|| "public.members" : "FOREIGN KEY (from_member_id, group_id) REFERENCES members(id, group_id)"
"public.settlements" }o--|| "public.members" : "FOREIGN KEY (to_member_id, group_id) REFERENCES members(id, group_id)"

"auth.users" {
  uuid id
}
"public.categories" {
  text category_name
  timestamp_with_time_zone created_at
  timestamp_with_time_zone deleted_at
  uuid group_id FK
  uuid id
  timestamp_with_time_zone updated_at
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
"public.members" {
  timestamp_with_time_zone created_at
  text display_name
  uuid group_id FK
  uuid id
  timestamp_with_time_zone updated_at
  uuid user_id FK
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
```

---

> Generated by [tbls](https://github.com/k1LoW/tbls)
