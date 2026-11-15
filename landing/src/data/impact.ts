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
    value: '3',
    label: 'Pilot zones in Huánuco',
    source: 'Source: project data package',
  },
  {
    value: '30',
    label: 'Crops scored by the engine',
    source: 'Source: NASA POWER + FAO ECOCROP',
  },
  {
    value: '≈3 KB',
    label: 'Regional package, gzipped',
    source: 'Source: project data package',
  },
];

/** Clave del diccionario con la nota de honestidad bajo los números. */
export const IMPACT_NOTE = 'Prototype design targets. Field-validated results are still pending.';
