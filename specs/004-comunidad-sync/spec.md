# Spec: Dispositivos, sincronización y validación automática

**Feature**: `004-comunidad-sync` · **Creada**: 2026-11-14 · **Estado**: Implementada
**Origen**: P1 #9 de `docs/SPECS.md` · SPECS_v2 §8, §9, §11.2 y §15

## Historias de usuario

### H1: Registrar mi celular sin cuenta (P1)
La primera vez con señal, la app pide un token anónimo. Sin nombre, teléfono ni DNI.

1. **Cuando** hago `POST /api/dispositivos`, **entonces** recibo `{id, token}`. El servidor guarda solo el hash del token.
2. **Dada** una misma IP que pide demasiados registros en una hora, **entonces** recibe 429.

### H2: Enviar lo que observé y a quién compartí (P1)
Cuando hay señal, la app envía observaciones y conexiones guardadas offline.

1. **Dado** un token válido, **cuando** hago `POST /api/sync`, **entonces** recibo cuántas se aceptaron y el estado de cada una (validada, pendiente o sospechosa).
2. **Dado** un reenvío con los mismos `id_local`, **entonces** no se duplica nada.
3. **Sin** token válido o con el dispositivo bloqueado, **entonces** 401.
4. **Dada** una observación con fecha futura, ubicación inválida o tipo desconocido, **entonces** se rechaza con su motivo.

### H3: Validación automática (P1)
Cada observación recibe un puntaje de 0 a 100: hasta 55 si coincide con el clima NASA y hasta 45 por consenso con otros dispositivos (misma zona, mismo tipo, ±3 días).

1. **Dada** una helada reportada en un mes donde NASA no registra frío, **entonces** queda `sospechosa`.
2. **Dada** una helada en junio en sierra, reportada por un solo dispositivo, **entonces** queda `pendiente`.
3. **Dado** un segundo dispositivo que reporta lo mismo, **entonces** ambas pasan a `validada` y la alerta entra al paquete de la zona.
4. **Dada** una observación `demo: true`, **entonces** nunca cuenta para el consenso ni para las alertas.

## Requisitos
- **RF-01** Token = aleatorio de 32 bytes; se guarda su SHA-256. Límite de registros por IP y hora.
- **RF-02** Máximo 50 observaciones por dispositivo y día.
- **RF-03** Ubicación redondeada a 2 decimales (~1 km) antes de guardar.
- **RF-04** Estados: ≥ 70 `validada` · 40–69 `pendiente` · < 40 `sospechosa`.
- **RF-05** `alertas_comunidad` del paquete = observaciones validadas, no demo, de los últimos 7 días, agrupadas por tipo y fecha. Una alerta nueva hace que el paquete de la zona se regenere.
- **RF-06** Conexiones `COMPARTIO` idempotentes (origen, destino, tipo, paquete).

## Supuestos
- El cruce con NASA usa el **calendario climático mensual** de la zona (no el dato diario): helada creíble si `t_min ≤ 2 °C` o `prob_helada ≥ 0.2` en ese mes.
- Tipos aceptados: `helada`, `sequia`, `lluvia_fuerte`, `granizo`, `plaga`, `otro`. Los que NASA no puede contrastar reciben un puntaje neutro (30).
- El límite por IP vive en memoria (un solo servidor).
