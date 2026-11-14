-- Esquema MVP (docs/SPECS_v2.md §12). Calendarios, cultivos y reglas NO van aquí: son JSON en data/.

CREATE TABLE dispositivos (
    id               UUID PRIMARY KEY,
    token_hash       TEXT        NOT NULL,
    demo             BOOLEAN     NOT NULL DEFAULT FALSE,
    creado           TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_contacto  TIMESTAMPTZ,
    bloqueado        BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE TABLE observaciones (
    id               UUID PRIMARY KEY,
    id_local         UUID        NOT NULL UNIQUE,          -- idempotencia de /api/sync
    dispositivo_id   UUID        NOT NULL REFERENCES dispositivos(id),
    zona_id          TEXT,
    celda            TEXT,
    tipo             TEXT        NOT NULL,
    fecha_evento     DATE        NOT NULL,
    valor            NUMERIC,
    lat_aprox        DOUBLE PRECISION,
    lon_aprox        DOUBLE PRECISION,
    puntaje          INT,
    estado           TEXT        NOT NULL DEFAULT 'pendiente',   -- validada | pendiente | sospechosa
    motivo_sospecha  TEXT,
    demo             BOOLEAN     NOT NULL DEFAULT FALSE,
    creado           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_obs_zona_fecha  ON observaciones (zona_id, fecha_evento);
CREATE INDEX ix_obs_celda_fecha ON observaciones (celda, fecha_evento);

CREATE TABLE conexiones (
    id       BIGSERIAL PRIMARY KEY,
    origen   TEXT        NOT NULL,
    destino  TEXT        NOT NULL,
    tipo     TEXT        NOT NULL,                       -- COMPARTIO | REPORTO | CONFIRMA
    paquete  TEXT,
    demo     BOOLEAN     NOT NULL DEFAULT FALSE,
    fecha    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (origen, destino, tipo, paquete)
);
CREATE INDEX ix_con_origen  ON conexiones (origen);
CREATE INDEX ix_con_destino ON conexiones (destino);

CREATE TABLE paquetes (
    clave         TEXT PRIMARY KEY,                      -- "huanuco-sierra@12" o "-0.5_36.0|en@1"
    origen        TEXT        NOT NULL,                  -- zona_oficial | coordenada
    zona_id       TEXT,
    celda         TEXT,
    idioma        TEXT        NOT NULL,
    version       INT         NOT NULL,
    hash          TEXT        NOT NULL,
    generado      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ruta_archivo  TEXT,
    contenido     TEXT                                   -- paquete sellado (JSON) tal como se sirve
);

CREATE TABLE descargas (
    id             BIGSERIAL PRIMARY KEY,
    clave_paquete  TEXT        NOT NULL,
    fecha          TIMESTAMPTZ NOT NULL DEFAULT now()
);
