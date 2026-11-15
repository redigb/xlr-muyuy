import React from 'react';
import { MapPin } from 'lucide-react';
import { pick } from '../i18n/localize';

/** íconos de marca inline: lucide-react v1 ya no los exporta. */
const BRAND_PATHS = {
  github:
    'M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12',
  linkedin:
    'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 1 1 0-4.125 2.062 2.062 0 0 1 0 4.125zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z',
};

/** @param {{ name: 'github' | 'linkedin' }} props */
function BrandIcon({ name }) {
  return (
    <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true" focusable="false">
      <path d={BRAND_PATHS[name]} />
    </svg>
  );
}

/** @typedef {import('../data/team').TeamMember} TeamMember */

const base = import.meta.env.BASE_URL;

function initials(name) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0] ?? '')
    .join('')
    .toUpperCase();
}

/** @param {{ member: TeamMember }} props */
function Avatar({ member }) {
  if (member.photo) {
    const src = member.photo.startsWith('/') ? base + member.photo.slice(1) : member.photo;
    return (
      <img className="muyuy-member-avatar" src={src} alt={member.name} width="72" height="72" loading="lazy" decoding="async" />
    );
  }
  return (
    <span className="muyuy-member-avatar muyuy-member-initials" aria-hidden="true">
      {initials(member.name)}
    </span>
  );
}

/**
 * Tarjetas del equipo. Los datos viven en src/data/team.ts.
 * Cada tarjeta aguanta datos faltantes: sin foto dibuja iniciales, sin enlaces
 * no muestra la fila de iconos, y `placeholder: true` añade un badge discreto
 * para que nunca se publique un nombre de ejemplo sin darse cuenta.
 *
 * @param {{
 *   members: TeamMember[],
 *   locale: import('../i18n/copy').Locale,
 *   t: (key: string) => string,
 *   glass: string,
 * }} props
 */
export default function TeamGrid({ members, locale, t, glass }) {
  return (
    <ul className="muyuy-team-grid">
      {members.map((member) => {
        const links = [
          member.links.github && { href: member.links.github, label: t('Open GitHub profile'), icon: 'github' },
          member.links.linkedin && { href: member.links.linkedin, label: t('Open LinkedIn profile'), icon: 'linkedin' },
        ].filter(Boolean);

        return (
          <li key={member.id} className={glass + ' muyuy-member'}>
            <div className="muyuy-member-head">
              <Avatar member={member} />
              <div className="muyuy-member-id">
                <h3>{member.name}</h3>
                {(member.location || member.lead) && (
                  <p className="muyuy-member-location">
                    {member.location && <><MapPin size={12} aria-hidden="true" />{member.location}</>}
                    {member.lead && (
                      <span className="muyuy-member-badge muyuy-member-lead" data-lead={member.lead}>
                        {t(member.lead === 'lead' ? 'Team lead' : 'Co-lead')}
                      </span>
                    )}
                  </p>
                )}
              </div>
              {member.placeholder && <span className="muyuy-member-badge">PENDING</span>}
            </div>

            <p className="muyuy-member-role">{pick(member.role, locale)}</p>
            {member.university && (
              <p className="muyuy-member-university">
                {member.university.logo && (
                  <img src={member.university.logo.startsWith('/') ? base + member.university.logo.slice(1) : member.university.logo}
                    alt="" width="28" height="28" loading="lazy" decoding="async" />
                )}
                <span>{member.university.name}</span>
              </p>
            )}
            <p className="muyuy-member-bio">{pick(member.bio, locale)}</p>

            {member.stack.length > 0 && (
              <ul className="muyuy-member-stack" aria-label={t('Stack')}>
                {member.stack.map((tech) => (
                  <li key={tech}>{tech}</li>
                ))}
              </ul>
            )}

            {links.length > 0 && (
              <div className="muyuy-member-links">
                {links.map(({ href, label, icon }) => (
                  <a key={label} href={href} target="_blank" rel="noopener noreferrer" title={label}>
                    <BrandIcon name={icon} />
                    <span className="muyuy-visually-hidden">{label}</span>
                  </a>
                ))}
              </div>
            )}
          </li>
        );
      })}
      <style>{css}</style>
    </ul>
  );
}

const css = `
  .muyuy-visually-hidden { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; border: 0; }
  .muyuy-team-grid { list-style: none; padding: 0; margin: 26px 0 28px; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 10px; }
  .muyuy-member { display: flex; flex-direction: column; gap: 8px; padding: 16px !important; min-width: 0; }
  .muyuy-member-head { display: flex; align-items: center; gap: 9px; min-height: 50px; }
  .muyuy-member-avatar { flex: none; width: 38px; height: 38px; border-radius: 50%; object-fit: cover; border: 1px solid #cadca640; }
  .muyuy-member-initials { display: grid; place-items: center; font: 600 12px/1 var(--font-mono, monospace); letter-spacing: .04em; color: #182012; background: #cadca6; }
  .muyuy-member-id { min-width: 0; flex: 1; }
  .muyuy-member-id h3 { font-size: 13px; line-height: 1.2; overflow-wrap: anywhere; }
  .muyuy-member-location { display: flex; align-items: center; gap: 3px; margin-top: 2px !important; font-size: 10px !important; color: #9fa699 !important; }
  .muyuy-member-badge { flex: none; align-self: flex-start; padding: 1px 5px; border: 1px solid #f0c96a55; border-radius: 4px; color: #f0c96a; font: 600 8px/1.6 var(--font-mono, monospace); letter-spacing: .08em; }
  .muyuy-member-lead { margin-left: 6px; align-self: center; border-color: #cadca666; color: #d7e8b4; background: #cadca614; text-transform: uppercase; }
  .muyuy-member-lead[data-lead=lead] { color: #182012; background: #cadca6; border-color: #cadca6; }
  .muyuy-member-university { display: flex; align-items: center; gap: 7px; margin: 0 !important; font-size: 10.5px !important; line-height: 1.3; color: #c3cab9 !important; }
  .muyuy-member-university img { flex: none; width: 28px; height: 28px; padding: 2px; border-radius: 6px; background: #fff; object-fit: contain; }
  .muyuy-member-role { font-size: 11px !important; font-weight: 600 !important; color: #d3e0ba !important; line-height: 1.35; }
  .muyuy-member-bio { font-size: 11.5px !important; line-height: 1.5; color: #b0b7aa !important; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
  .muyuy-member-stack { display: flex; flex-wrap: wrap; gap: 4px; list-style: none; padding: 0; margin: auto 0 0; }
  .muyuy-member-stack li { padding: 2px 5px; border: 1px solid #ffffff1f; border-radius: 4px; color: #a9b0a3; font: 9px/1.5 var(--font-mono, monospace); }
  .muyuy-member-links { display: flex; gap: 6px; padding-top: 2px; }
  .muyuy-member-links a { display: grid; place-items: center; width: 28px; height: 28px; border: 1px solid #ffffff26; border-radius: 7px; color: #cdd6c2; transition: background .18s, border-color .18s; }
  .muyuy-member-links a:hover { background: #cadca61f; border-color: #cadca673; }
  @media (max-width: 1180px) { .muyuy-team-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
  @media (max-width: 760px) { .muyuy-team-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  @media (max-width: 460px) { .muyuy-team-grid { grid-template-columns: minmax(0, 1fr); } }
`;
