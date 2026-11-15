import React from 'react';
import { IMPACT_STATS, IMPACT_NOTE } from '../data/impact';

const PILLARS = [
  [
    'Offline in the field',
    'Regional packages put the calendar within reach when mobile service drops.',
  ],
  [
    'Visible uncertainty',
    'Showing confidence helps farmers weigh a rotation alongside what they know about their own land.',
  ],
  [
    'Built to travel',
    'The same approach can be adapted to other regions by pairing climate records with local crop information.',
  ],
];

/**
 * "Why it matters": la sección que responde al jurado *por qué existe* el
 * proyecto. Las cifras salen de src/data/impact.ts y cada una lleva su fuente
 * visible; si un dato no está medido, no se muestra.
 *
 * @param {{ t: (key: string) => string, glass: string }} props
 */
export default function ImpactSection({ t, glass }) {
  return (
    <div className="muyuy-wide">
      <div className={'muyuy-impact ' + glass}>
        <header className="muyuy-impact-head">
          <p className="muyuy-eyebrow">{t('Why it matters')}</p>
          <h2 id="impact-title" className="tracking-tighter">{t('Useful where the signal ends.')}</h2>
          <p className="muyuy-impact-lead">
            {t(
              'Frost, irregular rain and exhausted soil already cost harvest after harvest in the Huánuco highlands. Muyuy turns four decades of NASA climate records into a decision a farmer can carry in a pocket — and use where there is no signal.'
            )}
          </p>
        </header>

        <dl className="muyuy-stats">
          {IMPACT_STATS.map((stat) => (
            <div key={stat.label}>
              <dt className="muyuy-stat-value">{stat.value}</dt>
              <dd>
                <span className="muyuy-stat-label">{t(stat.label)}</span>
                <span className="muyuy-stat-source">{t(stat.source)}</span>
              </dd>
            </div>
          ))}
        </dl>

        <p className="muyuy-small muyuy-stat-note">{t(IMPACT_NOTE)}</p>

        <ul className="muyuy-pillars">
          {PILLARS.map(([title, description]) => (
            <li key={title}>
              <h3>{t(title)}</h3>
              <p>{t(description)}</p>
            </li>
          ))}
        </ul>
      </div>
      <style>{css}</style>
    </div>
  );
}

const css = `
  .muyuy-impact { width: 100%; }
  .muyuy-impact-head { max-width: 760px; }
  .muyuy-impact-lead { max-width: 68ch; color: #c3c5bf; font-size: clamp(14px, 1.5vw, 16px); line-height: 1.7; margin-top: 6px; }
  .muyuy-stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 1px; margin: 34px 0 0; padding: 0; background: #ffffff14; border: 1px solid #ffffff14; border-radius: 12px; overflow: hidden; }
  .muyuy-stats > div { display: flex; flex-direction: column; gap: 6px; padding: 20px 18px; background: #0b0f0cd9; }
  .muyuy-stat-value { margin: 0; font: 400 clamp(30px, 3.6vw, 46px)/1 "Instrument Serif", Georgia, serif; letter-spacing: -.04em; color: #dcecc0; }
  .muyuy-stats dd { margin: 0; display: flex; flex-direction: column; gap: 7px; }
  .muyuy-stat-label { font-size: 12px; line-height: 1.4; color: #d6dbcf; }
  .muyuy-stat-source { font: 10px/1.5 var(--font-mono, monospace); color: #868d80; }
  .muyuy-stat-note { margin-top: 14px !important; }
  .muyuy-pillars { list-style: none; padding: 0; margin: 26px 0 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
  .muyuy-pillars li { padding: 18px 20px; border: 1px solid #ffffff17; border-radius: 12px; background: #0b0f0c99; }
  .muyuy-pillars h3 { font-size: 13px; color: #dcecc0; }
  .muyuy-pillars p { margin-top: 7px !important; font-size: 12px !important; line-height: 1.6; color: #adb4a7 !important; }
  @media (max-width: 900px) { .muyuy-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  @media (max-width: 760px) { .muyuy-pillars { grid-template-columns: minmax(0, 1fr); } .muyuy-stats { grid-template-columns: minmax(0, 1fr); } }
`;
