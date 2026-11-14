# Spec: Motor v2 (candidatas + aptitud)

**Feature**: `001-motor-candidatas` · **Creada**: 2026-11-14 · **Estado**: Implementada (15 pruebas en verde)
**Origen**: P0 #4 de `docs/SPECS.md` · sección 4 de `docs/SPECS_v2.md`

## Historias de usuario

### H1: Rotaciones candidatas para una zona (P1)
El servidor arma el paquete de una zona oficial. Para eso necesita **todas** las rotaciones candidatas de esa zona, con puntajes y confianza, y así la app puede filtrar y ordenar sin conexión.

**Prueba independiente:** para cada zona de `data/`, el motor devuelve candidatas válidas.

**Escenarios:**
1. **Dada** la sierra con su calendario, **cuando** se piden las candidatas, **entonces** se obtienen entre 6 y 10 por cada cultivo inicial, más la práctica común.
2. **Dada** cualquier zona, **cuando** se piden dos veces, **entonces** el resultado es idéntico (mismo orden y mismos puntajes).
3. **Dada** una candidata nueva, **entonces** nunca repite familia en campañas seguidas ni es papa → papa.

### H2: ¿Este cultivo es apto aquí? (P1)
El motor decide si un cultivo puede crecer en una zona según su clima. Sirve para armar candidatas y para medir el acierto contra MIDAGRI.

**Escenarios:**
1. **Dado** el maíz en sierra, con temperatura bajo su límite letal en meses de su ciclo, **entonces** no es apto.
2. **Dada** la papa en sierra, **entonces** es apta.
3. **Dado** un cultivo con lluvia del ciclo menor al 60 % de su necesidad, en secano, **entonces** no es apto.

### Casos borde
- Si hay menos de 6 candidatas válidas, se devuelven todas las que haya, sin inventar.
- Un cultivo inicial sin ninguna candidata válida solo trae la práctica común.
- El "descanso" puede ir en la práctica común, pero nunca cuenta como cultivo candidato.

## Requisitos

- **RF-01** `esApto(zona, cultivo, calendario)` es verdadero solo si se cumplen las 3 condiciones:
  - La temperatura media del ciclo está entre `t_opt_min − 3` y `t_opt_max + 3` °C.
  - Ningún mes del ciclo tiene `t_min` por debajo de `ktmp`.
  - La lluvia del ciclo es al menos el 60 % de su necesidad, o la zona tiene riego.
- **RF-02** Las secuencias son de 3 campañas, de 1 cultivo por año, sembradas en `inicio_siembra_mes`. Todos los cultivos de la secuencia son aptos.
- **RF-03** Se descartan las secuencias con la misma familia en campañas seguidas o con papa → papa, salvo la práctica común.
- **RF-04** Puntajes de 0 a 1 (`agua`, `suelo`, `ingresos`, `riesgo`) según la tabla de la sección 4.3 de SPECS_v2. `total` es su promedio.
- **RF-05** Se eligen hasta 10 por cultivo inicial, ordenadas por `total`, **sin repetir el cultivo de la 2.ª campaña**. En empate se ordena por id.
- **RF-06** Si la zona tiene práctica común, se agrega con `es_practica_comun = true` (sierra: papa → papa → descanso).
- **RF-07** Confianza en zona oficial: clima `alta` si hay 30 años de datos o más (si no, `media`), agua `alta`, suelo `media` y mercado `sin_datos`.
- **RF-08** Cada candidata trae `validar_con_experto` según su factor más débil.
- **RF-09** Los cultivos iniciales de una zona oficial salen de `data/zonas.json`.

## Entidades
- **Rotacion**: `id`, `cultivo_inicial`, `secuencia[3]`, `puntajes`, `confianza`, `explicacion` (vacía, la llena el Explicador), `validar_con_experto`, `es_practica_comun`.
- **Cultivo**: se agregan `ktmp`, `lluvia_opt_min`, `lluvia_opt_max` y `fuente`.

## Criterios de éxito
- **CE-01** Las 4 zonas generan candidatas sin errores. Selva y sierra dan resultados distintos.
- **CE-02** 0 candidatas nuevas violan las reglas prohibidas (100 %).
- **CE-03** Dos ejecuciones con el mismo input dan un resultado idéntico.
- **CE-04** Prueba del flujo de uso: con los datos reales de `data/`, zona → calendario → motor, en verde.

## Supuestos
- Hay **promedios mensuales**: `t_min` mensual por debajo de `ktmp` se toma como letal en más del 50 % de los años.
- La necesidad de lluvia del ciclo es `lluvia_opt_min × ciclo_meses / 12` (ECOCROP da valores anuales).
- `ktmp` y `lluvia_opt_*` se cargan con valores aproximados, marcados para verificar con ECOCROP (P0 #3).
- Las zonas oficiales usan el catálogo andino, igual que `global-demo` por ahora. El catálogo global es P1.
- Todas las zonas oficiales son de secano (sin riego) y siembran en octubre.
- El endpoint del paquete es la feature siguiente; aquí la prueba de flujo recorre datos reales → motor.
