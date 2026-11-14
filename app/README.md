# MUYUY · App Flutter

Decisiones de campo con datos climáticos para Huánuco. NASA Space Apps Challenge 2026.

## Estado actual

Frontend completo con las 5 pantallas del flujo:

1. **Inicio** — logo de marca, selector de zona, estado y descarga del paquete.
2. **Mi chacra** — zona, rotación actual, riego y 2 prioridades.
3. **Mi calendario** — escena de terreno animada, 12 meses y detalle climático.
4. **Mis opciones** — 3 rotaciones ordenadas en vivo, puntajes, confianza y explicación.
5. **Compartir** — QR de zona + versión, envío del archivo e importación offline.

Funciona con el paquete de respaldo incluido en `assets/data/` y guarda en el
dispositivo lo que descarga de la API, por lo que el flujo principal no depende
de la señal.

## Stack

- Flutter 3.50 · Dart 3.14 · Material 3 (`material_ui`)
- `http` · `shared_preferences` · `path_provider`
- `share_plus` · `file_selector` · `qr_flutter`
- `connectivity_plus` · `flutter_animate`

## Marca

- Colores: `#14532D`, `#22C55E`, `#84CC16`, `#A16207`, `#0EA5E9`, `#ECFDF5`.
- Tipografías empaquetadas: **Poppins** (títulos, marca, botones) e **Inter**
  (textos, párrafos, datos). Licencias OFL incluidas en `assets/fonts/`.
- Isotipo recortado para el ícono adaptativo de Android y la web.

## Ejecutar

```bash
flutter pub get
flutter run -d chrome          # demo web
flutter run -d <android>       # celular / emulador
```

API Quarkus (por defecto `http://10.0.2.2:8080` en Android y
`http://localhost:8080` en web):

```bash
flutter run --dart-define=MUYUY_API_URL=https://tu-api.example.com
```

Al no responder la API, la app carga el paquete local y muestra el estado
offline. El botón **Actualizar paquete** es el único que requiere red.

## Android

- `minSdk = 29` (Android 10 o superior), `applicationId = pe.muyuy.muyuy`.
- Íconos adaptativos con fondo verde de marca y foreground blanco.
- Permiso de internet; tráfico local sin TLS solo en builds `debug`.
- APK de desarrollo:

```bash
flutter build apk --debug
```

La firma release queda pendiente de la clave `.jks` del equipo.

## Estructura

```text
lib/
  data/        datos demo y cálculo de puntajes
  features/    inicio, chacra, calendario, opciones, compartir, splash
  models/      contrato JSON (paquete, zona, calendario, rotación)
  services/    API, almacenamiento local, archivo y QR
  state/       AppState + AppScope (offline-first)
  theme/       colores, tipografías y tema Material 3
  widgets/     logo, tarjetas, barras, escena de terreno, navegación
assets/
  data/        paquete de respaldo huanuco-sierra
  fonts/       Poppins e Inter + licencias
  images/      logos original/blanco, isotipo e íconos
screenshots/   capturas de las pantallas
```

## Pruebas

```bash
flutter analyze
flutter test
```

Las pruebas cubren el puntaje ponderado por prioridades, el orden de las
rotaciones, la serialización del paquete y la clasificación de meses.
