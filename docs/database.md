# Hestia: documentación de la base de datos

Gestor de gastos personales y familiares. Base de datos **PostgreSQL en Supabase** (plan gratuito), creada y versionada con **migraciones** en `supabase/migrations/`.

> Convenciones: nombres de tablas y columnas en inglés y `snake_case`, identificadores `uuid`, dinero en **céntimos** (enteros), todas las tablas con `created_at`.

> Referencia técnica generada automáticamente a partir de las migraciones: [database/README.md](database/README.md)

---

## 1. Decisiones de diseño

| Decisión | Por qué |
|---|---|
| **Modelo de hechos**: se guardan los gastos, no los saldos | Dos móviles escribiendo un saldo se pisan (*lost update*). Con gastos solo se añaden filas, y el saldo se **calcula** sumándolas |
| **Dinero en céntimos** (`bigint`) | 20 € = `2000`. Los decimales de coma flotante acumulan errores de redondeo |
| **`uuid` como identificador** | Cada dispositivo puede generar ids sin coordinarse y sin riesgo de colisión |
| **Migraciones, nunca clicar en el panel** | La historia de la base de datos queda en git y se puede reconstruir desde cero |
| **Una migración ya aplicada no se toca** | Supabase solo ejecuta las nuevas. Los errores se arreglan con otra migración (`alter table ...`) |
| **Fecha del gasto como `date`** | Un gasto del 31 de octubre a las 23:30 no debe pasar a noviembre por la zona horaria |
| **Borrado suave (`deleted_at`)** | El otro móvil se entera del borrado al sincronizar y se puede deshacer |
| **La lógica de saldos vive en Kotlin** (dominio), no en la base de datos | Se puede probar con tests y no depende del proveedor (Clean Architecture) |
| **Escritura delicada solo por funciones** | Crear grupos, entrar en uno o crear un gasto con su reparto exigen varias operaciones atómicas y comprobaciones |
| **El móvil genera los ids** | Permite crear gastos sin conexión, y reintentar un envío sin duplicar nada |
| **`updated_at` automático** | Al recuperar la conexión, el móvil pide "lo que cambió desde la última vez" |
| **Los gastos recurrentes los genera la base de datos** | Una tarea programada (pg_cron) crea cada día los gastos que tocan, y recupera los atrasados si el proyecto estuvo pausado |
| **Nada se borra de verdad** | Un borrado real no llega a un móvil que estaba sin conexión. Gastos, pagos y categorías usan `deleted_at` |

---

## 2. Diagrama

Las flechas van del lado "1" al lado "N". `1:N` significa "uno a muchos".

```
                   ┌───────────────┐
                   │ expense_groups│
                   └─┬──┬──┬──┬──┬─┘
        ┌────────────┘  │  │  │  └─────────────┐
        ▼ 1:N           │  │  │                ▼ 1:N
   ┌─────────┐          │  │  │         ┌──────────────┐
   │ members │          │  │  │         │ group_invites│
   └─┬─┬─┬─┬─┘          │  │  │         └──────────────┘
     │ │ │ │            │  │  │
     │ │ │ │      1:N   ▼  │  ▼ 1:N
     │ │ │ │   ┌────────────┐  ┌────────────┐
     │ │ │ └──▶│  expenses  │◀─│ categories │
     │ │ │     └──┬──────▲──┘  └────────────┘
     │ │ │  1:N   │      │ 1:N (plantilla)
     │ │ │        ▼      │
     │ │ │  ┌───────────────┐   ┌────────────────────┐
     │ │ └─▶│ expense_splits│   │ recurring_expenses │
     │ │    └───────────────┘   └─────────┬──────────┘
     │ │                                  │ 1:N
     │ │ 1:N (from / to)                  ▼
     │ └──────▶ ┌─────────────┐   ┌─────────────────────────┐
     │          │ settlements │   │ recurring_expense_splits│
     │          └─────────────┘   └─────────────────────────┘
     └─ (los miembros también se relacionan con los repartos de las plantillas)
```

