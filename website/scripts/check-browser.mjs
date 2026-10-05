import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';

const base = process.env.ROWIVO_PREVIEW_URL ?? 'http://127.0.0.1:4321';
const browser = await chromium.launch({
  executablePath: process.env.ROWIVO_CHROMIUM_PATH || undefined,
});
await mkdir('artifacts', { recursive: true });
let count = 0;
try {
  for (const width of [320, 390, 768, 1440]) {
    const context = await browser.newContext({
      viewport: { width, height: 900 },
      reducedMotion: 'reduce',
    });
    const page = await context.newPage();
    const failures = [];
    page.on('pageerror', (error) => failures.push(error.message));
    page.on('console', (message) => {
      if (message.type() === 'error') failures.push(message.text());
    });
    page.on('request', (request) => {
      if (!request.url().startsWith(base))
        failures.push(`External request: ${request.url()}`);
    });
    page.on('response', (response) => {
      if (response.status() >= 400)
        failures.push(`${response.status()}: ${response.url()}`);
    });
    for (const route of [
      '/de/',
      '/en/',
      '/de/impressum/',
      '/en/imprint/',
      '/de/datenschutz/',
      '/en/privacy/',
    ]) {
      await page.goto(base + route);
      await page.evaluate(() => document.fonts.ready);
      assert(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
        `Horizontal overflow: ${width} ${route}`,
      );
      assert.equal(await page.locator('h1').count(), 1);
      assert.equal(await page.locator('img:not([alt])').count(), 0);
      assert.equal(
        await page.locator('html').getAttribute('lang'),
        route.slice(1, 3),
      );
      const brokenAnchors = await page.evaluate(() =>
        [...document.querySelectorAll('a[href^="#"]')]
          .filter(
            (a) => !document.getElementById(a.getAttribute('href').slice(1)),
          )
          .map((a) => a.getAttribute('href')),
      );
      assert.deepEqual(brokenAnchors, [], `Broken anchors: ${route}`);
      if (route === '/de/' || route === '/en/') {
        const first = page.locator('details').first();
        await first.locator('summary').click();
        assert(await first.evaluate((element) => element.open));
        await first.locator('summary').press('Enter');
        assert.equal(await first.evaluate((element) => element.open), false);
        await page.locator('.hero .button').click();
        await page.waitForURL('**/#discover');
        await page.evaluate(() => scrollTo(0, 0));
        // Force lazy screenshots to load before capturing the full document.
        await page
          .locator('img')
          .evaluateAll((images) =>
            images.forEach((image) => (image.loading = 'eager')),
          );
        await page.evaluate(() =>
          Promise.all([...document.images].map((image) => image.decode())),
        );
        if (width === 390 || width === 1440)
          await page.screenshot({
            path: `artifacts/home-${route.slice(1, 3)}-${width}.png`,
            fullPage: true,
          });
      }
      if (route === '/de/datenschutz/' && width === 390)
        await page.screenshot({
          path: 'artifacts/privacy-de-390.png',
          fullPage: true,
        });
      const opposite = route.startsWith('/de/') ? 'en' : 'de';
      await page.locator(`.language-switch a[lang="${opposite}"]`).click();
      assert.equal(await page.locator('html').getAttribute('lang'), opposite);
      assert.equal(await context.cookies().then((c) => c.length), 0);
      assert.equal(await page.evaluate(() => localStorage.length), 0);
      count++;
    }
    assert.deepEqual(failures, [], `Browser errors at ${width}px`);
    await context.close();
  }
  console.log(
    `Passed ${count} page/viewport checks: layout, images, metadata language, navigation, keyboard FAQ, no external requests or storage.`,
  );
} finally {
  await browser.close();
}
