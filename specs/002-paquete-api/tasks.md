# Tasks: Paquete sellado + API de paquetes

- [X] T001 Columna `contenido` en `paquetes` (`db/migration/V1__esquema_inicial.sql`) y gzip en `application.yml`
- [X] T002 Records del paquete en `core/paquete/PaqueteDoc.java`
- [X] T003 [US1] JSON canónico + SHA-256 en `core/paquete/Sello.java` y `core/SelloTest.java`
- [X] T004 [US1][US2] `core/paquete/ServicioPaquetes.java`: armar núcleo, explicar con respaldo, sellar, guardar, cachear, regenerar
- [X] T005 [US1][US2][US3] `api/ApiResource.java` con OpenAPI
- [X] T006 **Prueba del flujo de uso** `api/PaqueteApiTest.java`: 4 zonas, hash verificable, versión estable y versión +1, 404, descargas
- [X] T007 `mvnw verify` en verde y bitácora de `docs/SPECS.md`
