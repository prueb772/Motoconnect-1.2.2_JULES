-- Migración: crear tabla evento_grupos (relación many-to-many entre eventos y grupos)
CREATE TABLE IF NOT EXISTS evento_grupos (
  evento_id UUID NOT NULL REFERENCES eventos(id) ON DELETE CASCADE,
  grupo_id  UUID NOT NULL REFERENCES grupos_ruta(id) ON DELETE CASCADE,
  PRIMARY KEY (evento_id, grupo_id)
);

ALTER TABLE evento_grupos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura pública" ON evento_grupos
  FOR SELECT USING (true);

CREATE POLICY "Gestión por creador" ON evento_grupos
  FOR ALL USING (
    auth.uid()::text = (
      SELECT creado_por::text FROM eventos WHERE id = evento_id
    )
  );
