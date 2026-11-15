import React, { useEffect, useState } from 'react';

/**
 * "Live backend": prueba, en el navegador del visitante, que el backend en
 * producción responde. Solo lectura y solo rutas públicas:
 *   GET /q/health/ready                 → estado, base de datos y catálogo
 *   GET /api/paquete/{zona}/version     → versión y hash vigentes de cada zona
 *
 * La página nunca depende de esto: si la API no responde, se dice con claridad
 * y el resto sigue con el snapshot incluido en el build.
 *
 * @param {{
 *   t: (key: string) => string,
 *   glass: string,
 *   apiBase: string,
 *   zones: { id: string, nombre: string }[],
 *   snapshot?: { fetchedAt: string, versions: Record<string, { version: number, hash: string }> },
 * }} props
 */
export default function LiveStatus({ t, glass, apiBase, zones, snapshot }) {
  const [health, setHealth] = useState({ state: 'checking' });
  const [versions, setVersions] = useState({});

  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 9000);
    const getJson = async (path) => {
      const response = await fetch(apiBase + path, { signal: controller.signal, headers: { accept: 'application/json' } });
      if (!response.ok) throw new Error(String(response.status));
      return response.json();
    };

    // Latencia de red real (Resource Timing): medirla con performance.now()
    // incluiría el tiempo en que el hilo principal está ocupado con el 3D.
    const networkTime = (url) => {
      const entry = performance.getEntriesByName(url).at(-1);
      return entry && entry.responseEnd > 0 ? Math.round(entry.responseEnd - entry.startTime) : null;
    };
    getJson('/q/health/ready')
      .then((body) => {
        const datos = body.checks?.find((check) => check.name === 'datos')?.data ?? {};
        const database = body.checks?.find((check) => /database/i.test(check.name))?.status;
        setHealth({
          state: body.status === 'UP' ? 'up' : 'down',
          latency: networkTime(apiBase + '/q/health/ready'),
          database,
          zonas: datos.zonas,
          cultivos: datos.cultivos,
          reglas: datos.reglas,
        });
      })
      .catch(() => setHealth({ state: 'offline' }));

    for (const zone of zones) {
      getJson(`/api/paquete/${zone.id}/version`)
        .then((body) => setVersions((current) => ({ ...current, [zone.id]: body })))
        .catch(() => {});
    }

    return () => { clearTimeout(timer); controller.abort(); };
  }, [apiBase, zones]);

  const status = {
    checking: t('Checking the live API…'),
    up: t('Operational'),
    down: t('Degraded'),
    offline: t('Unreachable · showing the bundled snapshot'),
  }[health.state];
  const snapshotDate = snapshot?.fetchedAt ? snapshot.fetchedAt.slice(0, 10) : null;

  return (
    <div className={'muyuy-live ' + glass} aria-labelledby="live-title">
      <header className="muyuy-live-head">
        <div>
          <p className="muyuy-eyebrow">{t('Live backend')}</p>
          <h3 id="live-title">{t('Not a mock-up. This page is talking to the engine right now.')}</h3>
        </div>
        <p className="muyuy-live-status" data-state={health.state} role="status">
          <span className="muyuy-live-dot" aria-hidden="true" />
          {status}
          {health.latency != null && <span className="muyuy-live-ms">{health.latency} ms</span>}
        </p>
      </header>

      <dl className="muyuy-live-grid">
        <div><dt>{t('Database')}</dt><dd>{health.database ?? '—'}</dd></div>
        <div><dt>{t('Official zones')}</dt><dd>{health.zonas ?? '—'}</dd></div>
        <div><dt>{t('Crops in the catalog')}</dt><dd>{health.cultivos ?? '—'}</dd></div>
        <div><dt>{t('Agronomic rules')}</dt><dd>{health.reglas ?? '—'}</dd></div>
      </dl>

      <ul className="muyuy-live-packages" aria-label={t('Sealed regional packages')}>
        {zones.map((zone) => {
          const live = versions[zone.id];
          const bundled = snapshot?.versions?.[zone.id];
          const liveHash = live ? String(live.hash).replace(/^sha256:/, '') : null;
          const same = live && bundled && liveHash === bundled.hash;
          return (
            <li key={zone.id}>
              <span className="muyuy-live-zone">{zone.nombre}</span>
              <code>{live ? `v${live.version} · ${liveHash.slice(0, 10)}` : bundled ? `v${bundled.version} · ${bundled.hash.slice(0, 10)}` : '—'}</code>
              <span className="muyuy-live-tag" data-kind={live ? (same ? 'same' : 'newer') : 'bundled'}>
                {live ? (same ? t('Matches this page') : t('Newer on the server')) : t('Bundled')}
              </span>
            </li>
          );
        })}
      </ul>

      <p className="muyuy-small muyuy-live-foot">
        {t('Read-only public routes')} · <code>GET /q/health/ready</code> · <code>GET /api/paquete/&#123;zona&#125;/version</code>
        {snapshotDate && <> · {t('Snapshot bundled on')} {snapshotDate}</>}
        {' · '}<a href={apiBase + '/q/swagger-ui'} target="_blank" rel="noopener noreferrer">{t('Open the API')} ↗</a>
      </p>
      <style>{css}</style>
    </div>
  );
}

