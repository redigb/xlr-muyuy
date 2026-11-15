import type { APIRoute } from 'astro';

/**
 * Sitemap mínimo escrito a mano.
 *
 * El sitio es una sola página (las 4 lenguas se cambian en el cliente sobre la
 * misma URL, así que no hay hreflang que declarar). Si en el futuro se agregan
 * rutas —/privacidad, /prensa, /documentacion— conviene reemplazar este
 * endpoint por la integración oficial `@astrojs/sitemap`.
 */
export const GET: APIRoute = ({ site }) => {
  const origin = site?.origin ?? null;
  const lastmod = new Date().toISOString().slice(0, 10);

  const urls = origin
    ? `  <url>
    <loc>${new URL('/', origin).href}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>`
    : '';

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>
`;

  return new Response(body, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
};
