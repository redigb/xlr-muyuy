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

export const FIELD_MEDIA: FieldMedia[] = [];

export const TESTIMONIALS: Testimonial[] = [];
