import { routes, site } from '../data/site';
export function GET() {
  const entries = Object.values(routes).flatMap((route) =>
    Object.values(route).map(
      (path) =>
        `<url><loc>${site}${path}</loc><xhtml:link rel="alternate" hreflang="de" href="${site}${route.de}"/><xhtml:link rel="alternate" hreflang="en" href="${site}${route.en}"/><xhtml:link rel="alternate" hreflang="x-default" href="${site}${route.de}"/></url>`,
    ),
  );
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${entries.join('')}</urlset>`,
    { headers: { 'Content-Type': 'application/xml; charset=utf-8' } },
  );
}
