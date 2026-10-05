export const site = 'https://rowivo.kromerlorenz.at';
export const languages = ['de', 'en'] as const;
export type Language = (typeof languages)[number];
export type Page = 'home' | 'imprint' | 'privacy';
export const routes: Record<Page, Record<Language, string>> = {
  home: { de: '/de/', en: '/en/' },
  imprint: { de: '/de/impressum/', en: '/en/imprint/' },
  privacy: { de: '/de/datenschutz/', en: '/en/privacy/' },
};
