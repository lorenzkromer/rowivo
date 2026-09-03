# Rowivo 0.1 — Implementierungsstand

Stand: 3. September 2026

## Struktur

| Pfad | Verantwortung |
|---|---|
| `Rowivo/RowivoApp.swift` | App-Start, Datencontainer, Navigation, Präsentation laufender Einheiten |
| `Rowivo/Views` | Einstieg, Heute, Plan, Training, Feedback, Coach, Verlauf und Einstellungen |
| `Rowivo/Design` | Farben, Typografie, Karten, Komponenten und Vektormarke |
| `Rowivo/Data` | SwiftData-Aggregat, transaktionales Speichern und Zustand der App |
| `Rowivo/Services` | Keychain, Anthropic, CoreBluetooth, CSV/Trainingssicherung und koordinierter Dateizugriff |
| `Rowivo/Resources` | Deutsch/Englisch als String Catalog und App-Icon |
| `Packages/RowivoCore` | Framework-unabhängige Modelle, Planvorlage, Regeln, Uhr, PM5-Parser und Aufzeichnung |
| `Tests` | App-/API-Tests und native UI-Tests |

## Entscheidungen für diesen Prototyp

- iPhone, SwiftUI, Swift 6, iOS 18+. Darstellung derzeit in heller Gestaltung.
- Die ursprünglichen Wochen sind Trainingsblöcke. Der nächste offene Termin wird in Reihenfolge angeboten; ein Ruhetag zwischen Einheiten gilt auch an Monatsgrenzen und bei Sommerzeitwechseln.
- 2 oder 3 Einheiten je Block. Das vom Nutzer gewählte Zeitbudget umfasst das ganze Training, einschließlich Pausen. Bei knappen Zeitbudgets werden Arbeitsphasen gekürzt bzw. Intervallpaare reduziert; Ein- und Ausrudern bleiben erhalten.
- Die Vorlage dient dem Einstieg und verwendet lockere bzw. gleichmäßige Belastung ohne individuelle Pulsvorgaben. Sie ist keine klinisch validierte Trainingsverschreibung. Die Intervalle mit hoher Intensität aus dem ursprünglichen Dokument sind nicht automatisch übernommen.
- Zeitgestoppte Einheiten verwenden verstrichene Zeit aus gespeicherten Zeitpunkten, keine heruntergezählten UI-Ticks. Eine manuelle Timerpause zählt nicht zur Trainingsdauer; geplante Erholung bleibt ein Abschnitt der Einheit. Ein Hintergrundwechsel oder App-Neustart verliert den Timerzustand nicht.
- Kürzere Einheiten bleiben im Verlauf, erfüllen aber den geplanten Termin nicht. Sensordaten, Distanzen, Kalorien oder Pulswerte werden nicht erfunden.
- Gemeldete Beschwerden sperren einen erneuten Start bis zum persönlichen Check-in. Der Coach kann diesen Check-in nicht automatisiert erledigen.

## Coach-Vertrag

Der Client verwendet die Anthropic Messages API über `URLSession`, einschließlich eines vollständigen `tool_use`/`tool_result`-Durchlaufs. Pro Antwort kann ein Vorschlag angelegt werden. Unterstützte Aktionen:

| Aktion | Grenze |
|---|---|
| `shorten_next` | 15 Minuten Mindestdauer, strikt kürzer als die nächste Einheit, Ein-/Ausrudern erhalten |
| `ease_next` | Nächste Einheit auf lockere Belastung setzen |
| `repeat_last_block` | Nur einen vollständig abgeschlossenen vorherigen Block wiederholen, neue IDs für die Wiederholung |
| `reduce_frequency` | Von 3 auf 2 Einheiten reduzieren, abgeschlossene Einheiten erhalten |

Ein Vorschlag enthält Planversion und ID der nächsten offenen Einheit. Die App prüft erneut beim Übernehmen; aktive Trainings verhindern Planänderungen. Jede übernommene Änderung erzeugt einen lokalen Versionsstand. Der Client behält einen alten Plan bei Netzwerkfehlern, unvollständigen Antworten oder ungültigen Vorschlägen.

Kontext: Trainingsziel, Erfahrung, Häufigkeit, Zeitbudget, nächste Einheit, Anzahl absolvierter Trainings, letzte acht Trainingsrückmeldungen und bis zu sechzehn Chatnachrichten. Der Profilname wird nicht als eigenes Kontextfeld mitgeschickt. In freiem Chat und Notizen kann der Nutzer dennoch persönliche Angaben eingeben. Die App macht dies vor der Weitergabe kenntlich. Nur eine explizite Nachricht des Nutzers löst einen Aufruf aus.

Der Schlüssel wird mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` im Keychain gespeichert und nicht ins Projekt geschrieben. Die App nimmt nur Verbindungen zu `https://api.anthropic.com/v1/messages` auf. Widerruf der Datenweitergabe beendet ausstehende Anfragen und verhindert neue; bereits übermittelte Daten werden dadurch nicht zurückgerufen.