Resumen de relaciones:

| Relación | Significado |
|---|---|
| `expense_groups` 1:N `members` | Una familia tiene varias personas |
| `expense_groups` 1:N `expenses`, `categories`, `settlements`, plantillas, invitaciones | Todo cuelga de un grupo |
| `members` 1:N `expenses` (`paid_id`) | Una persona paga varios gastos |
| `expenses` 1:N `expense_splits` | Un gasto se divide en varias partes |
| `members` 1:N `expense_splits` | Una persona tiene varias partes que pagar |
| `categories` 1:N `expenses` | Una categoría agrupa varios gastos (opcional) |
| `recurring_expenses` 1:N `expenses` | Una plantilla genera un gasto cada mes |
| `members` 1:N `settlements` (de dos formas) | Quién paga y quién recibe un pago de saldo |

---

## 3. Tablas

### `expense_groups`: una familia
| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | Clave primaria |
| `name` | text | Obligatorio, no vacío |
| `created_at` | timestamptz | Automático |
| `updated_at` | timestamptz | Automático (trigger) |

### `members`: una persona dentro de un grupo
| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | Clave primaria |
| `group_id` | uuid | → `expense_groups` |
| `user_id` | uuid | → `auth.users` (la cuenta de login de Supabase) |
| `display_name` | text | Obligatorio, no vacío |
| `created_at` | timestamptz | Automático |
| `updated_at` | timestamptz | Automático (trigger) |

Restricciones: `unique (group_id, user_id)` (una persona no está dos veces en el mismo grupo) y `unique (id, group_id)` (necesaria para las claves compuestas).

### `categories`: tipos de gasto de cada familia
| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | → `expense_groups` |
| `category_name` | text | Obligatorio, no vacío |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | Automático (trigger) |
| `deleted_at` | timestamptz | **Opcional**. Con valor = categoría borrada |

Restricciones: `unique (id, group_id)` y un índice único **solo entre categorías activas** (`unique (group_id, category_name) where deleted_at is null`), para poder volver a crear una categoría que se borró.

### `expenses`: el hecho central, "alguien pagó X por Y"
| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | → `expense_groups` |
| `paid_id` | uuid | Quién pagó. Clave compuesta `(paid_id, group_id)` → `members` |
| `category_id` | uuid | **Opcional**. Clave compuesta `(category_id, group_id)` → `categories`, `on delete set null (category_id)` |
| `amount_cents` | bigint | Mayor que 0 |
| `description` | text | No vacío |
| `expense_date` | date | Por defecto, hoy |
| `created_at` | timestamptz | |
| `recurring_expense_id` | uuid | **Opcional**. Plantilla de la que viene. Clave compuesta, `on delete set null (recurring_expense_id)` |
| `deleted_at` | timestamptz | **Opcional**. Con valor = gasto borrado |
| `updated_at` | timestamptz | Automático (trigger) |

Restricciones: `unique (id, group_id)` y un índice único parcial `(recurring_expense_id, expense_date)` cuando hay plantilla, para que una plantilla no genere dos veces el mismo día.

### `expense_splits`: el reparto de cada gasto
Una fila por persona y por gasto: "de este gasto, a este miembro le toca esta parte".

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `expense_id` | uuid | Clave compuesta `(expense_id, group_id)` → `expenses`, `on delete cascade` |
| `group_id` | uuid | → `expense_groups` |
| `member_id` | uuid | Clave compuesta `(member_id, group_id)` → `members` |
| `share_cents` | bigint | Mayor que 0 |
| `created_at` | timestamptz | |

Restricción: `unique (expense_id, member_id)`.

Un **gasto personal** es un gasto con un solo reparto, a nombre de quien pagó.

