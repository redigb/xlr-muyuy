# Landing de Muyuy · Astro

Sitio público del proyecto **Muyuy** (NASA Space Apps Challenge 2026, Huánuco, Perú).
Es una sola página: una isla de React (`client:only`) con un terreno andino en Three.js,
scroll narrativo y cuatro idiomas.

> El resto del monorepo: [`../app`](../app) (Flutter) · [`../backend`](../backend) (Quarkus).

---

## Arrancar

Requisitos: **Node ≥ 22.23.4** y pnpm (`packageManager` ya fija la versión).

```bash
pnpm install
pnpm dev          # http://localhost:4321
```

| Comando | Qué hace |
|---|---|
| `pnpm dev` | Servidor de desarrollo con recarga en caliente |
| `pnpm build` | Compila a `dist/` (sitio estático) |
| `pnpm preview` | Sirve `dist/` para revisar el build real |
| `pnpm verify` | Revisa el build: SEO, OG, robots, sitemap, placeholders |
| `pnpm verify:strict` | Igual, pero **falla** si quedan placeholders de release |
| `pnpm og` | Regenera `public/og-image.png` desde el logo (requiere Python + Pillow) |
| `pnpm sync:data` | Trae los paquetes reales de la API → `src/data/paquetes.json` |
| `pnpm verify:render` | Renderiza la isla en el servidor y falla si algo no monta |

> ⚠️ **Windows:** si `pnpm install` deja un `node_modules` con junctions y Astro falla
> con `Cannot find package 'mri'`, reinstala con `pnpm install --node-linker=hoisted`.
> Astro necesita además `ASTRO_TELEMETRY_DISABLED=1` si `%APPDATA%` no es escribible.

---

## Dónde se edita cada cosa

| Quiero cambiar… | Archivo |
|---|---|
| Nombres, roles, bios, fotos y links del equipo | [`src/data/team.ts`](src/data/team.ts) |
| Las cifras de "Why it matters" y sus fuentes | [`src/data/impact.ts`](src/data/impact.ts) |
| La prueba de campo: preguntas, fotos, testimonios | [`src/data/fieldValidation.ts`](src/data/fieldValidation.ts) |
| Cualquier texto del sitio (4 idiomas) | [`src/i18n/copy.ts`](src/i18n/copy.ts) |
| **Los datos climáticos** (calendario, zonas, rotaciones) | [`src/data/paquetes.json`](src/data/paquetes.json) ← generado con `pnpm sync:data` |
| El título/descripción para buscadores y redes | [`src/pages/index.astro`](src/pages/index.astro) (constantes `title` / `description`) |
| El dominio público | [`astro.config.mjs`](astro.config.mjs) (`site`) |
| Colores, tipografía, layout | [`src/layouts/Layout.astro`](src/layouts/Layout.astro), [`src/components/LandingUI.jsx`](src/components/LandingUI.jsx) |
| El terreno 3D | [`src/components/MuyuyTerrain.jsx`](src/components/MuyuyTerrain.jsx) |

---

## Idiomas

- **Inglés es el idioma por defecto** (`DEFAULT_LOCALE` en `src/i18n/copy.ts`).
- El inglés **es la clave** del diccionario: si una traducción no existe, se muestra el
  texto inglés en lugar de romperse. Nunca aparece una clave cruda en pantalla.
- Cada entrada tiene la forma `[español, quechua, aymara]`. Un `""` significa
  "sin revisar" y cae al español; así no publicamos quechua/aimara generado a máquina.
  El quechua es de la variedad **Chanka** y ambas lenguas están pendientes de revisión
  por hablantes nativos.
- Para agregar un texto nuevo: escribe el inglés donde va (dentro de `t('...')`) y añade
  la fila en `copy.ts`.

---

## Variables de entorno

Todas son opcionales y se pueden definir en un `.env` (copia de `.env.example`) o en el
panel del hosting. Se leen en build, por eso llevan el prefijo `PUBLIC_`.

| Variable | Para qué |
|---|---|
| `PUBLIC_SITE_URL` | Dominio real del sitio. Sobreescribe `site` sin tocar código (útil en previews de PR). |
| `PUBLIC_MUYUY_APK_URL` | URL del APK firmado. Sin ella, el botón de descarga queda deshabilitado. |
| `PUBLIC_MUYUY_APK_SHA256` | Hash de 64 hex del APK. Se muestran **los dos** o ninguno. |
| `PUBLIC_MUYUY_GITHUB_URL` | Repo público. Si falta, el footer dice "GitHub link pending". |
| `PUBLIC_MUYUY_VIDEO_EMBED_URL` | Video demo (YouTube o URL `https://` embebible). |
| `PUBLIC_MUYUY_FIELD_VIDEO_EMBED_URL` | Video de campo. |

---

## SEO y redes sociales

El `<head>` vive en [`src/layouts/Layout.astro`](src/layouts/Layout.astro) y genera:
`canonical`, Open Graph (`og:*`), Twitter con `summary_large_image` y JSON-LD `WebSite`.
Si `site` no está configurado, el build **no rompe**: omite las URLs absolutas.

- `public/og-image.png` es la tarjeta social (1200×630). Se regenera con `pnpm og`.
- `src/pages/robots.txt.ts` y `src/pages/sitemap.xml.ts` se generan en build para que
  apunten al dominio real.
- `pnpm verify` comprueba todo lo anterior y falla si algo se rompe.

---

## Estado del release

- [x] Landing en inglés, español, quechua y aimara
- [x] Open Graph + Twitter Card + JSON-LD
- [x] `robots.txt` y `sitemap.xml`
- [ ] Dominio real (`site` sigue en el placeholder `https://vercel.app`)
- [ ] APK firmado + checksum publicado → entonces pasar el CI a `pnpm verify:strict`
- [ ] Fotos y testimonios reales de la validación en campo
- [ ] Datos reales del equipo en `src/data/team.ts` (quitar `placeholder: true`)

Despliegue previsto: **Cloudflare Pages** (build `pnpm build`, salida `dist`).
