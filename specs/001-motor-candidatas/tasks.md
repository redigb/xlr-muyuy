# Tasks: Motor v2 (candidatas + aptitud)

**Entrada**: [plan.md](plan.md) · [spec.md](spec.md) · Rutas Java bajo `backend/src/main/java/pe/muyuy/`, pruebas bajo `backend/src/test/java/pe/muyuy/`.

## Fase 1: Datos (bloquea todo)
- [X] T001 [P] Agregar `ktmp`, `lluvia_opt_min`, `lluvia_opt_max` y `fuente` (aproximados, "verificar con ECOCROP") a cada cultivo de `data/cultivos.json`
- [X] T002 [P] En `data/zonas.json` reemplazar `cultivo_actual` por `cultivos_iniciales[]`, `practica_comun[]|null` y `riego:false`
- [X] T003 [P] Agregar `factor_lluvia_min: 0.6` y `max_candidatas: 10` a `data/reglas.json`

## Fase 2: Modelo (bloquea todo)
- [X] T004 Actualizar los records `core/model/Cultivo.java`, `Zona.java`, `Reglas.java` y `Rotacion.java` (v2), y borrar `core/model/Campania.java`
- [X] T005 Cambiar la interfaz `core/engine/MotorRotaciones.java` (catálogo + `esApto`) y `core/Explicador.java` (+ idioma); adaptar `core/ExplicadorPlantilla.java`

## Fase 3: H2, ¿es apto? (P1)
- [X] T006 [US2] Implementar `esApto` en `core/engine/MotorReal.java`: temperatura ±3, `t_min ≥ ktmp` y lluvia del ciclo ≥ 60 % (o riego)
- [X] T007 [US2] Pruebas de reglas de aptitud en `core/MotorReglasTest.java`: helada letal, lluvia insuficiente, temperatura fuera de rango y papa apta en sierra

## Fase 4: H1, candidatas (P1)
- [X] T008 [US1] Implementar `recomendar` en `core/engine/MotorReal.java`: generar, descartar prohibidas, puntuar, elegir hasta 10 diversas, agregar la práctica común, confianza y `validar_con_experto`
- [X] T009 [US1] Borrar `core/engine/MotorFalso.java` y `core/DatosYMotorFalsoTest.java`
- [X] T010 [US1] Agregar a `core/MotorReglasTest.java`: sin papa → papa, sin familia repetida y puntajes entre 0 y 1
- [X] T011 [US1] **Prueba del flujo de uso** `core/MotorFlujoTest.java` (`@QuarkusTest`, datos reales): las 4 zonas, sierra con 6 a 10 por inicial, práctica común presente, determinista y selva ≠ sierra

## Fase 5: Cierre
- [X] T012 `mvnw verify` en verde (todas las pruebas)
- [X] T013 Actualizar el tablero y la bitácora de `docs/SPECS.md` (P0 #4 → ✅)

## Dependencias
Fase 1 → Fase 2 → H2 → H1 → Cierre. T001, T002 y T003 se pueden hacer en paralelo.
