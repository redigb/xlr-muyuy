# Spec: Paquete sellado + API de paquetes

**Feature**: `002-paquete-api` · **Creada**: 2026-11-14 · **Estado**: Implementada
**Origen**: P0 #5, #6 y #7 de `docs/SPECS.md` · secciones 3 y 11 de `docs/SPECS_v2.md`

## Historias de usuario

### H1: Descargar el paquete de mi zona (P1)
La app, con señal, descarga el paquete de una zona oficial y lo usa 100 % offline.

1. **Dada** una zona oficial, **cuando** pido `GET /api/paquete/{zona}`, **entonces** recibo `meta` + `nucleo` + `extras` con todas las rotaciones explicadas.
2. **Dado** el paquete recibido, **cuando** la app recalcula el hash de `nucleo` + `extras`, **entonces** coincide con `meta.hash`.
3. **Dada** una zona que no existe, **entonces** recibo 404 con un mensaje claro.

### H2: ¿Hay una versión nueva? (P1)
La app pregunta `GET /api/paquete/{zona}/version` y solo descarga si la versión es mayor.

1. **Dado** el mismo contenido, **cuando** se regenera, **entonces** la versión NO cambia.
2. **Dado** un contenido distinto, **cuando** se regenera, **entonces** la versión sube en 1.

### H3: Zonas y salud (P2)
`GET /api/zonas` lista las zonas oficiales; `GET /api/salud` responde `{"ok": true}`.

## Requisitos
- **RF-01** Paquete con formato 2 (SPECS_v2 §3.2): `meta` (origen, zona, validada_localmente, idioma, version, generado, hash, secciones con vigencias) + `nucleo` (zona, fuente_clima, inicio_siembra_mes, calendario, condiciones, cultivos, rotaciones, alertas_comunidad) + `extras`.
- **RF-02** `hash` = `sha256:` + SHA-256 del JSON canónico de `{extras, nucleo}`: claves ordenadas alfabéticamente en todos los niveles, sin espacios, UTF-8.
- **RF-03** `version++` solo si el hash cambió. El paquete sellado se guarda en la tabla `paquetes`.
- **RF-04** Cada rotación lleva `explicacion`. Si el Explicador falla, se usa la plantilla (nunca un 500). Las explicaciones de rotaciones que no cambiaron se reutilizan del paquete anterior.
- **RF-05** `validada_localmente` es `true` en las zonas de Huánuco y `false` en `global-demo`.
- **RF-06** Vigencias: calendario 3 meses, condiciones 14 días, alertas 7 días.
- **RF-07** Cada descarga se cuenta en `descargas`. Respuestas comprimidas (gzip).
- **RF-08** Cada endpoint está documentado en OpenAPI con su intención.

## Criterios de éxito
- **CE-01** Las 4 zonas devuelven un paquete válido y verificable por hash.
- **CE-02** Regenerar sin cambios mantiene la versión; con cambios, sube en 1.
- **CE-03** Prueba del flujo de uso por HTTP en verde.

## Supuestos
- Idioma `es` por ahora (`en` es P2). `condiciones`, `alertas_comunidad` y `extras` van vacíos hasta sus features.
- El paquete se genera en el primer pedido tras arrancar y queda en memoria; reiniciar el backend lo regenera.
- El contenido sellado se guarda en la base (columna `contenido`), no en archivos.
