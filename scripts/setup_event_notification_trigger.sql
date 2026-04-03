-- ============================================================
-- Trigger: notificar creación de evento
-- Propósito: Llamar a la Edge Function send-event-notification
--            cada vez que se inserta un nuevo evento en la tabla eventos.
-- Requiere: Extensión pg_net habilitada en Supabase
-- Ejecutar en: Supabase SQL Editor
-- ============================================================

-- Función que invoca la Edge Function vía HTTP
CREATE OR REPLACE FUNCTION notify_new_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  edge_function_url TEXT;
  service_role_key  TEXT;
  payload           JSONB;
BEGIN
  -- URL de la Edge Function (ajustar con el project ref de Supabase)
  edge_function_url := 'https://otxzwutudsruildrtuzy.supabase.co/functions/v1/send-event-notification';

  -- Service Role Key de Supabase (se puede guardar en app.settings o hardcodear con cuidado)
  -- IMPORTANTE: usar la service_role key, NO la anon key
  SELECT current_setting('app.service_role_key', true) INTO service_role_key;

  -- Payload con los datos del nuevo evento
  payload := jsonb_build_object(
    'event_id',      NEW.id,
    'title',         NEW.titulo,
    'grupo_id',      NEW.grupo_id,
    'organizer_id',  NEW.creado_por,
    'is_public',     NEW.is_public
  );

  -- Llamada asíncrona a la Edge Function (pg_net no bloquea el INSERT)
  PERFORM net.http_post(
    url     := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_role_key
    ),
    body    := payload
  );

  RETURN NEW;
END;
$$;

-- Trigger que se dispara DESPUÉS de cada INSERT en eventos
DROP TRIGGER IF EXISTS trigger_notify_new_event ON eventos;

CREATE TRIGGER trigger_notify_new_event
  AFTER INSERT ON eventos
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_event();
