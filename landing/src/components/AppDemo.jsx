import React, { useEffect, useRef, useState } from 'react';
import { ArrowDown, CalendarDays, House, Layers3, Play, Share2, Sprout, X } from 'lucide-react';
import { motion, useMotionValue, useSpring } from 'framer-motion';
import { translate } from '../i18n/copy.ts';

const screens = [
  { id: 'home', Icon: House, label: 'Home', title: 'Take the calendar offline', description: 'Save the Huánuco package for offline use.' },
  { id: 'farm', Icon: Sprout, label: 'My farm', title: 'Watch your farm grow in 3D', description: 'Simulate three years of the recommended rotation, month by month.' },
  { id: 'calendar', Icon: CalendarDays, label: 'Calendar', title: 'Read the season', description: 'Check frost, rainfall and water balance by month.' },
  { id: 'rotations', Icon: Layers3, label: 'Rotations', title: 'Compare your options', description: 'Compare three rotations and their confidence levels.' },
  { id: 'share', Icon: Share2, label: 'Share', title: 'Send the regional package', description: 'Use the QR to identify it and the JSON file to send it.' },
];
const screenUrl = (id) => import.meta.env.BASE_URL + 'app-demo/' + id + '.webp';
const demoMedia = import.meta.env.BASE_URL + 'app-demo/field-preview.mp4';

function scrollLine(stage, device) {
  return parseFloat(getComputedStyle(stage).top) + device.offsetHeight / 2;
}

function stepCenter(step) {
  const rect = step.getBoundingClientRect();
  return rect.top + rect.height / 2;
}