### `settlements`: pagos entre personas para saldar deuda
Distinto de un gasto: no se compró nada ni tiene categoría. "Papá le pagó 7 € a mamá."

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | → `expense_groups` |
| `from_member_id` | uuid | Quién paga. Clave compuesta con `group_id` |
| `to_member_id` | uuid | Quién recibe. Clave compuesta con `group_id` |
| `amount_cents` | bigint | Mayor que 0 |
| `settlement_date` | date | Por defecto, hoy |
| `deleted_at` | timestamptz | **Opcional** |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | Automático (trigger) |

Restricción: `check (from_member_id <> to_member_id)`.

### `recurring_expenses`: plantillas de gastos que se repiten cada mes
Una plantilla **no es un gasto**: cada mes se genera un `expense` real a partir de ella. Si sube el alquiler, se pausa la plantilla y se crea una nueva; el historial de lo pagado se conserva, porque los gastos ya generados no cambian.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | |
| `paid_id` | uuid | Clave compuesta con `group_id` |
| `category_id` | uuid | **Opcional**. Clave compuesta, `set null (category_id)` |
| `amount_cents` | bigint | Mayor que 0 |
| `description` | text | No vacío |
| `day_of_month` | smallint | Entre 1 y 28 (el 29, 30 y 31 no existen en todos los meses) |
| `is_active` | boolean | Por defecto `true`. Sirve para pausar o terminar sin borrar |
| `next_run_on` | date | Próxima fecha en la que toca generar un gasto. La actualiza solo `generate_recurring_expenses` |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | Automático (trigger) |

Restricción: `unique (id, group_id)`.

### `recurring_expense_splits`: el reparto de cada plantilla
Igual que `expense_splits`, pero apuntando a `recurring_expenses`, con `unique (recurring_expense_id, member_id)`.

### `group_invites`: códigos para entrar en un grupo
| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | → `expense_groups`, `on delete cascade` |
| `code` | text | **Único en toda la tabla**: quien lo canjea no dice a qué grupo entra |
| `created_by` | uuid | Clave compuesta `(created_by, group_id)` → `members` |
| `expires_at` | timestamptz | Caducidad |
| `used_at` | timestamptz | **Opcional**. Vacío = sin usar |
| `used_by` | uuid | **Opcional**. → `members(id)`: el miembro que nació con esa invitación |
| `created_at` | timestamptz | |

---

## 4. Conceptos clave (para estudiar)

### Clave foránea compuesta
Una clave foránea normal solo garantiza que la fila apuntada **existe**. La compuesta `(paid_id, group_id) → members (id, group_id)` garantiza además que **pertenece al mismo grupo**. Por eso la base de datos rechaza, por ejemplo, un gasto de la familia A pagado por un miembro de la familia B.

Para poder apuntar a una pareja de columnas, la tabla apuntada necesita `unique (id, group_id)`. Es una formalidad (el `id` ya es único) que Postgres exige.

Si `category_id` está vacío, la clave compuesta **no se comprueba** (comportamiento normal de Postgres con valores nulos), y por eso la categoría es opcional.

### `on delete`: qué pasa con las filas que apuntan
| Opción | Efecto | Dónde se usa |
|---|---|---|
| *(por defecto)* | No deja borrar si hay filas apuntando | `members` con repartos |
| `cascade` | Borra también las filas que apuntan | Repartos al borrar su gasto; invitaciones al borrar su grupo |
| `set null` | Vacía la columna que apunta | Gasto sin categoría o sin plantilla |
| `set null (columna)` | Igual, pero solo esa columna | Obligatorio con claves compuestas: un `set null` normal intentaría vaciar también `group_id`, que es obligatorio |

### Acceso en dos capas: GRANT y RLS
Desde Supabase 2026, las tablas nuevas **no se exponen** a la API por defecto, así que hacen falta las dos capas:

| Capa | Qué decide |
|---|---|
| **GRANT** | Si el rol puede tocar la tabla (o columnas concretas) en absoluto |
| **Policy (RLS)** | Qué filas concretas puede ver o modificar |

