# 📱🔌 Rol: App Flutter + API + Groq — Proyecto Muyuy

> NASA Space Apps Challenge 2026 · Reto *"Field Shift: Adapting Farms with NASA Data"*
> Zona piloto: **Huánuco, Perú** · Entrega: **domingo 15/11, 23:59** (meta interna: 21:00)

---

## 1. Tu misión

Que el agricultor **pueda usar** lo que calcula el sistema: de los resultados del motor hasta su celular, **incluso sin señal**.

Eres dueño de **3 piezas**:

| Pieza | Qué es |
|---|---|
| 🔌 **API REST** | Endpoints de Quarkus que exponen el paquete regional |
| 🤖 **Groq** | Explicaciones en lenguaje simple de cada rotación |
| 📱 **App Flutter** | Las pantallas, el modo offline y compartir |

**No es tuyo** (lo hace el líder de backend): infraestructura Oracle, motor de rotaciones, cultivos, reglas, despliegue.

---

## 2. Reglas para no chocar

1. **Tu carpeta en el backend:** `backend/src/main/java/pe/muyuy/api/` y `.../ai/`. **No edites** `core/`.
2. **Archivos compartidos** (`pom.xml`, `application.properties`, `docker-compose.yml`): **solo los edita el líder**. Si necesitas una dependencia, pídesela.
3. **Rama propia:** `feat/api-groq` (backend) y `feat/app` (Flutter).
4. **PR a `main` cada 2–3 horas**, chicos. Antes de cada bloque: `git pull origin main`.
5. **Secretos** (clave de Groq) en `.env`, **nunca en GitHub**. Mantén `.env.example` actualizado.
6. **Solo el líder despliega** en Oracle.

---

## 3. El contrato JSON del paquete (se confirma el sábado a las 9:00 y NO se cambia)

`GET /api/paquete/{zonaId}` devuelve:

```json
{
  "version": "2026-11-14T10:00:00Z",
  "zona": {
    "id": "huanuco-sierra",
    "nombre": "Sierra de Huánuco, Perú",
    "lat": -9.90, "lon": -75.99, "elevacion_m": 3200
  },
  "calendario": [
    { "mes": 6, "prob_helada": 0.7, "lluvia_mm": 8,
      "et_mm": 95, "balance_hidrico_mm": -87, "estres_calor": 0.0 }
  ],
  "cultivos": [
    { "id": "haba", "nombre": "Haba", "familia": "Fabaceae",
      "fija_nitrogeno": true, "tolera_helada": "media",
      "agua": "media", "ciclo_meses": 6 }
  ],
  "rotaciones": [
    {
      "id": "B",
      "es_actual": false,
      "secuencia": ["papa", "haba", "avena_forrajera"],
      "puntajes": { "agua": 0.7, "suelo": 0.9, "ingresos": 0.6, "riesgo": 0.8 },
      "confianza": { "clima": "alta", "agua": "alta", "suelo": "media", "mercado": "sin_datos" },
      "explicacion": "El haba fija nitrógeno después de la papa...",
      "validar_con_experto": "Confirma si hay semilla de haba en tu zona."
    }
  ]
}
```

- `puntajes`: 0.0 a 1.0 (más alto = mejor; en `riesgo`, más alto = **menos** riesgo).
- `confianza`: `"alta" | "media" | "baja" | "sin_datos"`.
- `explicacion`: **la generas tú con Groq**.

Zonas: `huanuco-sierra` ⭐ (comunidad del domingo), `huanuco-valle`, `huanuco-selva` (Tingo María), `global-demo` (otro país).

---

## 4. Las 2 interfaces (punto de unión con el líder)

```java
// core/engine/MotorRotaciones.java  ← lo implementa el LÍDER
public interface MotorRotaciones {
    List<Rotacion> recomendar(Zona zona, Calendario calendario);
}

// core/Explicador.java  ← lo implementas TÚ
public interface Explicador {
    String explicar(Rotacion rotacion, Zona zona, Calendario calendario);
}
```

- El líder sube un **`MotorFalso`** (3 rotaciones fijas) el sábado a las ~9:30. **Arma la API encima de ese.**
- Tú subes un **`ExplicadorFalso`** (texto fijo) para que él pruebe sin depender de Groq.
- Cuando el real esté listo, **solo se cambia la implementación**.