export default function AppDemo({ locale, reduced, videoUrl }) {
  const t = (key) => translate(key, locale);
  const stage = useRef(null);
  const device = useRef(null);
  const steps = useRef([]);
  const videoDialog = useRef(null);
  const [active, setActive] = useState(0);
  const [videoOpen, setVideoOpen] = useState(false);
  const scrollProgress = useMotionValue(0);
  const screenProgress = useSpring(scrollProgress, { stiffness: 420, damping: 38, mass: .65 });

  useEffect(() => {
    let frame = 0;
    let settleTimer;
    let previousProgress;
    const update = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const line = scrollLine(stage.current, device.current);
        const positions = steps.current.map(stepCenter);
        const last = positions.length - 1;
        let index = 0;
        while (index < last && positions[index + 1] <= line) index++;
        const fraction = index === last ? 0
          : Math.max(0, Math.min(1, (line - positions[index]) / (positions[index + 1] - positions[index])));
        const progress = index + fraction;
        if (progress === previousProgress) return;
        const current = Math.round(progress);
        window.clearTimeout(settleTimer);
        if (previousProgress === undefined || reduced) {
          scrollProgress.jump(current);
          screenProgress.jump(current);
        } else {
          scrollProgress.set(progress);
          // Only the phone snaps to the selected screen. The page stays where the reader stopped.
          settleTimer = window.setTimeout(() => scrollProgress.set(current), 130);
        }
        previousProgress = progress;
        setActive(current);
      });
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    const measure = () => {
      const section = stage.current.closest('section');
      section.style.setProperty('--demo-stage-height', `${stage.current.offsetHeight}px`);
      section.style.setProperty('--demo-phone-height', `${device.current.offsetHeight}px`);
      update();
    };
    const observer = new ResizeObserver(measure);
    observer.observe(stage.current);
    observer.observe(stage.current.parentElement);
    measure();
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
      observer.disconnect();
      cancelAnimationFrame(frame);
      window.clearTimeout(settleTimer);
    };
  }, [reduced, locale, scrollProgress, screenProgress]);

  const goTo = (index) => {
    const top = stepCenter(steps.current[index]);
    window.scrollTo({ top: window.scrollY + top - scrollLine(stage.current, device.current), behavior: reduced ? 'instant' : 'smooth' });
  };

  const screen = screens[active];

  return (
    <section id="app-demo" tabIndex={-1} className="muyuy-app-demo" aria-labelledby="app-demo-title">
      <div className="muyuy-glass muyuy-demo-surface" aria-hidden="true" />
      <header className="muyuy-demo-intro">
        <div>
          <h2 id="app-demo-title">{t('See Muyuy in action')}</h2>
          <p>
            <motion.span aria-hidden="true" initial={false}
              whileInView={reduced ? undefined : { y: [0, 5, 0] }}
              viewport={{ once: true }} transition={{ duration: .8, repeat: 2 }}>
              <ArrowDown size={16} />
            </motion.span>
            {t('Scroll to explore.')}
          </p>
        </div>
        <button id="video-demo" className="muyuy-button pointer-events-auto" type="button"
          aria-haspopup="dialog" aria-controls="app-demo-video"
          onClick={() => {
            videoDialog.current.showModal();
            setVideoOpen(true);
          }}>
          <Play size={16} aria-hidden="true" />{t('Watch the demo')}
        </button>
      </header>
      <div className="muyuy-demo-grid">
        <motion.div className="muyuy-demo-stage" ref={stage}
          style={{ '--demo-progress': screenProgress, '--demo-active': active, '--demo-step-count': screens.length }}>
          <a ref={device} className="muyuy-demo-device" href={screenUrl(screen.id)} target="_blank" rel="noreferrer"
            aria-label={`${t('Open screenshot')}: ${t(screen.label)}`} title={t('Open screenshot')}>
            <span className="muyuy-demo-screen" aria-hidden="true">
              {screens.map(({ id }, index) => (
                <span key={id} className="muyuy-demo-shot" data-current={index === active} style={{ '--demo-index': index }}>
                  <img src={screenUrl(id)} alt="" width="720" height="1512" loading="lazy" decoding="async" />
                </span>
              ))}
            </span>
          </a>
          <div className="muyuy-demo-navigation">
            <div className="muyuy-demo-progress" aria-hidden="true"><span /></div>
            <nav className="muyuy-demo-controls" aria-label={t('App screens')}>
              {screens.map(({ id, label, Icon }, index) => (
                <button key={id} type="button" onClick={() => goTo(index)} aria-label={t(label)}
                  aria-current={index === active ? 'step' : undefined} aria-controls={`demo-${id}`} title={t(label)}>
                  <Icon size={17} aria-hidden="true" />
                </button>
              ))}
            </nav>
          </div>
        </motion.div>
        <div className="muyuy-demo-steps">
          {screens.map(({ id, title, description }, index) => (
            <article key={id} id={`demo-${id}`} ref={(element) => { steps.current[index] = element; }} className="muyuy-demo-step"
              data-active={index === active} aria-labelledby={`demo-${id}-title`}>
              <motion.div className="muyuy-demo-copy"
                initial={reduced ? false : { opacity: .82, y: 12 }}
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
      <dialog ref={videoDialog} id="app-demo-video" className="muyuy-glass muyuy-demo-dialog"
        aria-labelledby="app-demo-video-title" onClose={() => setVideoOpen(false)}>
        <header>
          <h3 id="app-demo-video-title">{t('Watch the demo')}</h3>
          <form method="dialog">
            <button className="muyuy-button" type="submit" aria-label={t('Close demo video')}>
              <X size={18} aria-hidden="true" />
            </button>
          </form>
        </header>
        {videoOpen && (videoUrl ? (
          <iframe src={videoUrl} title={t('Watch the demo')} allow="fullscreen; picture-in-picture"
            allowFullScreen referrerPolicy="strict-origin-when-cross-origin" />
        ) : (
          <video src={demoMedia} controls playsInline
            preload="metadata" aria-label={t('Watch the demo')} />
        ))}
      </dialog>
      <style>{css}</style>
    </section>
  );
}

const css = `
  .muyuy-app-demo {
    --demo-nav-clearance: 92px;
    --demo-step-height: clamp(128px, 17svh, 164px);
    --demo-phone-height: 420px;
    --demo-stage-height: 480px;
    --demo-sticky: max(var(--demo-nav-clearance), min(
      calc((100svh - var(--demo-phone-height)) / 2),
      calc(100svh - var(--demo-stage-height) - 10px)
    ));
    position: relative;
    scroll-margin-top: max(0px, calc(var(--demo-nav-clearance) - 100px));
    color: #ecf5e9;
    padding: clamp(30px, 4vw, 60px) calc(var(--muyuy-section-gutter) + clamp(18px, 2.4vw, 36px))
      clamp(26px, 4vw, 52px);
  }
  .muyuy-landing .muyuy-demo-surface {
    position: absolute;
    inset: 0 var(--muyuy-section-gutter);
    pointer-events: none;
    background-image: radial-gradient(ellipse at 20% 0%, #ffffff0d, transparent 50%);
    box-shadow: inset 0 1px #ffffff0d, 0 24px 64px #0003;
  }
  .muyuy-demo-intro, .muyuy-demo-grid { position: relative; width: min(100%, 1160px); margin-inline: auto; }
  .muyuy-demo-intro {
    display: flex;
    align-items: end;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 12px 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid #ffffff17;
  }
  .muyuy-demo-intro p { display: flex; align-items: center; gap: 9px; color: #bdd5c4; }
  .muyuy-demo-intro svg { flex: none; color: #abe3b2; }
  .muyuy-demo-intro button, .muyuy-demo-dialog button { cursor: pointer; }
  .muyuy-landing .muyuy-demo-dialog {
    position: fixed;
    inset: 0;
    margin: auto;
    width: min(calc(100% - 24px), 740px, calc((100dvh - 84px) * 16 / 9));
    padding: 12px;
    color: #ecf5e9;
    background: #09090bf5;
    pointer-events: auto;
  }
  .muyuy-demo-dialog::backdrop { background: #000c; }
  .muyuy-demo-dialog header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 10px; }
  .muyuy-demo-dialog :is(video, iframe) { display: block; width: 100%; aspect-ratio: 16 / 9; border: 0; border-radius: 8px; background: #000; }
  .muyuy-demo-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; column-gap: clamp(16px, 4vw, 64px); margin-top: 18px; }
  .muyuy-demo-stage { position: sticky; top: var(--demo-sticky); z-index: 1; display: grid; justify-items: center; gap: 12px; }
  .muyuy-demo-device {
    display: block;
    justify-self: center;
    width: min(100%, 300px, max(100px, calc((100svh - var(--demo-nav-clearance) - 82px) * 720 / 1512)));
    aspect-ratio: 720 / 1512;
    border: 1px solid #a9c8ad;
    border-radius: clamp(24px, 4vw, 42px);
    padding: clamp(6px, .8vw, 10px);
    background: linear-gradient(155deg, #334c3e, #07110c 33%, #07110c 70%, #1a2d21);
    box-shadow: 0 28px 72px #000a, 0 0 76px #7bea9425, inset 0 0 0 2px #c8e0ce28;
    cursor: zoom-in;
    pointer-events: auto;
  }
  .muyuy-demo-screen {
    display: block;
    position: relative;
    height: 100%;
    overflow: hidden;
    border-radius: clamp(18px, 3.2vw, 32px);
    background: #111f17;
  }
  .muyuy-demo-shot { position: absolute; inset: 0; }
  .muyuy-demo-screen img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top;
  }
  .muyuy-demo-shot[data-current=false] { visibility: hidden; }
  [data-motion=on] .muyuy-demo-shot {
    --demo-position: clamp(0, var(--demo-progress, 0), calc(var(--demo-step-count) - 1));
    --demo-offset: calc(var(--demo-index) - var(--demo-position));
    visibility: visible;
    transform: translate3d(calc(var(--demo-offset) * 100%), 0, 0);
  }
  .muyuy-demo-navigation { display: grid; gap: 6px; }
  .muyuy-demo-progress { height: 2px; margin-inline: 10px; border-radius: 2px; background: #ffffff26; }
  .muyuy-demo-progress span {
    display: block;
    height: 100%;
    border-radius: inherit;
    background: #b2e7b7;
    transform-origin: left;
    transform: scaleX(calc((var(--demo-active) + 1) / var(--demo-step-count)));
  }
  [data-motion=on] .muyuy-demo-progress span {
    transform: scaleX(calc((var(--demo-progress, 0) + 1) / var(--demo-step-count)));
  }
  .muyuy-demo-controls { display: flex; padding: 3px; gap: 3px; border: 1px solid #a5d7af40; border-radius: 18px; background: #101812e8; pointer-events: auto; }
  .muyuy-demo-controls button { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 13px; color: #bdd5c4; cursor: pointer; }
  .muyuy-demo-controls button:hover { background: #296044; }
  .muyuy-demo-controls button[aria-current=step] { color: #10291d; background: #b2e7b7; }
  .muyuy-demo-device:focus-visible, .muyuy-demo-controls button:focus-visible { outline: 2px solid #d9facb; outline-offset: 2px; }
  .muyuy-demo-steps {
    display: grid;
    grid-auto-rows: minmax(var(--demo-step-height), auto);
    padding-block: max(0px, calc((var(--demo-phone-height) - var(--demo-step-height)) / 2))
      max(0px, calc(var(--demo-stage-height) - (var(--demo-phone-height) + var(--demo-step-height)) / 2));
  }
  .muyuy-demo-step { display: grid; align-items: center; padding-block: 8px; }
  .muyuy-demo-copy { width: min(100%, 44ch); border: 1px solid #ffffff13; border-inline-start-color: #aeeab741; border-radius: 0 14px 14px 0; padding: 12px 16px; background: #09090bde; transition: border-color .28s, background-color .28s; }
  .muyuy-demo-step[data-active=true] .muyuy-demo-copy { border-inline-start-color: #b2e7b7; background-color: #141816; }
  .muyuy-app-demo .muyuy-demo-copy h3 { font: 400 clamp(25px, 3.2vw, 42px)/1.05 "Instrument Serif", Georgia, serif; letter-spacing: -.03em; margin-bottom: 6px; text-wrap: balance; }
  .muyuy-demo-copy p { color: #cde0d3; line-height: 1.45; }
  @media (max-width: 760px) {
    .muyuy-app-demo { --demo-nav-clearance: 152px; --demo-step-height: clamp(112px, 17svh, 144px); padding-inline: calc(var(--muyuy-section-gutter) + 10px); }
    .muyuy-demo-grid { grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); gap: clamp(10px, 3.3vw, 22px); }
    .muyuy-demo-stage { gap: 7px; }
    .muyuy-demo-device { width: min(100%, 226px, max(100px, calc((100svh - var(--demo-nav-clearance) - 112px) * 720 / 1512))); }
    .muyuy-demo-controls { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); }
    .muyuy-demo-controls button { width: clamp(30px, 8vw, 42px); height: 38px; }
    .muyuy-demo-copy { padding: 10px 11px; }
    .muyuy-app-demo .muyuy-demo-copy h3 { font-size: clamp(23px, 4.5vw, 34px); }
    .muyuy-demo-copy p { font-size: clamp(13px, 2.6vw, 16px); }
  }
  @media (max-width: 380px) {
    .muyuy-app-demo { --demo-nav-clearance: 172px; }
  }
  [data-motion=off] .muyuy-app-demo :is(img, .muyuy-demo-copy) { transition: none; }
`;