- Sin GRANT, la policy no sirve: falla con *permission denied*.
- Con GRANT pero sin policy, no se ve ninguna fila.
- Todo se da a `authenticated` (usuarios con sesión), **nunca a `anon`**.
- Los permisos pueden ir **por columna**: `grant update (display_name) on members ...`. Así nadie puede, por ejemplo, cambiar su propio `group_id` y "mudarse" a otra familia.

Cláusulas de una policy:
- `using`: qué filas **existentes** puedes ver, modificar o borrar.
- `with check`: qué filas puedes **dejar guardadas** al insertar o modificar.
- `for select` solo lleva `using`; `for insert` solo `with check`; `for update` lleva las dos.

### `security definer` y por qué hay una función auxiliar
La condición de casi todas las reglas es "el usuario es miembro del grupo de esa fila". Para comprobarlo hay que consultar `members`, que también tiene RLS, y eso provocaría un bucle de recursión. La función `is_group_member` se ejecuta con los permisos de su dueño (`security definer`) y se salta el RLS solo dentro de ella.

En toda función `security definer`:
- `set search_path = ''` es obligatorio por seguridad, y por eso las tablas se escriben completas (`public.members`).
- La identidad se saca de `auth.uid()` (del token de sesión) y **nunca** se recibe como parámetro, porque se podría falsificar.
- Se revoca el permiso a `public` y `anon` y se concede solo a `authenticated`.

### Atomicidad
Una función es una sola transacción: o se hace todo o no se hace nada. Es lo que evita un gasto sin reparto, o un grupo sin ningún miembro.

### Trigger
Un trigger es código que la base de datos ejecuta **sola** cuando pasa algo en una tabla. Aquí se usa uno solo, `set_updated_at`, que pone `updated_at = now()` en cada `update`. Es el caso en el que un trigger sí es la herramienta adecuada: el cliente no tiene permiso para escribir esa columna, así que nadie puede falsearla.

### Tarea programada (pg_cron)
`pg_cron` es una extensión de PostgreSQL que ejecuta consultas en un horario, como el `cron` de Linux. Aquí se programa una sola tarea que llama a `generate_recurring_expenses()` cada día a las 02:00 UTC. La lógica vive en la función, y la tarea solo la invoca. Se activa desde el panel de Supabase (Integrations → Cron) y la migración `schedule_recurring_expenses` registra la tarea con `cron.schedule`.

### Por qué falla un saldo guardado (*lost update*)
Si cada móvil guarda **su versión del saldo** en una única casilla, el último que escribe pisa al otro. En el ejemplo de 20 € y 6 €, el saldo real era ±7 y en el servidor quedaba +10 o -3 según el orden. Con el modelo de hechos cada móvil añade su fila y no pisa nada.

---

## 5. Funciones

| Función | Qué hace |
|---|---|
| `is_group_member(p_group_id)` | Devuelve si el usuario actual pertenece a ese grupo. La usan todas las policies |
| `create_group(p_name, p_display_name)` | Crea el grupo y el primer miembro (el que lo crea) en una transacción. Devuelve el id del grupo |
| `create_invite(p_group_id)` | Comprueba que eres miembro, genera un código de 12 caracteres que **caduca a los 7 días** y lo devuelve |
| `join_group(p_code, p_display_name)` | Canjea un código válido (no usado y no caducado), te añade como miembro y marca la invitación como usada. Bloquea la fila (`for update`) para que dos personas no usen el mismo código a la vez. Un único mensaje de error para código inexistente, caducado o usado |
| `create_expense(p_id, ...)` | Recibe el **id generado por el móvil**. Comprueba que eres miembro y que las partes **suman exactamente el importe**, y guarda el gasto y su reparto de forma atómica. Si ese gasto ya existe en tu grupo (un reintento), devuelve el mismo id sin duplicar. Si el id lo usa otro grupo, falla |
| `create_recurring_expense(p_id, ...)` | Igual que `create_expense`, pero crea una **plantilla** con su reparto de forma atómica. Valida el día (1 a 28) y que las partes sumen, calcula la primera fecha (`next_run_on`) y es idempotente por id |
| `set_recurring_expense_active(p_id, p_active)` | Pausa o reactiva una plantilla. Al reactivar recalcula `next_run_on` a la próxima fecha futura, para no generar lo que pasó mientras estaba pausada |
| `generate_recurring_expenses()` | Crea los gastos y repartos de las plantillas activas cuya fecha ya llegó. **Solo la ejecuta la tarea programada**: ningún usuario puede llamarla |
| `next_occurrence(p_day, p_from)` | Auxiliar interna: primera fecha igual o posterior a `p_from` que cae en el día `p_day` del mes |