---

## 5. 🔌 API REST (Quarkus)

| Endpoint | Devuelve |
|---|---|
| `GET /api/zonas` | Lista de zonas: `[{id, nombre, lat, lon}]` |
| `GET /api/paquete/{zonaId}` | Paquete completo (contrato de la sección 3) |
| `GET /api/salud` | `{"ok": true}` para verificar que el servidor vive |
| `POST /api/observaciones` | *(Opcional, solo si sobra tiempo)* reportes de campo |

- Ubicación: `api/ZonaResource.java`, `api/PaqueteResource.java`, `api/dto/`.
- Dependencias que pedirás al líder: `quarkus-rest`, `quarkus-rest-jackson`, `quarkus-rest-client-jackson`.
- **CORS** habilitado, para la demo web de Flutter.
- **Caché:** el paquete se arma **una vez** por zona (al iniciar o en la primera petición) y se guarda. **No llames a Groq en cada petición.**

---

## 6. 🤖 Groq

- Clave: https://console.groq.com → API Keys → guárdala en `.env` como `GROQ_API_KEY`.
- Endpoint compatible con OpenAI: `https://api.groq.com/openai/v1/chat/completions`
- Modelo: `llama-3.3-70b-versatile`
- Ubicación: `ai/GroqClient.java` (REST client) y `ai/ExplicadorGroq.java` (implementa `Explicador`).

### Reglas del prompt (críticas: la IA explica, NO decide)

1. Usa **solo** los datos que le pasas. Prohibido inventar números, cultivos o promesas.
2. Español simple, para un agricultor sin formación técnica. **Máximo 3 frases.**
3. Hablar en frecuencias reales ("7 de cada 10 años"), nunca "este año va a helar".
4. `temperature: 0.2`, para que sea estable.
5. Si Groq falla → usa un **texto de plantilla** (nunca dejes la explicación vacía).

### Prompt base

```
Eres un asistente agrícola. Explica en español muy simple, en máximo 3 frases,
por qué se sugiere esta rotación a un agricultor de {zona.nombre}.
Usa SOLO estos datos, no inventes nada:
- Rotación: {secuencia}
- Meses con helada probable (>50%): {meses_helada}
- Meses secos (balance hídrico negativo): {meses_secos}
- Puntajes (0 a 1): agua {agua}, suelo {suelo}, ingresos {ingresos}, menor riesgo {riesgo}
- Datos de cultivos: {cultivos_relevantes}
Termina con lo que el agricultor debería confirmar con un experto local.
```

---

## 7. 📱 App Flutter

### Las 5 pantallas

| # | Pantalla | Contenido |
|---|---|---|
| 1 | **Inicio** | Logo, "Elegir mi zona", estado del paquete (✅ descargado / ⬇️ descargar) |
| 2 | **Mi chacra** | Zona · rotación actual (íconos de cultivos) · ¿tienes riego? · prioridades (elegir 2: 🍲 comida, 💰 ingresos, 🌱 suelo, 💧 agua) |
| 3 | **Mi calendario** | 12 meses con colores: 🔵 helada, 🟠 seco, 🟢 bueno · **terreno 3D** en WebView con slider de meses |
| 4 | **Mis opciones** | 3 rotaciones (actual + 2) ordenadas · barras de agua/suelo/ingresos/riesgo · confianza por factor · explicación · "Confirma con un experto" |
| 5 | **Compartir** | QR + enviar el paquete a otro celular |

### Puntaje en el celular (offline)

Suma ponderada con las prioridades del usuario sobre los `puntajes` del paquete:

```dart
double puntajeFinal(Map<String, double> p, Set<String> prioridades) {
  const base = 1.0, extra = 2.0;
  double total = 0, pesos = 0;
  for (final f in ['agua', 'suelo', 'ingresos', 'riesgo']) {
    final w = prioridades.contains(f) ? extra : base;
    total += (p[f] ?? 0) * w;
    pesos += w;
  }
  return total / pesos;
}
```

### Paquetes sugeridos

| Paquete | Para |
|---|---|
| `http` | Llamar a la API |
| `path_provider` | Guardar el paquete como archivo JSON local |
| `webview_flutter` | Terreno 3D (HTML que hace la persona de la landing) |
| `qr_flutter` / `mobile_scanner` | Generar y leer QR |
| `share_plus` | Enviar el archivo del paquete a otro celular (Quick Share / Bluetooth) |

