import { readFile, access } from 'node:fs/promises';
import assert from 'node:assert/strict';
const pages = [
  'de/',
  'en/',
  'de/impressum/',
  'en/imprint/',
  'de/datenschutz/',
  'en/privacy/',
];
const origin = 'https://rowivo.kromerlorenz.at';
for (const route of pages) {
  const html = await readFile(`dist/${route}index.html`, 'utf8');
  assert(
    html.includes(`lang="${route.slice(0, 2)}"`),
    `Wrong language: ${route}`,
  );
  assert(
    html.includes(`rel="canonical" href="${origin}/${route}"`),
    `Wrong canonical: ${route}`,
  );
  assert.equal(
    (html.match(/<h1[ >]/g) ?? []).length,
    1,
    `One h1 required: ${route}`,
  );
  assert(!/<script\b/.test(html), `Unexpected client JS: ${route}`);
  assert(
    !/testflight\.apple|apps\.apple|play\.google|googletagmanager|matomo/i.test(
      html,
    ),
    `Store link or tracker: ${route}`,
  );
  for (const match of html.matchAll(/(?:href|src)="(\/[^"#]*)/g)) {
    const path = match[1].split('#')[0];
    await access(`dist${path}${path.endsWith('/') ? 'index.html' : ''}`);
  }
  for (const language of ['de', 'en', 'x-default'])
    assert(
      html.includes(`hreflang="${language}"`),
      `Missing alternate ${route}`,
    );
}
const map = await readFile('dist/sitemap.xml', 'utf8');
assert.equal((map.match(/<loc>/g) ?? []).length, pages.length);
for (const route of pages)
  assert(map.includes(`<loc>${origin}/${route}</loc>`));
await access('dist/404.html');
console.log(
  'Verified: 6 localized pages, local links/assets, metadata, sitemap; no client scripts, trackers or store links.',
);
