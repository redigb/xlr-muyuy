/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  POR QUÉ IMPORTA / WHY IT MATTERS
 * ─────────────────────────────────────────────────────────────────────────────
 *  ⚠️  Solo cambia los `value` si el dato real es distinto. Cada cifra lleva su
 *  fuente visible: un jurado técnico prefiere un número con procedencia que un
 *  número grande sin respaldo. Si un dato todavía no está medido, NO lo
 *  inventes: borra esa tarjeta y deja las demás.
 *
 *  Los `label` y `source` son claves del diccionario (src/i18n/copy.ts), por eso
 *  no se traducen acá: así el mismo texto existe en es/ qu/ ay.
 */

import paquetes from './paquetes.json';

export type ImpactStat = {
  /** Cifra corta y legible: "40", "≈2 KB", "100%". */
  value: string;
  /** Clave de src/i18n/copy.ts. */
  label: string;
  /** Clave de src/i18n/copy.ts. Siempre con procedencia. */
  source: string;
};

export const IMPACT_STATS: ImpactStat[] = [
  {
    value: '40',
    label: 'Years of NASA POWER records',
    source: 'Source: NASA POWER 1985–2024',
  },
  {
    value: String(paquetes.catalog.zonas),
    label: 'Pilot zones in Huánuco',
    source: 'Source: project data package',
  },
  {
    value: String(paquetes.catalog.cultivos),
    label: 'Crops in the global catalog',
    source: 'Source: NASA POWER + FAO ECOCROP',
  },
  {
    // Medido: núcleo del paquete (sin imagen satelital) 1.9–2.5 KB gzip.
    value: '≈2.5 KB',
    label: 'Regional data core, gzipped',
    source: 'Source: project data package',
  },
];

/** Clave del diccionario con la nota de honestidad bajo los números. */
export const IMPACT_NOTE = 'Prototype design targets. Field-validated results are still pending.';
