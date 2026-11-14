# 📋 Specs y avance del backend

Regla: una spec se marca ✅ solo cuando sus pruebas pasan con `mvnw verify`.
⬜ pendiente · 🟡 en curso · ✅ listo

## Tablero

| # | Pieza | Estado | Cómo sabemos que está lista |
|---|---|---|---|
| 1 | Esqueleto (Quarkus, Java 25, YAML dev/test/prod) | ✅ | `ApiBasicaTest`, `PerfilTestTest`, `PerfilProdTest` |
| 2 | Datos (`data/*.json`) | 🟡 calendarios inventados | `DatosYMotorFalsoTest` · faltan los de NASA |
| 3 | MotorFalso | ✅ | `DatosYMotorFalsoTest` |
| 4 | MotorReal | ⬜ | `MotorRealTest` (ver abajo) |
| 5 | API + Groq (compañero) | ⬜ | `GET /api/paquete/{zona}` → 3 rotaciones |
| 6 | Deploy Oracle (CI/CD) | 🟡 falta la VM | `https://api.<ip>.sslip.io/q/health/ready` en UP |

## Contrato (se confirma el sáb 9:00 · después solo se agregan campos)

El motor devuelve siempre 3 rotaciones: `[0]` es la actual y luego 2 recomendadas. Todo en snake_case.
```json
{ "id": "opcion-1", "nombre": "Opcion 1", "actual": false,
  "campanias": [{"numero": 1, "cultivo_id": "papa", "cultivo_nombre": "Papa", "familia": "Solanaceae", "mes_siembra": 10}],
  "puntajes": {"agua": 0.8, "suelo": 0.9, "ingresos": 0.65, "riesgo": 0.8, "total": 0.79},
  "confianza": {"clima": "alta", "agua": "media", "suelo": "media", "mercado": "sin_datos"},
  "validar_con_experto": "Confirma si hay semilla y compradores en tu zona." }
```
El contrato vivo está en `/q/swagger-ui`.

## MotorReal: pruebas que deben pasar
- [ ] Papa → papa nunca se recomienda
- [ ] Con helada fuerte en sierra, el maíz no entra al top 2
- [ ] Siempre salen 3 rotaciones
- [ ] Mismo input = mismo output
- [ ] No se repite familia seguida
- [ ] Puntajes entre 0 y 1

## Bitácora (la más reciente arriba)

| Fecha | Avance | Commit |
|---|---|---|
| 14/11 | Probador de APIs NASA en docs/ | `docs: probador de APIs NASA (ApisNASA.html)` |
| 14/11 | Logo + flujo en README | `docs: logo y diagramas de flujo en el README` |
| 14/11 | Specs del backend | `docs: specs y tablero de avance del backend` |
| 14/11 | Java 25 en todo | `chore(build): usar Java 25 (release 25) en todo el proyecto` |
| 14/11 | Config YAML dev/test/prod + 9 pruebas | `chore(config): application.yml con perfiles test y prod` |
| 14/11 | Esqueleto monorepo + MotorFalso + CI/CD | `chore: esqueleto monorepo Muyuy` |
