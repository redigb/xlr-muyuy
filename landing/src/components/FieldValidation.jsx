import React from 'react';
import { Camera } from 'lucide-react';
import { pick } from '../i18n/localize';
import { FIELD_MEDIA, TESTIMONIALS } from '../data/fieldValidation';

const base = import.meta.env.BASE_URL;
const asset = (src) => (src.startsWith('/') ? base + src.slice(1) : src);

/**
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
    <div className={glass + ' muyuy-field'}>
      <header className="muyuy-field-head">
        <p className="muyuy-eyebrow">{t('Field test · Huánuco')}</p>
        <h2 id="field-title" className="muyuy-field-title tracking-tighter">
          <span>{t('Grounded in')}</span> <em>{t('local experience.')}</em>
        </h2>
        <p className="muyuy-field-intro">
          {t('Avocado leaves and soil photographed in Huánuco during field tests of AgroVision and SoilVision.')}
        </p>
      </header>

      <section className="muyuy-field-media" aria-labelledby="field-media-title">
        <h3 id="field-media-title" className="muyuy-field-subtitle">
          {media.length > 0 ? t('Field photos · real tests') : t('Field photo and video slot')}
        </h3>
        {media.length > 0 && (
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
        )}
        {videoUrl && (
          <div className="muyuy-field-embed">
            <iframe
              src={videoUrl}
              title={t('Huánuco field video')}
              loading="lazy"
              allow="fullscreen; picture-in-picture"
              allowFullScreen
              referrerPolicy="strict-origin-when-cross-origin"
            />
          </div>
        )}
        {media.length === 0 && !videoUrl && (
          <div className="muyuy-media-empty" role="note">
            <Camera size={22} aria-hidden="true" />
            <p>{t('Field photos will be added here.')}</p>
          </div>
        )}
      </section>

      {testimonials.length > 0 && (
        <section className="muyuy-field-testimonial" aria-labelledby="field-testimonial-title">
          <h3 id="field-testimonial-title" className="muyuy-field-subtitle">{t('Testimonial')}</h3>
          <ul className="muyuy-testimonials">
            {testimonials.map((item, index) => (
              <li key={index}>
                <blockquote>
                  <p>“{pick(item.quote, locale)}”</p>
                  <cite>{item.author} · {pick(item.role, locale)}</cite>
                </blockquote>
              </li>
            ))}
          </ul>
        </section>
      )}
      <style>{css}</style>
    </div>
  );
}

const css = `
  .muyuy-landing #field-test { min-height: auto; padding-block: clamp(42px, 7vw, 105px); }
  .muyuy-field { width: 100%; }
  .muyuy-field-head { max-width: 840px; }
  .muyuy-field-intro { color: #c3c5bf; max-width: 62ch; }
  .muyuy-field-media, .muyuy-field-testimonial { margin-top: clamp(22px, 4vw, 42px); }
  .muyuy-field-subtitle {
    font-size: 11px !important;
    font-weight: 600 !important;
    letter-spacing: .13em;
    text-transform: uppercase;
    color: #bfcdab !important;
  }
  .muyuy-media-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    align-items: start;
    gap: clamp(6px, 1vw, 12px);
    list-style: none;
    padding: 0;
    margin: 14px 0 0;
  }
  .muyuy-media-grid figure { margin: 0; }
  .muyuy-media-grid :is(a, video) {
    display: block;
    width: 100%;
    border-radius: 8px;
    border: 1px solid #ffffff22;
    background: #0b0f0c;
  }
  .muyuy-media-grid a { padding: 3px; cursor: zoom-in; }
  .muyuy-media-grid :is(img, video) { display: block; width: 100%; height: auto; }
  .muyuy-media-grid a:hover { border-color: #b2e7b7; }
  .muyuy-media-grid a:focus-visible { outline: 2px solid #d9facb; outline-offset: 2px; }
  .muyuy-media-grid figcaption { margin-top: 5px; font-size: 12px; color: #c3c5bf; }
  .muyuy-field-embed { margin-top: 16px; }
  .muyuy-field-embed iframe {
    display: block;
    width: 100%;
    aspect-ratio: 16 / 9;
    border: 1px solid #ffffff22;
    border-radius: 12px;
    background: #09090b;
  }
  .muyuy-media-empty {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 16px;
    padding: 20px;
    border: 1px dashed #ffffff2e;
    border-radius: 10px;
  }
  .muyuy-testimonials { list-style: none; padding: 0; margin: 16px 0 0; display: grid; gap: 10px; }
  .muyuy-testimonials blockquote { margin: 0; padding: 18px 20px; border-left: 2px solid #cadca6; background: #0b0f0ca6; border-radius: 0 10px 10px 0; }
  .muyuy-testimonials p { font-size: 13.5px !important; line-height: 1.6; color: #d6dbcf !important; }
  .muyuy-testimonials cite { display: block; margin-top: 10px; font-size: 11px; font-style: normal; color: #9aa392; }
  @media (min-width: 761px) {
    .muyuy-media-grid { grid-template-columns: repeat(8, minmax(0, 1fr)); }
  }
`;
