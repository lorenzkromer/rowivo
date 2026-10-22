# Rowivo-Webseite

Statische, zweisprachige Produktwebseite für `https://rowivo.kromerlorenz.at`.
Erste Fassung vom 24. September 2026. Kein Download-, App-Store-, Play-Store-
oder TestFlight-Link, bis ein bestätigter Store-Link vorliegt.
Die Startseiten und Verfügbarkeits-FAQ kündigen den Start ab Dezember 2026 an.

## Lokal

Node.js ab 22.12; verwendet und geprüft mit Node 24.2.

```sh
cd website
npm ci
npm run check
npm run build
npm run preview -- --port 4321
```

Deutsch: <http://127.0.0.1:4321/de/> · Englisch: <http://127.0.0.1:4321/en/>.
Astro 7 startet die Vorschau als Hintergrundprozess. Beenden:
`npx astro preview stop`.

## Inhalt und Technik

- Astro, statische HTML-Ausgabe nach `dist/`, keine Client-Skripte.
- Startseiten: `/de/`, `/en/`.
- Impressum: `/de/impressum/`, `/en/imprint/`.
- Datenschutz für Webseite **und App**: `/de/datenschutz/`, `/en/privacy/`.
- Texte: `src/data/copy.ts` und `src/data/privacy.ts`.
- Firmenangaben: `src/data/business.ts`, übernommen aus dem gleichnamigen
  Modul in `/Users/lorenz/development/kromerlorenz.at`. Anschrift **185/1**,
  UID **ATU82749019**, geschäftliche Kontaktadresse; keine Alpengarten-Privatdaten.
- Farben und Zeichen entsprechen `Rowivo/Design/DesignSystem.swift`.
- Die Screenshots stammen aus `../docs/screenshots/` und zeigen Beispieldaten.
  `public/images/sources.txt` ordnet sie den Quelldateien zu. Deutsche und
  englische Screenshots sind jeweils passend zur Seitensprache eingebunden.
- `npm run assets` erzeugt optimierte WebP-Bilder und eigene Social-Preview-PNGs.
  Die fertigen Assets liegen im Repository; Docker benötigt keinen App-Quellcode.
- Systemschriften, native HTML-FAQ, keine Cookies, kein localStorage, kein
  Matomo, kein Kontaktformular, keine extern geladenen Ressourcen.
- Canonical, Sprachalternativen, Sitemap, robots.txt und Social-Metadaten.
- Sprache wird ausschließlich über URLs gewählt. `/` führt fest auf `/de/`.

## Prüfung

`npm run build` prüft zusätzlich alle sechs Inhaltsseiten auf richtige Sprache,
Canonical/Alternates, lokale Link- und Assetziele, eine H1 je Seite, Sitemap
sowie das Fehlen von Client-Skripten, Store-Links und Trackern.

Für die Browserprüfung bei laufender Vorschau:

```sh
npx playwright install chromium
npm run check:browser
```

Ein vorhandener Chromium kann alternativ über `ROWIVO_CHROMIUM_PATH`
angegeben werden; die Vorschauadresse über `ROWIVO_PREVIEW_URL`.
`scripts/check-browser.mjs` prüft 24 Kombinationen aus sechs Seiten und vier
Breiten (320, 390, 768, 1440), Sprachwechsel, FAQ per Maus und Tastatur,
Bildladung, Sprungmarken, Überläufe, Netzwerkfehler und Browserspeicher.
Screenshots entstehen unter `artifacts/` (nicht versioniert).

Prüfstand 24.09.2026: Build und Linkprüfung bestanden; Astro check ohne
Fehler/Warnungen; 24 Browserkombinationen bestanden. Desktop- und Mobilansichten
visuell kontrolliert. Browserlauf mit installiertem Chromium 1234.
Docker-Image lokal erfolgreich gebaut; nginx-Auslieferung, Rechtsseiten-Redirects,
echte 404-Antwort und Sicherheitsheader mit `node scripts/check-server.mjs`
geprüft. Die 24 Browserkombinationen auch gegen nginx mit aktiver CSP bestanden.
Ein Produktionsdeploy oder Schwachstellenscan der Containerbasis wurde nicht durchgeführt.

Prüfstand 05.10.2026 nach Ergänzung des Verfügbarkeitsdatums: Astro check ohne
Fehler/Warnungen, Build und Linkprüfung sowie alle 24 Browserkombinationen bestanden.

## Hosting vorbereiten

