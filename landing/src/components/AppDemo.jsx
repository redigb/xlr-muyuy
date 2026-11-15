import React, { useEffect, useRef, useState } from 'react';
import { ArrowDown, CalendarDays, House, Layers3, Share2, Sprout } from 'lucide-react';
import { motion } from 'framer-motion';
import { translate } from '../i18n/copy.ts';

const screens = [
  { id: 'home', Icon: House, label: 'Home', title: 'Take the calendar offline', description: 'Save the Huánuco package for offline use.' },
  { id: 'farm', Icon: Sprout, label: 'My farm', title: 'Set up your farm', description: 'Choose irrigation and two priorities.' },
  { id: 'calendar', Icon: CalendarDays, label: 'Calendar', title: 'Read the season', description: 'Check frost, rainfall and water balance by month.' },
  { id: 'rotations', Icon: Layers3, label: 'Rotations', title: 'Compare your options', description: 'Compare three rotations and their confidence levels.' },
  { id: 'share', Icon: Share2, label: 'Share', title: 'Send the regional package', description: 'Use the QR to identify it and the JSON file to send it.' },
];
const screenUrl = (id) => import.meta.env.BASE_URL + 'app-demo/' + id + '.png';

function scrollLine(stage) {
  const style = getComputedStyle(stage);
  const stickyTop = parseFloat(style.top);
  return style.getPropertyValue('--demo-stacked').trim() === '1'
    ? stickyTop + stage.offsetHeight + 12
    : stickyTop + 10;
}

export default function AppDemo({ locale, reduced }) {
  const t = (key) => translate(key, locale);
  const stage = useRef(null);
  const screenTrack = useRef(null);
  const steps = useRef([]);
  const [active, setActive] = useState(0);

  useEffect(() => {
    let frame = 0;
    const update = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const line = scrollLine(stage.current);
        const positions = steps.current.map((step) => step.getBoundingClientRect().top);
        const last = positions.length - 1;
        let index = 0;
        while (index < last && positions[index + 1] <= line) index++;
        const fraction = index === last ? 0
          : Math.max(0, Math.min(1, (line - positions[index]) / (positions[index + 1] - positions[index])));
        const progress = index + fraction;
        const current = Math.round(progress);
        screenTrack.current.style.transform = `translate3d(0, ${-(reduced ? current : progress) * 100}%, 0)`;
        setActive(current);
      });
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    const observer = new ResizeObserver(update);
    observer.observe(stage.current.parentElement);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [reduced, locale]);

  const goTo = (index) => {
    const top = steps.current[index].getBoundingClientRect().top;
    window.scrollTo({ top: window.scrollY + top - scrollLine(stage.current), behavior: reduced ? 'instant' : 'smooth' });
  };

  return (
    <section id="app-demo" tabIndex={-1} className="muyuy-app-demo" aria-labelledby="app-demo-title">
      <header className="muyuy-demo-intro">
        <h2 id="app-demo-title">{t('See Muyuy in action')}</h2>
        <p><ArrowDown size={16} aria-hidden="true" />{t('Scroll to explore.')}</p>
      </header>
      <div className="muyuy-demo-grid">
        <div className="muyuy-demo-stage" ref={stage}>
          <a className="muyuy-demo-device" href={screenUrl(screens[active].id)} target="_blank" rel="noreferrer"
            aria-label={`${t('Open screenshot')}: ${t(screens[active].label)}`} title={t('Open screenshot')}>
            <div className="muyuy-demo-screen" aria-hidden="true">
              <div className="muyuy-demo-track" ref={screenTrack}>
                {screens.map(({ id }) => (
                  <img key={id} src={screenUrl(id)} alt="" width="424" height="940" loading="lazy" decoding="async" />
                ))}
              </div>
            </div>
          </a>
          <nav className="muyuy-demo-controls" aria-label={t('App screens')}>
            {screens.map(({ id, label, Icon }, index) => (
              <button key={id} type="button" onClick={() => goTo(index)} aria-label={t(label)}
                aria-current={index === active ? 'step' : undefined} title={t(label)}>
                <Icon size={17} aria-hidden="true" />
              </button>
            ))}
          </nav>
        </div>
        <div className="muyuy-demo-steps">
          {screens.map(({ id, title, description }, index) => (
            <article key={id} ref={(element) => { steps.current[index] = element; }} className="muyuy-demo-step"
              data-active={index === active} aria-labelledby={`demo-${id}-title`}>
              <motion.div className="muyuy-demo-copy"
                initial={reduced ? false : { opacity: 0, y: 16 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: .25 }}
                transition={{ duration: reduced ? 0 : .5, ease: [.32, .72, 0, 1] }}>
                <h3 id={`demo-${id}-title`}>{t(title)}</h3>
                <p>{t(description)}</p>
              </motion.div>
            </article>
          ))}
        </div>
      </div>
      <style>{css}</style>
    </section>
  );
}

