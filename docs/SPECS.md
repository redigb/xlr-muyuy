# 📋 Specs y avance del backend

📘 **Especificación completa: [SPECS_v2.md](SPECS_v2.md) (v2.1).** Este archivo es solo el **tablero** y la **bitácora**.

Regla: una pieza se marca ✅ solo cuando sus pruebas pasan con `mvnw verify`.
⬜ pendiente · 🟡 en curso · ✅ listo · ⏭️ fuera del fin de semana

## Cómo trabajamos cada pieza (spec-kit liviano)

Reglas en `.specify/memory/constitution.md` (herramienta local, no va al repo). Por cada pieza del tablero:

```
/speckit-specify <qué y para qué>   → specs/NNN-nombre/spec.md
/speckit-plan                       → plan.md (cómo, en simple)
/speckit-tasks                      → tasks.md (incluye la prueba del flujo de uso)
/speckit-implement                  → código + pruebas en verde
```
Opcionales: `/speckit-clarify` (solo si hay dudas reales) y `/speckit-converge` (si quedó trabajo suelto).
La validación es **la prueba del flujo de uso en verde**, no checklists.

## Flujo v2.1 en una línea
El servidor **prepara paquetes** (NASA + motor + Groq, con versión y hash) → la app los **descarga o los recibe de otro celular** → se **usan 100 % offline** → las observaciones **vuelven** cuando hay señal.

## Tablero del backend

### 🔴 P0: imprescindible (hito: sábado 21:00)
| # | Pieza | Estado | Prueba / criterio |
|---|---|---|---|
| 1 | Esqueleto (Quarkus 3.40, Java 25, YAML dev/test/prod, CI/CD) | ✅ | `ApiBasicaTest`, `PerfilTestTest`, `PerfilProdTest` |
| 2 | Calendarios NASA corregidos por altitud (4 zonas) | ✅ reales (POWER 1985-2024, −6.5 °C/km, ET0 Hargreaves, helada ≤ 2 °C) · falta deploy | `pipeline/test_calendario.py` |
| 3 | `cultivos_andinos.json` (ECOCROP, con `ktmp` y `fuente`) + `reglas.json` | 🟡 borrador v1 | cargan y son válidos |
| 4 | Motor v2: **todas las candidatas** + `esApto` | ✅ | `MotorFlujoTest`, `MotorReglasTest` · spec `specs/001-motor-candidatas` |
| 5 | Paquete: `meta` (versión, hash SHA-256, vigencias) + `nucleo` | ✅ | `PaqueteApiTest`, `SelloTest` · spec `specs/002-paquete-api` |
| 6 | `GET /api/paquete/{zona}` y `/version` · `/api/zonas` · `/api/salud` | ✅ | `PaqueteApiTest` (flujo HTTP) |
| 7 | Explicador: Groq (1 llamada por zona) + reutilización + plantilla de respaldo | ✅ falta probar con la clave real | `ExplicadorGroqTest` (Groq falso) · spec `specs/003-explicador-groq` |
| 8 | Deploy en Oracle (`muyuy-bk.rdev7.net.pe`) | ✅ en producción, deploy automático en cada push a main | `/q/health/ready` en UP por HTTPS |

### 🟡 P1: después del hito
| # | Pieza | Estado |
|---|---|---|
| 9 | PostgreSQL + `/api/dispositivos` + `/api/sync` (idempotente) + puntaje automático + alertas en el paquete | ✅ `SyncApiTest`, `PuntajeYLimiteTest` · spec `specs/004-comunidad-sync` |
| 10 | `pipeline-api` (FastAPI) + `/api/paquete/coordenada` + catálogo global + inicio de siembra calculado | ✅ `CoordenadaApiTest`, `InicioSiembraTest`, `pipeline/test_servicio.py` |
| 10b | Paquetes en inglés (`?lang=en`) · `id_local` en `/api/dispositivos` · `estados` en `/api/sync` | ✅ `CoordenadaApiTest`, `SyncApiTest` |
| 10c | Imagen satelital en `extras` (Worldview, Landsat WELD sin nubes, ~100 KB, solo zonas oficiales) | ✅ `PaqueteApiTest` (fuente falsa) |
| 11 | Evaluación de aptitud contra MIDAGRI (métrica 2) | ⬜ |

### 🟢 P2: si sobra tiempo
~~`/api/red/publica`~~ ✅ (`RedApiTest`, `ServicioRedTest`) · ~~explicaciones en inglés~~ ✅ · precalcular ubicaciones de los jueces · backtesting

## Pruebas del motor (v2)
- [x] Nunca recomienda papa → papa (salvo `es_practica_comun`)
- [x] No repite familia en campañas seguidas
- [x] `esApto`: rechaza un cultivo con helada letal (`ktmp`) en su ciclo (maíz en sierra con helada en junio)
- [x] Entre 6 y 10 candidatas por cultivo inicial, diversas (2.ª campaña distinta)
- [x] Puntajes entre 0 y 1
- [x] Mismo input = mismo output (determinista) → mismo hash

