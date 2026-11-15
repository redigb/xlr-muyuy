// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

import react from '@astrojs/react';

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
const SITE = process.env.PUBLIC_SITE_URL ?? 'https://vercel.app';

// https://docs.astro.build/en/reference/configuration-reference/
export default defineConfig({
  site: SITE,
  trailingSlash: 'ignore',

  vite: {
    plugins: [tailwindcss()]
  },

  integrations: [react()]
});
