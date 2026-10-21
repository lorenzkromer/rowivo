# Ruderreise — erste Umsetzung

Stand: 21. Oktober 2026. Entwicklung im Git-Worktree `rudertrainer-journey`, Branch `feature/rowing-journey`. Der vorgefundene, noch nicht eingecheckte App-Stand wurde als eigener Ausgangscommit übernommen; der ursprüngliche Arbeitsordner bleibt erhalten.

## Bedienung

**Heute → Deine Ruderreise** und **Fortschritt → Deine Ruderreise** öffnen den See mit den erreichten und nächsten Orten. Schilfbucht wird nach 1.000 m, Waldanleger nach insgesamt 3.500 m und Insellichtung nach insgesamt 8.500 m erreicht. Alle drei Etappen dürfen sich über beliebig viele Einheiten verteilen.

Im Training ist **Landschaft** voreingestellt; **Messwerte** blendet die Szene aus. Die beiden Timer, Gerätewerte und die feste Leiste für Pause und Beenden bleiben verfügbar. Das Erreichen eines Ortes beendet das Training nicht. Oberhalb der gespeicherten Gesamtdistanz bleibt weiterer Fortschritt sichtbar, auch nach Entdeckung aller Orte.

Die Landschaft enthält Berge, Wald, ruhiges Wasser, ein Holzboot und einen näher kommenden Anleger. Die Uferbewegung folgt den erfassten Metern, während Wasser und Ruder dekorativ animiert werden. Der neue Reisebereich ist Deutsch und Englisch übersetzt und funktioniert offline.

**Landschaft ansehen** öffnet eine ausdrücklich simulierte Vorschau. Sie lässt sich pausieren und zum nächsten Ort weiterschalten. Ihre Meter schreiben weder Trainingsaufzeichnungen noch Freischaltungen.

## Fortschrittsregeln

Diese Regeln konkretisieren und ersetzen die entsprechenden Vorschläge im ursprünglichen [Plan](rowing-journey-plan.md):

- Alle vorhandenen, gespeicherten Geräteaufzeichnungen zählen ab sofort mit, einschließlich Teileinheiten. Manuelle Einträge und reine Timer-Einheiten erzeugen keine Reisemeter.
- Maßgeblich ist `RowerRecording.measuredDistance` aus der vorhandenen PM5-/FTMS-Aufzeichnung. Rohe Monitorzähler, Schlagzahl und geschätzte Meter werden nicht gutgeschrieben.
- Die laufende Einheit ist Vorschau. Nur erfolgreiches Speichern macht ihren Fortschritt dauerhaft; Verwerfen zählt nicht. Vorschau und gespeicherte Summe werden nicht doppelt addiert.
- Pause, Messlücken und Zählerrücksetzungen nutzen unverändert die vorhandenen Aufzeichnungsregeln. Ohne aktuelle gemessene Distanz steht das Boot. Ein Verbindungsverlust wird spätestens nach drei Sekunden in der Ansicht berücksichtigt.
- Die Reise wird aus eindeutigen Aufzeichnungs-IDs berechnet. Es gibt keine zweite, separat persistierte Gutschriftenliste. Wiederherstellung und erneutes Öffnen erzeugen keine Zusatzmeter.
- Beim Löschen einer Aufzeichnung werden Strecke und freigeschaltete Orte aus dem verbleibenden Verlauf neu berechnet. Es gibt keine dauerhaft erhaltenen Entdeckungen nach dem Löschen ihrer zugrunde liegenden Meter.
- Änderungen an Datum, Dauer oder Notizen lassen die originalen Gerätemeter und damit die Reise unverändert. Ein vollständiger Profilreset entfernt den Verlauf und damit die Reise.
- Bestehende `.rowivo`-Sicherungen enthalten die erforderlichen Gerätemesswerte bereits. Dateiformat 5 und das lokale Datenschema bleiben unverändert.

`AUFNAHME.md` der Infrastruktur wurde gelesen. Es gibt keine Änderung an Serverbetrieb, Domains, Login, Serverdatenhaltung oder Backups der Plattform; die dortigen Meldestellen benötigen deshalb keinen neuen Eintrag.

## Darstellung und technische Grenzen

Die Szene ist eine native SwiftUI-Canvas-Zeichnung mit flüssiger Interpolation zwischen gemessenen Distanzständen. Sie liest den Trainingszustand, verändert ihn aber nicht. Vorwärtsbewegung überschreitet den Messstand nicht. Die Animation pausiert bei inaktiver App; die vorhandene Hintergrundaufnahme und Watch-Steuerung bleiben unverändert.

„Bewegung reduzieren“ deaktiviert die laufende Landschaftsbewegung. Reisetexte und Fortschrittsanzeige bleiben für VoiceOver verfügbar. Eine echte Gerätefahrt zur Beurteilung von Akku, Wärme, Funkabbrüchen und Lesbarkeit am Rudergerät bleibt vor Freigabe notwendig. Es gibt bislang eine stilisierte Welt mit drei Etappen, keine weiteren Welten und keinen Zeitmodus ohne Distanzdaten.

## Prüfung

- **42 Core-Tests ohne Fehler**, einschließlich Etappengrenzen, übergreifender Distanz, ungültiger Messwerte, Vorschau, Teileinheiten, eindeutiger Aufzeichnungs-IDs und JSON-Roundtrip. Kommando: `swift test --package-path Packages/RowivoCore`.
- **57 App-/Dateitests ohne Fehler** in `build/JourneyValidation.xcresult`. Der neue Integrationstest prüft Live-Vorschau, Speichern, wiederholten Speicheraufruf, Sicherung/Wiederherstellung, Bearbeiten und Löschen. Bestehende PM5-/FTMS-/Watch- und Dateitests bleiben erfolgreich.
- **Zwei neue UI-Abläufe erfolgreich** auf dem iPhone-18-Pro-Simulator (iOS 27): deutsche Reisevorschau mit Pause und Etappensprung in `build/JourneyUIFinal.xcresult`; englischer Trainingsmodus mit sichtbarem Timer, Ansichtswechsel und Pause in `build/JourneyWorkoutFinal.xcresult`.
- Ein erster unsignierter App-Testlauf scheiterte am bestehenden Keychain-Test mit fehlender Entitlement-Berechtigung. Der Wiederholungslauf mit normaler Simulator-Signierung besteht vollständig. Der erste Vorschautest verwendete einen falschen Accessibility-Elementtyp; der korrigierte Selektor besteht im abschließenden Lauf.
- Reiseübersicht, Vorschau und aktive Trainingsansicht wurden visuell geprüft. Die Timer wurden dabei oberhalb der Landschaft kompakt angeordnet, damit sie ohne Scrollen sichtbar sind.
- Alle Buildsettings wurden aus der Projektdatei ausgelesen und gegen den gesicherten Ausgangscommit verglichen: identisch. Projektvorlage, Info.plists, Entitlements und geteilte Schemes sind unverändert. Es gab keinen XcodeGen-Lauf; die Projektdatei registriert ausschließlich die neue Swift-Quelldatei.

Screenshots: [Reiseübersicht](screenshots/journey-overview-de.png), [Landschaftsvorschau](screenshots/journey-preview-de.png), [aktives Training](screenshots/journey-workout-en.png).

Physische PM5-/FTMS-Fahrt, Akku-/Wärmeprüfung und ein eigener Durchgang mit VoiceOver, großer Schrift und kleinen Geräten bleiben vor Auslieferung offen. Es wurde kein TestFlight-Upload und kein Deployment ausgeführt.
