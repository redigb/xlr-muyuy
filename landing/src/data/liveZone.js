/**
 * Paquete en vivo para la ubicación del visitante (modo global).
 *
 * Usa la misma ruta pública que la app: GET /api/paquete/coordenada. La primera
 * consulta de una celda nueva tarda varios segundos en el servidor (calcula 40
 * años de NASA POWER); las siguientes salen de caché.
 *
 * El recorte replica scripts/sync-data.mjs → recortar()/biomaDe(): la portada
 * muestra lo mismo para una zona del snapshot que para una calculada en vivo.
 */

/** Bioma del terreno 3D a partir del clima real. */
export function biomeOf(nucleo) {
  const frost = Math.max(...nucleo.calendario.map((m) => m.prob_helada));
  const rain = nucleo.calendario.reduce((total, m) => total + m.lluvia_mm, 0);
  if (frost >= 0.3 || nucleo.zona.elevacion_m >= 2500) return 'sierra';
  return rain >= 1200 ? 'selva' : 'valle';
}

/** Convierte la respuesta de la API en la forma de zona que usa LandingUI. */
export function zoneFromPackage(paquete, { id, nombre, apiUrl }) {
  const { meta, nucleo } = paquete;
  if (!nucleo?.calendario?.length) throw new Error('package without calendar');
  return {
    id,
    nombre: nombre ?? nucleo.zona?.nombre ?? id,
    region: biomeOf(nucleo),
    elevacion_m: nucleo.zona.elevacion_m,
    global: true,
    live: true,
    cultivos: nucleo.cultivos.length,
    inicioSiembra: nucleo.inicio_siembra_mes,
    fuenteClima: nucleo.fuente_clima,
    calendar: nucleo.calendario,
    rotaciones: [...nucleo.rotaciones].sort((a, b) => b.puntajes.total - a.puntajes.total).slice(0, 3),
    nombres: Object.fromEntries(nucleo.cultivos.map((c) => [c.id, c.nombre])),
    version: meta.version,
    hash: String(meta.hash).replace(/^sha256:/, ''),
    validada: Boolean(meta.validada_localmente),
    apiUrl,
  };
}

/** Pide la posición al navegador (solo tras un clic del visitante). */
export function currentPosition() {
  return new Promise((resolve, reject) => {
    if (!('geolocation' in navigator)) return reject(new Error('geolocation unavailable'));
    navigator.geolocation.getCurrentPosition(
      (position) => resolve(position.coords),
      reject,
      { enableHighAccuracy: false, timeout: 12000, maximumAge: 600000 }
    );
  });
}

/**
 * Calcula el paquete de una coordenada. Se redondea a 2 decimales (~1 km):
 * la celda de NASA POWER es de 0.5°, así que no se pierde nada útil y no se
 * envía la posición exacta.
 */
export async function fetchLiveZone(apiBase, lat, lon, signal) {
  const la = Math.round(lat * 100) / 100;
  const lo = Math.round(lon * 100) / 100;
  if (Math.abs(la) > 60) throw new Error('out-of-range');
  const apiUrl = `${apiBase}/api/paquete/coordenada?lat=${la}&lon=${lo}&lang=en`;
  const response = await fetch(apiUrl, { headers: { accept: 'application/json' }, signal });
  if (!response.ok) throw new Error(`API ${response.status}`);
  const { paquete } = await response.json();
  return zoneFromPackage(paquete, { id: 'my-location', apiUrl });
}