## PM5-Verbindung und Aufzeichnung

Die Anbindung verwendet die dedizierten Concept2-GATT-Notifications `0031` (Status), `0032` (Tempo/Schlagzahl/Puls) und optional `0036` (Schlagleistung) im Dienst `CE060030-43E5-11E4-916C-0800200C9A66`. Die Statusrate wird auf eine Sekunde angefordert. Der Parser akzeptiert die älteren und aktuellen Paketlängen und verwirft zu kurze Pakete. Puls 0/255 und ungültige Tempowerte werden als fehlend behandelt.

Die erste Messung bildet eine Basis, keine bereits geruderten Meter werden importiert. Nur aufeinanderfolgende, plausible Zeit-/Distanzänderungen werden addiert. Nach manueller Pause wird neu angesetzt. Unterbrechungen über fünf Sekunden, Zählerresets und App-Neustart erzeugen eine Lücke und eine neue Basis. Die Messreihe wird auf höchstens einen Punkt pro Sekunde begrenzt; Zähleränderungen werden bei jeder Notification verarbeitet. Je Messwerttyp verhindern sowohl Empfangszeit als auch PM5-Zeit die Vermischung mit alten Daten.

Laufende Aufzeichnungen werden spätestens beim nächsten Messpaket nach fünf Sekunden, beim Hintergrundwechsel, bei Pause/Verbindungsabbruch und beim Abschluss in SwiftData gesichert. Ein erzwungener Prozessabbruch kann deshalb die letzten circa fünf Sekunden verlieren. Eine Einheit bleibt an das erste verwendete Gerät gebunden. Optionale neue JSON-Felder erhalten die Kompatibilität mit bisherigen lokalen Daten.

`bluetooth-central` ermöglicht Messwertempfang einer bestehenden Verbindung im Hintergrund. Es gibt keine Wiederherstellung der CoreBluetooth-Verbindung nach Prozessbeendigung. Suchläufe bleiben im Vordergrund und enden nach 15 Sekunden; Verbindung und Wiederverbindung erhalten jeweils ein Limit von 20 Sekunden. PM5-Daten werden nicht in den Coach-Kontext aufgenommen. Eine entsprechende Regression prüft den tatsächlichen Request-Body.

Die App setzt Just Row voraus und programmiert keine Workouts auf dem Monitor. Das Feedback schließt die Einheit ab; ein PM5-Endstatus speichert nicht unbeaufsichtigt ein Training.

## Eigener Datei- und Cloud-Speicher

Freiwillige Ordnerkopien und einmaliger Dateiexport ergänzen die lokale Datenbank. Vier CSV-Tabellen dienen der Auswertung, ein versioniertes JSON-Archiv der Wiederherstellung. Exporte enthalten ausschließlich Trainingsdaten; Chat, API-Schlüssel, Freigaben und aktive Einheiten sind ausgeschlossen. Die automatische Ordnerkopie ist zunächst aus und kann für gespeicherte Einheiten und Planänderungen aktiviert werden. Wiederherstellen erfolgt nach Prüfung und Bestätigung, mit vorheriger lokaler Rückfallkopie. Details und Datenvertrag: [file-storage.md](file-storage.md).

## Validierung

- 10 Tests der Trainingslogik: alle unterstützten Zeitbudgets/Frequenzen, Abschnittsgrenzen, Ende des Plans, Ruhetage über Sommerzeitwechsel, Schutz vor Erhöhung und veralteten Änderungen, Wiederholungen mit neuen IDs, Erhalt abgeschlossener Einheiten und Timer-Wiederherstellung.
- 9 bisherige App-/API-Tests: echte lokale Datenbank wieder öffnen, Teil-Einheiten, Duplikate, Beschwerden, Vorschlagsübernahme/Versionierung, Änderungen während eines Trainings, Einwilligung vor Netzwerkzugriff, Authentifizierungsfehler, Tool-Protokoll, ungültige Vorschläge und abgeschnittene Antworten.
- 3 bisherige UI-Tests: Einstieg → Profil → manueller Eintrag → Verlauf; Timer → Pause → Navigation → Fortsetzen → Verwerfen; deutsche Übersicht → Coach → Einstellungen mit deaktivierter Datenweitergabe.
- 9 PM5-Core-Tests: Byte-Reihenfolge und Einheiten, alte/neue Paketlängen, ungültige Werte, Aktualität, Startbasis, Pause, Datenlücken, Reset, doppelte/verspätete Pakete, Rate und alte JSON-Daten.
- 4 zusätzliche App-Tests: PM5-Datenbank wieder öffnen und abschließen, Pause/Gerätewechsel/Verwerfen, keine PM5-Daten im Coach-Request, bestehendes App-JSON laden.
- Zusätzlicher UI-Test: deutsche PM5-Einrichtung, ehrlicher Simulatorstatus und Zugang aus dem laufenden Training. PM5-Prüfstand: 36 Tests erfolgreich vor Erweiterung des Dateiexports. Simulator-Build und unsignierter Build für ein echtes iPhone sind erfolgreich.
- Simulatorbilder von Einstieg, Tagesübersicht, Coach, laufendem Training und PM5-Verbindung visuell geprüft. Alle vom Compiler erfassten Oberflächentexte sind im Deutsch-/Englisch-Katalog enthalten.

