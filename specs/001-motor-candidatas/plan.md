# Plan: Motor v2 (candidatas + aptitud)

**Feature**: `001-motor-candidatas` · **Spec**: [spec.md](spec.md) · **Fecha**: 2026-11-14

## Resumen
Se reemplaza `MotorFalso` por un `MotorReal` determinista. Para cada cultivo inicial, el motor genera todas las secuencias de 3 campañas con cultivos aptos, descarta las prohibidas, las puntúa y elige hasta 10 diversas. También agrega la práctica común. `esApto` se expone para la evaluación.

## Contexto técnico
Java 25 · Quarkus 3.40 · JUnit 5 + `@QuarkusTest` · datos en `data/*.json` · sin base de datos · todo en memoria (<1 s por zona).

## Chequeo de constitución
| Principio | ✔ |
|---|---|
| I. Simple: 1 clase de motor + records, sin capas nuevas | ✔ |
| II. Prueba del flujo de uso: `MotorFlujoTest` (datos reales → motor) + unitarias solo de reglas | ✔ |
| III. Determinista: orden estable y puntajes redondeados a 2 decimales (para un hash estable) | ✔ |
| IV. La IA no decide: `explicacion` queda vacía; la llena el Explicador | ✔ |
| V. Contrato: los cambios de `Rotacion`/`Zona`/`Cultivo` se hacen antes del congelamiento (v2.1) | ✔ |

## Decisiones (investigación)
- **Mes seco** = `balance_hidrico_mm < balance_mes_seco_mm` (0).
- **Ciclo** = `ciclo_meses` meses desde `mes_siembra` (10), con desborde de año (`Calendario.mes`).
- **Riesgo por cultivo** = promedio de:
  - helada: `max(prob_helada del ciclo) × {baja 1 · media 0.5 · alta 0.2}`
  - sequía: `(meses secos / ciclo) × {alta 1 · media 0.6 · baja 0.3}`

  Luego `riesgo = 1 − promedio de los 3 cultivos`.
- **Suelo:** "termina en cobertura o forraje" = el último cultivo tiene `cobertura` o es de la familia Poaceae.
- **Descanso:** agua 1.0, valor 0, no fija nitrógeno. Solo aparece en la práctica común.
- **Cultivo inicial no apto:** solo se devuelve su práctica común (si la hay).
- **`id`** = `papa-haba-avena_forrajera`; la práctica común lleva el prefijo `comun-`.
- **`validar_con_experto`** según el factor más débil, con el nombre del cultivo de la 2.ª campaña.
- **Catálogo** = `List<Cultivo>` (no `Set`) para mantener el orden determinista.

## Modelo de datos (cambios)
- **Cultivo** `+ ktmp, lluvia_opt_min, lluvia_opt_max, fuente{}`
- **Zona** `− cultivo_actual` · `+ cultivos_iniciales[], practica_comun[]|null, riego`
- **Rotacion (v2)**: `id, cultivo_inicial, secuencia[], puntajes, confianza, explicacion, validar_con_experto, es_practica_comun`
- **Reglas** `+ factor_lluvia_min (0.6), max_candidatas (10)`
- Se eliminan `Campania` y `MotorFalso`.

## Contrato interno
```java
interface MotorRotaciones {
  List<Rotacion> recomendar(Zona zona, Calendario calendario, List<Cultivo> catalogo);
  boolean esApto(Zona zona, Cultivo cultivo, Calendario calendario);
}
interface Explicador { String explicar(Rotacion r, Zona z, Calendario c, String idioma); }
```

## Archivos
```
data/cultivos.json, zonas.json, reglas.json             (campos nuevos)
core/model/{Cultivo, Zona, Rotacion, Reglas}.java      (v2)
core/engine/{MotorRotaciones, MotorReal}.java          (MotorFalso se borra)
core/{Explicador, ExplicadorPlantilla}.java            (+ idioma)
test: MotorFlujoTest (flujo) · MotorReglasTest (reglas)
```

Guía de validación: [quickstart.md](quickstart.md)
