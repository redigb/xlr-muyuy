#!/usr/bin/env node
/**
 * Guardián del build de la landing.
 *
 * Corre después de `astro build` (en CI y a mano) y falla si el sitio saldría
 * a producción roto o con placeholders. Cada check imprime ✅ / ❌ y el
 * proceso termina con código 1 si alguno falla.
 *
 *   node scripts/verify-build.mjs
 */
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const DIST = new URL('../dist/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const problems = [];
const warnings = [];

/**
 * Mientras el APK firmado no exista, los checks de release son AVISOS.
 * Cuando se publique el release, el CI debe pasar `--strict`
 * (o definir STRICT_RELEASE=1) y entonces sí rompen el build.
 */
const STRICT = process.argv.includes('--strict') || process.env.STRICT_RELEASE === '1';

const ok = (msg) => console.log(`  ✅ ${msg}`);
const bad = (msg) => {
  problems.push(msg);
  console.log(`  ❌ ${msg}`);
};
const warn = (msg) => {
  warnings.push(msg);
  console.log(`  ⚠️  ${msg}`);
};

function read(path) {
  return readFileSync(path, 'utf8');
}

/** Lee ancho/alto de un PNG sin dependencias. */
function pngSize(path) {
  const buffer = readFileSync(path);
  if (buffer.toString('ascii', 1, 4) !== 'PNG') return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

console.log('\n▸ verificando dist/');

if (!existsSync(DIST)) {
  console.error('  ❌ no existe dist/ — corre `pnpm build` primero');
  process.exit(1);
}

// ── 1. HTML generado ────────────────────────────────────────────────────────
const htmlPath = join(DIST, 'index.html');
if (!existsSync(htmlPath)) {
  bad('falta dist/index.html');
} else {
  const html = read(htmlPath);

  if (!/<link rel="canonical" href="https?:\/\/[^"]+"/.test(html)) bad('falta <link rel="canonical"> absoluto (¿site sin configurar?)');
  else ok('canonical presente');

  if (!/property="og:image" content="https?:\/\/[^"]*og-image\.png"/.test(html)) bad('falta og:image apuntando a og-image.png');
  else ok('og:image presente');

  if (!/name="twitter:card" content="summary_large_image"/.test(html)) bad('twitter:card no es summary_large_image');
  else ok('twitter:card = summary_large_image');

  if (!/name="twitter:image"/.test(html)) bad('falta twitter:image');
  else ok('twitter:image presente');

  if (!/application\/ld\+json/.test(html)) bad('falta JSON-LD');
  else ok('JSON-LD presente');

  if (/PENDING_BUILD_HASH/.test(html)) {
    (STRICT ? bad : warn)('el HTML todavía contiene PENDING_BUILD_HASH (placeholder de release)');
  } else ok('sin hashes de relleno en el HTML');

  // contenido real sin JavaScript (SEO + primera pintura)
  const text = html.replace(/<script[\s\S]*?<\/script>/g, ' ').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  if (text.length < 400) bad(`el HTML estático casi no tiene texto (${text.length} chars): los buscadores y las conexiones lentas no ven nada`);
  else ok(`contenido estático indexable (${text.length} chars)`);
}

// ── 2. imagen social ────────────────────────────────────────────────────────
const ogPath = join(DIST, 'og-image.png');
if (!existsSync(ogPath)) {
  bad('falta dist/og-image.png');
} else {
  const size = pngSize(ogPath);
  if (!size) bad('og-image.png no es un PNG válido');
  else if (size.width !== 1200 || size.height !== 630) bad(`og-image.png mide ${size.width}×${size.height}, debería ser 1200×630`);
  else ok(`og-image.png 1200×630 (${(statSync(ogPath).size / 1024).toFixed(0)} KB)`);
}

// ── 3. rastreo ──────────────────────────────────────────────────────────────
const robots = join(DIST, 'robots.txt');
if (!existsSync(robots)) bad('falta dist/robots.txt');
else if (!/Sitemap: https?:\/\//.test(read(robots))) bad('robots.txt sin línea Sitemap absoluta');
else ok('robots.txt con sitemap');

const sitemap = join(DIST, 'sitemap.xml');
if (!existsSync(sitemap)) bad('falta dist/sitemap.xml');
else if (!read(sitemap).includes('<urlset')) bad('sitemap.xml inválido');
else ok('sitemap.xml válido');

// ── 4. placeholders que NO pueden viajar a producción ───────────────────────
const walk = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });

const leaks = walk(DIST)
  .filter((file) => /\.(html|js|css|txt|xml)$/.test(file))
  .filter((file) => read(file).includes('PENDING_BUILD_HASH'));

if (leaks.length) (STRICT ? bad : warn)(`${leaks.length} archivo(s) publican PENDING_BUILD_HASH`);
else ok('sin hashes de relleno en el bundle');

// ── 5. avisos (no rompen el build) ──────────────────────────────────────────
if (existsSync(htmlPath) && read(htmlPath).includes('https://vercel.app')) {
  warn('el dominio sigue siendo el placeholder "https://vercel.app" — cámbialo en astro.config.mjs antes de publicar');
}

const js = walk(DIST).filter((f) => f.endsWith('.js'));
const biggest = js.map((f) => ({ f, size: statSync(f).size })).sort((a, b) => b.size - a.size)[0];
if (biggest && biggest.size > 900 * 1024) {
  warn(`chunk más grande: ${(biggest.size / 1024).toFixed(0)} KB — revisa que el 3D siga cargando en diferido`);
} else if (biggest) {
  ok(`chunk más grande: ${(biggest.size / 1024).toFixed(0)} KB`);
}

console.log('\n────────────────────────────────────────');
if (problems.length) {
  console.error(`✗ ${problems.length} problema(s): el build no está listo para publicar.\n`);
  process.exit(1);
}
console.log(`✓ Build verificado${warnings.length ? ` (${warnings.length} aviso/s)` : ''}.\n`);