## Cambios de contrato v1 → v2 (a confirmar a las 9:00)
| v1 (código actual) | v2.1 |
|---|---|
| `recomendar(zona, calendario)` devuelve 3 | `recomendar(zona, calendario, catalogo)` devuelve **todas las candidatas** · `esApto(...)` |
| `Rotacion.campanias[]`, `actual` | `cultivo_inicial`, `secuencia[]`, `explicacion`, `es_practica_comun` |
| `explicar(rotacion, zona, calendario)` | `+ idioma` |
| Se responde una rotación | Se responde el **paquete** (`meta` + `nucleo` + `extras`) |

## Bitácora (la más reciente arriba)

| Fecha | Avance | Commit |
|---|---|---|
| 14/11 | Catálogo global: +13 cultivos ECOCROP (sorgo, mijo, arroz, soya, maní, caupí, garbanzo, lenteja, camote, girasol, tomate, cebolla, colza). Zonas oficiales solo con su catálogo andino; coordenadas con todo. `MotorGlobalTest` con clima NASA real de Kenia, Punjab y Níger | `feat(data): catalogo global de cultivos para otros paises` |
| 14/11 | `GET /api/red/publica`: red anónima (alias por consulta, sin demo) + alcance/saltos + serie 30 días | `feat(api): red publica anonima con metricas` |
| 14/11 | Imagen satelital NASA (Landsat WELD) en `extras` de zonas oficiales; app la muestra plegada en Chacra | `feat(api): imagen satelital en el paquete` |
| 14/11 | `pipeline-api` + `/api/paquete/coordenada` + paquetes en inglés + `id_local`/`estados` en sync; calendarios reales NASA POWER | `feat(api): paquete por coordenada, ingles y calendarios reales` |
| 14/11 | Monorepo: app Flutter en `app/` (sin builds ni `local.properties`; modelo TFLite solo en `assets/`) + `app-ci.yml` (analyze + test) | `feat(app): app flutter offline` |
| 14/11 | Monorepo: landing (Astro, pnpm con scripts bloqueados + minimumReleaseAge) en `landing/`; workflows con filtro por carpeta (`landing-ci.yml` aparte, el deploy a Oracle solo si cambia backend/data/infra) | `chore: monorepo con landing y ci por carpeta` |
| 14/11 | Evaluación de modelos Groq con prompt y paquetes reales (6 configuraciones) → `gpt-oss-120b` + `reasoning_effort: low`; 41 pruebas | `feat(ai): reasoning_effort low y evaluacion de modelos groq` |
| 14/11 | Groq: llama-3.3-70b retirado (404) → `openai/gpt-oss-120b`, configurable con `GROQ_MODEL`; probado en local 30/30 rotaciones explicadas | `fix(ai): modelo groq gpt-oss-120b configurable con GROQ_MODEL` |
| 14/11 | Deploy #8 en producción: https://muyuy-bk.rdev7.net.pe (Actions → GHCR → VM, Caddy HTTPS); fixes de YAML en CI y secretos con espacios | `docs: deploy en produccion listo` |
| 14/11 | Deploy sin compilar en la VM: Actions arma la imagen (arm64+amd64) → GHCR → la VM hace pull | `ci(deploy): imagen armada en github actions y publicada en ghcr` |
| 14/11 | Jurado en inglés: README + Swagger (cada campo, snake_case = JSON real) + errores API; `groq.clave` para que `.env` no pise el perfil test, 40 pruebas | `docs: README y OpenAPI en ingles para el jurado` |
| 14/11 | `.claude/` y `.specify/` fuera del repo + `backend/.env` local | `chore: ignorar herramientas locales y entorno local con backend/.env` |
| 14/11 | Dispositivos anónimos + `/api/sync` + puntaje NASA y consenso + alertas en el paquete, 38 pruebas | `feat(api): dispositivos, sync y validacion automatica de observaciones (spec 004)` |
| 14/11 | Explicador Groq en lote con respaldo de plantilla | `feat(ai): explicador groq en lote con plantilla de respaldo (spec 003)` |
| 14/11 | Paquete sellado (hash + versión en PostgreSQL) + API de paquetes, 25 pruebas | `feat(api): paquete sellado con hash y version + endpoints de paquetes (spec 002)` |
| 14/11 | PostgreSQL + Flyway (esquema V1 §12), CI con Postgres, 17 pruebas | `feat(db): postgresql con flyway y esquema inicial` |
| 14/11 | Motor v2 (MotorReal): candidatas + esApto, 15 pruebas en verde | `feat(core): motor v2 con rotaciones candidatas y esApto` |
| 14/11 | spec-kit 1.2.0 liviano (Claude) + constitución del proyecto | `chore(specs): spec-kit liviano y constitucion del proyecto` |
| 14/11 | Specs v2.1: flujo offline con paquetes (reemplaza el flujo "consulta en cada uso") | `docs: specs v2.1 (flujo offline con paquetes) y tablero actualizado` |
| 14/11 | Probador de APIs NASA en docs/ | `docs: probador de APIs NASA (ApisNASA.html)` |
| 14/11 | Logo + flujo en README | `docs: logo y diagramas de flujo en el README` |
| 14/11 | Specs del backend | `docs: specs y tablero de avance del backend` |
| 14/11 | Java 25 en todo | `chore(build): usar Java 25 (release 25) en todo el proyecto` |
| 14/11 | Config YAML dev/test/prod + 9 pruebas | `chore(config): application.yml con perfiles test y prod` |
| 14/11 | Esqueleto monorepo + MotorFalso + CI/CD | `chore: esqueleto monorepo Muyuy` |
