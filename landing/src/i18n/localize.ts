import type { Locale } from './copy';

/** Texto bilingüe: inglés obligatorio, el resto opcional. */
export type Localized = Partial<Record<Locale, string>> & { en: string };

/**
 * Resuelve un texto localizado con caída segura:
 * idioma pedido → español → inglés. Nunca devuelve vacío.
 */
export function pick(text: Localized, locale: Locale): string {
  return text[locale] || text.es || text.en;
}
