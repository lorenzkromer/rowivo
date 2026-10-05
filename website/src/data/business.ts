// Einzige Quelle fuer Geschaefts- und Identitaetsdaten — speist JsonLd.astro, Footer.astro und
// spaeter das Impressum (Plan 01-03). Jeder Wert stammt woertlich aus dem blockierenden
// Checkpoint "Geschaefts- und Identitaetsdaten bereitstellen" (Plan 01-02, Task 1) bzw. aus dem
// bestehenden Impressum unter https://zuglast.kromerlorenz.at/impressum (Gewerbewortlaut,
// Gewerbebehoerde, Kammerzugehoerigkeit, Berufsrecht — vom Nutzer als Quelle benannt). Nichts
// hier ist erfunden, geschaetzt oder als Platzhalter eingesetzt (siehe PLAN.md
// <threat_model> T-01-04 und die Prohibition im Frontmatter).
//
// Was per "entfaellt" beantwortet wurde, fehlt hier bewusst vollstaendig statt als leerer
// String oder erratener Wert:
// - Firmenbuchnummer / Firmenbuchgericht: entfaellt — Einzelunternehmen, nicht im Firmenbuch
//   eingetragen.
// - WKO-Firmen-A-Z-Profil-URL: keine verfuegbar (die GLN-basierte Lookup-URL liefert 404); nicht
//   geraten, siehe globalLocationNumber unten als schema.org-Identifier statt als sameAs-URL.

export const BUSINESS = {
  /** Vollstaendiger Firmenwortlaut (ECG §5). */
  name: 'Kromer Lorenz - IT Services & Solutions',
  /** Rechtsform: Einzelunternehmen (nicht im Firmenbuch eingetragen, siehe oben). */
  legalForm: 'Einzelunternehmen',
  owner: {
    name: 'Lorenz Kromer',
  },
  /** Ladungsfaehige Geschaeftsanschrift, als Einzelfelder statt eines Strings. */
  address: {
    street: 'Hohe Straße 185/1',
    postalCode: '4048',
    city: 'Puchenau',
    region: 'Oberösterreich',
    country: 'Österreich',
    /** ISO-3166-1-alpha-2, fuer schema.org PostalAddress.addressCountry. */
    countryCode: 'AT',
  },
  /** Kontakt-E-Mail (ECG §5) — zugleich die dauerhaft sichtbare Fußzeilen-Adresse (D-16). */
  email: 'hallo@kromerlorenz.at',
  phone: '+436648665200',
  /** UID-Nummer. */
  vatId: 'ATU82749019',
  trade: {
    /** Gewerbewortlaut der Gewerbeberechtigung. */
    description:
      'Dienstleistungen in der automatischen Datenverarbeitung und Informationstechnik',
    /** Zustaendige Bezirksverwaltungsbehoerde (Gewerbebehoerde). */
    authority: 'Bezirkshauptmannschaft Urfahr-Umgebung',
    /** Kammerzugehoerigkeit: WKO-Landeskammer und Fachgruppe. */
    chamber:
      'Wirtschaftskammer Oberösterreich, Fachgruppe Unternehmensberatung, Buchhaltung und Informationstechnologie (UBIT)',
    /** Anwendbare berufsrechtliche Vorschrift samt Fundstelle. */
    regulation: {
      name: 'Gewerbeordnung 1994 (GewO 1994)',
      url: 'https://www.ris.bka.gv.at/',
    },
  },
  gdpr: {
    /**
     * Verantwortlicher i.S.d. Art. 4 Nr. 7 DSGVO — identisch mit Name/Anschrift/E-Mail oben,
     * kein abweichender Verantwortlicher.
     */
    controllerIsBusinessItself: true,
    /**
     * Kein Datenschutzbeauftragter benannt. Bewusst modelliert als "nicht benannt", nicht
     * weggelassen: ein Einzelunternehmen loest die Pflicht zur Benennung eines DSB nach
     * Art. 37(1) DSGVO nicht aus, und ein DSB kann nach Art. 38(6) DSGVO ohnehin nicht mit dem
     * Verantwortlichen selbst identisch sein — der Nutzer ist Verantwortlicher (Art. 4 Nr. 7),
     * nicht Datenschutzbeauftragter (Art. 37). Finale Bestaetigung des daraus resultierenden
     * Datenschutzerklaerung-Wortlauts erfolgt am blockierenden Rechts-Checkpoint in Plan 01-03.
     */
    dataProtectionOfficerDesignated: false,
  },
  /** Profil-URLs fuer JSON-LD sameAs — nur echte Profil-URLs, keine Identifier. */
  sameAs: [
    'https://www.linkedin.com/in/lorenz-kromer/',
    'https://github.com/lorenzkromer',
  ] as const,
  /**
   * WKO-GLN (Global Location Number) — ein schema.org-Identifier, kein Profil-Link. Gehoert auf
   * Organization.globalLocationNumber, nicht in sameAs. Keine WKO-Firmen-A-Z-URL verfuegbar (die
   * GLN-basierte Lookup-URL liefert 404) — nicht geraten.
   */
  globalLocationNumber: '9110026470471',
} as const;

export type Business = typeof BUSINESS;
