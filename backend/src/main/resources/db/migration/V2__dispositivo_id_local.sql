-- ID anónimo que la app genera al primer uso (va en el "sobre" y en las conexiones COMPARTIO).
-- Une el dispositivo registrado con sus nodos del grafo. Opcional y único.
ALTER TABLE dispositivos ADD COLUMN id_local TEXT UNIQUE;
