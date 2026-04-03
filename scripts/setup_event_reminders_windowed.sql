-- ============================================================
-- Recordatorios de eventos basados en ventanas de tiempo
-- Reemplaza el cron diario de las 9 AM por un sistema que
-- envía recordatorios 24h y 2h antes de cada evento.
--
-- Cambios en BD:
--   - Agrega reminder_24h_sent y reminder_2h_sent a eventos
--   - Elimina cron send-event-reminders-daily
--   - Crea cron send-event-reminders-windowed (cada 30 min)
-- ============================================================

-- 1. Agregar flags a la tabla eventos
ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS reminder_24h_sent BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reminder_2h_sent  BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Eliminar cron job anterior (9 AM diario)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-event-reminders-daily') THEN
    PERFORM cron.unschedule('send-event-reminders-daily');
  END IF;
END;
$$;

-- 3. Crear nuevo cron: cada 30 minutos
--    La Edge Function usa ventanas ±15 min alrededor de las marcas 24h y 2h.
--    Los flags reminder_*_sent evitan envíos duplicados.
SELECT cron.schedule(
  'send-event-reminders-windowed',
  '*/30 * * * *',
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

-- Verificar
SELECT jobid, jobname, schedule, active FROM cron.job
WHERE jobname IN ('send-event-reminders-daily', 'send-event-reminders-windowed');
