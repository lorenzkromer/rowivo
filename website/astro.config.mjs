import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://rowivo.kromerlorenz.at',
  output: 'static',
  trailingSlash: 'always',
  build: { inlineStylesheets: 'never' },
});
