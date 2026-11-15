import type { APIRoute } from 'astro';

/**
 * robots.txt generado en build para que la línea `Sitemap:` apunte al dominio
 * real configurado en `site` (no puede ser un archivo estático en /public).
 */
export const GET: APIRoute = ({ site }) => {
  const origin = site?.origin ?? null;
  const lines = ['User-agent: *', 'Allow: /'];

  if (origin) {
    lines.push('', `Sitemap: ${new URL('sitemap.xml', origin).href}`);
  }

  return new Response(lines.join('\n') + '\n', {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
