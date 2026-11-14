# Plan: Explicador con Groq

**Spec**: [spec.md](spec.md)

- `Explicador` gana `explicarTodas(...)` (por defecto recorre una por una).
- `ai/ClienteGroq.java`: REST client (`configKey = groq`), `POST /v1/chat/completions`.
- `ai/ExplicadorGroq.java`: arma un prompt con todas las rotaciones, pide JSON y devuelve `{id → texto}`. Sin clave o deshabilitado: plantilla.
- `ServicioPaquetes`: reutiliza la explicación previa solo si no es la de plantilla; pide el resto en lote; completa lo que falte con plantilla.
- Config: `groq.enabled`, `groq.model`, timeouts del REST client. En test `groq.enabled=false`.
- Pruebas: `ai/ExplicadorGroqTest` con un cliente falso (sin red): éxito, fallo, deshabilitado y contenido del prompt.
