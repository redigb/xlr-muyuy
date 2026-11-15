import React, { createContext, lazy, Suspense, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { motion, MotionConfig } from 'framer-motion';
import { Toaster, toast } from 'sonner';
import { Drawer } from 'vaul';
import { ArrowDown, ArrowUpRight, Check, ChevronRight, Copy, Download, Droplets, Globe2, Layers3, LoaderCircle, LocateFixed, Play, Radio, ShieldCheck, Snowflake, Sprout, X, ZoomOut } from 'lucide-react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import AppDemo from './AppDemo.jsx';
import TeamGrid from './TeamGrid.jsx';
import ImpactSection from './ImpactSection.jsx';
import FieldValidation from './FieldValidation.jsx';
import LiveStatus from './LiveStatus.jsx';
import { currentPosition, fetchLiveZone } from '../data/liveZone.js';
import { TEAM } from '../data/team.ts';
import { DEFAULT_LOCALE, LOCALES, months, translate } from '../i18n/copy.ts';

// three.js pesa ~600 kB: el terreno entra en un chunk aparte y se descarga
// después del primer pintado. El gradiente atmosférico cubre la espera.
// El .catch es la red de seguridad: si el chunk no llega (red, cache, deploy a
// medias), la pagina se queda sin 3D pero sigue funcionando.
// La descarga arranca al evaluar este módulo, no al primer render: así no
// espera a que React monte la isla (el HTML además la precarga, ver
// astro.config.mjs → preloadTerrain).
const terrainModule = typeof window === 'undefined'
  ? null
  : import('./MuyuyTerrain.jsx').catch((error) => {
    console.error('[Muyuy] no se pudo cargar el terreno 3D', error);
    return { default: () => null };
  });
const MuyuyTerrain = lazy(() => terrainModule ?? import('./MuyuyTerrain.jsx'));

// Loader de index.astro (#muyuy-loader): vive fuera de la isla, se ve desde el
// primer byte y se retira cuando el terreno pintó su primer frame.
const LOADER_TIMEOUT_MS = 9000;
function loaderStage(stage) {
  const loader = typeof document !== 'undefined' && document.getElementById('muyuy-loader');
  if (!loader || loader.dataset.stage === 'ready') return;
  loader.dataset.stage = stage;
  if (stage !== 'ready') return;
  loader.setAttribute('aria-busy', 'false');
  loader.addEventListener('transitionend', () => loader.remove(), { once: true });
  setTimeout(() => loader.remove(), 1200);
}

const EASE = [.32, .72, 0, 1];
const MotionEnabled = createContext(true);
const PENDING_HASH = 'PENDING_BUILD_HASH_2026...';
const APK_NOTICE = 'Muyuy is a hackathon prototype distributed outside Google Play, so Android may show a security warning. The APK is signed by our team. Verify the SHA-256 checksum below before installing.';
const LAYERS = [
  { value: 'normal', label: 'Normal', Icon: Layers3 },
  { value: 'helada', label: 'Frost Risk', Icon: Snowflake },
  { value: 'agua', label: 'Water Balance', Icon: Droplets },
];
const EXAMPLE_CALENDAR = [
  [.06, 34], [.04, 39], [.06, 27], [.13, 2], [.29, -19], [.56, -38],
  [.66, -49], [.50, -40], [.29, -24], [.17, -8], [.10, 14], [.07, 28],
].map(([prob_helada, balance_hidrico_mm], index) => ({ mes: index + 1, prob_helada, balance_hidrico_mm }));
/**
 * Capítulos de la historia que se ve ANTES del explorador. El scroll interpola
 * entre ellos con una curva suave, así el terreno nunca salta: verde → nevado →
 * deshielo → seco → verde otra vez.
 *
 * Cada capítulo fija nieve y aridez explícitas (0–1); `frost` solo alimenta las
 * etiquetas. Ajustá los `at` para mover los capítulos en la página.
 */
const STORY_CHAPTERS = [
  { at: 0, snow: 0, aridity: .16, frost: .02 },      // hero: verde
  { at: .09, snow: 0, aridity: .20, frost: .03 },    // se sostiene el verde
  { at: .21, snow: .92, aridity: .24, frost: .95 },  // helada: todo nevado
  { at: .33, snow: .55, aridity: .38, frost: .55 },  // deshielo
  { at: .46, snow: 0, aridity: .92, frost: .10 },    // estación seca
  { at: .58, snow: 0, aridity: .16, frost: .02 },    // vuelve el verde
  { at: 1, snow: 0, aridity: .16, frost: .02 },      // se mantiene hasta el explorador
];
const smoothstep = (value) => value * value * (3 - 2 * value);
function storyAt(progress) {
  const at = Math.min(1, Math.max(0, Number.isFinite(progress) ? progress : 0));
  for (let index = 0; index < STORY_CHAPTERS.length - 1; index++) {
    const from = STORY_CHAPTERS[index];
    const to = STORY_CHAPTERS[index + 1];
    if (at > to.at) continue;
    const t = smoothstep((at - from.at) / Math.max(1e-6, to.at - from.at));
    const mix = (a, b) => a + (b - a) * t;
    return { snow: mix(from.snow, to.snow), aridity: mix(from.aridity, to.aridity), frost: mix(from.frost, to.frost) };
  }
  return STORY_CHAPTERS[STORY_CHAPTERS.length - 1];
}
const glass = 'muyuy-glass pointer-events-auto bg-zinc-950/70 backdrop-blur-md border border-white/10';
const mono = 'font-mono tabular-nums';
const brandLogo = import.meta.env.BASE_URL + 'muyuy-logo.png';

function firstFieldScrollOffset(section) {
  const copy = section.firstElementChild;
  const bottomGap = 100;
  return Math.max(0, copy.offsetTop + copy.offsetHeight + bottomGap - window.innerHeight);
}

function safeUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return undefined;
  if (/^\/(?!\/)/.test(value)) return value;
  try { return new URL(value).protocol === 'https:' ? value : undefined; } catch { return undefined; }
}

/**
 * Red de seguridad de la isla.
 *
 * Si el render falla, la pagina NO se queda en negro: mantiene la marca, un
 * boton de recarga y —solo en desarrollo— el stack del error, para que el fallo
 * sea diagnosticable en pantalla en lugar de invisible.
 */
class IslandBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error('[Muyuy] error al renderizar la landing', error, info);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="muyuy-crash" role="alert">
        <img src={brandLogo} alt="Muyuy" width="1370" height="436" />
        <h1>Muyuy</h1>
        <p>NASA data to the last field — even without signal.</p>
        <p className="muyuy-crash-note">The interactive view could not start. Reload the page to try again.</p>
        <button type="button" onClick={() => window.location.reload()}>Reload</button>
        {import.meta.env.DEV && <pre className="muyuy-crash-stack">{String((this.state.error && this.state.error.stack) || this.state.error)}</pre>}
        <style>{CRASH_CSS}</style>
      </div>
    );
  }
}
function Reveal({ children, className = '', delay = 0, active }) {
  const enabled = useContext(MotionEnabled);
  const [entered, setEntered] = useState(false);
  const hidden = { opacity: 0, y: 42, filter: 'blur(5px)' };
  const visible = { opacity: 1, y: 0, filter: 'blur(0px)' };
  return (
    <motion.div className={`muyuy-reveal ${className}`} data-entered={(active ?? entered) ? 'true' : undefined}
      initial={enabled ? hidden : false}
      animate={!enabled ? visible : active === undefined ? undefined : active ? visible : hidden}
      whileInView={enabled && active === undefined ? visible : undefined}
      viewport={{ once: true, amount: .08, margin: '0px 0px -6% 0px' }}
      onViewportEnter={() => setEntered(true)}
      transition={{ duration: enabled ? 1.16 : 0, delay: enabled ? delay : 0, ease: EASE }}>
      {children}
    </motion.div>
  );
}

async function copyText(value, success) {
  try {
    await navigator.clipboard.writeText(value);
    toast.success(success);
  } catch {
    toast.error('Clipboard unavailable. Select and copy the text manually.');
  }
}

/**
 * Render this single React island with client:only="react".
 * It owns one MuyuyTerrain instance and forwards mode, month, data and scrollProgress.
 * Manual layers override scroll until "Follow the story" is pressed.
 * calendar entries: { mes: 1..12, prob_helada: 0..1, balance_hidrico_mm }.
 * Supply consented field media, a video embed URL, APK URL and the real checksum.
 */
/** Etiquetas cortas por región; el nombre largo de la zona viene de la API. */
const REGIONS = { sierra: 'Highlands', valle: 'Valley', selva: 'Jungle' };

