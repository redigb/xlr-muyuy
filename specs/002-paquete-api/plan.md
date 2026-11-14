# Plan: Paquete sellado + API de paquetes

**Feature**: `002-paquete-api` · **Spec**: [spec.md](spec.md)

## Resumen
`ServicioPaquetes` arma el núcleo (zona + calendario + motor + explicador), lo sella (hash + versión contra la tabla `paquetes`) y lo cachea en memoria. `ApiResource` lo expone por HTTP.

## Chequeo de constitución
Simple (1 servicio + 1 recurso, JDBC directo, sin ORM) ✔ · prueba del flujo por HTTP ✔ · determinista y verificable ✔ · la IA solo explica, con respaldo ✔ · contrato en OpenAPI ✔

## Decisiones
- **JSON canónico:** el `ObjectMapper` de Quarkus (snake_case) convierte a árbol y se escribe con las claves ordenadas, sin espacios. Los números se escriben como en el JSON de la respuesta (`8.0` sigue siendo `8.0`).
- **Persistencia:** JDBC con `AgroalDataSource`. Columna `contenido` (texto JSON) en `paquetes`; clave `zona@version`.
- **Mismo hash al regenerar:** se conserva la versión y se refrescan `generado` y las vigencias (están fuera del hash).
- **Se sirve el texto guardado tal cual**, para que el hash siempre coincida.
- **Cultivos del núcleo:** solo los que aparecen en las rotaciones.

## Archivos
```
core/paquete/PaqueteDoc.java        records del paquete
core/paquete/Sello.java             JSON canónico + SHA-256
core/paquete/ServicioPaquetes.java  armar, sellar, guardar, cachear
api/ApiResource.java                /api/salud, /zonas, /paquete/{zona}, /paquete/{zona}/version
db/migration/V1                     + columna contenido
test: api/PaqueteApiTest (flujo HTTP) · core/SelloTest (hash)
```
