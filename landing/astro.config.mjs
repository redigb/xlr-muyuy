// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

import react from '@astrojs/react';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * El terreno 3D (three.js, ~260 KB gzip) es un chunk diferido: sin ayuda, el
 * navegador solo lo pide cuando React ya montó la isla (cascada de red). Tras
 * el build se añade un <link rel="modulepreload"> en el HTML para que se
 * descargue en paralelo con React desde el primer byte.
 */
const preloadTerrain = {
  name: 'muyuy-preload-terrain',
  hooks: {
    'astro:build:done': ({ dir }) => {
      const dist = fileURLToPath(dir);
      const chunk = readdirSync(dist + '_astro').find((f) => /^MuyuyTerrain\.[\w-]+\.js$/.test(f));
      if (!chunk) return;
      const html = dist + 'index.html';
      const page = readFileSync(html, 'utf8');
      const tag = `<link rel="modulepreload" href="${base()}_astro/${chunk}">`;
      if (!page.includes(tag)) writeFileSync(html, page.replace('</head>', tag + '</head>'));
    },
  },
};
const base = () => (process.env.BASE_URL ?? '/').replace(/\/?$/, '/');

/**
 * Dominio público del sitio.
 *
 * ⚠️ TODO(deploy): reemplazar por el dominio real cuando se publique
 * (Cloudflare Pages / Vercel). `site` alimenta el <link rel="canonical">,
 * og:url, twitter:url, el sitemap y robots.txt.
 *
 * Se puede sobreescribir sin tocar código con la variable de entorno
 * PUBLIC_SITE_URL — útil para previews de cada PR.
 */
const SITE = process.env.PUBLIC_SITE_URL ?? 'https://landing-nine-sigma-82.vercel.app';

// https://docs.astro.build/en/reference/configuration-reference/
export default defineConfig({
  site: SITE,
  trailingSlash: 'ignore',

  vite: {
    plugins: [tailwindcss()]
  },

  integrations: [react(), preloadTerrain]
});