const css = `
  .muyuy-live { width: 100%; margin-top: 12px; }
  .muyuy-live-head { display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 12px 24px; }
  .muyuy-live-head h3 { margin-top: 4px; font: 400 clamp(20px, 2.2vw, 26px)/1.2 "Instrument Serif", Georgia, serif; color: #eef2e6; max-width: 34ch; }
  .muyuy-live-status { display: inline-flex; align-items: center; gap: 8px; margin: 0 !important; padding: 6px 12px; border: 1px solid #ffffff1f; border-radius: 999px; font: 500 11px/1.4 var(--font-mono, monospace); color: #cdd6c2 !important; }
  .muyuy-live-dot { width: 8px; height: 8px; border-radius: 50%; background: #8a8f84; }
  .muyuy-live-status[data-state=up] .muyuy-live-dot { background: #8fdc6a; box-shadow: 0 0 0 0 #8fdc6a88; animation: muyuy-live-pulse 2s infinite; }
  .muyuy-live-status[data-state=down] .muyuy-live-dot { background: #f0c96a; }
  .muyuy-live-status[data-state=offline] .muyuy-live-dot { background: #e0806a; }
  .muyuy-live-ms { color: #8f978a; }
  @keyframes muyuy-live-pulse { 70% { box-shadow: 0 0 0 7px #8fdc6a00; } 100% { box-shadow: 0 0 0 0 #8fdc6a00; } }
  .muyuy-live-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 1px; margin: 20px 0 0; background: #ffffff14; border: 1px solid #ffffff14; border-radius: 10px; overflow: hidden; }
  .muyuy-live-grid > div { padding: 12px 14px; background: #0b0f0cd9; }
  .muyuy-live-grid dt { font-size: 10.5px; color: #8f978a; }
  .muyuy-live-grid dd { margin: 4px 0 0; font: 500 18px/1.2 var(--font-mono, monospace); color: #dcecc0; }
  .muyuy-live-packages { list-style: none; padding: 0; margin: 14px 0 0; display: grid; gap: 6px; }
  .muyuy-live-packages li { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 12px; padding: 8px 12px; border: 1px solid #ffffff12; border-radius: 8px; font-size: 12px; }
  .muyuy-live-zone { color: #d6dbcf; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .muyuy-live-packages code { font: 11px/1.4 var(--font-mono, monospace); color: #b9c4ac; }
  .muyuy-live-tag { padding: 1px 7px; border-radius: 4px; font: 600 9px/1.6 var(--font-mono, monospace); letter-spacing: .06em; text-transform: uppercase; border: 1px solid #ffffff26; color: #a9b0a3; }
  .muyuy-live-tag[data-kind=same] { border-color: #8fdc6a55; color: #a9e08c; }
  .muyuy-live-tag[data-kind=newer] { border-color: #f0c96a55; color: #f0c96a; }
  .muyuy-live-foot { margin-top: 14px !important; }
  .muyuy-live-foot code { font-size: 10px; color: #9fa699; }
  @media (max-width: 760px) {
    .muyuy-live-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .muyuy-live-packages li { grid-template-columns: minmax(0, 1fr) auto; }
    .muyuy-live-packages code { display: none; }
  }
  @media (prefers-reduced-motion: reduce) { .muyuy-live-dot { animation: none !important; } }
`;
