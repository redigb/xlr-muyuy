# 🌐 Rol: Landing + Terreno 3D + Presentación — Proyecto Muyuy

> NASA Space Apps Challenge 2026 · Reto *"Field Shift: Adapting Farms with NASA Data"*
> Zona piloto: **Huánuco, Perú** · Entrega: **domingo 15/11, 23:59** (meta interna: 21:00)

---

## 1. Tu misión

Que el proyecto **se vea increíble y se entienda en 30 segundos**. Los jueces revisan cientos de proyectos: casi ninguno instala un APK. **Lo que tú hagas es lo que la mayoría de jueces verá.**

| Pieza | Qué es |
|---|---|
| 🌐 **Landing** | Página pública: problema, solución, video, demo, APK, repo |
| 🏔️ **Terreno 3D** | Un HTML con Three.js que usan **la landing y la app** (WebView) |
| 🎥 **Video demo** | **Máx. 30 s, subtítulos en inglés** (con tomas del campo del domingo) |
| 📊 **Diapositivas** | **Máx. 7**, en inglés |
| ✍️ **Textos de entrega** | Resumen, descripción, datos NASA, uso de IA (en inglés) |

**No es tuyo:** backend, motor, API, app (los demás). Pero **sí debes entender el flujo** para contarlo.

---

## 2. Reglas para no chocar

1. Tus carpetas: `landing/` y `terreno3d/`. No edites otras.
2. Rama: `feat/landing`. **PR a `main` cada 2–3 h.**
3. **Todo en inglés** en lo que se entrega (landing, video, diapositivas, formulario).
4. **NO uses el logo de la NASA** ni su marca visual. Puedes escribir "uses NASA Earth data", pero sin logos.
5. Imágenes o videos generados con IA → **marca de agua visible** que lo indique.
6. Sin datos personales del agricultor (ni nombre completo, ni DNI, ni ubicación de su casa) y **sin menores de edad reconocibles**.
7. Música e imágenes: solo con licencia libre (Pixabay, YouTube Audio Library) y **anótalas en los créditos**.

---

## 3. 🏔️ Terreno 3D (`terreno3d/`) — PRIORIDAD 1 del sábado

Reutiliza el código Three.js del terreno de **XLR Harvest**.

### Requisitos
- **Un solo `index.html`** con su JS y **`three.module.js` local** (sin CDN): la app lo carga **offline** desde sus `assets/`.
- Liviano: debe correr en un **celular de gama baja** (pocos polígonos, sin sombras pesadas, `pixelRatio` máx. 1.5).
- Fondo transparente o del color de la app.

### Contrato con la app (cómo la app lo controla)

La app (Flutter WebView) llama funciones globales de JavaScript:

```js
// La app manda los datos de la zona una vez (el mismo "calendario" del paquete)
window.muyuy.cargarZona({
  zona: { id: "huanuco-sierra", elevacion_m: 3200 },
  calendario: [ { mes: 1, prob_helada: 0.05, balance_hidrico_mm: 30, estres_calor: 0 }, ... ]
});

// La app cambia el mes (slider)
window.muyuy.setMes(6);

// La app cambia la capa visible
window.muyuy.setCapa("helada");   // "helada" | "agua" | "normal"
```

Para probar sin la app: si la URL trae `?demo=1`, carga un calendario de ejemplo y muestra su propio slider de meses.

### Qué debe verse

| Capa | Color | Dato |
|---|---|---|
| `helada` | ❄️ Azul (más intenso = más probable) | `prob_helada` del mes |
| `agua` | 🟠 Naranja = seco · 🟢 Verde = bien | `balance_hidrico_mm` del mes |
| `normal` | Textura de pasto o tierra | — |

- **Relieve:** de una ladera andina (procedural está bien para el MVP). Si la persona de datos entrega una grilla de elevación (`elevacion_<zona>.json`: `{ancho, alto, min, max, valores[]}`), úsala. Si no, procedural.
- **Extra visual (si sobra tiempo):** partículas de escarcha en los meses de helada y una animación suave al cambiar de mes.

### Prueba del sábado 21:00
- [ ] Abre en el navegador del celular y en el WebView de la app
- [ ] Cambia de color al mover el mes
- [ ] Funciona **sin internet**

---

## 4. 🌐 Landing (`landing/`)

