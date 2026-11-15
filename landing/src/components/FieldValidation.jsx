import React from 'react';
import { Camera, Check, Clock, Quote } from 'lucide-react';
import { pick } from '../i18n/localize';
import {
  VALIDATION_QUESTIONS,
  FIELD_MEDIA,
  TESTIMONIALS,
} from '../data/fieldValidation';

const base = import.meta.env.BASE_URL;
const asset = (src) => (src.startsWith('/') ? base + src.slice(1) : src);

/**
 * Prueba de campo. Se renderiza distinto según lo que haya en
 * src/data/fieldValidation.ts:
 *   · sin medios  → marco punteado "pendiente" (se ve intencional, no roto).
 *   · sin citas   → tarjeta con el formato final y el aviso de consentimiento.
 *   · con medios  → galería real + cita real.
 * Mañana solo se rellenan los datos; el diseño no se toca.
 *
 * @param {{
 *   t: (key: string) => string,
 *   glass: string,
 *   locale: import('../i18n/copy').Locale,
 *   videoUrl?: string,
 * }} props
 */
export default function FieldValidation({ t, glass, locale, videoUrl }) {
  const media = FIELD_MEDIA.filter((item) => item.src);
  const testimonials = TESTIMONIALS.filter((item) => item.consent);

  return (
    <div className="muyuy-wide">
      <div className={glass + ' muyuy-field'}>
        <header className="muyuy-field-head">
          <p className="muyuy-eyebrow">{t('Field test · Huánuco')}</p>
          <h2 id="field-title" className="muyuy-field-title tracking-tighter">
            <span>{t('Grounded in')}</span> <em>{t('local experience.')}</em>
          </h2>
          <p className="muyuy-field-intro">
            {t(
              'The planned Peru pilot will check whether farmers can open the calendar offline, understand the uncertainty, and use the rotation comparison to discuss what to plant next.'
            )}
          </p>
        </header>

        <div className="muyuy-field-grid">
          <section className="muyuy-field-plan" aria-labelledby="validation-plan-title">
            <h3 id="validation-plan-title" className="muyuy-field-subtitle">
              {t('Validation plan')}
            </h3>
            <ol className="muyuy-questions">
              {VALIDATION_QUESTIONS.map((item) => {
                const done = item.status === 'done';
                return (
                  <li key={item.id} data-status={item.status}>
                    <span className="muyuy-question-icon" aria-hidden="true">
                      {done ? <Check size={13} /> : <Clock size={13} />}
                    </span>
                    <p>{t(item.question)}</p>
                    <span className="muyuy-question-status">{done ? item.date ?? t('Done') : t('Planned')}</span>
                  </li>
                );
              })}
            </ol>
          </section>

          <section className="muyuy-field-media" aria-labelledby="field-media-title">
            <h3 id="field-media-title" className="muyuy-field-subtitle">
              {media.length > 0 ? t('Field photos · real tests') : t('Field photo and video slot')}
            </h3>
            {videoUrl ? (
              <div className="muyuy-field-embed">
                <iframe
                  src={videoUrl}
                  title={t('Huánuco field video')}
                  loading="lazy"
                  allow="fullscreen; picture-in-picture"
                  allowFullScreen
                  referrerPolicy="strict-origin-when-cross-origin"
                />
                <p className="muyuy-small">{t('Example video made from app screenshots')}</p>
              </div>
            ) : media.length > 0 ? (
              <>
                <ul className="muyuy-media-grid">
                  {media.map((item) => (
                    <li key={item.id}>
                      <figure>
                        {item.kind === 'video' ? (
                          <video src={asset(item.src)} controls playsInline preload="metadata" aria-label={item.alt} />
                        ) : (
                          <a href={asset(item.src)} target="_blank" rel="noopener noreferrer" title={t('Open photo')}>
                            <img src={asset(item.src)} alt={item.alt} width="720" height="1280" loading="lazy" decoding="async" />
                          </a>
                        )}
                        {item.credit && <figcaption>{item.credit}</figcaption>}
                      </figure>
                    </li>
                  ))}
                </ul>
                <p className="muyuy-small muyuy-media-note">
                  {t('Leaves and soil photographed in the field to test AgroVision and SoilVision with real images, not stock photos.')}
                </p>
              </>
            ) : (
              <div className="muyuy-media-empty" role="note">
                <Camera size={22} aria-hidden="true" />
                <p>
                  {t(
                    'Pending the field visit. Drop the files in public/field-photos/ and list them in src/data/fieldValidation.ts.'
                  )}
                </p>
              </div>
            )}

            <h3 className="muyuy-field-subtitle muyuy-testimonial-title">{t('Testimonial')}</h3>
            {testimonials.length > 0 ? (
              <ul className="muyuy-testimonials">
                {testimonials.map((item, index) => (
                  <li key={index}>
                    <blockquote>
                      <p>“{pick(item.quote, locale)}”</p>
                      <cite>
                        {item.author} · {pick(item.role, locale)}
                      </cite>
                    </blockquote>
                  </li>
                ))}
              </ul>
            ) : (
              <div className="muyuy-testimonial-empty">
                <Quote size={18} aria-hidden="true" />
                <p>{t("Quotes are added after the interviews, with each participant's written consent.")}</p>
              </div>
            )}
          </section>
        </div>
      </div>
      <style>{css}</style>
    </div>
  );
}

