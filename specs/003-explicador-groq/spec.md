# Spec: Explicador con Groq

**Feature**: `003-explicador-groq` · **Creada**: 2026-11-14 · **Estado**: Implementada
**Origen**: P0 #7 de `docs/SPECS.md` · SPECS_v2 §4.3 (paso 7) y principio "la IA explica, no decide"

## Historia de usuario (P1)
El agricultor lee, en lenguaje sencillo, por qué se le propone cada rotación. El texto lo redacta Groq a partir de los datos del motor; nunca cambia la recomendación.

1. **Dada** una zona con rotaciones nuevas, **cuando** se arma el paquete, **entonces** se hace UNA llamada a Groq para todas y cada rotación recibe su explicación.
2. **Dado** que Groq falla, responde 429, tarda demasiado o no hay clave, **entonces** se usa la plantilla y el paquete sale igual.
3. **Dada** una rotación que no cambió y ya tenía explicación de Groq, **entonces** se reutiliza sin llamar a Groq.
4. **Dada** una rotación que quedó con plantilla, **cuando** se regenera el paquete, **entonces** se vuelve a intentar con Groq.

## Requisitos
- **RF-01** Una llamada por zona (lote), modelo `llama-3.3-70b-versatile`, respuesta JSON `{id: texto}`.
- **RF-02** El prompt solo lleva datos del motor (secuencia, puntajes, clima) y pide no inventar cifras; 2 frases por rotación; idioma `es` o `en`.
- **RF-03** Sin clave o con `groq.enabled=false` no se hace ninguna llamada.
- **RF-04** Cualquier fallo → plantilla. Nunca un error hacia la API.
- **RF-05** La clave vive solo en `.env` (`GROQ_API_KEY`).

## Criterios de éxito
- **CE-01** El paquete siempre trae explicación en todas las rotaciones, con o sin Groq.
- **CE-02** Las pruebas no llaman a Groq real.
