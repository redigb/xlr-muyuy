# Constitución de Muyuy (backend)

> Reglas que toda spec, plan, tarea e implementación debe respetar.
> Producto completo: `docs/SPECS_v2.md` (v2.1). Tablero y bitácora: `docs/SPECS.md`.

## Principios

### I. Simple y sencillo primero
Hackatón con entrega el **domingo 15/11 a las 23:59**. Se construye lo mínimo que cumple la spec: sin capas, patrones ni abstracciones "por si acaso". Si algo puede ser un `record` y un método, no es una jerarquía de clases. Toda complejidad extra se justifica en el plan o se elimina.

### II. Probar el flujo de uso, no acumular validaciones (OBLIGATORIO)
- Cada feature se cierra con **al menos una prueba del flujo real de uso**: `@QuarkusTest` + RestAssured contra el endpoint, con los JSON reales de `data/`, tal como lo usaría la app.
- Las pruebas unitarias solo se escriben para **reglas del motor** que pueden fallar en silencio (rotaciones prohibidas, aptitud, puntajes, determinismo, hash).
- No se generan checklists ni reportes de consistencia: **la prueba en verde es la validación**.
- `mvnw verify` en verde es requisito para marcar una tarea como hecha.

### III. Offline primero, datos verificables
La app nunca depende del servidor en el momento de uso. El servidor **prepara paquetes** con `version` + `hash` SHA-256 + vigencias. Mismo input = mismo output (determinista) = mismo hash.

### IV. La IA explica, no decide
Las recomendaciones salen del motor determinista con datos NASA y FAO. Groq solo redacta, con caché y **plantilla de respaldo**: si Groq falla, nunca hay un 500.

### V. Contrato estable
El contrato JSON se congela el **sábado 14/11 a las 9:00**. Después solo se **agregan** campos; nunca se renombran ni se quitan. El contrato vivo se publica en `/q/swagger-ui`, y cada endpoint lleva `@Operation` con su intención.

## Restricciones técnicas

- **Java 25** (pom con `release 25`, Temurin 25 en CI y Docker) · **Quarkus 3.40** · Maven.
- Configuración en **YAML**: `application.yml` (base y dev), `application-test.yml` y `application-prod.yml`.
- Conocimiento en `data/*.json` (montado en Docker), nunca escrito en el código.
- Secretos solo en `.env` (documentados en `.env.example`). Nunca en el repo ni en las specs.
- Paquetes: `pe.muyuy.core` (líder), `pe.muyuy.api` y `pe.muyuy.ai` (compañero).

## Flujo de trabajo

1. **Spec-kit en versión liviana:** `/speckit-specify` → (`/speckit-clarify` solo si hay dudas reales) → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`. `/speckit-converge` solo si quedó trabajo suelto.
2. Una spec por pieza del tablero P0/P1 de `docs/SPECS.md`, en `specs/NNN-nombre/`.
3. **Commits y ramas los hace el líder a mano.** La IA nunca hace commit ni push: al final de cada avance entrega los comandos y un **mensaje de commit sugerido**, y actualiza la bitácora de `docs/SPECS.md`.
4. Ramas `feat/<tema>` → PR a `main` → la CI en verde → deploy automático a Oracle.

## Gobernanza

Esta constitución manda sobre las plantillas de spec-kit. Si una plantilla pide algo que la contradice (checklists, validaciones extensas, artefactos innecesarios), **gana la constitución**. Cambiarla requiere el visto bueno del líder y una línea en la bitácora.

**Versión**: 1.0.0 | **Ratificada**: 2026-11-14 | **Última modificación**: 2026-11-14