### Offline (obligatorio)

1. Al descargar un paquete → **guardarlo como JSON** en el almacenamiento de la app.
2. Al abrir la app → **leer siempre del archivo local** primero.
3. **Paquete de respaldo en `assets/`** (la zona del domingo) por si en el campo no hay internet ni para la primera descarga.
4. Prueba obligatoria: **modo avión** → toda la app funciona.

### Compartir: ojo con el tamaño del QR

Un QR solo guarda unos **~2–3 KB**, y el paquete completo pesa más. Entonces:
- **QR** = el `zonaId` + la `version` (para identificar el paquete o descargarlo cuando haya señal).
- **Archivo** = el paquete completo se envía con `share_plus` (Quick Share / Bluetooth, sin internet).
- La app debe poder **importar** un paquete recibido como archivo.

### APK y web

```bash
flutter build apk --release --split-per-abi   # APK firmado (clave release, NO debug)
flutter build web                             # demo pública sin instalar
```

La clave de firma (`.jks`) y `key.properties` **no se suben a GitHub**.

---

## 8. 📅 Tu cronograma

### Viernes 13 (preparación, sin programar el proyecto)
- [ ] Flutter + Android Studio instalados · "Hola mundo" corriendo en un **celular real**
- [ ] Cuenta de Groq + clave guardada (no en GitHub)
- [ ] Bocetos de las 5 pantallas (papel o Figma)
- [ ] Leer la documentación de los paquetes de la sección 7
- [ ] Repo de GitHub creado con carpetas `app/`, `backend/`, `pipeline/`, `landing/` + README

### Sábado 14
| Hora | Tarea |
|---|---|
| **9:00** | 🤝 Confirmar el contrato JSON y las interfaces con el equipo |
| 9–10 | Esqueleto Flutter + navegación entre las 5 pantallas |
| 10–14 | API `/zonas` y `/paquete` sobre el `MotorFalso` + `GroqClient` funcionando |
| 14–18 | `ExplicadorGroq` con el prompt + caché · pantallas 2, 3 y 4 con datos falsos |
| **18:00** | 🔀 **Merge con el líder: motor real + API + Groq** |
| 18–21 | App conectada a la API real en Oracle |
| **21:00** | 🔴 **HITO: flujo completo con datos reales de Huánuco** |
| 21–24 | Offline + compartir + APK firmado instalado en **2 celulares** + prueba en **modo avión** |

⚠️ **Decisión a las 18:00:** si vas atrasado, el líder toma la API y tú te quedas con la app + Groq.

### Domingo 15
| Hora | Tarea |
|---|---|
| **7–12** | 🚜 **Prueba de campo** en Huánuco (tú vas para dar soporte técnico) |
| 12–13 | Revisión con el equipo: errores y comentarios del agricultor |
| 13–18 | Corregir errores del campo · `flutter build web` → demo pública |
| **18:00** | 🧊 **Código congelado** |
| 18–20 | APK final publicado en la landing |
| 20–21 | ✅ Entrega con todo el equipo |

---

## 9. 🚜 Checklist para el campo (domingo)

- [ ] APK **release** instalado en 2 celulares
- [ ] Paquete `huanuco-sierra` **ya cargado** (no depender de señal)
- [ ] Probado en modo avión **antes de salir**
- [ ] Compartir probado entre los 2 celulares
- [ ] Baterías cargadas + batería externa

---

## 10. ✅ "Terminado" significa

- [ ] La app abre, eliges la zona y ves el calendario y las 3 rotaciones **con su explicación**
- [ ] Cambiar las prioridades **reordena** las rotaciones
- [ ] Funciona **completa en modo avión**
- [ ] Un paquete pasa de un celular a otro
- [ ] APK firmado + demo web pública

## 11. ✂️ Si falta tiempo, se corta en este orden

1. `POST /api/observaciones`
2. Lectura de QR (queda solo enviar el archivo)
3. Terreno 3D → se reemplaza por el calendario de colores 2D

**Lo que nunca se corta:** zona → calendario → 3 rotaciones con explicación → **offline**.
