import { useEffect, useRef, useState } from 'react';
import { Mountain, ScanLine } from 'lucide-react';

const base = import.meta.env.BASE_URL + 'scanner-demo/';
const scanners = [
  {
    id: 'agrovision',
    title: 'AgroVision AI',
    Icon: ScanLine,
    description: 'Scan a leaf photo to see which diseases the app considers possible, even offline.',
  },
  {
    id: 'soilvision',
    title: 'SoilVision AI',
    Icon: Mountain,
    description: 'Use a photo to find the closest visual soil category. Fertility requires a separate assessment.',
  },
];

export default function ScannerDemo({ t, glass, reduced }) {
  const track = useRef(null);
  const panel = useRef(null);
  const travel = useRef(null);
  const videos = useRef([]);
  const [sticky, setSticky] = useState(false);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const viewport = window.matchMedia('(min-width: 901px) and (min-height: 720px)');
    const updateLayout = () => setSticky(viewport.matches);
    updateLayout();
    viewport.addEventListener('change', updateLayout);
    return () => viewport.removeEventListener('change', updateLayout);
  }, []);

  useEffect(() => {
    if (!sticky) return;
    let frame = 0;
    const update = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const top = parseFloat(getComputedStyle(panel.current).top);
        const distance = top - track.current.getBoundingClientRect().top;
        setActive(distance >= travel.current.offsetHeight / 2 ? 1 : 0);
      });
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
      cancelAnimationFrame(frame);
    };
  }, [sticky]);

  useEffect(() => {
    if (sticky) videos.current[1 - active]?.pause();
  }, [active, sticky]);

  const goTo = (index) => {
    const top = parseFloat(getComputedStyle(panel.current).top);
    window.scrollBy({
      top: track.current.getBoundingClientRect().top - top + travel.current.offsetHeight * (index === 0 ? .25 : .75),
      behavior: reduced ? 'instant' : 'smooth',
    });
  };

  return (
    <div className="muyuy-scanner-track" ref={track} data-sticky={sticky}>
      <div className={glass + ' muyuy-scanner-panel'} ref={panel}>
        <header className="muyuy-scanner-heading">
          <h2 id="scanner-demo-title">{t('Leaf and soil scanners')}</h2>
          {sticky && (
            <nav className="muyuy-scanner-controls" aria-label={t('Leaf and soil scanners')}>
              {scanners.map(({ id, title, Icon }, index) => (
                <button key={id} type="button" onClick={() => goTo(index)}
                  aria-controls={`${id}-demo`} aria-current={active === index ? 'step' : undefined}>
                  <Icon size={16} aria-hidden="true" />{title}
                </button>
              ))}
            </nav>
          )}
        </header>
        <div className="muyuy-scanner-pairs">
          {scanners.map(({ id, title, Icon, description }, index) => (
            <article key={id} id={`${id}-demo`} className="muyuy-scanner-demo" aria-labelledby={`${id}-demo-title`}
              data-active={active === index} inert={sticky && active !== index}>
              <header>
                <h3 id={`${id}-demo-title`}><Icon size={22} aria-hidden="true" />{title}</h3>
                <p>{t(description)}</p>
              </header>
              <div className="muyuy-scanner-media">
                <figure className="muyuy-scanner-capture">
                  <a href={base + id + '.png'} target="_blank" rel="noreferrer"
                    aria-label={`${t('Open screenshot')}: ${title}`}>
                    <img src={base + id + '.png'} alt={`${title} · ${t('App screenshot')}`}
                      width="702" height="1600" loading="lazy" decoding="async" />
                  </a>
                  <figcaption>{t('App screenshot')}</figcaption>
                </figure>
                <figure className="muyuy-scanner-clip">
                  <video ref={(element) => { videos.current[index] = element; }}
                    src={base + id + '.mp4'} controls playsInline preload="metadata"
                    width="854" height="480" aria-label={`${title} · ${t('Video walkthrough')}`} />
                  <figcaption>{t('Video walkthrough')}</figcaption>
                </figure>
              </div>
            </article>
          ))}
        </div>
      </div>
      {sticky && <div ref={travel} className="muyuy-scanner-travel" aria-hidden="true" />}
      <style>{css}</style>
    </div>
  );
}

