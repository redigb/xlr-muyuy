#!/usr/bin/env node
/**
 * Prueba de render de la isla.
 *
 * `astro build` NO ejecuta los componentes de React que van con `client:only`,
 * así que un `ReferenceError` dentro de LandingUI (una variable, un prop mal
 * renombrado) compila perfecto y deja la página en negro en el navegador.
 *
 * Este script renderiza la isla en el servidor con una página temporal, revisa
 * que las secciones existan y limpia todo. Falla si el render explota.
 *
 *   node scripts/render-check.mjs
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const PAGE = join(ROOT, 'src/pages/render-check.astro');
const OUT = join(ROOT, 'dist/render-check/index.html');
const ASTRO = join(ROOT, 'node_modules/astro/bin/astro.mjs');

/** Secciones que deben existir sí o sí en el HTML renderizado. */
const EXPECTED_SECTIONS = [
  'hero',
  'cultivated-field',
  'problem',
  'how-it-works',
  'explorer',
  'app-demo',
  'field-test',
  'why-it-matters',
  'download',
  'team',
];

const PAGE_SOURCE = `---
// Generado por scripts/render-check.mjs — no editar ni commitear.
// Usa los MISMOS datos reales que src/pages/index.astro: si el snapshot está
// mal formado o un prop cambió de forma, esto falla antes que el navegador.
import LandingUI from '../components/LandingUI.jsx';
import paquetes from '../data/paquetes.json';

const ZONES = paquetes.zonas.map((zona) => {
  const paquete = paquetes.paquetes[zona.id];
  return {
    id: zona.id,
    nombre: zona.nombre,
    region: zona.region,
    elevacion_m: zona.elevacion_m,
    cultivos: paquete.cultivos,
    inicioSiembra: paquete.inicio_siembra_mes,
    fuenteClima: paquete.fuente_clima,
    calendar: paquete.calendario,
    rotaciones: paquete.rotaciones,
    nombres: paquete.nombres,
    version: paquete.meta.version,
    hash: String(paquete.meta.hash).replace(/^sha256:/, ''),
    apiUrl: paquetes.api + '/api/paquete/' + zona.id,
  };
});
---

<html>
  <body>
    <LandingUI zones={ZONES} />
  </body>
</html>
`;

const cleanup = () => {
  for (const path of [PAGE, join(ROOT, 'dist/render-check')]) {
    rmSync(path, { recursive: true, force: true });
  }
};

let failed = false;

try {
  writeFileSync(PAGE, PAGE_SOURCE, 'utf8');

  console.log('\n▸ renderizando la isla en el servidor…');
  // stdio: 'inherit' — con 'pipe' algunos sandboxes (y Windows CI) fallan con EPERM.
  execFileSync(process.execPath, [ASTRO, 'build'], {
    cwd: ROOT,
    stdio: 'inherit',
    env: { ...process.env, ASTRO_TELEMETRY_DISABLED: '1' },
  });

  if (!existsSync(OUT)) {
    console.error('  ❌ el render no generó HTML');
    process.exit(1);
  }

  const html = readFileSync(OUT, 'utf8');
  const found = [...html.matchAll(/<section id="([^"]+)"/g)].map((m) => m[1]);

  for (const id of EXPECTED_SECTIONS) {
    if (found.includes(id)) console.log(`  ✅ #${id}`);
    else {
      console.error(`  ❌ falta la sección #${id}`);
      failed = true;
    }
  }

  // Señales de que el contenido real llegó al DOM (no solo los contenedores)
  for (const [label, probe] of [
    ['tarjetas del equipo', 'muyuy-team-grid'],
    ['cifras de impacto', 'muyuy-stat-value'],
    ['plan de validación', 'muyuy-questions'],
    ['botón de descarga', 'Download Muyuy APK'],
    ['datos reales de la API', 'Sierra de Huanuco'],
    ['selector de zona', 'muyuy-zone-options'],
    ['calendario climatico', 'muyuy-climate-month'],
    ['helada pico real (82%)', '82%'],
    ['rotacion real del motor', 'muyuy-step-data'],
    ['footer profesional', 'muyuy-footer-main'],
  ]) {
    if (html.includes(probe)) console.log(`  ✅ ${label}`);
    else {
      console.error(`  ❌ no se renderizó: ${label}`);
      failed = true;
    }
  }
} catch (error) {
  console.error('\n❌ el render de la isla falló:\n');
  console.error(error.message);
  failed = true;
} finally {
  cleanup();
}

console.log('\n────────────────────────────────────────');
if (failed) {
  console.error('✗ la isla no renderiza: la página saldría en negro.\n');
  process.exit(1);
}
console.log('✓ la isla renderiza y todas las secciones están presentes.\n');
