-- ============================================================
-- pg_cron: recordatorio diario un día antes del evento
-- Propósito: Ejecutar diariamente a las 9:00 AM UTC la Edge Function
--            send-event-reminders que notifica a participantes confirmados
--            y posibles de eventos que ocurren al día siguiente.
-- Requiere: Extensión pg_cron habilitada en Supabase
--           (Dashboard → Database → Extensions → pg_cron)
-- Ejecutar en: Supabase SQL Editor
-- ============================================================

-- Eliminar job existente si ya fue registrado antes (evita duplicados en re-ejecución)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-event-reminders-daily') THEN
    PERFORM cron.unschedule('send-event-reminders-daily');
  END IF;
END;
$$;

-- Registrar job: 9:00 AM UTC todos los días
SELECT cron.schedule(
  'send-event-reminders-daily',   -- nombre del job
  '0 9 * * *',                    -- cron expression: cada día a las 9:00 AM UTC
  $$
    SELECT net.http_post(
      url     := 'https://otxzwutudsruildrtuzy.supabase.co/functions/v1/send-event-reminders',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body    := '{}'::jsonb
    );
  $$
);

-- Verificar que el job quedó registrado
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'send-event-reminders-daily';
