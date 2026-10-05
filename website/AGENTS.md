# Rowivo website

- This directory is the static DE/EN marketing website, not the native app.
- Domain: `rowivo.kromerlorenz.at`. No store or TestFlight links until a confirmed
  store link is supplied. Do not advertise an available Android app.
- Keep both languages and legal pages aligned. Use actual company data from
  `src/data/business.ts`; do not substitute the private Alpengarten imprint.
- No analytics, cookies, localStorage, remote fonts or third-party embeds in
  the approved initial scope. Keep the site functional without JavaScript.
- Read README.md for pending provider facts before claiming legal publication
  readiness. Never invent TypeSafe retention, regions or contractual safeguards.
- Validate with `npm run check`, `npm run build`, and appropriate browser checks.
- Before deployment/domain/infrastructure work, read
  `/Users/lorenz/development/kromerlorenz-infrastructure/AUFNAHME.md` and follow
  its registration procedure. Infrastructure changes must be announced first.
  `.github/workflows/website.yml` validates, builds and scans the linux/amd64
  image, pushes `ghcr.io/lorenzkromer/rowivo-website` (SHA and latest), then
  dispatches `rowivo-image-pushed` to the infrastructure repository.
  The platform owns the production stack, deployment and monitoring.
