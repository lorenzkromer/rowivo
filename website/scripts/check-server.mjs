import assert from 'node:assert/strict';
const base = process.env.ROWIVO_PREVIEW_URL ?? 'http://127.0.0.1:4322';
for (const [path, status, location] of [
  ['/', 302, '/de/'],
  ['/de/', 200],
  ['/en/', 200],
  ['/impressum', 301, '/de/impressum/'],
  ['/datenschutz/', 301, '/de/datenschutz/'],
  ['/privacy', 301, '/en/privacy/'],
  ['/missing-page', 404],
]) {
  const response = await fetch(base + path, { redirect: 'manual' });
  assert.equal(response.status, status, path);
  assert(
    response.headers
      .get('content-security-policy')
      ?.includes("frame-ancestors 'none'"),
  );
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(response.headers.get('x-frame-options'), 'DENY');
  if (location)
    assert.equal(
      new URL(response.headers.get('location'), base).pathname,
      location,
    );
  if (status === 404)
    assert((await response.text()).includes('Hier geht’s zurück.'));
}
console.log(
  'Passed nginx checks: page delivery, redirects, real custom 404 and security headers.',
);
