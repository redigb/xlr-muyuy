#!/usr/bin/env node
/**
 * Sincroniza los paquetes climáticos reales de la API al landing.
 *
 * El landing NO consulta la API en runtime: guarda un snapshot en
 * `src/data/paquetes.json` y lo usa en build. Así el build es determinista
 * (sin red en CI) y actualizar los datos es un acto explícito:
 *
 *   node scripts/sync-data.mjs
 *
 * De cada zona se conserva lo que la portada realmente muestra —calendario
 * mensual, zona, procedencia, mes de siembra y las 3 mejores rotaciones— y se
 * descartan `extras` (imagen satelital en base64, pesa más que todo lo demás) y
 * la tabla completa de cultivos.
 */
import { gzipSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

const API = process.env.MUYUY_API ?? 'https://muyuy-bk.rdev7.net.pe';
const OUT = join(new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'), 'src/data/paquetes.json');

const get = async (path) => {
  const response = await fetch(API + path, { headers: { accept: 'application/json' } });
  if (!response.ok) throw new Error(`${path} → ${response.status} ${response.statusText}`);
  return response.json();
};

console.log(`\n▸ ${API}`);

// Solo las 3 zonas reales de Huánuco: `global-demo` es un paquete de demo,
// no un lugar, y confundiría el selector.
const zonas = (await get('/api/zonas')).filter(
  (z) => ['sierra', 'valle', 'selva'].includes(z.region) && !/demo/i.test(z.id)
);
if (!Array.isArray(zonas) || !zonas.length) {
  console.error('  ❌ /api/zonas no devolvió zonas');
  process.exit(1);
}

/**
 * Modo global: lugares fuera de Huánuco calculados por el mismo motor con
 * /api/paquete/coordenada. Se generan aquí (la primera consulta de una celda
 * tarda ~7 s en el servidor) para que el visitante no espere.
 */
const GLOBALES = [
  { id: 'kenya-highlands', nombre: 'Nairobi, Kenya', lat: -1.29, lon: 36.82 },
  { id: 'punjab', nombre: 'Punjab, India', lat: 30.9, lon: 75.85 },
  { id: 'sahel', nombre: 'Niamey, Niger', lat: 13.51, lon: 2.11 },
  { id: 'iowa', nombre: 'Iowa, USA', lat: 41.88, lon: -93.1 },
];

/** Bioma del terreno 3D a partir del clima real (no hay `region` fuera de Huánuco). */
function biomaDe(nucleo) {
  const helada = Math.max(...nucleo.calendario.map((m) => m.prob_helada));
  const lluvia = nucleo.calendario.reduce((total, m) => total + m.lluvia_mm, 0);
  if (helada >= 0.3 || nucleo.zona.elevacion_m >= 2500) return 'sierra';
  return lluvia >= 1200 ? 'selva' : 'valle';
}

/** Lo que la portada muestra de un paquete: igual para zonas y lugares globales. */
function recortar({ meta, nucleo }) {
  if (!nucleo?.calendario?.length) throw new Error('paquete sin calendario');
  // Solo las 3 mejores rotaciones: es lo que se compara en la portada.
  const rotaciones = [...nucleo.rotaciones]
    .sort((a, b) => b.puntajes.total - a.puntajes.total)
    .slice(0, 3)
    .map(({ id, secuencia, puntajes, explicacion, es_practica_comun }) => ({
      id,
      secuencia,
      puntajes,
      explicacion,
      es_practica_comun,
    }));

  return {
    meta: {
      version: meta.version,
      hash: meta.hash,
      generado: meta.generado,
      validada_localmente: meta.validada_localmente,
      origen: meta.origen,
    },
    zona: nucleo.zona,
    fuente_clima: nucleo.fuente_clima,
    inicio_siembra_mes: nucleo.inicio_siembra_mes,
    calendario: nucleo.calendario.map(({ mes, prob_helada, lluvia_mm, et_mm, balance_hidrico_mm, t_min, t_max }) => ({
      mes,
      prob_helada,
      lluvia_mm,
      et_mm,
      balance_hidrico_mm,
      t_min,
      t_max,
    })),
    rotaciones,
    // id → nombre legible, para mostrar la secuencia de la rotación.
    nombres: Object.fromEntries(nucleo.cultivos.map((c) => [c.id, c.nombre])),
    cultivos: nucleo.cultivos.length,
  };
}

const paquetes = {};

for (const zona of zonas) {
  const { paquete } = await get(`/api/paquete/${zona.id}`);
  const { nucleo } = paquete;

  if (!nucleo?.calendario?.length) {
    console.error(`  ❌ ${zona.id} llegó sin calendario`);
    process.exit(1);
  }

  paquetes[zona.id] = recortar(paquete);

  const frost = Math.max(...nucleo.calendario.map((m) => m.prob_helada));
  const dry = Math.min(...nucleo.calendario.map((m) => m.balance_hidrico_mm));
  console.log(
    `  ✅ ${zona.id.padEnd(16)} ${String(zona.elevacion_m).padStart(4)} m · helada máx ${String(Math.round(frost * 100)).padStart(3)}% · balance mín ${dry} mm · siembra mes ${nucleo.inicio_siembra_mes}`
  );
}

const globales = [];
for (const lugar of GLOBALES) {
  const t0 = Date.now();
  const { paquete } = await get(`/api/paquete/coordenada?lat=${lugar.lat}&lon=${lugar.lon}&lang=en`);
  const recorte = recortar(paquete);
  globales.push({
    ...lugar,
    region: biomaDe(paquete.nucleo),
    elevacion_m: paquete.nucleo.zona.elevacion_m,
    paquete: recorte,
  });
  console.log(`  🌍 ${lugar.id.padEnd(16)} ${String(paquete.nucleo.zona.elevacion_m).padStart(4)} m · ${biomaDe(paquete.nucleo).padEnd(6)} · siembra mes ${recorte.inicio_siembra_mes} · ${Date.now() - t0} ms`);
}

const snapshot = {
  fetchedAt: new Date().toISOString(),
  api: API,
  /** Totales del catálogo (para las cifras de impacto). */
  catalog: {
    zonas: zonas.length,
    cultivos: Number(await get('/q/health/ready').then((h) => h.checks.find((c) => c.name === 'datos')?.data?.cultivos ?? 0)),
    reglas: Number(await get('/q/health/ready').then((h) => h.checks.find((c) => c.name === 'datos')?.data?.reglas ?? 0)),
  },
  zonas: zonas.map(({ id, nombre, region, lat, lon, elevacion_m, riego, cultivos_iniciales }) => ({
    id,
    nombre,
    region,
    lat,
    lon,
    elevacion_m,
    riego,
    cultivos_iniciales,
  })),
  paquetes,
  globales,
};

writeFileSync(OUT, JSON.stringify(snapshot, null, 2) + '\n', 'utf8');

const gz = gzipSync(Buffer.from(JSON.stringify(snapshot))).length;
console.log(`\n  catálogo  ${snapshot.catalog.zonas} zonas · ${snapshot.catalog.cultivos} cultivos · ${snapshot.catalog.reglas} reglas`);
console.log(`  snapshot  ${(Buffer.byteLength(JSON.stringify(snapshot)) / 1024).toFixed(1)} KB · ${(gz / 1024).toFixed(1)} KB gzip`);
console.log(`  → ${OUT}\n`);