`Dockerfile` und `nginx.conf` liefern die gebauten Dateien aus. Build-Kontext
ist dieses Verzeichnis: `docker build -t rowivo-website .`.
Der Container hat keine Datenbank, keine Schlüssel und kein Volume.
nginx liefert CSP und weitere Sicherheitsheader; die Infrastruktur übernimmt
TLS und Access-Logs. Eigene nginx-Access-Logs sind ausgeschaltet, damit kein
zweiter, unbefristeter Bestand entsteht.

Die vorgesehenen kurzen Rechts-URLs `/impressum`, `/datenschutz` und `/privacy`
werden durch nginx auf die entsprechenden Sprachseiten umgeleitet. Für einen
anderen statischen Host sind diese Redirects gesondert zu konfigurieren; die
sechs vollständigen Inhalts-URLs funktionieren unabhängig davon.

Der Image-Build und die Übergabe an die Plattform sind in
`../.github/workflows/website.yml` eingerichtet. Bei Änderungen an `website/**`
oder am Workflow auf `main` (sowie manuell per `workflow_dispatch`) laufen zuerst
`npm ci`, `npm run check` und `npm run build`. Danach wird das linux/amd64-Image
gebaut und mit Trivy auf behebbare HIGH/CRITICAL-Schwachstellen geprüft.
Nur nach erfolgreicher Prüfung wird genau dieses Image nach
`ghcr.io/lorenzkromer/rowivo-website` mit Commit-SHA und `latest` gepusht.
`INFRASTRUCTURE_DISPATCH_TOKEN` ist ein Repository-Secret. Der anschließende
Dispatch an `lorenzkromer/kromerlorenz-infrastructure` heißt
`rowivo-image-pushed` und übergibt `sha`, `ref`, `actor` und `run_id`.
App-Änderungen allein lösen keinen Website-Build aus.

Der Produktionsbetrieb mit Stack, TLS, Deploy und Monitoring liegt auf der
Plattform `kromerlorenz-infrastructure`. Den tatsächlichen Betriebsstatus führt
deren `HOSTS.md`; ein erfolgreicher Image-Build bestätigt noch keinen Deploy.
Für Aufnahme und Änderungen am Betrieb ist
`/Users/lorenz/development/kromerlorenz-infrastructure/AUFNAHME.md` maßgeblich:
Stack, HOSTS-Zuordnung, Image-/Deploy-Workflow, TLS, Bestandsverzeichnis und
Übersicht; Monitoring-Probe erst nach erfolgreichem Deploy. Öffentlich ohne
Login betreiben. Vor dem Ausrollen Containerbasis nach Infrastrukturvorgabe
auf Schwachstellen prüfen. Keine fremden Infrastrukturänderungen überschreiben.

## Datenschutz: Quellen und noch zu klärende Angaben

Die vorhandenen Unternehmensdaten sind übernommen, die Datenschutztexte wurden
für die tatsächlich beschriebenen Rowivo-Datenflüsse neu geschrieben. Die Texte
sind implementiert, aber wegen folgender offener Punkte **noch nicht als finale
Store-Datenschutzerklärung zur Veröffentlichung freigegeben**:

1. **Tatsächlicher Betrieb:** Der Hostingtext basiert auf dem lokalen
   Infrastruktur-Lieferantenverzeichnis (Hetzner, EU; Microsoft 365 für
   Geschäftsmail) und `monitoring/loki-config.yml` (720 Stunden Retention).
   Beim Deploy mit dem tatsächlichen Routing, GeoIP/Logging und Anbieter-Verträgen
   abgleichen; ggf. die Angaben zu Auftragsverarbeitung und internationalen
   Zugriffen ergänzen. Abgleich am 05.10.2026 mit den lokalen Quellen von
   `kromerlorenz.at/src/content/pages/de/privacy.md` und dem Infrastruktur-
   Lieferantenverzeichnis: Die Firmenwebsite beschreibt ebenfalls Self-Hosting
   mit Docker/nginx und technische Zugriffsprotokolle. Deren Matomo-Abschnitt
   trifft auf Rowivo nicht zu. Die pauschale Aussage der Firmenwebsite zu
   ausschließlich österreichischer Verarbeitung wurde nicht übernommen, da
   die Infrastrukturunterlagen Hetzner-Hosting in der EU ausweisen. Der direkte
   öffentliche Abruf der Firmen-Datenschutzseite war beim Abgleich nicht möglich.

App-Quellen: `../README.md`, `../docs/file-storage.md`, `../docs/watch.md`.
Die experimentelle Vorschlagsfunktion wurde am 14.10.2026 entfernt.

Spätere Änderungen an Analytics, Formularen, App-Datenflüssen oder Cloud-Diensten
müssen gleichzeitig in beiden Datenschutz-Sprachversionen nachgezogen werden.