export default function LandingUI({
  /** Zonas reales del paquete regional (scripts/sync-data.mjs). */
  zones = [],
  /** Modo global: lugares de otros continentes calculados por el mismo motor. */
  globalZones = [],
  /** Versiones y fecha del snapshot, para compararlas con la API en vivo. */
  snapshot,
  calendar: fallbackCalendar = EXAMPLE_CALENDAR,
  elevation: fallbackElevation = 3200,
  apkUrl,
  apkSha256 = PENDING_HASH,
  videoEmbedUrl,
  fieldVideoEmbedUrl,
  githubUrl,
  apiBase = 'https://muyuy-bk.rdev7.net.pe',
}) {
  const wrapper = useRef(null);
  const [zoneId, setZoneId] = useState(zones[0]?.id ?? null);
  // "Use my location": paquete calculado en vivo para la posición del visitante.
  const [myZone, setMyZone] = useState(null);
  const [locating, setLocating] = useState('idle');
  const allZones = myZone ? [...zones, ...globalZones, myZone] : [...zones, ...globalZones];
  const activeZone = allZones.find((candidate) => candidate.id === zoneId) ?? zones[0] ?? null;
  const calendar = activeZone?.calendar ?? fallbackCalendar;
  const elevation = activeZone?.elevacion_m ?? fallbackElevation;
  const exampleData = calendar === EXAMPLE_CALENDAR;
  const [manualMonth, setManualMonth] = useState(null);
  const [manualLayer, setManualLayer] = useState(null);
  const [storyLayer, setStoryLayer] = useState('normal');
  const [progress, setProgress] = useState(0);
  const [fieldJourney, setFieldJourney] = useState(null);
  const [explorerEntered, setExplorerEntered] = useState(false);
  const [wideFieldView, setWideFieldView] = useState(false);
  const [wideIslandView, setWideIslandView] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [motionEnabled, setMotionEnabled] = useState(true);
  const [locale, setLocale] = useState(DEFAULT_LOCALE);
  const [terrainReady, setTerrainReady] = useState(false);
  const markTerrainReady = useCallback(() => setTerrainReady(true), []);
  useEffect(() => {
    loaderStage('terrain');
    let alive = true;
    terrainModule?.then(() => { if (alive) loaderStage('render'); });
    // Red de seguridad: un equipo sin WebGL o un chunk que no llega nunca
    // dejan la página detrás del loader.
    const timer = setTimeout(() => { if (alive) setTerrainReady(true); }, LOADER_TIMEOUT_MS);
    return () => { alive = false; clearTimeout(timer); };
  }, []);
  useEffect(() => {
    if (!terrainReady) return;
    loaderStage('ready');
    ScrollTrigger.refresh();
  }, [terrainReady]);
  const t = (key) => translate(key, locale);
  const monthNames = months[locale];
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);
  const reduced = !motionEnabled;
  const layer = manualLayer ?? storyLayer;
  // Los tres capítulos del relato se anclan a los extremos REALES del paquete:
  // mes de siembra, mes de mayor helada y mes de peor balance hídrico.
  const frostPeak = calendar.reduce((best, entry) => (entry.prob_helada > best.prob_helada ? entry : best), calendar[0]);
  const driest = calendar.reduce((worst, entry) => (entry.balance_hidrico_mm < worst.balance_hidrico_mm ? entry : worst), calendar[0]);
  const sowingMonth = activeZone?.inicioSiembra ?? 10;
  const storyMonth = storyLayer === 'helada' ? frostPeak.mes : storyLayer === 'agua' ? driest.mes : sowingMonth;
  const month = manualMonth ?? storyMonth;
  const selectedMonth = Array.isArray(calendar) ? calendar.find((entry) => entry?.mes === month) : undefined;
  const probability = selectedMonth?.prob_helada;
  const water = selectedMonth?.balance_hidrico_mm;
  const rain = selectedMonth?.lluvia_mm;
  const frostValid = Number.isFinite(probability) && probability >= 0 && probability <= 1;
  // Riesgo de sequía derivado del paquete: fracción de la demanda hídrica
  // (ET0) que la lluvia no cubre. No es un campo de la API, se calcula y se
  // muestra como indicador derivado.
  const drought = Number.isFinite(selectedMonth?.balance_hidrico_mm) && Number.isFinite(selectedMonth?.et_mm)
    ? Math.min(1, Math.max(0, -selectedMonth.balance_hidrico_mm / Math.max(1, selectedMonth.et_mm)))
    : null;
  // Antes de llegar al explorador el terreno narra las estaciones solo; al
  // entrar, manda la zona piloto y el mes elegidos con datos reales.
  const chapter = storyAt(progress);
  const climate = explorerEntered
    ? {
        region: activeZone?.region ?? 'sierra',
        treeRegion: activeZone?.region ?? 'sierra',
        elevation,
        frost: frostValid ? probability : null,
        water: Number.isFinite(water) ? water : null,
        rain: Number.isFinite(rain) ? rain : null,
        et: Number.isFinite(selectedMonth?.et_mm) ? selectedMonth.et_mm : null,
        drought,
      }
    : {
        region: 'story',
        treeRegion: activeZone?.region ?? 'sierra',
        elevation,
        frost: chapter.frost,
        water: null,
        rain: null,
        et: null,
        drought: chapter.aridity,
        snow: chapter.snow,
        aridity: chapter.aridity,
      };
  const terrainData = explorerEntered
    ? {
        elevacion_m: Number.isFinite(elevation) ? elevation : undefined,
        prob_helada: frostValid ? probability : undefined,
        balance_hidrico_mm: Number.isFinite(water) ? water : undefined,
        sequia: drought ?? undefined,
      }
    : {
        elevacion_m: Number.isFinite(elevation) ? elevation : undefined,
        prob_helada: chapter.frost,
        sequia: chapter.aridity,
      };

  const apk = safeUrl(apkUrl);
  const video = safeUrl(videoEmbedUrl);
  const fieldVideo = safeUrl(fieldVideoEmbedUrl);
  const provenance = activeZone && {
    zona: activeZone.nombre,
    region: activeZone.region,
    altitud: activeZone.elevacion_m,
    version: activeZone.version,
    hash: activeZone.hash,
    fuente: activeZone.fuenteClima,
    url: activeZone.apiUrl,
    siembra: activeZone.inicioSiembra,
  };
  // Rotación mejor puntuada por el motor, con nombres legibles de cultivo.
  const topRotation = activeZone?.rotaciones?.[0];
  const rotationLine = topRotation
    ? topRotation.secuencia.map((id) => activeZone.nombres?.[id] ?? id).join(' → ') + ' · ' + topRotation.puntajes.total.toFixed(2)
    : null;
  const topExplanation = topRotation?.explicacion ?? null;
  const pickZone = (id) => { setZoneId(id); setManualMonth(null); setManualLayer(null); };
  const busyLocating = locating === 'locating' || locating === 'computing';
  const useMyLocation = async () => {
    if (busyLocating) return;
    try {
      setLocating('locating');
      const { latitude, longitude } = await currentPosition();
      setLocating('computing');
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 30000);
      const zone = await fetchLiveZone(apiBase, latitude, longitude, controller.signal).finally(() => clearTimeout(timer));
      setMyZone(zone);
      pickZone(zone.id);
      setLocating('idle');
    } catch (error) {
      setLocating(error?.message === 'out-of-range' ? 'range' : error?.code === 1 ? 'denied' : 'error');
    }
  };
  const locatingText = {
    locating: t('Waiting for location permission…'),
    computing: t('Computing 40 years of NASA POWER for your area… (up to ~10 s)'),
    denied: t('Location permission denied. Try a preset place.'),
    range: t('The engine covers latitudes between 60° S and 60° N.'),
    error: t('The live API did not answer. Try a preset place.'),
  }[locating];
  const github = safeUrl(githubUrl);
  const checksum = typeof apkSha256 === 'string' ? apkSha256.trim() : PENDING_HASH;
  const verifiedHash = /^[a-f0-9]{64}$/i.test(checksum);
  const downloadReady = Boolean(apk && verifiedHash);

  useEffect(() => {
    gsap.registerPlugin(ScrollTrigger);
    const host = wrapper.current;
    let disposed = false;
    let refreshFrame = 0;
    const context = gsap.context(() => {
      const problem = host.querySelector('#problem');
      const how = host.querySelector('#how-it-works');
      const firstField = host.querySelector('#cultivated-field');
      const explorer = host.querySelector('#explorer');
      const explorerCopy = explorer.firstElementChild;
      const update = (trigger) => {
        setProgress(trigger.progress);
        const starts = [firstField, problem, how].map((section) => section.getBoundingClientRect().top);
        const cameraLine = parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop) +
          parseFloat(getComputedStyle(firstField).scrollMarginTop);
        const leg = starts[1] > cameraLine ? 0 : 1;
        const distance = starts[leg + 1] - starts[leg];
        const firstStop = starts[0] + firstFieldScrollOffset(firstField);
        const route = leg === 0
          ? Math.max(0, Math.min(1, -firstStop / Math.max(1, starts[1] - cameraLine - firstStop)))
          : 1 + Math.max(0, Math.min(1, (cameraLine - starts[1]) / Math.max(1, distance)));
        const passedFields = explorer.getBoundingClientRect().top + explorerCopy.offsetTop <= window.innerHeight * .86;
        setExplorerEntered(passedFields);
        const inFields = starts[0] <= window.innerHeight * .82 && !passedFields;
        setFieldJourney(inFields ? route : null);
        if (!inFields) setWideFieldView(false);
        setStoryLayer(['normal', 'helada', 'agua'][Math.round(route)]);
      };
      const trigger = ScrollTrigger.create({
        trigger: host.querySelector('#story'),
        start: 'top top',
        end: 'bottom bottom',
        onUpdate: update,
        onRefresh: update,
      });
      update(trigger);
    }, host);
    const observer = new ResizeObserver(() => {
      cancelAnimationFrame(refreshFrame);
      refreshFrame = requestAnimationFrame(() => ScrollTrigger.refresh());
    });
    observer.observe(host);
    document.fonts.ready.then(() => { if (!disposed) ScrollTrigger.refresh(); });
    return () => {
      disposed = true;
      observer.disconnect();
      cancelAnimationFrame(refreshFrame);
      context.revert();
    };
  }, []);

  const zoomOut = useCallback(() => setWideFieldView(true), []);
  const widenIslandView = useCallback(() => setWideIslandView(true), []);
  const enterFields = useCallback(() => {
    const field = wrapper.current?.querySelector('#cultivated-field');
    if (!field) return;
    window.scrollTo({
      top: window.scrollY + field.getBoundingClientRect().top + firstFieldScrollOffset(field),
      behavior: reduced ? 'instant' : 'smooth',
    });
  }, [reduced]);

  const scrollTo = (event, id) => {
    const destination = wrapper.current?.querySelector('#' + id);
    if (!destination) return;
    event.preventDefault();
    if (id === 'cultivated-field') {
      enterFields();
    } else {
      destination.scrollIntoView({ behavior: reduced ? 'instant' : 'smooth', block: 'start' });
    }
    destination.focus({ preventScroll: true });
    history.replaceState(null, '', '#' + id);
  };

  // La guía solo pide bajar: el scroll ya no tiene pasos de zoom en el 3D.
  const guideStage = fieldJourney === null ? 'approach' : 'continue';
  const nextSection = ['problem', 'how-it-works', 'explorer'][Math.round(fieldJourney ?? 0)];
  const guide = {
    approach: { title: 'Get closer', instruction: 'Scroll down over the island.', Icon: ZoomOut, Direction: ArrowDown },
    continue: { title: 'Keep exploring', instruction: 'Scroll down to see the next part of the story.', Icon: ArrowDown },
  }[guideStage];
  const GuideIcon = guide.Icon;
  const GuideDirection = guide.Direction;
  const guideDestination = guideStage === 'approach' ? 'cultivated-field' : nextSection;
  const GuideAction = 'a';
  const guideActionProps = { href: '#' + guideDestination, onClick: (event) => scrollTo(event, guideDestination) };

  return (
    <IslandBoundary>
    <MotionConfig reducedMotion={motionEnabled ? 'never' : 'always'}>
    <MotionEnabled.Provider value={motionEnabled}>
    <div ref={wrapper} className="muyuy-landing pointer-events-none" data-motion={motionEnabled ? 'on' : 'off'} data-ready={terrainReady} data-wide-field={wideFieldView} data-layer={layer} data-summer={month === 12 || month <= 2} data-winter={month >= 6 && month <= 8}>
      <style>{STYLES}</style>
      <div className="muyuy-atmosphere" aria-hidden="true">
        <div className="muyuy-atmosphere-frost" />
        <div className="muyuy-atmosphere-water" />
        <div className="muyuy-atmosphere-grid" />
        <div className="muyuy-sun" />
        <div className="muyuy-snow" />
      </div>
      <Suspense fallback={<span className="muyuy-terrain-loading" aria-hidden="true" />}>
        <MuyuyTerrain fixed editorialLayout motionEnabled={motionEnabled} climate={climate} month={month} data={terrainData}
          fieldJourney={fieldJourney} onEnterFields={enterFields} wideFieldView={wideFieldView} onZoomOut={zoomOut}
          wideIslandView={wideIslandView} onWidenIslandView={widenIslandView}
          scrollProgress={progress} showControls={false} onReady={markTerrainReady}
          className="pointer-events-auto" style={{ background: 'transparent' }} />
      </Suspense>
      <div className="muyuy-vignette" aria-hidden="true" />
      {progress < .63 && (storyLayer !== 'agua' || fieldJourney !== null) && (
        <div className="muyuy-gesture" aria-live="polite">
          <motion.div key={guideStage} className="muyuy-gesture-card"
            initial={reduced ? false : { opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: reduced ? 0 : .34, ease: EASE }}>
            <GuideAction {...guideActionProps}>
              <span className="muyuy-gesture-icon"><GuideIcon size={18} aria-hidden="true" /></span>
              <span className="muyuy-gesture-copy">
                <strong>{t(guide.title)}</strong>
                <span>{t(guide.instruction)}</span>
              </span>
              {GuideDirection && <GuideDirection size={16} className="muyuy-gesture-arrow" aria-hidden="true" />}
            </GuideAction>
          </motion.div>
        </div>
      )}
      <Toaster theme="dark" position="bottom-right" toastOptions={{ className: 'muyuy-toast' }} />

      <header className={glass + ' muyuy-navigation'}>
        <a className="muyuy-brand" href="#hero" onClick={(event) => scrollTo(event, 'hero')} aria-label="Muyuy home"><img src={brandLogo} alt="" width="1370" height="436" /></a>
        <nav aria-label="Main navigation">
          <a href="#explorer" onClick={(event) => scrollTo(event, 'explorer')}>{t('Explore')}</a>
          <a href="#download" onClick={(event) => scrollTo(event, 'download')}>{t('Get the app')} <ArrowUpRight size={14} aria-hidden="true" /></a>
          <button type="button" className="muyuy-motion-switch" aria-pressed={motionEnabled} onClick={() => setMotionEnabled((enabled) => !enabled)}>{t(motionEnabled ? 'Motion on' : 'Motion off')}</button>
          <select className="muyuy-language" aria-label={t('Language')} value={locale} onChange={(event) => setLocale(event.target.value)}>
            {LOCALES.map(([code, name]) => <option key={code} value={code} lang={code}>{name}</option>)}
          </select>
        </nav>
      </header>

      <main id="story" className="pointer-events-none">
        <section id="hero" tabIndex={-1} aria-labelledby="hero-title" className="muyuy-section muyuy-hero">
          <div className="muyuy-copy">
            <Reveal><p className="muyuy-eyebrow">NASA SPACE APPS CHALLENGE 2026</p></Reveal>
            <h1 id="hero-title" className="tracking-tighter" aria-label="Muyuy">{Array.from('Muyuy.').map((letter, index) => <span aria-hidden="true" key={index} className="muyuy-letter" style={{ '--letter-delay': `${.18 + index * .095}s` }}>{letter}</span>)}</h1>
            <Reveal delay={.67}><p className="muyuy-tagline">{t('NASA data to the last field — even without signal.')}</p></Reveal>
            <Reveal delay={.79}><p className="muyuy-location"><span className="muyuy-dot" /> {t('Uses NASA Earth data')} · {t('Huánuco, Peru')} <span className={mono}>({Number.isFinite(elevation) ? elevation.toLocaleString('en-US') : '—'}m)</span></p></Reveal>
            <Reveal delay={.9}>
            <div className="muyuy-actions pointer-events-auto">
              <a className="muyuy-button primary" href="#cultivated-field" onClick={(event) => scrollTo(event, 'cultivated-field')}>{t('Enter the fields')} <ArrowDown size={15} aria-hidden="true" /></a>
              <a className="muyuy-button active:scale-[0.98]" href="#download" onClick={(event) => scrollTo(event, 'download')}>{t('Download APK')} <Download size={16} aria-hidden="true" /></a>
              <a className="muyuy-button active:scale-[0.98]" href="#app-demo" onClick={(event) => scrollTo(event, 'app-demo')}><Play size={15} aria-hidden="true" /> {t('Open the web demo')}</a>
            </div>
            </Reveal>
          </div>
        </section>

        <section id="cultivated-field" tabIndex={-1} aria-labelledby="starting-field-title" className="muyuy-section muyuy-plot-section">
          <Reveal className={glass + ' muyuy-copy'}>
            <p className="muyuy-eyebrow">{t('CULTIVATED FIELD')}</p>
            <h2 id="starting-field-title" className="muyuy-field-title"><span>{t('From the hillside')}</span>{' '}<em>{t('to the first row.')}</em></h2>
            <p>{t('Follow the stone reservoir and irrigation channel to the native potato rows. Scroll to visit the neighboring plots.')}</p>
            <p className="muyuy-field-reading"><Droplets size={15} aria-hidden="true" /> {monthNames[sowingMonth - 1]} · {t('Sowing month')}</p>
            <p className="muyuy-small">{t('Illustrative field scenes. The monthly climate layer can be changed in the explorer.')}</p>
          </Reveal>
        </section>

        <section id="problem" tabIndex={-1} aria-labelledby="problem-title" className="muyuy-section muyuy-plot-section">
          <Reveal className={glass + ' muyuy-copy'}>
            <p className="muyuy-eyebrow">{t('The problem')}</p>
            <h2 id="problem-title" className="muyuy-field-title tracking-tighter"><span>{t('The land is familiar.')}</span>{' '}<em>{t('The seasons are changing.')}</em></h2>
            <p className="muyuy-field-reading"><Snowflake size={15} aria-hidden="true" /> {monthNames[frostPeak.mes - 1]} · {Math.round(frostPeak.prob_helada * 100)}% {t('frost probability')}</p>
            <p className="muyuy-small">{t('The winter scene illustrates a separate late blight management activity.')}</p>
            <p>{t('Meet Pedrito, an illustrative farmer in the highlands of Huánuco. Sudden June frosts threaten his crops. Rain arrives irregularly. The soil is exhausted. And in the field, there is no internet signal.')}</p>
            <p>{t('Choosing the next crop means balancing all of this with the knowledge he has built over years on the land.')}</p>
            <div className="muyuy-risk-list"><span><Snowflake size={16} /> {t('Sudden frost')}</span><span><Droplets size={16} /> {t('Irregular rain')}</span><span><Radio size={16} /> {t('No signal')}</span></div>
          </Reveal>
        </section>

        <section id="how-it-works" tabIndex={-1} aria-labelledby="how-title" className="muyuy-section muyuy-plot-section">
          <div className="muyuy-copy">
            <Reveal><p className="muyuy-eyebrow">{t('How it works')}</p><h2 id="how-title" className="muyuy-field-title tracking-tighter"><span>{t('From orbit')}</span>{' '}<em>{t('to the field.')}</em></h2><p className="muyuy-field-reading"><Droplets size={15} aria-hidden="true" /> {monthNames[driest.mes - 1]} · {driest.balance_hidrico_mm} mm {t('water balance')}</p></Reveal>
            <div className="muyuy-workflow">
              {[
                ['1. 40 Years of NASA Earth Data', 'Turn historical climate records into a monthly view of frost and water availability.', Globe2, null],
                ['2. Smart Crop Rotations', 'Compare three alternatives with confidence levels and visible trade-offs.', Sprout, rotationLine],
                ['3. 100% Offline & Phone-to-Phone Sharing', 'Keep regional packages on the phone and share them where connectivity ends.', Radio, null],
              ].map(([title, description, Icon, extra], index) => (
                <React.Fragment key={title}>
                  {index > 0 && <ChevronRight className="muyuy-flow-arrow" size={16} aria-hidden="true" />}
                  <Reveal delay={index * .06} className={glass + ' muyuy-step'}>
                    <Icon size={20} aria-hidden="true" />
                    <div>
                      <h3>{t(title)}</h3>
                      <p>{t(description)}</p>
                      {extra && <p className={'muyuy-step-data ' + mono}>{t('Top rotation')}: {extra}</p>}
                    </div>
                  </Reveal>
                </React.Fragment>
              ))}
            </div>
          </div>
        </section>

        <section id="explorer" tabIndex={-1} aria-labelledby="explorer-title" className="muyuy-section">
          <div className="muyuy-copy">
            <Reveal className={glass} active={explorerEntered}>
              <p className="muyuy-eyebrow">{t('INTERACTIVE 3D EXPLORER')}</p>
              <h2 id="explorer-title" className="tracking-tighter">{t('Move through')}<br /><em>{t('the seasons.')}</em></h2>
              <p>{t('Choose a month and a layer to inspect the crops and water supply.')}</p>

              {zones.length > 1 && (
                <fieldset className="muyuy-zone-field">
                  <legend>{t('Pilot zone')} · Huánuco</legend>
                  <div className="muyuy-zone-options">
                    {zones.map((candidate) => (
                      <button type="button" key={candidate.id} aria-pressed={candidate.id === activeZone?.id}
                        className="active:scale-[0.98]" onClick={() => pickZone(candidate.id)}>
                        <strong>{t(REGIONS[candidate.region] ?? candidate.id)}</strong>
                        <span className={mono}>{candidate.elevacion_m} m</span>
                      </button>
                    ))}
                  </div>
                </fieldset>
              )}

              {globalZones.length > 0 && (
                <fieldset className="muyuy-zone-field muyuy-zone-global">
                  <legend><Globe2 size={12} aria-hidden="true" /> {t('Global mode · same engine, other continents')}</legend>
                  <div className="muyuy-zone-options">
                    {globalZones.map((candidate) => (
                      <button type="button" key={candidate.id} aria-pressed={candidate.id === activeZone?.id}
                        className="active:scale-[0.98]" onClick={() => pickZone(candidate.id)}>
                        <strong>{candidate.nombre}</strong>
                        <span className={mono}>{candidate.elevacion_m} m</span>
                      </button>
                    ))}
                    <button type="button" className="muyuy-zone-locate active:scale-[0.98]"
                      aria-pressed={activeZone?.id === 'my-location'} aria-busy={busyLocating}
                      onClick={myZone && !busyLocating ? () => pickZone(myZone.id) : useMyLocation}>
                      <strong>
                        {busyLocating
                          ? <LoaderCircle size={12} className="muyuy-spin" aria-hidden="true" />
                          : <LocateFixed size={12} aria-hidden="true" />}
                        {myZone ? t('My location') : t('Use my location')}
                      </strong>
                      <span className={mono}>{myZone ? myZone.elevacion_m + ' m' : t('live API')}</span>
                    </button>
                  </div>
                  {locatingText && <p className="muyuy-small muyuy-zone-status" role="status">{locatingText}</p>}
                </fieldset>
              )}

              <div className="muyuy-month-label"><span>{t('Month')}</span><output className={mono}>{monthNames[month - 1]}</output></div>

              {/*
                Calendario real del paquete: una barra por mes con la
                probabilidad de helada. Se hace clic para mover el terreno a
                ese mes, así el 3D y el dato cuentan la misma historia.
              */}
              <div className="muyuy-climate" role="group" aria-label={t('Climate calendar')}>
                {calendar.map((entry) => {
                  const selected = entry.mes === month;
                  const frost = Math.round((entry.prob_helada ?? 0) * 100);
                  const tip = `${monthNames[entry.mes - 1]} · ${frost}% ${t('frost probability')} · ${entry.balance_hidrico_mm} mm ${t('water balance')}`;
                  return (
                    <button type="button" key={entry.mes} className="muyuy-climate-month"
                      data-active={selected} aria-pressed={selected} aria-label={tip} title={tip}
                      onClick={() => setManualMonth(entry.mes)}>
                      <span className="muyuy-climate-bar" style={{ '--frost': Math.max(4, frost) + '%' }} aria-hidden="true" />
                      <span className="muyuy-climate-name" aria-hidden="true">{monthNames[entry.mes - 1].slice(0, 3)}</span>
                    </button>
                  );
                })}
              </div>
              <p className="muyuy-small muyuy-climate-note">{t('Frost probability by month, straight from the sealed regional package.')}</p>
              <p className="muyuy-small">{t('Drought risk is derived: unmet water demand (−balance / ET₀) for the selected month.')}</p>

              <button type="button" className="muyuy-follow" aria-pressed={manualLayer === null && manualMonth === null} onClick={() => { setManualLayer(null); setManualMonth(null); }}>
                {manualLayer === null && manualMonth === null && <Check size={14} aria-hidden="true" />} {t('Follow the story')}
              </button>
              <dl className={'muyuy-readings ' + mono} aria-live="polite" aria-atomic="true">
                <div><dt>{t('Frost probability')}</dt><dd>{frostValid ? Math.round(probability * 100) + '%' : t('Unavailable')}</dd></div>
                <div><dt>{t('Water balance')}</dt><dd>{Number.isFinite(water) ? (water > 0 ? '+' : '') + water + ' mm' : t('Unavailable')}</dd></div>
                <div><dt>{t('Rainfall')}</dt><dd>{Number.isFinite(rain) ? rain + ' mm' : t('Unavailable')}</dd></div>
                <div><dt>{t('Drought risk')}</dt><dd>{Number.isFinite(drought) ? Math.round(drought * 100) + '%' : t('Unavailable')}</dd></div>
              </dl>
              {topRotation && (
                <div className="muyuy-rotation">
                  <p className="muyuy-eyebrow">{t('Top rotation from the engine')}</p>
                  <p className={'muyuy-rotation-line ' + mono}>{rotationLine}</p>
                  {topExplanation && <p className="muyuy-small">{topExplanation}</p>}
                </div>
              )}
              <p className="muyuy-small">
                {exampleData
                  ? t('Example calendar · Illustrative values for this interactive prototype.')
                  : t('Regional calendar · Values supplied by the project data package.')}
              </p>
              {provenance && (
                <p className="muyuy-provenance">
                  {activeZone?.validada
                    ? t('Verified regional package')
                    : activeZone?.live
                      ? t('Computed live for your area · not validated locally')
                      : t('On-demand package · not validated locally')}
                  {' · '}{t('Source')} NASA POWER 1985–2024
                  <br />
                  {provenance.zona} · {provenance.altitud} m · v{provenance.version} ·{' '}
                  <code className={mono}>{String(provenance.hash).slice(0, 8)}</code>{' '}
                  <a href={provenance.url} target="_blank" rel="noopener noreferrer">API ↗</a>
                </p>
              )}
            </Reveal>
            {video && <Reveal className={glass + ' muyuy-video-card'}>
              <div id="video-demo" tabIndex={-1} className="muyuy-video" aria-label="30-second video demo">
                <iframe src={video} title="Muyuy 30-second demo" loading="lazy" allow="fullscreen; picture-in-picture" allowFullScreen referrerPolicy="strict-origin-when-cross-origin" />
              </div>
            </Reveal>}
          </div>
        </section>

        <AppDemo locale={locale} reduced={reduced} />

        <section id="field-test" tabIndex={-1} aria-labelledby="field-title" className="muyuy-section">
          <Reveal className="muyuy-wide">
            <FieldValidation t={t} glass={glass} locale={locale} videoUrl={fieldVideo} />
          </Reveal>
        </section>

        <section id="why-it-matters" tabIndex={-1} aria-labelledby="impact-title" className="muyuy-section">
          <Reveal className="muyuy-wide">
            <ImpactSection t={t} glass={glass} />
            <LiveStatus t={t} glass={glass} apiBase={apiBase} zones={zones} snapshot={snapshot} />
          </Reveal>
        </section>

        <section id="download" tabIndex={-1} aria-labelledby="download-title" className="muyuy-section">
          <Reveal className={glass + ' muyuy-download'}>
            <div><p className="muyuy-eyebrow">{t('Download the mobile app')}</p><h2 id="download-title" className="tracking-tighter">{t('The next season.')}<br /><em>{t('In your pocket.')}</em></h2><p>{t('Take the Muyuy prototype into the field.')}</p></div>
            <div className="muyuy-download-actions">
              {downloadReady ? <a className="muyuy-button primary active:scale-[0.98]" href={apk} download><Download size={18} aria-hidden="true" /> {t('Download Muyuy APK (v1.0)')}</a>
                : <><button type="button" disabled className="muyuy-button primary"><Download size={18} aria-hidden="true" /> {t('Download Muyuy APK (v1.0)')}</button><p className="muyuy-small">{t('The signed APK and verified checksum are pending.')}</p></>}
              <div className="muyuy-checksum"><span className="muyuy-eyebrow">{t('SHA-256 CHECKSUM')}</span><code className={mono}>{checksum || PENDING_HASH}</code>
                <button type="button" className="muyuy-button active:scale-[0.98]" onClick={() => copyText(checksum || PENDING_HASH, 'SHA-256 checksum copied to clipboard')}><Copy size={14} aria-hidden="true" /> {t('Copy checksum')}</button>
                {!verifiedHash && <p className="muyuy-small">{t('Placeholder only · Replace with the signed release hash before installation.')}</p>}
              </div>
              <Drawer.Root open={drawerOpen} onOpenChange={setDrawerOpen}>
                <Drawer.Trigger asChild><button type="button" className="muyuy-guide"><ShieldCheck size={17} aria-hidden="true" /> {t('Installation Guide & NASA Data Specs')} <ChevronRight size={15} aria-hidden="true" /></button></Drawer.Trigger>
                <Drawer.Portal>
                  <Drawer.Overlay className="muyuy-drawer-overlay" />
                  <Drawer.Content className="muyuy-drawer pointer-events-auto">
                    <div className="muyuy-drawer-handle" aria-hidden="true" />
                    <div className="muyuy-drawer-heading"><Drawer.Title>{t('From download to field.')}</Drawer.Title><Drawer.Close asChild><button type="button" aria-label={t('Close installation guide')}><X size={20} /></button></Drawer.Close></div>
                    <Drawer.Description>{t('Install the prototype and understand the climate inputs behind the calendar.')}</Drawer.Description>
                    <div className="muyuy-drawer-scroll">
                      <h3>{t('Install on Android')}</h3>
                      <ol>
                        <li>{t("Download the signed APK from this project's release link when it becomes available.")}</li>
                        <li>{t("Calculate the downloaded file's SHA-256 and compare all 64 characters with the published checksum. On Windows, use")} <code>Get-FileHash .\Muyuy.apk -Algorithm SHA256</code>. {t('On macOS, use')} <code>shasum -a 256 Muyuy.apk</code>.</li>
                        <li>{t('On Android, open the APK. If prompted, allow “Install unknown apps” for the browser or file manager used to open it.')}</li>
                        <li>{t('Complete installation, then turn that permission off again. Open Muyuy and obtain a regional package before testing offline access.')}</li>
                      </ol>
                      <p className="muyuy-small">{t(APK_NOTICE)}</p>
                      <h3>{t('NASA POWER data specifications')}</h3>
                      <p>{t('Daily records from 1985–2024, corrected for altitude. Each regional package states its exact source:')}{provenance?.fuente && <><br /><code>{provenance.fuente}</code></>}</p>
                      <dl className="muyuy-specs">
                        <div><dt>{t('Temperature')}</dt><dd>{t('Daily minima, means and maxima, in °C. Minimum temperature contributes to monthly frost exposure estimates.')}</dd></div>
                        <div><dt>{t('Precipitation')}</dt><dd>{t('Daily rainfall, in mm/day, aggregated into monthly totals.')}</dd></div>
                        <div><dt>{t('Relative humidity')}</dt><dd>{t('Daily relative humidity, in %, adds context for crop conditions.')}</dd></div>
                        <div><dt>{t('Evapotranspiration & water balance')}</dt><dd>{t('Monthly water balance compares rainfall with reference evapotranspiration (ET₀, Hargreaves · FAO-56).')}</dd></div>
                      </dl>
                      <a href="https://power.larc.nasa.gov/docs/services/api/temporal/daily/" target="_blank" rel="noreferrer">{t('NASA POWER Daily API documentation ↗')}</a>
                    </div>
                  </Drawer.Content>
                </Drawer.Portal>
              </Drawer.Root>
              <p className="muyuy-notice">{t(APK_NOTICE)}</p>
            </div>
          </Reveal>
        </section>

        <section id="team" tabIndex={-1} aria-labelledby="team-title" className="muyuy-section muyuy-team-section">
          <div className="muyuy-wide">
            <Reveal>
              <p className="muyuy-eyebrow">{t('The team')}</p>
              <h2 id="team-title" className="tracking-tighter">{t('Many perspectives.')}<br /><em>{t('One shared field.')}</em></h2>
              <p className="muyuy-team-intro">{t('Five people, one goal: turn forty years of NASA climate records into a decision a farmer can make with no signal.')}</p>
            </Reveal>
            <TeamGrid members={TEAM} locale={locale} t={t} glass={glass} />
            <footer className={glass + ' muyuy-footer'}>
              <div className="muyuy-footer-main">
                <div className="muyuy-footer-brand">
                  <a className="muyuy-brand" href="#hero" onClick={(event) => scrollTo(event, 'hero')}><img src={brandLogo} alt="Muyuy" width="1370" height="436" /></a>
                  <p>{t("AI explains, it doesn't decide.")}</p>
                  <p className="muyuy-small">{t('Offline-first agro-climatic prototype · NASA Earth data · Deterministic rotation engine')}</p>
                </div>

                <nav className="muyuy-footer-col" aria-labelledby="footer-project">
                  <h3 id="footer-project">{t('Project')}</h3>
                  <a href="#explorer" onClick={(event) => scrollTo(event, 'explorer')}>{t('Explore')}</a>
                  <a href="#app-demo" onClick={(event) => scrollTo(event, 'app-demo')}>{t('Open the web demo')}</a>
                  <a href={`${apiBase}/q/swagger-ui`} target="_blank" rel="noopener noreferrer">{t('API documentation')} ↗</a>
                  <a href={`${apiBase}/q/health/ready`} target="_blank" rel="noopener noreferrer">{t('API status')} ↗</a>
                  {github
                    ? <a href={github} target="_blank" rel="noopener noreferrer">GitHub ↗</a>
                    : <span className="muyuy-small">{t('GitHub link pending')}</span>}
                </nav>

                <div className="muyuy-footer-col">
                  <h3>{t('Data & credits')}</h3>
                  <a href="https://power.larc.nasa.gov/" target="_blank" rel="noopener noreferrer">NASA POWER ↗</a>
                  <a href="https://www.fao.org/land-water/databases-and-software/crop-information/en/" target="_blank" rel="noopener noreferrer">FAO ECOCROP ↗</a>
                  <a href="https://github.com/mrdoob/three.js/blob/dev/LICENSE" target="_blank" rel="noopener noreferrer">Three.js · MIT</a>
                  <a href="https://lucide.dev/license" target="_blank" rel="noopener noreferrer">Lucide · ISC</a>
                </div>

                <div className="muyuy-footer-col">
                  <h3>{t('Regional package')}</h3>
                  {provenance ? (
                    <>
                      <p className="muyuy-small">{provenance.zona}</p>
                      <p className="muyuy-small">{activeZone?.validada ? t('Validated locally') : t('On-demand package')} · v{provenance.version}</p>
                      <p className="muyuy-small"><code className={mono}>{String(provenance.hash).slice(0, 12)}…</code></p>
                      <a href={provenance.url} target="_blank" rel="noopener noreferrer">{t('Source')} ↗</a>
                    </>
                  ) : (
                    <p className="muyuy-small">{t('Source: project data package')}</p>
                  )}
                </div>
              </div>

              <div className="muyuy-footer-bottom">
                <p className="muyuy-small">{t('Built for NASA Space Apps Challenge 2026')} · MIT</p>
                <p className="muyuy-small">{t('Procedural terrain · AI-assisted development. Field media credits accompany approved photographs.')}</p>
              </div>
            </footer>
          </div>
        </section>
      </main>
    </div>
    </MotionEnabled.Provider>
    </MotionConfig>
    </IslandBoundary>
  );
}