const css = `
  .muyuy-app-demo { --demo-phone-height: min(680px, calc(100svh - 173px)); --demo-sticky: 104px; --demo-stacked: 0; position: relative; scroll-margin-top: 0; color: #ecf5e9; background: #0005; border-block: 1px solid #9ddfaf30; padding: clamp(25px, 4vw, 52px) clamp(16px, 6vw, 88px) 20px; }
  .muyuy-demo-intro, .muyuy-demo-grid { width: min(100%, 1120px); margin-inline: auto; }
  .muyuy-demo-intro p { display: flex; align-items: center; gap: 9px; color: #bdd5c4; }
  .muyuy-demo-intro svg { flex: none; color: #abe3b2; }
  .muyuy-demo-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; column-gap: clamp(16px, 4vw, 64px); margin-top: 18px; }
  .muyuy-demo-stage { position: sticky; top: var(--demo-sticky); z-index: 1; display: grid; justify-items: center; gap: 12px; }
  .muyuy-demo-device { display: block; height: var(--demo-phone-height); width: min(100%, var(--demo-phone-height) * .472); box-sizing: border-box; border: 1px solid #9bc7a1; border-radius: clamp(20px, 3vw, 40px); padding: clamp(4px, .65vw, 8px); background: #061610; box-shadow: 0 18px 52px #0008, 0 0 44px #7bea9421, inset 0 0 0 2px #506557; cursor: zoom-in; pointer-events: auto; }
  .muyuy-demo-screen { height: 100%; overflow: hidden; border-radius: calc(clamp(20px, 3vw, 40px) - 5px); background: #e9faf2; }
  .muyuy-demo-track { height: 100%; }
  .muyuy-demo-screen img { display: block; width: 100%; height: 100%; object-fit: contain; }
  .muyuy-demo-controls { display: flex; padding: 3px; gap: 3px; border: 1px solid #a5d7af40; border-radius: 18px; background: #101812e8; pointer-events: auto; }
  .muyuy-demo-controls button { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 13px; color: #bdd5c4; cursor: pointer; }
  .muyuy-demo-controls button:hover { background: #296044; }
  .muyuy-demo-controls button[aria-current=step] { color: #10291d; background: #b2e7b7; }
  .muyuy-demo-device:focus-visible, .muyuy-demo-controls button:focus-visible { outline: 2px solid #d9facb; outline-offset: 2px; }
  .muyuy-demo-step { min-height: clamp(174px, 34svh, 310px); display: grid; align-items: start; padding-top: 12px; }
  .muyuy-demo-step:last-child { min-height: calc(var(--demo-phone-height) + 70px); }
  .muyuy-demo-copy { width: min(100%, 40ch); border-inline-start: 1px solid #aeeab741; border-radius: 0 14px 14px 0; padding: 12px 16px; background: #050805b8; transition: border-color .28s; }
  .muyuy-demo-step[data-active=true] .muyuy-demo-copy { border-color: #b2e7b7; }
  .muyuy-app-demo .muyuy-demo-copy h3 { font: 400 clamp(25px, 3.7vw, 48px)/1.05 "Instrument Serif", Georgia, serif; letter-spacing: -.03em; margin-bottom: 6px; text-wrap: balance; }
  .muyuy-demo-copy p { color: #cde0d3; line-height: 1.45; }
  @media (max-width: 760px) {
    .muyuy-app-demo { --demo-phone-height: clamp(180px, calc(64svh - 95px), 455px); --demo-stacked: 1; padding-inline: 14px; }
    .muyuy-demo-grid { grid-template-columns: minmax(0, 1fr); margin-top: 14px; }
    .muyuy-demo-stage { padding: 5px 0; gap: 5px; }
    .muyuy-demo-step { min-height: clamp(142px, 26svh, 230px); padding-block-start: 7px; }
    .muyuy-demo-step:last-child { min-height: max(165px, calc(100svh - var(--demo-sticky) - var(--demo-phone-height) - 55px)); }
    .muyuy-demo-copy { margin-inline: auto; }
  }
  @media (max-height: 540px) and (orientation: landscape) {
    .muyuy-app-demo { --demo-phone-height: max(115px, calc(100svh - 150px)); --demo-sticky: 82px; --demo-stacked: 0; }
    .muyuy-demo-grid { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
    .muyuy-demo-step { min-height: max(140px, 45svh); }
    .muyuy-demo-step:last-child { min-height: calc(var(--demo-phone-height) + 65px); }
  }
  [data-motion=off] .muyuy-app-demo :is(img, .muyuy-demo-copy) { transition: none; }
`;