const css = `
  .muyuy-field { width: 100%; }
  .muyuy-field-head { max-width: 720px; }
  .muyuy-field-intro { color: #c3c5bf; max-width: 66ch; }
  .muyuy-field-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: clamp(18px, 3vw, 40px); margin-top: 32px; }
  .muyuy-field-subtitle { font-size: 11px !important; font-weight: 600 !important; letter-spacing: .13em; text-transform: uppercase; color: #bfcdab !important; }
  .muyuy-questions { list-style: none; padding: 0; margin: 16px 0 0; display: grid; gap: 8px; }
  .muyuy-questions li { display: grid; grid-template-columns: 26px minmax(0, 1fr) auto; align-items: center; gap: 11px; padding: 13px 15px; border: 1px solid #ffffff1a; border-radius: 10px; background: #0b0f0ca6; }
  .muyuy-questions p { font-size: 12.5px !important; line-height: 1.5; color: #cdd2c6 !important; }
  .muyuy-question-icon { display: grid; place-items: center; width: 26px; height: 26px; border-radius: 50%; border: 1px solid #ffffff26; color: #9aa392; }
  .muyuy-questions li[data-status=planned] .muyuy-question-icon { border-style: dashed; }
  .muyuy-questions li[data-status=done] .muyuy-question-icon { border-color: #9ed48a66; color: #9ed48a; background: #9ed48a1a; }
  .muyuy-question-status { font: 600 9px/1.6 var(--font-mono, monospace); letter-spacing: .09em; text-transform: uppercase; padding: 2px 6px; border: 1px dashed #ffffff33; border-radius: 4px; color: #9aa392; white-space: nowrap; }
  .muyuy-questions li[data-status=done] .muyuy-question-status { border-style: solid; border-color: #9ed48a66; color: #9ed48a; }
  .muyuy-field-embed { margin-top: 16px; }
  .muyuy-field-embed iframe { display: block; width: 100%; aspect-ratio: 16/9; border: 1px solid #bcddbf45; border-radius: 11px; background: #091611; }
  .muyuy-field-embed p { margin-top: 8px; }
  .muyuy-media-empty, .muyuy-testimonial-empty { display: flex; align-items: center; gap: 12px; margin-top: 16px; padding: 20px; border: 1px dashed #ffffff2e; border-radius: 10px; background: #0b0f0c66; color: #9aa392; }
  .muyuy-media-empty p, .muyuy-testimonial-empty p { font-size: 11.5px !important; line-height: 1.6; color: #9aa392 !important; }
  .muyuy-media-empty svg, .muyuy-testimonial-empty svg { flex: none; }
  .muyuy-testimonial-title { margin-top: 26px; }
  .muyuy-media-grid { list-style: none; padding: 0; margin: 16px 0 0; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
  .muyuy-media-grid figure { margin: 0; height: 100%; }
  .muyuy-media-grid a { display: block; height: 100%; overflow: hidden; border-radius: 10px; border: 1px solid #bcddbf45; background: #0b0f0c; cursor: zoom-in; }
  .muyuy-media-grid :is(img, video) { display: block; width: 100%; height: 100%; aspect-ratio: 3/4; object-fit: cover; border-radius: 10px; }
  .muyuy-media-grid a img { border-radius: 0; filter: saturate(1.05) contrast(1.03); transition: transform .5s cubic-bezier(.32,.72,0,1); }
  .muyuy-media-grid a:hover img, .muyuy-media-grid a:focus-visible img { transform: scale(1.04); }
  .muyuy-media-grid a:focus-visible { outline: 2px solid #d9facb; outline-offset: 2px; }
  .muyuy-media-note { margin-top: 10px !important; }
  @media (prefers-reduced-motion: reduce) { .muyuy-media-grid img { transition: none; } }
  .muyuy-media-grid figcaption { margin-top: 6px; font-size: 10.5px; color: #868d80; }
  .muyuy-testimonials { list-style: none; padding: 0; margin: 16px 0 0; display: grid; gap: 10px; }
  .muyuy-testimonials blockquote { margin: 0; padding: 18px 20px; border-left: 2px solid #cadca6; background: #0b0f0ca6; border-radius: 0 10px 10px 0; }
  .muyuy-testimonials p { font-size: 13.5px !important; line-height: 1.6; color: #d6dbcf !important; }
  .muyuy-testimonials cite { display: block; margin-top: 10px; font-size: 11px; font-style: normal; color: #9aa392; }
  @media (max-width: 900px) { .muyuy-field-grid { grid-template-columns: minmax(0, 1fr); } }
`;