`create_expense` recibe el reparto como JSON:

```json
[
  { "member_id": "id-de-mamá", "share_cents": 1000 },
  { "member_id": "id-de-papá", "share_cents": 1000 }
]
```

Parámetros, en orden: `p_id`, `p_group_id`, `p_paid_id`, `p_amount_cents`, `p_description`, `p_splits`, y los opcionales `p_category_id` y `p_expense_date`.

---

## 6. Permisos por tabla

| Tabla | Leer | Crear | Editar | Borrar |
|---|---|---|---|---|
| `expense_groups` | Miembros | `create_group` | Solo `name` | No |
| `members` | Miembros del grupo | `create_group`, `join_group` | Solo tu propio `display_name` | No |
| `categories` | Miembros | Miembros (con id propio) | Solo `category_name` y `deleted_at` | Suave (`deleted_at`) |
| `expenses` | Miembros | `create_expense` | Solo `description`, `category_id`, `expense_date`, `deleted_at` | Suave (`deleted_at`) |
| `expense_splits` | Miembros | `create_expense` | No | Por cascada con su gasto |
| `settlements` | Miembros | Miembros (6 columnas, incluido el `id`) | Solo `deleted_at` | Suave (`deleted_at`) |
| `recurring_expenses` | Miembros | `create_recurring_expense` | Solo pausar o reactivar, con `set_recurring_expense_active` | No (se pausa) |
| `recurring_expense_splits` | Miembros | `create_recurring_expense` | No | Por cascada con su plantilla |
| `group_invites` | Nadie | `create_invite` | `join_group` | No |

Notas:
- **Importe y pagador de un gasto no se editan.** Cambiarlos obligaría a rehacer el reparto. Si te equivocas, se marca el gasto como borrado y se crea uno nuevo.
- Las filas con `deleted_at` rellenado **siguen siendo visibles** para la lectura: el otro móvil necesita verlas para sincronizar el borrado. La app es la que decide no mostrarlas.
- En `settlements` el `insert` está limitado por columnas, para que nadie falsee `created_at` ni cree un pago ya borrado.

---

## 7. Cómo se calcula un saldo (lógica del dominio, en Kotlin)

El saldo no se guarda. Se calcula por miembro, **ignorando** los gastos y pagos con `deleted_at` rellenado:

```
saldo(miembro) =  Σ amount_cents de los gastos que pagó
               −  Σ share_cents de sus repartos
               +  Σ amount_cents de los pagos (settlements) que hizo
               −  Σ amount_cents de los pagos que recibió
```

Positivo = le deben dinero. Negativo = debe dinero.

Ejemplo del diseño original:

| Hecho | Mamá | Papá |
|---|---|---|
| Mamá paga 20 € (partes: 10 € y 10 €) | +2000 − 1000 = +1000 | −1000 |
| Papá paga 6 € (partes: 3 € y 3 €) | −300 | +600 − 300 = +300 |
| **Saldo total** | **+700** | **−700** |
| Papá le paga 7 € a mamá (`settlement`) | +700 − 700 = 0 | −700 + 700 = 0 |

