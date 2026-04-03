-- ============================================================
-- Tabla: fcm_tokens
-- Propósito: Almacenar tokens FCM por usuario para push notifications
-- Ejecutar en: Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id   UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token        TEXT        NOT NULL,
  plataforma   TEXT        NOT NULL DEFAULT 'android',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (usuario_id, token)
);

-- Índice para búsquedas por usuario
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_usuario_id ON fcm_tokens(usuario_id);

-- Row Level Security: cada usuario solo gestiona sus propios tokens
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios gestionan sus propios tokens"
  ON fcm_tokens
  FOR ALL
  USING (auth.uid()::text = usuario_id::text)
  WITH CHECK (auth.uid()::text = usuario_id::text);

-- Las Edge Functions (service_role) pueden leer todos los tokens para enviar notificaciones
-- Esto se maneja automáticamente con el service_role key en las Edge Functions.