### Tecnología
- **Astro** (o Vite + HTML si es más rápido para ti) + Three.js para el hero.
- Despliegue en **Cloudflare Pages** (gratis), conectado al repo de GitHub.
- Responsive: **debe verse bien en el celular** (muchos jueces la abren ahí).

### Secciones (en este orden)

| # | Sección | Contenido |
|---|---|---|
| 1 | **Hero** | Terreno 3D animado de fondo · **"Muyuy"** · eslogan · botones: *Watch the demo* / *Try it now* |
| 2 | **The problem** | Pedrito, agricultor de la sierra de Huánuco: heladas, lluvia irregular, suelo cansado, **sin señal** |
| 3 | **How it works** | 3 pasos con íconos: *NASA data → Smart rotations → Works offline, shared phone-to-phone* |
| 4 | **NASA data** | Qué datos y para qué (sección 7) — sin logos de la NASA |
| 5 | **Demo** | Video de 30 s embebido · botón **Try the web demo** · botón **Download APK** + SHA-256 + aviso |
| 6 | **Field test** | Fotos o clip de la prueba en Huánuco + la opinión del agricultor (domingo) |
| 7 | **Why it matters** | Offline · Global · Incertidumbre visible · Basado en evidencia, no en adivinanzas |
| 8 | **Team** | Nombres y roles (solo de los miembros, con su permiso) |
| 9 | **Footer** | GitHub · licencias y créditos · declaración de uso de IA |

### Eslogan (elige uno)
- *"Ancestral rotation wisdom, seen through NASA's eyes."*
- *"NASA data to the last field — even without signal."*

### Aviso para el APK (copiar tal cual)
> *Muyuy is a hackathon prototype distributed outside Google Play, so Android may show a security warning. The APK is signed by our team. Verify the SHA-256 checksum below before installing.*

(El compañero de la app te pasa el APK y su SHA-256 el domingo.)

---

## 5. 🎥 Video demo (máx. 30 s · subtítulos en inglés)

### Storyboard

| Seg. | Toma | Subtítulo (inglés) |
|---|---|---|
| 0–4 | Chacra en la sierra de Huánuco, cielo, helada o campo seco | *"Frost and erratic rain are changing farming in the Andes."* |
| 4–8 | Celular en **modo avión** abriendo Muyuy | *"Muyuy brings NASA Earth data to farmers — even offline."* |
| 8–14 | El agricultor elige su chacra y su rotación · el calendario se pinta de azul en junio | *"40 years of NASA climate data reveal frost and drought risk."* |
| 14–20 | Las 3 rotaciones con barras y confianza · terreno 3D girando | *"It compares crop rotations and explains the trade-offs."* |
| 20–25 | Un celular pasa el paquete a otro | *"Data travels phone-to-phone where there's no signal."* |
| 25–30 | El agricultor sonriendo o asintiendo · logo Muyuy | *"Tested with a real farmer in Huánuco, Peru. Muyuy."* |

### Reglas
- Graba en **horizontal**, 1080p. Grabación de pantalla del celular para las tomas de la app.
- Subtítulos **quemados en el video** (no solo un archivo aparte).
- Súbelo a **YouTube (público o no listado)** o a Google Drive **con acceso público**. Prueba el enlace en incógnito.
- **Plan B:** si el domingo no hay tomas del campo, usa la grabación de pantalla + fotos de la zona con licencia libre.
- Editor gratis: CapCut, DaVinci Resolve o Clipchamp.

---

## 6. 📊 Diapositivas (máx. 7 · inglés)

| # | Título | Contenido |
|---|---|---|
| 1 | **Muyuy** | Eslogan · reto · equipo · Huánuco, Peru |
| 2 | **The problem** | Pedrito: frost, erratic rain, tired soil, no signal · 1 dato fuerte de la zona |
| 3 | **Our solution** | Diagrama: NASA data → calendar → rotation engine → offline app → phone-to-phone |
| 4 | **Evidence, not guesses** | Datos NASA usados + ciencia agronómica · gráfico de helada por mes (de la persona de datos) · *"AI explains, it doesn't decide"* |
| 5 | **Demo** | Capturas: calendario, 3 rotaciones con confianza, 3D, modo avión |
| 6 | **Field test** | Fotos de Huánuco + qué dijo el agricultor + qué aprendimos |
| 7 | **Impact & next steps** | Global (cualquier coordenada) · quechua · SMAP/Landsat/Prithvi · piloto con cooperativas |