Como el reparto de un gasto lo valida `create_expense` (suma exacta), el cálculo cuadra siempre: la suma de todos los saldos de un grupo es 0.

---

## 8. Tiempo real

Publicadas en Realtime: `expenses`, `expense_splits`, `settlements`, `categories` y `members`. El tiempo real **respeta las reglas de acceso**: cada usuario solo recibe los cambios de sus grupos. Se puede filtrar por `group_id`, y los repartos lo llevan precisamente para eso.

Las plantillas no están publicadas porque cambian poco. Se añaden con una migración cuando haga falta.

---

## 8 bis. Sincronización sin conexión

Objetivo: poder crear gastos, pagos y categorías sin conexión y que se sincronicen solos al recuperarla.

| Pieza | Cómo funciona |
|---|---|
| **Crear** | El móvil genera el uuid, lo guarda en local y lo añade a una cola de envío |
| **Reintentos** | `create_expense` devuelve el mismo id si ya existe en el grupo. Los pagos usan `on conflict (id) do nothing` y las categorías fallan por clave duplicada, que el móvil trata como "ya enviado" |
| **Recuperar lo que cambió** | Al volver la conexión, primero envía la cola y luego pide las filas con `updated_at` mayor que el último que recibió. Para repartos se usa `created_at`, porque no se editan |
| **Cursor** | Siempre el `updated_at` que **manda el servidor**, nunca la hora del móvil (los relojes se desajustan) |
| **Borrados** | Son borrados suaves (`deleted_at`), así que llegan como una actualización más |
| **Conflictos** | Gana el último en llegar al servidor. Para una familia es suficiente |

Solo funcionan con conexión: crear un grupo, unirse con un código y crear plantillas recurrentes. Los saldos que se ven sin conexión se calculan con lo que el móvil tiene y se corrigen al sincronizar.

---

## 8 ter. Gastos recurrentes

Una **plantilla** (`recurring_expenses` y su reparto) genera un gasto real (`expenses`) cada mes. Así, todo lo que ves en un mes son filas de `expenses`, vengan de una plantilla o sean compras puntuales.

| Momento | Qué pasa |
|---|---|
| **Crear** | `create_recurring_expense` guarda la plantilla y calcula `next_run_on`: la primera fecha, desde hoy, que cae en el día elegido |
| **Cada día, 02:00 UTC** | `generate_recurring_expenses` busca las plantillas activas con `next_run_on <= hoy`. Por cada una crea un gasto con `expense_date = next_run_on`, copia el reparto de la plantilla y avanza `next_run_on` un mes. Repite mientras queden fechas atrasadas |
| **Pausar** | `set_recurring_expense_active(id, false)`. La plantilla deja de generar, sin borrar nada |
| **Reactivar** | `set_recurring_expense_active(id, true)`. Salta a la próxima fecha futura, y no genera los meses en que estuvo pausada |

Casos que cubre el diseño:

| Caso | Cómo se resuelve |
|---|---|
| El proyecto gratuito se pausó una semana o más | Al volver, la función recupera los meses perdidos con la fecha que les correspondía |
| La tarea se ejecuta dos veces | El índice único `(recurring_expense_id, expense_date)` impide duplicados |
| Alguien borra (suave) un gasto generado | No se vuelve a generar: la fila sigue existiendo |
| Día 29, 30 o 31 | No existen en todos los meses, por eso el día va de 1 a 28 |
| "Hoy" cerca de medianoche | Se calcula en la zona horaria `Europe/Madrid`, no en UTC |
| Cambiar importe, pagador o reparto | Se pausa la plantilla y se crea una nueva |

---

## 9. Orden de las migraciones

Los nombres son orientativos: lo que importa es el orden.

