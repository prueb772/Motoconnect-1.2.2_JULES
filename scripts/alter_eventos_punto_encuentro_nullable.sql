-- Migración: hacer punto_encuentro nullable en la tabla eventos
-- Punto de Encuentro pasa a ser OPCIONAL; Destino pasa a ser REQUERIDO.
ALTER TABLE eventos ALTER COLUMN punto_encuentro DROP NOT NULL;