const css = `
  .muyuy-landing #scanner-demo { display: block; min-height: auto; padding-block: clamp(46px, 7vw, 108px); }
  .muyuy-landing .muyuy-scanner-panel {
    background-image: radial-gradient(ellipse at 15% 35%, #aaddae10, transparent 56%);
    box-shadow: inset 0 1px #ffffff10, 0 24px 70px #0004;
  }
  .muyuy-scanner-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px 24px;
    margin-bottom: clamp(18px, 2.5vw, 32px);
    padding-bottom: clamp(14px, 2vw, 24px);
    border-bottom: 1px solid #ffffff20;
  }
  .muyuy-landing .muyuy-scanner-heading h2 {
    margin: 0;
    font-size: clamp(33px, 4.25vw, 62px);
    text-wrap: balance;
  }
  .muyuy-scanner-controls {
    display: flex;
    flex: none;
    gap: 4px;
    padding: 4px;
    border: 1px solid #ffffff20;
    border-radius: 14px;
    background: #0a0c0b;
  }
  .muyuy-scanner-controls button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    min-height: 44px;
    padding: 6px 12px;
    border-radius: 10px;
    color: #dce6df;
    font-size: 12px;
    font-weight: 650;
    cursor: pointer;
  }
  .muyuy-scanner-controls button:hover { background: #ffffff15; }
  .muyuy-scanner-controls button[aria-current="step"] { color: #102017; background: #b2e7b7; }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-panel {
    position: sticky;
    top: 94px;
    padding: clamp(16px, 2.2vh, 22px) clamp(18px, 2.4vw, 34px);
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-heading {
    margin-bottom: 15px;
    padding-bottom: 12px;
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-heading h2 {
    font-size: clamp(34px, 3.8vw, 52px);
  }
  .muyuy-scanner-travel { height: clamp(230px, 37vh, 350px); pointer-events: none; }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-pairs { display: grid; }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo {
    grid-area: 1 / 1;
    display: grid;
    grid-template-columns: minmax(min(23vw, 246px), 1fr) minmax(0, 2.85fr);
    grid-template-areas: "capture description" "capture video";
    gap: 10px clamp(18px, 2.5vw, 38px);
    align-content: start;
    visibility: hidden;
    opacity: 0;
    pointer-events: none;
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo[data-active=true] {
    visibility: visible;
    opacity: 1;
    pointer-events: auto;
  }
  [data-motion=on] .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo {
    transform: translateY(10px);
    transition: opacity .28s ease, transform .42s cubic-bezier(.2,.75,.25,1), visibility 0s .28s;
  }
  [data-motion=on] .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo[data-active=true] {
    transform: translateY(0);
    transition-delay: .04s, .04s, 0s;
  }
  .muyuy-scanner-demo + .muyuy-scanner-demo {
    margin-top: clamp(28px, 4vw, 48px);
    padding-top: clamp(28px, 4vw, 48px);
    border-top: 1px solid #ffffff24;
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo + .muyuy-scanner-demo {
    margin: 0;
    padding: 0;
    border: 0;
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-demo header {
    grid-area: description;
    align-self: end;
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-media { display: contents; }
  .muyuy-scanner-demo h3 {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 6px;
    font: 400 clamp(26px, 4vw, 40px)/1.1 "Instrument Serif", Georgia, serif;
  }
  .muyuy-scanner-demo h3 svg { flex: none; color: #b2e7b7; }
  .muyuy-scanner-demo header p { max-width: 62ch; }
  .muyuy-scanner-media {
    display: grid;
    grid-template-columns: minmax(222px, 1fr) minmax(0, 2.65fr);
    align-items: center;
    gap: clamp(16px, 4vw, 54px);
    max-width: 1100px;
    margin: 16px auto 0;
  }
  .muyuy-scanner-capture { width: min(100%, 280px); justify-self: center; text-align: center; }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-capture {
    grid-area: capture;
    align-self: center;
    width: min(100%, 280px, calc((100svh - 226px) * 702 / 1600));
  }
  .muyuy-scanner-track[data-sticky=true] .muyuy-scanner-clip {
    grid-area: video;
    width: min(100%, calc((100svh - 380px) * 854 / 480));
  }
  .muyuy-scanner-capture a {
    display: block;
    padding: 6px;
    border: 1px solid #a9c8ad;
    border-radius: clamp(23px, 3vw, 33px);
    background: linear-gradient(150deg, #334c3e, #091510 36%, #13261c);
    box-shadow: inset 0 0 0 2px #ffffff16, 0 20px 44px #0008, 0 0 46px #aadfba19;
    cursor: zoom-in;
  }
  .muyuy-scanner-capture img { display: block; width: 100%; height: auto; border-radius: clamp(17px, 2.5vw, 27px); }
  .muyuy-scanner-clip video {
    display: block;
    width: 100%;
    height: auto;
    overflow: hidden;
    aspect-ratio: 854 / 480;
    border: 1px solid #ffffff26;
    border-radius: 17px;
    background: #09090b;
    box-shadow: 0 18px 44px #0006;
  }
  .muyuy-scanner-media figcaption { margin-top: 7px; color: #c3c5bf; font-size: 12px; }
  @media (max-width: 800px) {
    .muyuy-scanner-media { grid-template-columns: minmax(0, 1fr); gap: 18px; }
    .muyuy-scanner-capture { width: min(100%, clamp(220px, 58vw, 280px)); }
  }
  @media (max-width: 560px) {
    .muyuy-landing .muyuy-scanner-panel { padding-inline: 12px; }
  }
`;
