/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  PRUEBA DE CAMPO / FIELD VALIDATION  ·  Huánuco
 * ─────────────────────────────────────────────────────────────────────────────
 *  Mañana solo se rellenan estas tres listas; el diseño ya está hecho.
 *
 *  1. VALIDATION_QUESTIONS — las preguntas que se llevan a la chacra.
 *     status: 'planned' → chip gris · 'done' → chip verde con la fecha.
 *
 *  2. FIELD_MEDIA — fotos o videos reales de la visita.
 *     Copia los archivos a `public/field-photos/` y añade una entrada:
 *       { id: 'visita-01', kind: 'photo', src: '/field-photos/visita-01.webp',
 *         alt: 'Descripción real de la foto', credit: 'Foto: Nombre' }
 *     Si la lista está vacía, la sección muestra un marco de "pendiente"
 *     que se ve intencional, no roto.
 *
 *  3. TESTIMONIALS — citas con consentimiento escrito. Sin `consent: true`
 *     no se renderiza nada: nunca publicamos una cita sin permiso.
 */

import type { LocalizedText } from './team';

export type QuestionStatus = 'planned' | 'done';

export type ValidationQuestion = {
  id: string;
  /** Clave del diccionario (src/i18n/copy.ts). */
  question: string;
  status: QuestionStatus;
  /** Fecha ISO visible cuando status === 'done'. */
  date?: string;
};

export type FieldMedia = {
  id: string;
  kind: 'photo' | 'video';
  src: string;
  /** Texto alternativo real, obligatorio por accesibilidad. */
  alt: string;
  credit?: string;
};

export type Testimonial = {
  quote: LocalizedText;
  author: string;
  role: LocalizedText;
  /** Sin consentimiento explícito la cita NO se muestra. */
  consent: boolean;
};

export const VALIDATION_QUESTIONS: ValidationQuestion[] = [
  {
    id: 'airplane-mode',
    question: 'Can the calendar open with the phone in airplane mode?',
    status: 'planned',
  },
  {
    id: 'confidence',
    question: 'Do farmers read the confidence level as useful information?',
    status: 'planned',
  },
  {
    id: 'next-crop',
    question: 'Would they use the comparison to decide the next crop with a neighbour?',
    status: 'planned',
  },
];

/** Fotos reales de la prueba de campo (15/11/2026): hojas y suelo para probar AgroVision y SoilVision. */
export const FIELD_MEDIA: FieldMedia[] = [
  { id: 'campo-01', kind: 'photo', src: '/field-photos/campo-01-hoja-manchas-haz.webp', alt: 'Avocado leaf with dark and yellow spots on the upper side, held by hand' },
  { id: 'campo-02', kind: 'photo', src: '/field-photos/campo-02-arbol-palta.webp', alt: 'Young avocado tree in the plot where the photos were taken' },
  { id: 'campo-03', kind: 'photo', src: '/field-photos/campo-03-hoja-enves.webp', alt: 'Underside of an avocado leaf, photographed in natural light' },
  { id: 'campo-04', kind: 'photo', src: '/field-photos/campo-04-hoja-manchas-amarillas.webp', alt: 'Avocado leaf with yellow mottling, still on the branch' },
  { id: 'campo-05', kind: 'photo', src: '/field-photos/campo-05-brote-dano.webp', alt: 'Avocado shoot with dry, damaged leaves' },
  { id: 'campo-06', kind: 'photo', src: '/field-photos/campo-06-hoja-enves-2.webp', alt: 'Underside of a second avocado leaf, held by hand' },
  { id: 'campo-07', kind: 'photo', src: '/field-photos/campo-07-muestra-suelo.webp', alt: 'Patch of bare soil cleared for a soil photo' },
  { id: 'campo-08', kind: 'photo', src: '/field-photos/campo-08-hoja-lesiones.webp', alt: 'Avocado leaf with pale lesions next to the irrigation hose' },
];

export const TESTIMONIALS: Testimonial[] = [];