Ein echter Anthropic-Aufruf ist noch nicht getestet, weil kein API-Schlüssel bereitgestellt wurde. Es wurden weder Kosten ausgelöst noch persönliche Trainingsdaten an Anthropic geschickt.

Zusätzlich prüfen 2 Core-Tests den CSV-Vertrag und 7 App-/Dateitests Export, Dateikoordination, Opt-in, Fehler und Wiederherstellung. Die zwei zusätzlichen Datei-UI-Abläufe sind erfolgreich: Wiederherstellung vor der Profilerstellung sowie Dateiexport in den echten lokalen iOS-Dateianbieter und anschließende Wiederherstellung mit Vorschau/Bestätigung. Insgesamt 47 Tests erfolgreich. Echte Cloud-Konten wurden nicht verbunden.

## Noch offen vor öffentlicher Veröffentlichung

- Backend, Anmeldung, serverseitiger Schlüssel, Nutzungslimits und Kostenmodell statt eines persönlichen API-Schlüssels.
- Sportfachliche Validierung, Evaluation der Coach-Antworten einschließlich problematischer Trainingswünsche und Beschwerden sowie Freigabe der Trainingsregeln.
- Erweiterte individuelle Programmerstellung, frei änderbare Profile und zusätzliche Exportoptionen für Chat sowie vollständige lokale Löschfunktionen. CSV-Trainingsexport und Wiederherstellung sind implementiert.
- Physischer PM5-Verbindungstest, Hintergrund-/Sperrbildschirmtest, spätere PM5-Workoutprogrammierung, HealthKit und Watch-App.
- Weitere Sprachen, größere Bedienungshilfen-Schriftgrößen und kleine Displays im vollständigen Testlauf, dunkles Erscheinungsbild.
- App-Store-Datenschutzangaben, weitere Veröffentlichungsunterlagen und Prüfung der Zielländer sowie Marken-/Domain-Verfügbarkeit.

## Ergänzung: Bedienung und Texte (3. September 2026)

- Ein Tipp auf die freie Fläche einer Planzeile wurde vor der Korrektur im Simulator reproduzierbar ignoriert. Die Zeilen haben jetzt eine vollständige rechteckige Tippfläche, mindestens 68 pt Höhe, Trennlinien und eine Rückmeldung beim Drücken.
- Die Anzeige verwendet konkrete Trainingsarten, nummerierte Einträge und die Bezeichnung „Block“. Wiederholte Motivationssätze und doppelte Statusmeldungen wurden entfernt. Einheitliche Belastung steht einmal in der Zusammenfassung; bei wechselnder Belastung bleiben die Angaben pro Abschnitt erhalten. Der Pausenhinweis erscheint einmal unter dem Ablauf.
- Die neuen Bezeichnungen sind reine Darstellung. Codable-Rohwerte, gespeicherte Pläne, Training und CSV-Kennungen wurden nicht geändert.
- Zwei neue UI-Abläufe prüfen Englisch/Deutsch, einzelne Tipps auf freie Flächen und Ränder sowie Navigation nach dem Scrollen. Zusammen mit den betroffenen bisherigen Abläufen wurden fünf UI-Tests erfolgreich ausgeführt (`RowivoPlanAndCopy.xcresult`). Der ursprüngliche Tippfehler wurde vorher durch denselben Test nachgewiesen (`RowivoPlanTapBefore.xcresult`). Die abschließende Kürzung der Abschnittstexte wurde nochmals im deutschen Ablauf geprüft (`RowivoWorkoutCopy2.xcresult`).
- Xcode-Projekt, Scheme, Signing-/General-Einstellungen und Info.plist blieben unverändert; keine Projektgenerierung für diese Korrektur nötig.
- Recherche und Empfehlung zum Zugang ohne persönlichen API-Schlüssel: [Coach-Zugang](coach-access.md). Die laufende API-Anbindung bleibt der Prototyp; eine neue Kontoanbindung wurde nicht implementiert.

## Referenzen

Die Quellen dienten als technische bzw. allgemeine Trainingsgrundlage, nicht als Validierung des gesamten Rowivo-Plans:

- [Anthropic Tool Use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)
- [Anthropic Structured Outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Anthropic-Datenspeicherung](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
- [Concept2: erste Trainingseinheiten](https://www.concept2.com/blog/getting-started-try-these-workouts)
- [Apple-Lokalisierung](https://developer.apple.com/localization/)

- [Concept2 Softwareentwicklung](https://www.concept2.de/support/software-development)
- [Concept2 PM CSAFE Communication Definition, Rev. 0.34, Seiten 17–22](https://cms.concept2.de/sites/default/files/2026-03/Concept2%20PM%20CSAFE%20Communication%20Definition.pdf)
- [Apple: CoreBluetooth im Hintergrund](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
