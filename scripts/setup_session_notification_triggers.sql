-- ============================================================
-- Triggers: notificaciones FCM para eventos de sesión grupal
-- Edge Function: send-session-notification
--
-- Eventos cubiertos:
--   1. session_started → miembros del grupo (excepto iniciador)
--   2. member_joined   → participantes aprobados en sesión (excepto el que se unió)
--   3. session_ended   → todos los participantes aprobados en sesión
-- ============================================================

-- ── Trigger 1: Sesión iniciada ───────────────────────────────
CREATE OR REPLACE FUNCTION notify_session_started()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://otxzwutudsruildrtuzy.supabase.co/functions/v1/send-session-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := jsonb_build_object(
      'event_type',    'session_started',
      'sesion_id',     NEW.id,
      'grupo_id',      NEW.grupo_id,
      'iniciada_por',  NEW.iniciada_por,
      'nombre_sesion', COALESCE(NEW.nombre_sesion, 'Sesión de ruta')
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_session_started ON sesiones_ruta_activa;
CREATE TRIGGER trigger_session_started
  AFTER INSERT ON sesiones_ruta_activa
  FOR EACH ROW EXECUTE FUNCTION notify_session_started();

-- ── Trigger 2: Miembro aprobado ──────────────────────────────
CREATE OR REPLACE FUNCTION notify_member_joined()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.estado_aprobacion = 'aprobado'
     AND (OLD.estado_aprobacion IS DISTINCT FROM 'aprobado') THEN
    PERFORM net.http_post(
      url     := 'https://otxzwutudsruildrtuzy.supabase.co/functions/v1/send-session-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body := jsonb_build_object(
        'event_type', 'member_joined',
        'sesion_id',  NEW.sesion_id,
        'usuario_id', NEW.usuario_id
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_member_joined ON participantes_sesion;
CREATE TRIGGER trigger_member_joined
  AFTER UPDATE ON participantes_sesion
  FOR EACH ROW EXECUTE FUNCTION notify_member_joined();

-- ── Trigger 3: Sesión finalizada ─────────────────────────────
CREATE OR REPLACE FUNCTION notify_session_ended()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.estado = 'finalizada' AND OLD.estado IS DISTINCT FROM 'finalizada' THEN
    PERFORM net.http_post(
      url     := 'https://otxzwutudsruildrtuzy.supabase.co/functions/v1/send-session-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body := jsonb_build_object(
        'event_type',    'session_ended',
        'sesion_id',     NEW.id,
        'grupo_id',      NEW.grupo_id,
        'nombre_sesion', COALESCE(NEW.nombre_sesion, 'Sesión de ruta')
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_session_ended ON sesiones_ruta_activa;
CREATE TRIGGER trigger_session_ended
  AFTER UPDATE ON sesiones_ruta_activa
  FOR EACH ROW EXECUTE FUNCTION notify_session_ended();
