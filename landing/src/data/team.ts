import type { Locale } from '../i18n/copy';

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  EQUIPO / TEAM
 * ─────────────────────────────────────────────────────────────────────────────
 *  ⚠️  TODO(equipo): reemplaza los 5 registros de abajo con los datos reales.
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
  location: string;
  role: LocalizedText;
  bio: LocalizedText;
  stack: string[];
  photo?: string;
  links: { github?: string; linkedin?: string };
  /** true = datos de ejemplo; la tarjeta muestra un badge discreto. */
  placeholder?: boolean;
};

export const TEAM: TeamMember[] = [
  {
    id: 'earth-data',
    name: 'Nombre Apellido',
    location: 'Huánuco, Perú',
    role: {
      en: 'Earth data & agronomy',
      es: 'Datos de la Tierra y agronomía',
    },
    bio: {
      en: 'Turns NASA POWER daily records (1985–2024) into monthly frost and water-balance indicators, and pairs them with an Andean crop table following FAO ECOCROP.',
      es: 'Convierte los registros diarios de NASA POWER (1985–2024) en indicadores mensuales de helada y balance hídrico, y los cruza con una tabla de cultivos andinos según FAO ECOCROP.',
    },
    stack: ['NASA POWER', 'Python', 'FAO ECOCROP', 'Agronomy'],
    links: { github: 'https://github.com/', linkedin: 'https://www.linkedin.com/' },
    placeholder: true,
  },
  {
    id: 'backend',
    name: 'Nombre Apellido',
    location: 'Lima, Perú',
    role: {
      en: 'Backend & rotation engine',
      es: 'Backend y motor de rotaciones',
    },
    bio: {
      en: 'Builds the deterministic rotation engine in Quarkus: candidate scoring, confidence levels and the SHA-256 sealed regional package the app downloads once.',
      es: 'Construye el motor determinista de rotaciones en Quarkus: puntuación de candidatas, niveles de confianza y el paquete regional sellado con SHA-256 que la app descarga una vez.',
    },
    stack: ['Java 25', 'Quarkus', 'PostgreSQL', 'Flyway'],
    links: { github: 'https://github.com/', linkedin: 'https://www.linkedin.com/' },
    placeholder: true,
  },
  {
    id: 'mobile',
    name: 'Nombre Apellido',
    location: 'Huancayo, Perú',
    role: {
      en: 'Mobile app & offline sync',
      es: 'App móvil y sincronización sin conexión',
    },
    bio: {
      en: 'Owns the Flutter app: offline package storage and hash verification, phone-to-phone sharing, community sync and the on-device soil classifier.',
      es: 'Responsable de la app Flutter: almacenamiento offline y verificación del hash, compartición teléfono a teléfono, sincronización comunitaria y el clasificador de suelo en el dispositivo.',
    },
    stack: ['Flutter', 'Dart', 'TensorFlow Lite', 'SQLite'],
    links: { github: 'https://github.com/', linkedin: 'https://www.linkedin.com/' },
    placeholder: true,
  },
  {
    id: 'landing',
    name: 'Nombre Apellido',
    location: 'Arequipa, Perú',
    role: {
      en: 'Landing & 3D visualization',
      es: 'Landing y visualización 3D',
    },
    bio: {
      en: 'Builds this site: Astro + React islands, the procedural Andean terrain in Three.js and the scroll narrative that explains the climate layers.',
      es: 'Construye este sitio: Astro con islas de React, el terreno andino procedural en Three.js y la narrativa de scroll que explica las capas climáticas.',
    },
    stack: ['Astro', 'React', 'Three.js', 'Tailwind'],
    links: { github: 'https://github.com/', linkedin: 'https://www.linkedin.com/' },
    placeholder: true,
  },
  {
    id: 'infra',
    name: 'Nombre Apellido',
    location: 'Lima, Perú',
    role: {
      en: 'Infrastructure & deployment',
      es: 'Infraestructura y despliegue',
    },
    bio: {
      en: 'Runs the pipeline from pull request to production: GitHub Actions, container images on GHCR, Docker Compose and Caddy with automatic TLS on Oracle Cloud.',
      es: 'Opera el camino del pull request a producción: GitHub Actions, imágenes de contenedor en GHCR, Docker Compose y Caddy con TLS automático en Oracle Cloud.',
    },
    stack: ['Docker', 'GitHub Actions', 'Caddy', 'Oracle Cloud'],
    links: { github: 'https://github.com/', linkedin: 'https://www.linkedin.com/' },
    placeholder: true,
  },
];
