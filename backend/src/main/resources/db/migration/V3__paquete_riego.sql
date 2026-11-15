-- Paquetes por coordenada calculados con riego (la app manda ?riego=true): otra variante en caché.
ALTER TABLE paquetes ADD COLUMN riego BOOLEAN NOT NULL DEFAULT FALSE;
