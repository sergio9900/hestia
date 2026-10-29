-- Todos los días a las 02:00 UTC (03:00 o 04:00 en España según la época del año)
select cron.schedule(
  'generate-recurring-expenses',
  '0 2 * * *',
  $$select public.generate_recurring_expenses()$$
);
