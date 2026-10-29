# public.categories

## Description

Tipos de gasto de cada grupo (supermercado, ocio...). Se borran de forma suave.

## Columns

| Name          | Type                     | Default           | Nullable | Children                                                                                        | Parents                                           | Comment                                                               |
| ------------- | ------------------------ | ----------------- | -------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| category_name | text                     |                   | false    |                                                                                                 |                                                   | Nombre de la categoría. Único entre las categorías activas del grupo. |
| created_at    | timestamp with time zone | now()             | false    |                                                                                                 |                                                   |                                                                       |
| deleted_at    | timestamp with time zone |                   | true     |                                                                                                 |                                                   | Si tiene valor, la categoría está borrada. Nunca se borra de verdad.  |
| group_id      | uuid                     |                   | false    | [public.expenses](public.expenses.md) [public.recurring_expenses](public.recurring_expenses.md) | [public.expense_groups](public.expense_groups.md) |                                                                       |
| id            | uuid                     | gen_random_uuid() | false    | [public.expenses](public.expenses.md) [public.recurring_expenses](public.recurring_expenses.md) |                                                   |                                                                       |
| updated_at    | timestamp with time zone | now()             | false    |                                                                                                 |                                                   | Se actualiza sola con un trigger. Sirve para sincronizar cambios.     |

## Constraints

| Name                           | Type        | Definition                                           |
| ------------------------------ | ----------- | ---------------------------------------------------- |
| categories_category_name_check | CHECK       | CHECK ((length(TRIM(BOTH FROM category_name)) > 0))  |
| categories_group_id_fkey       | FOREIGN KEY | FOREIGN KEY (group_id) REFERENCES expense_groups(id) |
| categories_id_group_id_key     | UNIQUE      | UNIQUE (id, group_id)                                |
| categories_pkey                | PRIMARY KEY | PRIMARY KEY (id)                                     |

## Indexes

| Name                             | Definition                                                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| categories_group_name_active_key | CREATE UNIQUE INDEX categories_group_name_active_key ON public.categories USING btree (group_id, category_name) WHERE (deleted_at IS NULL) |
| categories_group_updated_idx     | CREATE INDEX categories_group_updated_idx ON public.categories USING btree (group_id, updated_at)                                          |
| categories_id_group_id_key       | CREATE UNIQUE INDEX categories_id_group_id_key ON public.categories USING btree (id, group_id)                                             |
| categories_pkey                  | CREATE UNIQUE INDEX categories_pkey ON public.categories USING btree (id)                                                                  |

## Triggers

| Name           | Definition                                                                                                      |
| -------------- | --------------------------------------------------------------------------------------------------------------- |
| set_updated_at | CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION set_updated_at() |

## Relations

```mermaid
erDiagram

"public.categories" }o--|| "public.expense_groups" : "FOREIGN KEY (group_id) REFERENCES expense_groups(id)"
"public.expenses" }o--|| "public.categories" : "FOREIGN KEY (category_id, group_id) REFERENCES categories(id, group_id) ON DELETE SET NULL (category_id)"
"public.recurring_expenses" }o--|| "public.categories" : "FOREIGN KEY (category_id, group_id) REFERENCES categories(id, group_id) ON DELETE SET NULL (category_id)"

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
```

---

> Generated by [tbls](https://github.com/k1LoW/tbls)