const CRASH_CSS = `
  .muyuy-crash { min-height: 100svh; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 14px; padding: 40px 24px; text-align: center; background: #09090b; color: #f4f4f1; font: 15px/1.6 "Inter", system-ui, sans-serif; }
  .muyuy-crash img { width: clamp(140px, 22vw, 230px); height: auto; }
  .muyuy-crash h1 { font-size: clamp(34px, 6vw, 56px); letter-spacing: -.05em; margin: 0; }
  .muyuy-crash p { margin: 0; max-width: 46ch; color: #c3c5bf; }
  .muyuy-crash-note { font-size: 13px; color: #9fa699; }
  .muyuy-crash button { margin-top: 8px; padding: 11px 18px; border-radius: 8px; border: 1px solid #d2dfb6; background: #d2dfb6; color: #161c12; font-weight: 600; cursor: pointer; }
  .muyuy-crash-stack { max-width: min(100%, 780px); margin-top: 18px; padding: 14px; border: 1px solid #ffffff1f; border-radius: 8px; background: #0f1210; color: #f0a5a5; font: 11px/1.6 ui-monospace, monospace; text-align: left; overflow: auto; white-space: pre-wrap; }
`;
const STYLES = `
  .muyuy-landing { position: relative; isolation: isolate; color: #f4f4f1; font: 15px/1.65 var(--font-sans, "Inter"), system-ui, sans-serif; }
  .muyuy-landing *, .muyuy-drawer * { box-sizing: border-box; }
  .muyuy-landing .pointer-events-none { pointer-events: none; }
  .muyuy-landing .pointer-events-auto { pointer-events: auto; }
  .muyuy-landing { pointer-events: none; }
  .muyuy-landing a { color: inherit; text-decoration: none; }
  .muyuy-landing h1, .muyuy-landing h2, .muyuy-landing h3, .muyuy-landing p, .muyuy-landing figure { margin: 0; }
  .muyuy-landing button, .muyuy-drawer button { font: inherit; cursor: pointer; }
  .muyuy-landing :focus-visible, .muyuy-drawer :focus-visible { outline: 2px solid #d4e5af; outline-offset: 4px; }
  .muyuy-landing section:focus { outline: none; }
  .muyuy-landing .font-mono { font-family: ui-monospace, "SFMono-Regular", Consolas, monospace; font-variant-numeric: tabular-nums; }
  .muyuy-atmosphere { position: fixed; inset: 0; background: radial-gradient(ellipse at 72% 58%, #324735 0%, #17231c 46%, #090c0b 87%); pointer-events: none; }
  .muyuy-atmosphere > div { position: absolute; inset: 0; }
  .muyuy-atmosphere-frost, .muyuy-atmosphere-water { opacity: 0; transition: opacity 1.4s cubic-bezier(.32,.72,0,1); }
  .muyuy-atmosphere-frost { background: radial-gradient(ellipse at 72% 53%,#304e68,#101e2a 58%,#080d13 88%); }
  .muyuy-atmosphere-water { background: radial-gradient(ellipse at 72% 58%,#594630,#25231a 55%,#100e0b 90%); }
  [data-layer=helada] .muyuy-atmosphere-frost, [data-layer=agua] .muyuy-atmosphere-water { opacity: 1; }
  .muyuy-atmosphere-grid { background-image: linear-gradient(#dfebd414 1px,transparent 1px),linear-gradient(90deg,#dfebd414 1px,transparent 1px); background-size: 42px 42px; mask-image: radial-gradient(ellipse at 73% 58%,#000,transparent 66%); }
  .muyuy-atmosphere .muyuy-sun { inset: 4% 4% auto auto; width: min(55vw, 650px); aspect-ratio: 1; opacity: 0; background: radial-gradient(circle at 65% 30%,#fff2bd 0%,#f5d18e 2%,#da974c44 15%,transparent 60%); transition: opacity 1.2s; }
  [data-summer=true]:not([data-layer=helada]) .muyuy-sun { opacity: 1; }
  .muyuy-atmosphere .muyuy-snow { opacity: 0; background-image: radial-gradient(circle,#eff8ff9c 1px,transparent 2px),radial-gradient(circle,#e8f4ff60 1px,transparent 1.8px); background-size: 103px 127px, 79px 157px; transition: opacity 1s; }
  :is([data-layer=helada],[data-layer=normal][data-winter=true]) .muyuy-snow { opacity: .7; }
  [data-motion=on]:is([data-layer=helada],[data-layer=normal][data-winter=true]) .muyuy-snow { animation: muyuy-snowfall 18s linear infinite; }
  @keyframes muyuy-snowfall { to { background-position: 103px 254px, -79px 314px; } }
  .muyuy-vignette { position: fixed; inset: 0; background: linear-gradient(90deg,#09090bcc,transparent 67%); pointer-events: none; z-index: 1; }
  .muyuy-landing #story { position: relative; z-index: 2; }
  .muyuy-landing .muyuy-terrain > span { display: none; }
  .muyuy-glass { padding: clamp(22px,3vw,40px); background: #09090bb3; border: 1px solid #ffffff1a; backdrop-filter: blur(14px); border-radius: 18px; }
  .muyuy-navigation { position: sticky; top: 18px; z-index: 40; margin: 18px 4% -78px; padding: 12px 18px; display: flex; justify-content: space-between; align-items: center; gap: 20px; }
  .muyuy-brand { display: inline-flex; align-items: center; flex: none; }
  .muyuy-brand img { display: block; width: clamp(90px, 12vw, 133px); height: auto; }
  .muyuy-navigation nav { display: flex; align-items: center; gap: clamp(10px, 2.5vw, 25px); font-size: 12px; }
  .muyuy-navigation nav a { display: inline-flex; align-items: center; gap: 5px; }
  .muyuy-section { min-height: 110svh; padding: 135px 6vw 100px; display: flex; align-items: center; position: relative; scroll-margin-top: 80px; }
  .muyuy-copy { width: min(100%, 530px); }
  .muyuy-landing #explorer { align-items: flex-start; padding-top: clamp(30px, 6svh, 64px); }
  .muyuy-hero .muyuy-copy { width: min(100%, 490px); }
  .muyuy-landing .muyuy-hero h1 { font-size: clamp(76px, 9.6vw, 158px); }
  .muyuy-hero .muyuy-actions { max-width: 440px; }
  .muyuy-hero .muyuy-actions { pointer-events: none; }
  .muyuy-hero .muyuy-actions > a { pointer-events: auto; }
  .muyuy-plot-section > .muyuy-copy { width: min(37vw, 460px); }
  .muyuy-field-reading { display: flex; align-items: center; gap: 8px; color: #d3e0ba !important; font: 12px/1.5 var(--font-mono, monospace); }
  .muyuy-wide { width: 100%; }
  .muyuy-eyebrow { color: #bfcdab; font-size: 10px; font-weight: 600; letter-spacing: .15em; margin-bottom: 17px !important; }
  .muyuy-landing h1 { font-size: clamp(88px,11vw,180px); line-height: .9; white-space: nowrap; letter-spacing: -.08em; font-weight: 600; margin: 26px 0 !important; }
  .muyuy-landing h1 span:last-child { color: #cadca6; }
  .muyuy-landing[data-motion=on] .muyuy-letter { display: inline-block; opacity: 0; }
  .muyuy-landing[data-motion=on][data-ready=true] .muyuy-letter { animation: muyuy-type 1ms var(--letter-delay) both; }
  @keyframes muyuy-type { to { opacity: 1; } }
  .muyuy-landing[data-motion=on] .muyuy-reveal[data-entered=true] > :is(h2, h3, p):not(:only-child) {
    animation: muyuy-text-in 1.12s cubic-bezier(.32,.72,0,1) both;
  }
  .muyuy-landing[data-motion=on] .muyuy-reveal[data-entered=true] > :is(h2, h3, p):nth-child(2) { animation-delay: .16s; }
  .muyuy-landing[data-motion=on] .muyuy-reveal[data-entered=true] > :is(h2, h3, p):nth-child(n+3) { animation-delay: .28s; }
  @keyframes muyuy-text-in { from { opacity: 0; transform: translateY(19px); } to { opacity: 1; transform: translateY(0); } }
  .muyuy-field-title > :is(span, em) { display: block; }
  .muyuy-landing[data-motion=on][data-wide-field=true] .muyuy-plot-section .muyuy-reveal[data-entered=true] > .muyuy-field-title {
    animation: none;
  }
  .muyuy-landing[data-motion=on][data-wide-field=true] .muyuy-reveal[data-entered=true] > .muyuy-field-title > :is(span, em) {
    animation: muyuy-field-title-in .72s cubic-bezier(.32,.72,0,1) .10s both;
  }
  .muyuy-landing[data-motion=on][data-wide-field=true] .muyuy-reveal[data-entered=true] > .muyuy-field-title > em { animation-delay: .21s; }
  .muyuy-landing[data-motion=on][data-wide-field=true] .muyuy-plot-section .muyuy-reveal[data-entered=true] > .muyuy-field-title ~ p {
    animation: muyuy-field-copy-in .6s cubic-bezier(.32,.72,0,1) .29s both;
  }
  .muyuy-landing[data-motion=on][data-wide-field=true] .muyuy-plot-section .muyuy-reveal[data-entered=true] > .muyuy-field-title ~ p + p { animation-delay: .38s; }
  @keyframes muyuy-field-title-in {
    from { opacity: .18; transform: translateY(.32em); clip-path: inset(0 0 72%); }
    to { opacity: 1; transform: translateY(0); clip-path: inset(-15% -3%); }
  }
  @keyframes muyuy-field-copy-in {
    from { opacity: .32; transform: translateY(9px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .muyuy-motion-switch { border: 1px solid #ffffff26; border-radius: 6px; padding: 4px 7px; color: #d5e2ba; background: #ffffff0c; white-space: nowrap; }
  .muyuy-language { max-width: 100%; padding: 5px 7px; border: 1px solid #ffffff26; border-radius: 6px; background: #18211b; color: #eef2e7; font: inherit; }
  .muyuy-gesture { position: fixed; inset: auto max(12px, env(safe-area-inset-right)) max(14px, env(safe-area-inset-bottom)) max(12px, env(safe-area-inset-left)); z-index: 15; display: flex; justify-content: center; pointer-events: none; }
  .muyuy-gesture-card { width: min(100%, 375px); }
  .muyuy-gesture :is(a, button) { display: flex; width: 100%; min-height: 66px; align-items: center; gap: 12px; pointer-events: auto; text-align: start; padding: 9px 13px 9px 10px; border: 1px solid #d8edb54d; border-radius: 16px; color: #edf3df; background: #101711eb; backdrop-filter: blur(16px); box-shadow: 0 8px 30px #0006, inset 0 1px #e9f4d30d; cursor: pointer; transition: background-color .2s, border-color .2s; }
  .muyuy-gesture :is(a, button):hover { border-color: #d8edb58c; background: #19231af5; }
  .muyuy-gesture :is(a, button):focus-visible { outline: 2px solid #d4e8ab; outline-offset: 3px; }
  .muyuy-gesture-icon { flex: none; display: grid; place-items: center; width: 38px; height: 38px; border: 1px solid #d8edb536; border-radius: 11px; color: #d9edb5; background: #d8edb518; }
  .muyuy-gesture-copy { flex: 1; min-width: 0; display: grid; gap: 2px; overflow-wrap: anywhere; }
  .muyuy-gesture-copy strong { font-size: 14px; line-height: 1.25; }
  .muyuy-gesture-copy > span { color: #c4cdbd; font-size: 11px; line-height: 1.4; }
  .muyuy-gesture-arrow { color: #d9edb5; }
  .muyuy-gesture svg { flex: none; }
  .muyuy-landing h2 { font: 400 clamp(38px,4.3vw,64px)/1.02 "Instrument Serif", Georgia, serif; letter-spacing: -.045em; margin-bottom: 20px; }
  .muyuy-landing h2 em, .muyuy-tagline em { color: #cadca6; font-weight: 400; }
  .muyuy-landing h3 { font-size: 16px; font-weight: 600; line-height: 1.35; }
  .muyuy-landing p + p { margin-top: 13px; }
  .muyuy-copy > p:not(.muyuy-eyebrow), .muyuy-copy > div > p, .muyuy-glass p { color: #c3c5bf; }
  .muyuy-tagline { font-size: clamp(21px,2.5vw,32px); line-height: 1.4; }
  .muyuy-location { display: flex; flex-wrap: wrap; align-items: center; gap: 7px; font-size: 11px; margin-top: 25px !important; }
  .muyuy-dot { width: 5px; height: 5px; background: #cadca6; border-radius: 50%; }
  .muyuy-actions { display: flex; flex-wrap: wrap; gap: 9px; margin-top: 25px; width: fit-content; }
  .muyuy-button { min-height: 44px; display: inline-flex; align-items: center; justify-content: center; gap: 9px; padding: 11px 15px; background: #18181bcc; border: 1px solid #ffffff26; border-radius: 8px; color: #eee; font-size: 12px !important; font-weight: 600 !important; transition: transform .18s cubic-bezier(.32,.72,0,1), background .18s; }
  .muyuy-button.primary { background: #d2dfb6; border-color: #d2dfb6; color: #161c12; }
  .muyuy-button:active:not(:disabled), .muyuy-layer-options button:active { transform: scale(.98); }
  .muyuy-button:hover:not(:disabled) { filter: brightness(1.09); }
  .muyuy-button:disabled { opacity: .5; cursor: default; }
  .muyuy-scroll { position: absolute; left: 6vw; bottom: 35px; display: inline-flex; gap: 15px; align-items: center; font-size: 11px; color: #b9c1ae !important; }
  .muyuy-risk-list { display: flex; flex-wrap: wrap; gap: 17px; padding-top: 23px; color: #c5d3b2; font-size: 11px; }
  .muyuy-risk-list span { display: inline-flex; align-items: center; gap: 7px; }
  .muyuy-muted { color: #b5b7b1; }
  .muyuy-workflow { margin-top: 24px; }
  .muyuy-step { padding: 18px; display: flex; gap: 14px; align-items: flex-start; }
  .muyuy-step > svg { flex: none; color: #cadca6; }
  .muyuy-step p { font-size: 13px; margin-top: 5px; }
  .muyuy-flow-arrow { display: block; margin: 5px 23px; transform: rotate(90deg); color: #bdc7b1; }
  .muyuy-month-label { display: flex; justify-content: space-between; margin-top: 25px; font-size: 12px; }
  .muyuy-zone-field { border: 0; padding: 0; margin: 22px 0 0; }
  .muyuy-zone-global { margin-top: 14px; }
  .muyuy-zone-global legend { display: inline-flex; align-items: center; gap: 5px; }
  .muyuy-zone-locate { border-style: dashed !important; }
  .muyuy-zone-locate strong { display: inline-flex; align-items: center; gap: 4px; }
  .muyuy-zone-status { margin-top: 8px !important; }
  .muyuy-spin { animation: muyuy-spin 1s linear infinite; }
  @keyframes muyuy-spin { to { transform: rotate(360deg); } }
  .muyuy-rotation { margin-top: 16px; padding: 12px 14px; border: 1px solid #ffffff17; border-radius: 10px; background: #0b0f0c80; }
  .muyuy-rotation-line { margin-top: 6px !important; font-size: 12.5px; color: #dcecc0; }
  .muyuy-rotation .muyuy-small { margin-top: 6px !important; }
  .muyuy-zone-field legend { font-size: 11px; margin-bottom: 8px; }
  .muyuy-zone-options { display: flex; flex-wrap: wrap; gap: 6px; }
  .muyuy-zone-options button { display: flex; flex-direction: column; align-items: flex-start; gap: 2px; padding: 8px 11px; border: 1px solid #ffffff20; border-radius: 8px; background: transparent; color: #c9ccc4; font-size: 11px; transition: transform .18s cubic-bezier(.32,.72,0,1); }
  .muyuy-zone-options button strong { font-size: 12px; font-weight: 600; }
  .muyuy-zone-options button span { font-size: 10px; color: #92988b; }
  .muyuy-zone-options button[aria-pressed=true] { background: #cadca6; border-color: #cadca6; color: #182012; }
  .muyuy-zone-options button[aria-pressed=true] span { color: #3f4d2f; }
  .muyuy-climate { display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); align-items: end; gap: 3px; margin-top: 12px; }
  .muyuy-climate-month { display: flex; flex-direction: column; justify-content: flex-end; gap: 5px; height: 78px; padding: 0; border: 0; background: none; }
  .muyuy-climate-bar { display: block; width: 100%; height: var(--frost, 4%); min-height: 3px; border-radius: 3px 3px 0 0; background: linear-gradient(180deg, #a9c8db, #4c7d94); opacity: .5; transition: opacity .18s, background .18s; }
  .muyuy-climate-month:hover .muyuy-climate-bar { opacity: .85; }
  .muyuy-climate-name { font: 9px/1 var(--font-mono, monospace); color: #868d80; }
  .muyuy-climate-month[data-active=true] .muyuy-climate-bar { background: #cadca6; opacity: 1; }
  .muyuy-climate-month[data-active=true] .muyuy-climate-name { color: #cadca6; }
  .muyuy-climate-note { margin-top: 9px !important; }
  .muyuy-step-data { margin-top: 8px !important; font-size: 10.5px !important; color: #b9c4ac !important; }

  .muyuy-layer-field { border: 0; padding: 0; margin: 22px 0 0; }
  .muyuy-layer-field legend { font-size: 11px; margin-bottom: 8px; }
  .muyuy-layer-options { display: flex; flex-wrap: wrap; gap: 6px; }
  .muyuy-layer-options button { display: inline-flex; align-items: center; gap: 7px; padding: 8px 10px; border: 1px solid #ffffff20; border-radius: 7px; background: transparent; color: #c9ccc4; font-size: 11px; transition: transform .18s cubic-bezier(.32,.72,0,1); }
  .muyuy-layer-options button[aria-pressed=true] { color: #182012; background: #cadca6; border-color: #cadca6; }
  .muyuy-follow { display: flex; align-items: center; gap: 6px; padding: 8px 0; margin-top: 6px; border: 0; background: none; color: #c9d6b4; font-size: 11px !important; text-decoration: underline; text-underline-offset: 4px; }
  .muyuy-readings { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 15px; padding-top: 18px; margin: 17px 0; border-top: 1px solid #ffffff1a; }
  .muyuy-readings dt { font: 10px system-ui; color: #adb3a5; } .muyuy-readings dd { margin: 4px 0 0; font-size: clamp(17px, 4.5vw, 23px); overflow-wrap: anywhere; }
  .muyuy-provenance { margin-top: 10px; font: 10.5px/1.7 var(--font-mono, monospace); color: #8e958a; }
  .muyuy-provenance code { color: #b9c4ac; }
  .muyuy-provenance a { color: #cadca6; text-decoration: underline; text-underline-offset: 3px; }
  .muyuy-small { font-size: 11px !important; color: #9fa699 !important; line-height: 1.65; }
  .muyuy-video-card { padding: 9px; margin-top: 15px; }
  .muyuy-video { aspect-ratio: 16/9; border-radius: 12px; overflow: hidden; scroll-margin-top: 100px; }
  .muyuy-video iframe { display: block; width: 100%; height: 100%; border: 0; }
  .muyuy-video > div { height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; gap: 9px; padding: 20px; }
  .muyuy-video p { font-size: 12px; }
  .muyuy-field-content { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); align-items: start; gap: clamp(18px, 3vw, 38px); margin-top: 30px; }
  .muyuy-field-media > figure img { width: 100%; height: auto; aspect-ratio: 3/2; object-fit: cover; border-radius: 10px; }
  .muyuy-field-content figcaption { font-size: 11px; color: #aaa; }
  .muyuy-field-note { margin-top: 16px; }
  .muyuy-field-collage { display: grid; grid-template-columns: 1.1fr 1fr; grid-template-rows: minmax(0, .8fr) minmax(0, 1.2fr); gap: 8px; aspect-ratio: 1.35; }
  .muyuy-field-collage a { display: block; min-width: 0; min-height: 0; overflow: hidden; border: 1px solid #bcddbf45; border-radius: 10px; }
  .muyuy-field-collage a:first-child { grid-row: span 2; }
  .muyuy-field-collage img { display: block; width: 100%; height: 100%; object-fit: cover; }
  .muyuy-field-collage a:last-child img { object-position: center 43%; }
  .muyuy-field-collage + figcaption { margin-top: 10px; }
  .muyuy-field-video { display: block; width: 100%; aspect-ratio: 16/9; border: 1px solid #bcddbf45; border-radius: 13px; background: #091611; }
  .muyuy-field-video + figcaption { margin-top: 10px; }
  .muyuy-field-demo-link { margin-top: 15px; }
  .muyuy-field-content blockquote { margin: 0; } .muyuy-field-content cite { display: block; margin-top: 16px; font-size: 12px; color: #b3b8aa; }
  .muyuy-download { width: 100%; display: grid; grid-template-columns: 1fr 1fr; gap: 45px; align-items: start; }
  .muyuy-download-actions { min-width: 0; } .muyuy-download-actions > .muyuy-button { width: 100%; }
  .muyuy-checksum { margin-top: 25px; padding: 17px; border: 1px solid #ffffff1a; border-radius: 10px; }
  .muyuy-checksum code { display: block; overflow-wrap: anywhere; user-select: all; font-size: 12px; margin: 9px 0 16px; }
  .muyuy-checksum .muyuy-small { margin-top: 10px; }
  .muyuy-guide { margin-top: 18px; display: flex; align-items: center; gap: 7px; padding: 0; background: none; border: 0; color: #d0dbbb; font-size: 12px !important; text-align: left; }
  .muyuy-notice { font-size: 11px; margin-top: 19px !important; color: #adb2a5 !important; }
  .muyuy-team-section { min-height: 90svh; padding-bottom: 56px; }
  .muyuy-footer { display: grid; gap: 26px; }
  .muyuy-footer-main { display: grid; grid-template-columns: minmax(0, 1.6fr) repeat(3, minmax(0, 1fr)); gap: clamp(18px, 3vw, 40px); align-items: start; }
  .muyuy-footer-brand { max-width: 34ch; }
  .muyuy-footer-brand img { width: clamp(110px, 14vw, 150px); height: auto; }
  .muyuy-footer-brand p { margin-top: 12px; font-size: 13px; color: #cdd2c6; }
  .muyuy-footer-col { display: flex; flex-direction: column; gap: 9px; min-width: 0; }
  .muyuy-footer-col h3 { font-size: 10px; font-weight: 600; letter-spacing: .14em; text-transform: uppercase; color: #bfcdab; }
  .muyuy-footer-col a { font-size: 12px; color: #cdd2c6; transition: color .18s; overflow-wrap: anywhere; }
  .muyuy-footer-col a:hover { color: #cadca6; }
  .muyuy-footer-col .muyuy-small { margin: 0 !important; }
  .muyuy-footer-col code { font-size: 10.5px; color: #b9c4ac; }
  .muyuy-footer-bottom { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 10px 24px; padding-top: 18px; border-top: 1px solid #ffffff14; }
  .muyuy-footer-bottom .muyuy-small { max-width: 60ch; }
  .muyuy-team-intro { max-width: 62ch; color: #c3c5bf; }
  .muyuy-terrain-loading { position: fixed; inset: 0; z-index: 0; pointer-events: none; }
  .muyuy-footer p { margin-top: 10px; } .muyuy-footer-links { max-width: 330px; display: flex; flex-wrap: wrap; gap: 12px; font-size: 11px; }
  .muyuy-footer-links a, .muyuy-footer-links button { display: inline-flex; align-items: center; gap: 5px; }
  .muyuy-footer-links button { background: transparent; border: 0; color: #cadca6; padding: 0; font-size: 11px; }
  .muyuy-toast { pointer-events: auto; }
  .muyuy-drawer-overlay { position: fixed; inset: 0; z-index: 100; background: #0009; pointer-events: auto; }
  .muyuy-drawer { position: fixed; z-index: 101; bottom: 0; left: 0; right: 0; margin-inline: auto; width: min(100%,760px); max-height: 88dvh; display: flex; flex-direction: column; background: #111113; border: 1px solid #ffffff1a; border-bottom: 0; border-radius: 22px 22px 0 0; padding: 12px 26px 0; color: #ededeb; font: 14px/1.65 var(--font-sans, "Inter"),system-ui,sans-serif; pointer-events: auto; }
  .muyuy-drawer-handle { flex: none; width: 42px; height: 4px; border-radius: 8px; background: #505054; margin: 0 auto 22px; }
  .muyuy-drawer-heading { display: flex; justify-content: space-between; align-items: center; gap: 20px; }
  .muyuy-drawer-heading h2 { font-size: 23px; margin: 0; letter-spacing: -.04em; }
  .muyuy-drawer-heading button { padding: 7px; border: 1px solid #ffffff20; border-radius: 8px; color: #eee; background: transparent; }
  .muyuy-drawer > p { color: #b8b8b0; font-size: 12px; margin: 10px 0 20px; }
  .muyuy-drawer-scroll { overflow-y: auto; padding: 0 0 max(28px,env(safe-area-inset-bottom)); overscroll-behavior: contain; }
  .muyuy-drawer-scroll h3 { font-size: 15px; margin: 22px 0 12px; } .muyuy-drawer-scroll li { margin-bottom: 13px; color: #c1c3ba; }
  .muyuy-drawer-scroll ol { padding-left: 21px; }
  .muyuy-drawer code { font: 11px ui-monospace,monospace; overflow-wrap: anywhere; color: #d0ddb8; }
  .muyuy-drawer a { color: #d0ddb8; font-size: 12px; }
  .muyuy-specs > div { padding: 12px 0; border-top: 1px solid #ffffff14; }
  .muyuy-specs dt { font-weight: 600; font-size: 12px; } .muyuy-specs dd { margin: 4px 0 0; color: #b4b8ac; font-size: 12px; }
  @media (max-width: 760px) {
    .muyuy-navigation { margin-inline: 12px; padding: 8px 12px; top: 8px; gap: 8px 14px; flex-wrap: wrap; }
    .muyuy-navigation nav { min-width: 0; gap: 6px 10px; font-size: 11px; flex-wrap: wrap; }
    .muyuy-navigation nav > :is(a, button, select) { min-height: 36px; }
    .muyuy-section { padding: 120px 18px 240px; min-height: 115svh; align-items: start; }
    .muyuy-hero { padding-top: 112px; padding-bottom: 46svh; min-height: 100svh; }
    .muyuy-hero .muyuy-location { margin-top: 15px !important; }
    .muyuy-hero .muyuy-actions { margin-top: 16px; }
    .muyuy-scroll { bottom: 16px; }
    .muyuy-copy { max-width: 100%; width: 100%; }
    .muyuy-plot-section { align-items: end; padding: 110px 18px 35px; }
    .muyuy-plot-section > .muyuy-copy { width: 100%; }
    .muyuy-plot-section .muyuy-copy.muyuy-glass { padding: 16px 19px; }
    .muyuy-plot-section h2 { font-size: clamp(29px, 8.5vw, 42px); margin-bottom: 9px; }
    .muyuy-landing h1 { font-size: clamp(56px,19.5vw,128px); margin: 14px 0 !important; }
    .muyuy-landing .muyuy-hero h1 { font-size: clamp(56px,19.5vw,128px); }
    .muyuy-footer-main { grid-template-columns: minmax(0, 1fr); }
    .muyuy-team-section { padding-bottom: 70px; }
    .muyuy-glass { background: #09090bca; }
    .muyuy-vignette { background: linear-gradient(180deg,#09090b80,transparent 75%); }
  }
  @media (max-width: 380px) {
    .muyuy-navigation nav { width: 100%; justify-content: space-between; }
    .muyuy-gesture :is(a, button) { min-height: 60px; gap: 8px; }
    .muyuy-gesture-icon { width: 32px; height: 32px; }
    .muyuy-glass { padding: 18px; }
  }
  @media (max-height: 500px) and (orientation: landscape) {
    .muyuy-hero { padding-block: 96px 100px; }
    .muyuy-gesture { justify-content: flex-end; }
    .muyuy-gesture-card { width: min(52vw, 375px); }
  }
  @media (prefers-reduced-motion: reduce) {
    .muyuy-button, .muyuy-layer-options button { transition: none; }
  }
  .muyuy-landing[data-motion=off] :is(.muyuy-atmosphere-frost,.muyuy-atmosphere-water) { transition: none; }
`;