| # | Migración | Contenido |
|---|---|---|
| 1 | `create_expense_groups` | Tabla de grupos |
| 2 | `create_members` | Miembros |
| 3 | `create_categories` | Categorías |
| 4 | `create_expenses` | Gastos |
| 5 | `create_expense_splits` | Repartos |
| 6 | `create_recurring_expenses` | Plantillas |
| 7 | `create_recurring_expense_splits` | Reparto de plantillas |
| 8 | `add_recurring_expense_id_to_expenses` | Enlace gasto → plantilla |
| 9 | función `is_group_member` | Función auxiliar de acceso |
| 10 | `create_settlements` | Pagos entre miembros + `unique (id, group_id)` en `members` |
| 11 | `enforce_group_integrity` | Claves compuestas y `group_id` en los repartos |
| 12 | `add_deleted_at_to_expenses` | Borrado suave |
| 13 | `add_categories_access` | GRANT y policy de categorías |
| 14 | `add_groups_and_members_access` | GRANT y policies de grupos y miembros |
| 15 | `create_group_function` | Función `create_group` |
| 16 | `create_group_invites` | Tabla de invitaciones |
| 17 | `add_invite_functions` | `create_invite` y `join_group` |
| 18 | `add_create_expense_function` | Función `create_expense` |
| 19 | `add_ledger_access` | GRANT y policies de gastos, repartos, pagos y plantillas |
| 20 | `enable_realtime` | Publicación en Realtime |
| 21 | `prepare_offline_sync` | `updated_at` con trigger, ids del móvil, `create_expense` idempotente y categorías con borrado suave |
| 22 | `add_schema_comments` | Descripciones de tablas y columnas, que usa la documentación generada |
| 23 | `add_next_run_on_to_recurring_expenses` | Columna `next_run_on` e índice único parcial en `expenses` |
| 24 | `add_recurring_expense_functions` | `create_recurring_expense`, `set_recurring_expense_active`, `generate_recurring_expenses` y `next_occurrence` |
| 25 | `schedule_recurring_expenses` | Tarea diaria de pg_cron |

---

## 10. Flujo de trabajo con migraciones

```powershell
npx supabase migration new nombre_descriptivo    # crea un archivo SQL vacío
# escribes el SQL dentro de ese archivo
npx supabase db push --linked                    # lo aplica en la nube
git add supabase/migrations
git commit -m "feat(db): descripción del cambio"
```

- Si el SQL da error y **no llegó a aplicarse**, se puede corregir ese mismo archivo y repetir el `push`.
- Si ya se aplicó, **no se toca**: se crea una migración nueva.
- `npx supabase migration list` muestra qué migraciones hay y cuáles están aplicadas.

### Lista de comprobación antes de aplicar una migración
1. El nombre del `alter table ... enable row level security` es **el mismo** que el del `create table`.
2. Hay coma entre todas las definiciones, y **no** hay coma tras la última.
3. `on delete ...` va pegado al `references`, y `not null` antes del `references`.
4. Los permisos por columna llevan paréntesis: `update (name)`.
5. Una policy termina con un único `;` al final, no después de cada cláusula.
6. Una tabla nueva tiene su **GRANT** además de su policy.
7. El nombre de la tabla de cada `grant` coincide con el de su `on`.

---

## 11. Límites conocidos y pendientes

**Pendiente de base de datos:** nada por ahora.

**Decisiones asumidas:**
- Cualquier miembro puede hacer todo lo permitido en su grupo. No hay roles ni administrador.
- No hay forma de salir de un grupo ni de expulsar a un miembro.
- Las invitaciones caducan a los 7 días (cambiable en `create_invite`).
- Todo miembro tiene cuenta de login (`user_id` obligatorio).
- Las categorías las gestiona cualquier miembro, y no se crean categorías por defecto al crear un grupo.
- Sin conexión, en caso de conflicto gana la última escritura que llega al servidor.
- Crear grupos, unirse con un código y crear plantillas exigen conexión.
- Las plantillas no se editan: para cambiarlas se pausan y se crea otra.
- La generación de gastos recurrentes ocurre una vez al día a las 02:00 UTC, no al instante.

