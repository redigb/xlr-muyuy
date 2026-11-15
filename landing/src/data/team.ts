import type { Locale } from '../i18n/copy';

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  EQUIPO / TEAM
 * ─────────────────────────────────────────────────────────────────────────────
 *  Datos tomados del README (sección Team), del historial de git y de los
 *  perfiles públicos de GitHub; nombres según el registro del equipo en
 *  NASA Space Apps. Faltan ciudades y LinkedIn: cada integrante los completa aquí.
 *
 *  Para cada integrante:
 *    name      → nombre y apellido reales.
 *    location  → ciudad, país (ej. "Huánuco, Perú").
 *    role      → qué construyó EXACTAMENTE en el hackathon (no "desarrollador").
 *    bio       → 1–2 líneas: stack + aporte concreto al prototipo.
 *    stack     → 3–5 tecnologías que realmente tocó (se muestran como chips).
 *    photo     → opcional, ruta en /public (ej. "/team/ana.jpg"). Si falta,
 *                la tarjeta dibuja las iniciales del nombre. Nunca deja un
 *                hueco roto.
 *    links     → github y/o linkedin completos (https://...). Los que falten
 *                simplemente no se muestran.
 *
 *  Cuando termines de rellenar, pon `placeholder: false` y el badge
 *  "PENDING" desaparece de la tarjeta.
 */

/** Texto con versión inglesa obligatoria y traducciones opcionales. */
export type LocalizedText = Partial<Record<Locale, string>> & { en: string };

export type TeamMember = {
  id: string;
  name: string;
  /** Opcional: si falta, la tarjeta no muestra la línea de ubicación. */
  location?: string;
  role: LocalizedText;
  bio: LocalizedText;
  stack: string[];
  photo?: string;
  links: { github?: string; linkedin?: string };
  /** Rol de liderazgo en el equipo: se muestra como badge en la tarjeta. */
  lead?: 'lead' | 'co-lead';
  /** Universidad del integrante; `logo` es una ruta en /public. */
  university?: { name: string; logo?: string };
  /** true = datos de ejemplo; la tarjeta muestra un badge discreto. */
  placeholder?: boolean;
};

export const TEAM: TeamMember[] = [
  {
    id: 'backend',
    name: 'Renzo Raúl Condezo Rivera',
    location: 'Perú',
    role: {
      en: 'Backend, engine & deployment',
      es: 'Backend, motor y despliegue',
    },
    bio: {
      en: 'Builds the deterministic rotation engine in Quarkus and the SHA-256 sealed regional package, and runs it in production: GitHub Actions, GHCR, Docker Compose and Caddy on Oracle Cloud.',
      es: 'Construye el motor determinista de rotaciones en Quarkus y el paquete regional sellado con SHA-256, y lo opera en producción: GitHub Actions, GHCR, Docker Compose y Caddy en Oracle Cloud.',
    },
    stack: ['Java 25', 'Quarkus', 'Docker'],
    photo: 'https://github.com/redigb.png?size=144',
    lead: 'lead',
    links: { github: 'https://github.com/redigb' },
  },
  {
    id: 'earth-data',
    name: 'Luis Ángel Flores Cruz',
    location: 'Perú',
    role: {
      en: 'NASA API research',
      es: 'Investigación de APIs de la NASA',
    },
    bio: {
      en: 'Mapped the NASA Earth data services behind Muyuy — POWER, SMAP, GIBS, EPIC, AppEEARS and FIRMS — with their endpoints, keys and limits.',
      es: 'Relevó los servicios de datos de la NASA detrás de Muyuy —POWER, SMAP, GIBS, EPIC, AppEEARS y FIRMS— con sus endpoints, claves y límites.',
    },
    stack: ['NASA POWER', 'SMAP', 'GIBS', 'FIRMS'],
    photo: 'https://github.com/LuisFc11.png?size=144',
    links: { github: 'https://github.com/LuisFc11' },
  },
  {
    id: 'mobile',
    name: 'Leo Rosario Lucas Caqui',
    location: 'Lima, Perú',
    role: {
      en: 'Mobile app (Flutter)',
      es: 'App móvil (Flutter)',
    },
    bio: {
      en: 'Builds the offline Flutter app: regional package storage, soil analysis and the on-device plant-disease model.',
      es: 'Construye la app Flutter offline: almacenamiento del paquete regional, análisis de suelo y el modelo de enfermedades de plantas en el dispositivo.',
    },
    stack: ['Flutter', 'Dart', 'TensorFlow Lite'],
    photo: 'https://github.com/LeoLucasC.png?size=144',
    lead: 'co-lead',
    university: {
      name: 'Universidad Privada de Trujillo',
      logo: '/team/universidad-privada-de-trujillo.webp',
    },
    links: { github: 'https://github.com/LeoLucasC' },
  },
  {
    id: 'landing',
    name: 'Jhonn Yhoy Clemente Daza',
    location: 'Perú',
    role: {
      en: 'Landing & 3D terrain',
      es: 'Landing y terreno 3D',
    },
    bio: {
      en: 'Builds this site: Astro + React islands, the procedural Andean terrain in Three.js and the real NASA data shown on the page.',
      es: 'Construye este sitio: Astro con islas de React, el terreno andino procedural en Three.js y los datos reales de la NASA que muestra la página.',
    },
    stack: ['Astro', 'React', 'Three.js', 'Tailwind'],
    photo: 'https://github.com/ClemDYhoy.png?size=144',
    links: { github: 'https://github.com/ClemDYhoy' },
  },
  {
    id: 'field',
    name: 'Xander Villogas Cagna',
    location: 'Perú',
    role: {
      en: 'Field validation & outreach',
      es: 'Validación en campo y difusión',
    },
    bio: {
      en: 'Takes the prototype to farmers in Huánuco: runs the airplane-mode test and gathers feedback on the climate calendar.',
      es: 'Lleva el prototipo a los agricultores de Huánuco: hace la prueba en modo avión y recoge sus comentarios sobre el calendario climático.',
    },
    stack: ['Field testing', 'User research'],
    photo: 'https://github.com/xander-18.png?size=144',
    links: { github: 'https://github.com/xander-18' },
  },
];
