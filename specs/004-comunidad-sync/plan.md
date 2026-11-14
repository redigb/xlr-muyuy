# Plan: Dispositivos, sincronización y validación automática

**Spec**: [spec.md](spec.md)

- `core/comunidad/ServicioComunidad.java` (JDBC): registrar dispositivo, autenticar token, guardar observaciones y conexiones, puntuar, recalcular consenso, alertas por zona.
- `core/comunidad/Puntaje.java`: reglas puras del puntaje NASA + consenso (prueba unitaria).
- `core/comunidad/LimiteIp.java`: contador por IP y hora en memoria.
- `api/ComunidadResource.java`: `POST /api/dispositivos`, `POST /api/sync`, con OpenAPI.
- `ServicioPaquetes`: llena `alertas_comunidad` y expone `invalidar(zona)`.
- Config: `muyuy.limites.*`; en prod `proxy-address-forwarding` (IP real detrás de Caddy).
- Pruebas: `api/SyncApiTest` (flujo HTTP completo) · `core/PuntajeTest` · `core/LimiteIpTest`.