**Plan gratuito de Supabase:**
- Los proyectos gratuitos se **pausan tras una semana de inactividad** y hay que reactivarlos desde el panel. Mientras está pausado no corre la tarea programada, pero al volver recupera los gastos recurrentes atrasados.
- Los límites habituales (500 MB de base de datos y dos proyectos) sobran para este uso.

---

## 12. Cómo se verificó

Se montó una copia local de PostgreSQL 16 simulando Supabase (roles `anon` y `authenticated`, `auth.uid()` y la exposición sin permisos por defecto), con tres usuarios: A y B de la misma familia y C ajeno. Se ejecutaron **62 comprobaciones** sobre el diseño base otras **35** sobre la sincronización sin conexión y otras **48** sobre los gastos recurrentes (145 en total), todas correctas. Cubren:

- Aislamiento entre familias en todas las tablas.
- Que no se puede escribir directamente en las tablas protegidas.
- Que no se pueden mezclar grupos (pagador, reparto, categoría, pagos).
- Que importe y pagador de un gasto no se editan.
- Invitaciones inexistentes, caducadas, usadas y de otro grupo.
- Que `anon` y las peticiones sin sesión no acceden a nada.
- El borrado suave de categorías y la cascada de repartos.
- Que un reintento de `create_expense` no duplica gastos ni repartos, y que un id de otra familia se rechaza.
- Que `updated_at` avanza al editar y que el cliente no puede escribirlo.
- Que un gasto puede usar una categoría borrada (creado sin conexión) y que se puede volver a crear su nombre.
- Plantillas recurrentes: validaciones, reintentos, permisos, pausar y reactivar sin generar atrasos.
- Generación: recuperar meses perdidos, no duplicar al ejecutarla dos veces, no regenerar lo borrado y copiar la categoría y el reparto.
- Que ningún usuario puede ejecutar la generación ni editar `next_run_on`.

El `pg_cron` real tampoco se pudo simular en local: se comprobó en el panel de Supabase que la tarea existe y que la función se ejecuta.

No se pudo probar el servicio de tiempo real, porque es de Supabase y no se puede simular en local.

---

## 13. Preguntas de repaso

Para comprobar que lo entiendes, sin mirar el documento:

1. ¿Por qué se guardan los gastos y no los saldos? ¿Qué pasa con dos móviles escribiendo a la vez?
2. ¿Qué garantiza una clave foránea compuesta que no garantiza una normal?
3. ¿Por qué `on delete set null` normal falla en una clave compuesta, y cómo se arregla?
4. ¿Qué diferencia hay entre un GRANT y una policy? ¿Qué pasa si falta una de las dos?
5. ¿Por qué `is_group_member` necesita `security definer`? ¿Qué problema evita?
6. ¿Por qué la identidad se saca de `auth.uid()` y no se pasa como parámetro?
7. ¿Por qué `create_expense` es una función y no dos `insert` desde la app?
8. ¿Por qué el día de una plantilla solo llega hasta el 28?
9. ¿Por qué el `code` de una invitación es único en toda la tabla y no solo por grupo?
10. Calcula el saldo de cada persona si mamá paga 30 € a medias y papá le paga 5 € a mamá para saldar parte.
11. ¿Por qué el móvil genera el id del gasto en lugar de hacerlo el servidor?
12. ¿Por qué ya no se borra nada de verdad? ¿Qué le pasaría a un móvil que estuvo sin conexión?
13. ¿Por qué el cursor de sincronización es el `updated_at` del servidor y no la hora del móvil?
14. ¿Por qué una plantilla recurrente no es un gasto? ¿Qué ventaja tiene sobre copiar el gasto 12 meses por adelantado?
15. Si el proyecto estuvo pausado dos meses, ¿cómo recupera la función los gastos perdidos sin duplicar ninguno?
16. ¿Por qué al reactivar una plantilla pausada no se generan los meses en que estuvo pausada?
