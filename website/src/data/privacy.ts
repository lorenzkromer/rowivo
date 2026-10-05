// App data flows: ../docs/jev.md, file-storage.md, watch.md and current source.
// Hosting basis: kromerlorenz-infrastructure/handbuch/inhalt/lieferanten/index.md
// and monitoring/loki-config.yml. See README.md for pre-publication checks.
export const privacy = {
  de: {
    title: 'Datenschutzerklärung',
    description:
      'Informationen zum Datenschutz auf der Rowivo-Webseite und in der Rowivo-App.',
    intro:
      'Hier erfährst du, welche Daten beim Besuch dieser Webseite und bei der Nutzung von Rowivo verarbeitet werden. Die Webseite und die App haben unterschiedliche Datenflüsse.',
    updated: 'Stand: 24. September 2026',
    controller: 'Verantwortlicher',
    website: 'Webseite',
    app: 'Rowivo-App',
    rights: 'Deine Rechte',
    sections: [
      {
        id: 'website',
        title: '1. Bereitstellung der Webseite',
        paragraphs: [
          'Diese Webseite wird auf der von Lorenz Kromer verwalteten Infrastruktur bei Hetzner Online GmbH, Industriestraße 25, 91710 Gunzenhausen, Deutschland, betrieben. Die Server befinden sich in der EU. Hetzner ist als Hosting-Dienstleister eingebunden.',
          'Beim Seitenaufruf werden technische Zugriffsdaten verarbeitet: IP-Adresse, Datum und Uhrzeit, angeforderte Adresse, HTTP-Status, übertragene Datenmenge, gegebenenfalls die verweisende Seite sowie Browser- und Betriebssysteminformationen. Die Betriebsprotokolle dienen der sicheren Auslieferung, Fehleranalyse und Abwehr von Missbrauch. Die Infrastruktur kann IP-Adressen mithilfe einer lokal gespeicherten Datenbank einem ungefähren Herkunftsland bzw. Ort zuordnen; hierfür wird keine Besucheradresse an einen Geolokalisierungsdienst gesendet.',
          'Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO, das berechtigte Interesse am sicheren Betrieb. Für die zentralen Betriebsprotokolle ist eine Aufbewahrungsdauer von 30 Tagen eingerichtet; die technische Löschung erfolgt anschließend im regulären Bereinigungslauf.',
        ],
      },
      {
        title: '2. Cookies, Schriftarten und externe Inhalte',
        paragraphs: [
          'Die Rowivo-Webseite verwendet keine Analyse- oder Werbetracker, keine Cookies und keinen localStorage. Die Sprache wird über die aufgerufene Seitenadresse ausgewählt. Bilder und Styles werden von derselben Domain geladen; für die Schrift werden die auf deinem Gerät verfügbaren Systemschriften verwendet.',
          'Es werden keine Karten, Videos, Kontaktformulare oder Social-Media-Inhalte von Drittanbietern eingebettet. Externe Links übertragen erst beim Öffnen Daten an das jeweilige Ziel. Für das Versenden einer E-Mail wird dein eigenes E-Mail-Programm geöffnet.',
        ],
      },
      {
        title: '3. Kontakt per E-Mail',
        paragraphs: [
          'Wenn du uns schreibst, verarbeiten wir deine E-Mail-Adresse, gegebenenfalls deinen Namen sowie den Inhalt und die technischen Metadaten deiner Nachricht, um deine Anfrage zu beantworten. Die Geschäftskorrespondenz wird über Microsoft 365 abgewickelt. Bitte beschränke deine Nachricht auf die für die Anfrage erforderlichen Angaben.',
          'Die Verarbeitung erfolgt zur Bearbeitung vertragsbezogener Anfragen nach Art. 6 Abs. 1 lit. b DSGVO, bei sonstigen Anfragen aufgrund unseres berechtigten Interesses an der Kommunikation nach Art. 6 Abs. 1 lit. f DSGVO. Korrespondenz wird gelöscht, sobald sie für die Bearbeitung nicht mehr erforderlich ist, sofern keine gesetzlichen Aufbewahrungspflichten oder erforderliche Nachweise für Rechtsansprüche entgegenstehen.',
        ],
      },
      {
        id: 'app',
        title: '4. Lokale Daten in der Rowivo-App',
        paragraphs: [
          'Rowivo speichert dein Profil, Trainingsziel, Erfahrung, Trainingspläne, absolvierte Einheiten, Rückmeldungen, Notizen und gegebenenfalls empfangene Gerätemesswerte lokal auf deinem iPhone. Belastungsangaben, Beschwerden, Pulsdaten und Freitext können gesundheitsbezogene Informationen enthalten. Für die manuelle Planung und das Training ist kein Rowivo-Konto erforderlich. Ein zentraler Rowivo-Server erhält diese Trainingsdaten nicht.',
          'Die lokale Verarbeitung dient den von dir verwendeten Planungs-, Trainings- und Verlaufsfunktionen. Die Daten bleiben erhalten, bis du Einträge oder unter „Profil und Daten löschen“ die App-Daten entfernst. Je nach deinen Betriebssystemeinstellungen können lokale App-Daten außerdem Bestandteil einer von dir verwalteten Gerätesicherung sein.',
        ],
      },
      {
        title: '5. Bluetooth, Apple Watch und Apple Health',
        paragraphs: [
          'Mit deiner Bluetooth-Freigabe kann Rowivo einen Concept2 PM5 oder ein kompatibles FTMS-Rudergerät verbinden. Je nach Gerät werden Distanz, Tempo, Schlagzahl, Leistung und Puls empfangen und für die Trainingsaufzeichnung gespeichert. Du kannst die Verbindung trennen und die Berechtigung in den iOS-Einstellungen entziehen.',
          'Die optionale Watch-App tauscht Trainingszustand, Steuerbefehle und Rückmeldungen mit dem gekoppelten iPhone über Apples WatchConnectivity aus. Bei freigegebenem HealthKit-Zugriff kann die Watch-App auf deinen Wunsch eine Trainingseinheit in Apple Health speichern. Eine eigene Pulsmessung über die Watch ist derzeit nicht implementiert. Gesundheitsdaten werden nicht zu Werbezwecken genutzt.',
          'Berechtigungen für Apple Health verwaltest du in den Systemeinstellungen bzw. in Health. Bereits in Apple Health gespeicherte Einträge werden durch das Löschen der Rowivo-App-Daten nicht automatisch gelöscht. Für die Speicherung und eine gegebenenfalls aktivierte Synchronisation von Apple Health gelten außerdem deine Apple-Einstellungen und die Datenschutzinformationen von Apple.',
        ],
      },
      {
        title: '6. Export und Trainingssicherungen',
        paragraphs: [
          'Auf deinen Wunsch exportiert Rowivo CSV-Dateien oder eine wiederherstellbare .rowivo-Trainingssicherung. Du wählst den Zielordner über die Dateien-Funktionen von iOS aus. Wenn dieser Ordner bei iCloud Drive oder einem anderen Cloud-Anbieter liegt, übernimmt dieser Anbieter die Speicherung bzw. Übertragung nach deinen dortigen Einstellungen. Optionale automatische Dateikopien verwenden ebenfalls den von dir gewählten Ordner.',
          'Trainingssicherungen können dein Profil, deinen Plan, Verlauf, Notizen und Messwerte enthalten. Der TypeSafe-API-Schlüssel ist nicht Bestandteil dieser Exporte. Bereits exportierte Dateien, Cloud-Kopien und externe Sicherungen bleiben beim Löschen der lokalen Rowivo-Daten bestehen; du verwaltest und löschst sie beim jeweiligen Dateianbieter.',
        ],
      },
      {
        title: '7. Optionale Jev-Vorschläge über TypeSafe',
        paragraphs: [
          'Jev ist eine freiwillige, experimentelle Zusatzfunktion. Du verwendest dafür deinen eigenen TypeSafe-Zugang. Der API-Schlüssel wird in den In-App-Einstellungen eingegeben und im Schlüsselbund des iPhones gespeichert, nur bei entsperrtem Gerät zugänglich und an dieses Gerät gebunden. Er wird bei Anfragen zur Authentifizierung an TypeSafe übermittelt. Du kannst ihn in der App entfernen; „Profil und Daten löschen“ entfernt ihn ebenfalls.',
          'Erst wenn du „An TypeSafe senden und Vorschlag erhalten“ auswählst, sendet die App eine HTTPS-Anfrage direkt an api.typesafe.ai. Übermittelt werden Trainingsziel, Erfahrung, die Abschnitte der nächsten Einheit, dein Zeitbudget und bis zu drei aktuelle Trainingsrückmeldungen mit Dauer, Belastung, Beschwerdeangabe und jeweils bis zu 2.000 Zeichen Notiz sowie bis zu 2.000 Zeichen deiner aktuellen Ergänzung. Freitext kann persönliche und gesundheitliche Angaben enthalten. TypeSafe erhält durch die Verbindung auch technische Daten wie deine IP-Adresse.',
          'Profilname, interne IDs, eigene Namen von Trainingseinheiten und Gerätemessreihen werden nicht in den Anfrageinhalt aufgenommen. Es gibt keine automatischen Anfragen im Hintergrund. Strukturierte Beschwerden in der letzten Rückmeldung blockieren derzeit die Anfrage. Das ersetzt keine Prüfung dessen, was du freiwillig in Notizen eingibst.',
          'Der Zweck ist die Auswertung deiner Anfrage für eine kürzere oder leichtere nächste Einheit. Eine Vorschau wird vorübergehend im Arbeitsspeicher gehalten. Erst dein Übernehmen speichert die Planänderung mit einem lokalen Verlaufseintrag. Die Entscheidung über eine Änderung bleibt bei dir.',
          'Die Verarbeitung durch TypeSafe erfolgt über deinen eigenen Anbieterzugang. Die für diesen Zugang geltenden Datenschutz- und Vertragsbedingungen enthalten die Angaben zur weiteren Verarbeitung, Speicherung und zu etwaigen internationalen Übermittlungen beim Anbieter. Die lokale Speicherung in Rowivo bedeutet nicht, dass auch die von dir an TypeSafe gesendeten Daten ausschließlich auf deinem Gerät oder innerhalb der EU verarbeitet werden. Wenn du diese Übermittlung nicht möchtest, nutze Rowivo ohne Jev; manuelle Planung und Training bleiben verfügbar.',
        ],
      },
      {
        id: 'rights',
        title: '8. Deine Rechte und Kontakt',
        paragraphs: [
          'Soweit die gesetzlichen Voraussetzungen vorliegen, hast du das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch nach Art. 15 bis 21 DSGVO. Gegen eine Verarbeitung auf Grundlage eines berechtigten Interesses kannst du aus Gründen, die sich aus deiner besonderen Situation ergeben, Widerspruch einlegen. Soweit eine Verarbeitung auf Einwilligung beruht, kannst du diese jederzeit mit Wirkung für die Zukunft widerrufen.',
          'Kontaktiere hierfür den oben genannten Verantwortlichen. Auf ausschließlich lokal gespeicherte Trainingsdaten haben wir keinen Fernzugriff. Für diese Daten stehen dir die Bearbeitungs-, Export- und Löschfunktionen der App zur Verfügung. Beim Entfernen einer Berechtigung werden bereits exportierte oder extern gespeicherte Daten nicht automatisch entfernt.',
          'Du kannst dich bei einer Datenschutzaufsichtsbehörde beschweren, insbesondere an deinem gewöhnlichen Aufenthaltsort, Arbeitsplatz oder am Ort des vermuteten Verstoßes. In Österreich ist dies die Österreichische Datenschutzbehörde, Barichgasse 40–42, 1030 Wien, dsb.gv.at.',
          'Es findet durch Rowivo keine automatisierte Entscheidung mit rechtlicher oder ähnlich erheblicher Wirkung statt. Trainingsvorschläge werden nicht automatisch angewendet. Diese Erklärung wird angepasst, wenn sich Funktionen oder Datenverarbeitungen ändern.',
        ],
      },
    ],
  },
  en: {
    title: 'Privacy notice',
    description:
      'How personal data is handled on the Rowivo website and in the Rowivo app.',
    intro:
      'This notice explains how data is handled when you visit this website and use Rowivo. The website and the app have different data flows.',
    updated: 'Last updated: 24 September 2026',
    controller: 'Controller',
    website: 'Website',
    app: 'Rowivo app',
    rights: 'Your rights',
    sections: [
      {
        id: 'website',
        title: '1. Providing this website',
        paragraphs: [
          'This website is hosted on infrastructure managed by Lorenz Kromer at Hetzner Online GmbH, Industriestraße 25, 91710 Gunzenhausen, Germany. The servers are located in the EU. Hetzner provides the hosting service.',
          'Page requests involve technical access data: IP address, date and time, requested address, HTTP status, amount of data transferred, referring page where provided, and browser and operating system information. Operational logs support secure delivery, troubleshooting and abuse prevention. The infrastructure may use a locally stored database to associate IP addresses with an approximate country or location; no visitor IP address is sent to a geolocation service for this purpose.',
          'The legal basis is Article 6(1)(f) GDPR, our legitimate interest in secure operation. Central operational logs have a configured retention period of 30 days; technical deletion follows in the regular cleanup cycle.',
        ],
      },
      {
        title: '2. Cookies, fonts and external content',
        paragraphs: [
          'The Rowivo website uses no analytics or advertising trackers, cookies or localStorage. The page address determines the language. Images and styles are loaded from the same domain; text uses the system fonts available on your device.',
          'No third-party maps, videos, contact forms or social media content are embedded. External links transfer data to their destination only when opened. Email links open your own email application.',
        ],
      },
      {
        title: '3. Contact by email',
        paragraphs: [
          'When you contact us, we process your email address, your name if provided, and the content and technical metadata of your message to respond to your enquiry. Business correspondence is handled through Microsoft 365. Please limit your message to information needed for the enquiry.',
          'The legal basis for contract-related enquiries is Article 6(1)(b) GDPR. Other enquiries are handled under Article 6(1)(f) GDPR, our legitimate interest in communication. Correspondence is deleted when it is no longer needed to handle the enquiry, unless statutory retention obligations or evidence needed for legal claims require it to be kept.',
        ],
      },
      {
        id: 'app',
        title: '4. Local data in the Rowivo app',
        paragraphs: [
          'Rowivo stores your profile, training goal, experience, training plans, completed workouts, feedback, notes and any received device readings locally on your iPhone. Effort ratings, discomfort, heart rate and free text may contain health-related information. Manual planning and workouts do not require a Rowivo account. These training records are not sent to a central Rowivo server.',
          'Local processing supports the planning, workout and history features you use. Data remains until you remove entries or use “Delete profile and data” to clear the app. Depending on your operating system settings, local app data may also be included in a device backup that you manage.',
        ],
      },
      {
        title: '5. Bluetooth, Apple Watch and Apple Health',
        paragraphs: [
          'With Bluetooth permission, Rowivo can connect to a Concept2 PM5 or a compatible FTMS rowing machine. Depending on the machine, distance, pace, stroke rate, power and heart rate are received and stored with the workout. You can disconnect the device and revoke permission in iOS settings.',
          'The optional Watch app exchanges workout state, controls and feedback with your paired iPhone using Apple’s WatchConnectivity. With HealthKit permission, the Watch app can save a workout to Apple Health at your request. Direct heart-rate measurement with the Watch is not currently implemented. Health data is not used for advertising.',
          'You can manage Apple Health permissions in system settings or Health. Deleting Rowivo app data does not automatically remove entries already saved to Apple Health. Your Apple settings and Apple’s privacy information also apply to storage and any enabled synchronisation of Apple Health data.',
        ],
      },
      {
        title: '6. Exports and training backups',
        paragraphs: [
          'At your request, Rowivo exports CSV files or a restorable .rowivo training backup. You choose the destination through iOS Files. If you select iCloud Drive or another cloud provider, that provider handles storage and transfer according to your settings. Optional automatic file copies also use the folder you select.',
          'Training backups may contain your profile, plan, history, notes and readings. The TypeSafe API key is not included in these exports. Exported files, cloud copies and external backups remain when you delete local Rowivo data; you manage and delete them with the relevant file provider.',
        ],
      },
      {
        title: '7. Optional Jev suggestions through TypeSafe',
        paragraphs: [
          'Jev is a voluntary, experimental feature using your own TypeSafe access. You enter your API key in the app settings. It is stored in your iPhone’s keychain, accessible only while the device is unlocked and bound to that device. The key is sent to TypeSafe to authenticate requests. You can remove it in the app; deleting your profile and data also removes it.',
          'Only when you select “Send to TypeSafe and get suggestion” does the app send an HTTPS request directly to api.typesafe.ai. It includes your training goal, experience, next session’s segments, time budget and up to three recent workout feedback entries with duration, effort, discomfort and up to 2,000 characters of notes each, plus up to 2,000 characters of your current note. Free text may contain personal and health information. TypeSafe also receives technical connection data such as your IP address.',
          'The request content does not include your profile name, internal IDs, custom workout names or device measurement series. No requests are made automatically in the background. A structured discomfort report in the latest feedback currently blocks the request. This does not replace reviewing what you voluntarily put in notes.',
          'The purpose is to assess your request for a shorter or easier next session. A preview is held temporarily in memory. Only applying it saves the plan change and a local history entry. You remain in control of the change.',
          'Processing by TypeSafe takes place through your own provider account. The privacy and contractual terms for that account describe further processing, retention and any international transfers by the provider. Local storage in Rowivo does not mean that data you send to TypeSafe is processed only on your device or within the EU. If you do not want this transfer, use Rowivo without Jev; manual planning and workouts remain available.',
        ],
      },
      {
        id: 'rights',
        title: '8. Your rights and contact',
        paragraphs: [
          'Subject to the applicable legal requirements, you have rights of access, rectification, erasure, restriction, portability and objection under Articles 15–21 GDPR. You may object to processing based on legitimate interests on grounds relating to your particular situation. Where processing is based on consent, you may withdraw that consent at any time for the future.',
          'Contact the controller listed above to exercise these rights. We have no remote access to training data stored exclusively on your device. You can use the app’s editing, export and deletion features for that data. Revoking a permission does not automatically remove data already exported or stored elsewhere.',
          'You may complain to a data protection supervisory authority, particularly in the country of your habitual residence, workplace or the alleged infringement. In Austria, this is the Austrian Data Protection Authority, Barichgasse 40–42, 1030 Vienna, dsb.gv.at.',
          'Rowivo does not make automated decisions that produce legal or similarly significant effects. Training suggestions are not applied automatically. This notice will be updated when features or data processing change.',
        ],
      },
    ],
  },
};