Herramienta: Google Slides o Canva → exportar a PDF → enlace **público**.

---

## 7. ✍️ Borradores de textos para el formulario (inglés)

> Ajústalos con lo que realmente terminemos construyendo.

**Project summary**
> Muyuy is an offline-first mobile app that helps smallholder farmers choose more resilient crop rotations using NASA Earth data. It turns 40 years of NASA POWER climate records into a simple agro-climatic calendar (frost, drought, water balance) and compares the farmer's current rotation with two alternatives, showing benefits, trade-offs and confidence levels in plain language. Designed for rural areas without internet, Muyuy shares regional data packages phone-to-phone. We built and tested it with a farmer in Huánuco, Peru.

**NASA data used**
> We used NASA POWER (daily temperature, precipitation, evapotranspiration and humidity, 1985–2024) to compute monthly frost probability, rainfall, evapotranspiration and water balance for each zone. These indicators feed our rotation engine, which matches them with crop requirements to score each rotation for water use, soil health, income and climate risk.

**Other data, resources and tools**
> FAO ECOCROP (crop requirements), Flutter, Quarkus, Three.js, Astro, Oracle Cloud, Cloudflare Pages, Groq (Llama 3.3 70B). [+ música, imágenes y librerías con licencia que usemos.]

**Use of AI**
> We used Groq (Llama 3.3 70B) to generate plain-language explanations of each rotation recommendation. All numbers and recommendations come from our deterministic rotation engine based on NASA data; the AI only rephrases them. AI coding assistants were used to support development. No AI-generated images or NASA branding were used. [Ajustar si se usó IA para imágenes, audio o video → marca de agua.]

---

## 8. 📅 Tu cronograma

### Viernes 13 (preparación)
- [ ] Cuenta de Cloudflare · crear el proyecto de Pages
- [ ] Ubicar el código Three.js del terreno de XLR Harvest y hacerlo correr
- [ ] Guion del video (sección 5) y títulos de las diapositivas (sección 6)
- [ ] Hoja de **permiso de grabación** para el agricultor
- [ ] Revisar con el equipo quién y dónde se graba el domingo

### Sábado 14
| Hora | Tarea |
|---|---|
| **9:00** | 🤝 Confirmar el contrato del paquete (el `calendario` que recibe el 3D) |
| 9–14 | **Terreno 3D** con el contrato de la sección 3 (`?demo=1` funcionando) → entregarlo a la app |
| 14–18 | Landing: hero + problem + how it works + NASA data |
| 18–21 | Publicar en Cloudflare Pages · pedir el gráfico de evidencia a la persona de datos |
| **21:00** | 🔴 Hito del equipo · probar el 3D dentro de la app |
| 21–24 | Diapositivas 1–4 · preparar el equipo de grabación (baterías, espacio libre) |

### Domingo 15
| Hora | Tarea |
|---|---|
| **7–12** | 🚜 **Prueba de campo: grabar las tomas** (permiso firmado primero) |
| 12–13 | Revisión del equipo |
| 13–17 | **Editar el video** de 30 s con subtítulos en inglés |
| 17–18 | Landing: video + sección de prueba de campo |
| **18:00** | 🧊 Código congelado |
| 18–20 | Diapositivas 5–7 · APK + SHA-256 en la landing · textos del formulario finales |
| 20–21 | ✅ Entrega con todo el equipo · **probar cada enlace en incógnito** |

---

## 9. ✅ "Terminado" significa

- [ ] Landing pública en Cloudflare Pages, bien vista en el celular
- [ ] Terreno 3D funcionando **offline dentro de la app** y en la landing
- [ ] Video ≤ 30 s, subtítulos en inglés, enlace público
- [ ] ≤ 7 diapositivas en inglés, enlace público
- [ ] Textos del formulario listos en inglés
- [ ] Sin logo NASA, sin datos personales, sin menores, créditos completos

## 10. ✂️ Si falta tiempo, se corta en este orden

1. Partículas y animaciones extra del 3D
2. Sección *Team* de la landing (basta con el footer)
3. Diapositivas → entregar **solo el video** como demo (es válido)

**Lo que nunca se corta:** el video de 30 s con subtítulos y una landing pública con enlace a la demo y al repo.
