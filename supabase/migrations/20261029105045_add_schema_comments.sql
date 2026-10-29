-- Descripciones de tablas y columnas. La documentación generada las incluye.

comment on table expense_groups is 'Una familia o grupo. Todo lo demás cuelga de un grupo.';
comment on column expense_groups.name is 'Nombre visible del grupo.';
comment on column expense_groups.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table members is 'Una persona dentro de un grupo. Se enlaza con la cuenta de login de Supabase.';
comment on column members.user_id is 'Cuenta de login (auth.users) de esta persona.';
comment on column members.display_name is 'Nombre que se muestra en el grupo.';
comment on column members.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table categories is 'Tipos de gasto de cada grupo (supermercado, ocio...). Se borran de forma suave.';
comment on column categories.category_name is 'Nombre de la categoría. Único entre las categorías activas del grupo.';
comment on column categories.deleted_at is 'Si tiene valor, la categoría está borrada. Nunca se borra de verdad.';
comment on column categories.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table expenses is 'Hecho central: alguien pagó una cantidad por algo. El saldo no se guarda, se calcula a partir de estas filas.';
comment on column expenses.paid_id is 'Miembro que pagó el gasto.';
comment on column expenses.category_id is 'Categoría opcional del gasto.';
comment on column expenses.amount_cents is 'Importe en céntimos (20 EUR = 2000). Siempre mayor que 0.';
comment on column expenses.expense_date is 'Día del gasto, sin hora, para que no cambie de mes por la zona horaria.';
comment on column expenses.recurring_expense_id is 'Plantilla recurrente de la que viene este gasto, si la hay.';
comment on column expenses.deleted_at is 'Si tiene valor, el gasto está borrado. Nunca se borra de verdad.';
comment on column expenses.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table expense_splits is 'Reparto de un gasto: una fila por miembro con la parte que le toca. Se crean junto al gasto y no se editan.';
comment on column expense_splits.group_id is 'Grupo del gasto. Permite filtrar y comprobar la integridad entre grupos.';
comment on column expense_splits.share_cents is 'Parte que le toca al miembro, en céntimos. Las partes de un gasto suman su importe.';

comment on table settlements is 'Pagos entre dos miembros para saldar deuda. No son gastos: no hay compra ni categoría.';
comment on column settlements.from_member_id is 'Miembro que paga.';
comment on column settlements.to_member_id is 'Miembro que recibe el pago.';
comment on column settlements.amount_cents is 'Importe en céntimos. Siempre mayor que 0.';
comment on column settlements.deleted_at is 'Si tiene valor, el pago está borrado. Nunca se borra de verdad.';
comment on column settlements.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table recurring_expenses is 'Plantilla de un gasto que se repite cada mes. No es un gasto: genera uno real cada mes.';
comment on column recurring_expenses.day_of_month is 'Día del mes en que toca, entre 1 y 28 (el 29, 30 y 31 no existen en todos los meses).';
comment on column recurring_expenses.is_active is 'Permite pausar o terminar la plantilla sin borrarla.';
comment on column recurring_expenses.updated_at is 'Se actualiza sola con un trigger. Sirve para sincronizar cambios.';

comment on table recurring_expense_splits is 'Reparto de una plantilla recurrente. Igual que expense_splits.';

comment on table group_invites is 'Códigos de invitación para entrar en un grupo. Caducan y son de un solo uso. Solo se tocan mediante funciones.';
comment on column group_invites.code is 'Código que se comparte. Único en toda la tabla.';
comment on column group_invites.expires_at is 'Fecha de caducidad de la invitación.';
comment on column group_invites.used_at is 'Cuándo se canjeó. Vacío significa sin usar.';
comment on column group_invites.used_by is 'Miembro que entró en el grupo con esta invitación.';
