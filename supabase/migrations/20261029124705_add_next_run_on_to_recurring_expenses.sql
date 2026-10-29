-- Próxima fecha en la que toca generar un gasto a partir de la plantilla
alter table recurring_expenses add column next_run_on date not null;

comment on column recurring_expenses.next_run_on is
  'Próxima fecha en la que toca generar un gasto real. La actualiza solo la función generate_recurring_expenses.';

-- Un mismo día no puede generarse dos veces desde la misma plantilla (protege de ejecuciones repetidas)
create unique index expenses_recurring_date_key
  on expenses (recurring_expense_id, expense_date)
  where recurring_expense_id is not null;
