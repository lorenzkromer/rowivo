# Rowivo — Implementierungsstand

Stand: 3. September 2026. Aktuelle Produktrichtung: manuelle Trainingsplanung. KI ist vorerst entfernt.

## Struktur

| Pfad | Verantwortung |
|---|---|
| `Rowivo/RowivoApp.swift` | Datencontainer, Heute/Plan/Fortschritt, laufende Einheit |
| `Rowivo/Views/WorkoutEditorView.swift` | Entwurf, Abschnitte, Intervalle und Reihenfolge |
| `Rowivo/Views/PlanView.swift` | Blöcke, vollständige Tippflächen und Trainingsdetails |
| `Rowivo/Data/RowivoStore.swift` | Transaktionale Planänderungen, Speicherung, Timer und Dateiabläufe |
| `Rowivo/Services` | CoreBluetooth, CSV/Trainingssicherung und koordinierter Dateizugriff |
| `Packages/RowivoCore` | Modelle, manuelle Validierung, Vorlage, Uhr, PM5-Parser und Aufzeichnung |
| `Rowivo/Resources` | Deutsche/englische Texte und App-Icon |
| `docs/archive/ai-prototype` | Aus dem App-Target entfernte historische KI-Quellen |

## Manueller Plan

Der Einstieg erzeugt standardmäßig einen leeren Plan. Die optionale Acht-Block-Vorlage bleibt erhalten. Neue Einheiten bekommen zunächst drei Abschnitte; im Editor kann der Nutzer alle Typen, Dauern und Belastungen ändern, Abschnitte hinzufügen, löschen und sortieren. Intervallgruppen enthalten 2–20 Wiederholungen und keine zusätzliche Pause nach dem letzten Arbeitsabschnitt. Sie werden vor einem vorhandenen letzten Ausruderabschnitt eingefügt.

Ein gültiges Training enthält mindestens einen Ruderabschnitt. Ein Abschnitt dauert 1–3600 Sekunden, die gesamte Einheit höchstens vier Stunden und umfasst höchstens 100 Abschnitte. Namen sind optional und auf 80 Zeichen begrenzt. Blöcke dürfen leer sein. Ein Block enthält höchstens 100 Einheiten, der Plan höchstens 1000 Blöcke und 10.000 Einheiten. Diese Grenzen schützen die Verarbeitung und sind keine sportfachliche Freigabe.

Der Editor arbeitet mit einem lokalen Entwurf. Speichern prüft dessen Ausgangsversion, die aktive Einheit und den vollständigen Plan vor der Übernahme. Jede tatsächliche Änderung erhält eine neue Planrevision. Ein fehlgeschlagenes Speichern verändert den vorherigen Zustand nicht. Während eines laufenden oder pausierten Timers sind Planänderungen gesperrt.

Sobald eine Einheit eine vollständige oder teilweise Aufzeichnung hat, bleiben ihre ID und Definition erhalten. Bearbeiten und Löschen sind gesperrt; Duplizieren erzeugt unabhängige IDs für Einheit und Abschnitte. Gespeicherte Aufzeichnungen enthalten den Namen zum Aufnahmezeitpunkt. Die Reihenfolge kann auch bei vorhandenen Aufzeichnungen geändert werden. Die nächste offene Einheit ergibt sich aus der Planreihenfolge und vollständig erledigten Einträgen.

## Bestehende Daten und entfernte KI

`customName` ist ein optionales Codable-Feld in Einheit und Aufzeichnung. Daten ohne dieses Feld behalten die lokalisierte Bezeichnung ihrer Trainingsart. Bisherige Enum-Rohwerte und IDs wurden nicht geändert. Die SwiftData-Ablage verwendet weiterhin das bestehende lokale JSON-Aggregat.

Coach-Tab, KI-Verbindungseinstellungen, das Lesen und Speichern von API-Schlüsseln sowie der Anthropic-Netzwerkclient sind aus dem App-Target entfernt. Die Funktion zum vollständigen Zurücksetzen löscht ausschließlich einen gegebenenfalls vorhandenen historischen Schlüssel. Alte lokale Chatfelder bleiben zum verlustfreien Lesen vorhandener Daten erhalten. Frühere KI-Freigaben und offene Vorschläge werden beim Öffnen deaktiviert. Frühere Schlüssel werden nicht gelesen. Die reine Core-Logik früherer Planaktionen bleibt für bestehende Modelle und Regressionen bestehen; sie ist nicht über die App ausführbar. Es gibt keinen aktiven KI-Anfrageweg.

## Timer und Aufzeichnung

SwiftUI/Swift 6, iPhone, iOS 18+, helle Gestaltung. Der Timer verwendet gespeicherte Zeitpunkte, keine heruntergezählten UI-Ticks. Manuelle Pause zählt nicht zur Trainingsdauer; geplante Erholung bleibt ein Abschnitt. Hintergrundwechsel oder Neustart verlieren den gespeicherten Timerzustand nicht. Teil-Einheiten bleiben im Verlauf, erfüllen aber nicht den geplanten Termin. Die bestehende Ruhetag-Regel und der Check-in nach Beschwerden bleiben für neue Starts aktiv. Nachträge dokumentieren bereits absolvierte Einheiten und sind auch an Ruhetagen oder während eines noch offenen Check-ins möglich; laufende Timer sperren sie weiterhin.

PM5 verwendet Concept2-GATT-Notifications `0031`, `0032` und optional `0036` im Dienst `CE060030-43E5-11E4-916C-0800200C9A66`. Angefordert wird eine Statusrate von einer Sekunde. Parser und Recorder behandeln ältere Paketlängen, fehlende Werte, Pause, verspätete Daten, Gerätewechsel, Zählerreset und Verbindungslücken. Nur plausible Zähleränderungen während des Trainings werden gezählt, fehlende Meter nicht geschätzt. Messreihen sind auf einen Punkt pro Sekunde begrenzt.

Laufende Messwerte werden beim nächsten Paket nach fünf Sekunden, beim Hintergrundwechsel, bei Pause/Verbindungsabbruch und beim Abschluss gesichert. Erzwungenes Beenden kann die letzten circa fünf Sekunden verlieren. Das Training bleibt an das erste verwendete PM5-Gerät gebunden. `bluetooth-central` ermöglicht Hintergrundempfang bestehender Verbindungen; nach Prozessende erfolgt keine automatische CoreBluetooth-Wiederherstellung.

Die App setzt Just Row voraus und programmiert keine Workouts auf dem Monitor. Feedback schließt die Einheit ab. Der physische PM5-, Hintergrund- und Sperrbildschirmtest steht noch aus: [Prüfanleitung](pm5.md).

## Dateien

Format 3 erhält die Trainingsnamen und freien Pläne aus Format 2 und ergänzt `trained_at_utc` in `sessions.csv`. `recorded_at_utc` behält seine Bedeutung als Erfassungszeitpunkt. Sicherungen der Versionen 1 und 2 bleiben lesbar. Ein optionales Dateien-Bookmark, `NSFileCoordinator` und ein eigener Actor führen Dateioperationen aus; die lokale SwiftData-Datenbank bleibt maßgeblich. Wiederherstellung validiert zuerst und erstellt eine lokale Rückfallkopie. Details: [Dateiformat](file-storage.md).

## Projektsettings

Es wurde kein Projekt neu generiert. Die Editor-Datei ersetzt den bisherigen Coach-Dateiverweis; Anthropic- und Keychain-Quellverweise wurden entfernt. Alle Debug/Release-Buildsettings, geteilten Schemes und die Info.plist entsprechen der Sicherung vor der Änderung. Die zusätzliche Prüfung mit `scripts/check-project-settings.py` ist erfolgreich.

## Prüfung und offene Arbeit

Core-Tests prüfen unter anderem freie Pläne, Grenzen, Intervallgruppen, unabhängige IDs und Reihenfolge. App-Tests prüfen echtes Wiederöffnen der Datenbank, Schutz aufgezeichneter Einheiten, veraltete Entwürfe, aktive Timer, Legacy-Daten und die Sicherungsformate 1 und 2. PM5-, Datei- und Wiederherstellungsregressionen bleiben Teil der Tests.

Der aktuelle UI-Prüflauf deckt Einstieg mit leerem Plan, Erstellen und manuelles Protokollieren, deutsche Abschnitts- und Intervallbearbeitung, Abbrechen, Duplizieren, entfernte KI-Einstellungen, vollständige Tippflächen, Timer, PM5 und Dateidialoge ab. Die beiden zunächst gefundenen Probleme sind behoben: Zeitfelder behalten leere/ungültige Eingaben als Entwurf und speichern keine frühere Zahl; die Testauswahl ersetzt den vollständigen Feldinhalt. Der manuelle Protokollknopf liegt neben dem Start als eigener Bereich im festen Fußbereich und kann nicht vom Startknopf überlagert werden. Manuelle Einträge übernehmen außerdem die sekundengenaue Plandauer.

Vor Veröffentlichung offen: physischer PM5-Test, echte Cloud-Provider und Wiederherstellung auf einem zweiten Gerät, größere Schriften und kleine Displays, Profiländerung, fachliche Prüfung der Trainingsregeln sowie App-Store-Unterlagen und zusätzliche Sprachen. Watch, HealthKit und PM5-Programmierung bleiben spätere Erweiterungen. KI ist pausiert.


## Verifizierter Stand

- **24 Core-Tests** erfolgreich (`manual-core-output.log`).
- **21 App-/Dateitests** erfolgreich (`build/RowivoManualPlanning.xcresult`): Speicherung, Änderungen, Datenkompatibilität, PM5 und Sicherungen.
- **8 unterschiedliche UI-Abläufe** erfolgreich: sechs bestehende Abläufe im ersten Gesamtlauf; die beiden korrigierten Abläufe und der betroffene Timer erneut erfolgreich in `build/RowivoManualEditorFinal.xcresult` (3 Tests, 0 Fehler). Der Einstieg prüft ausdrücklich 30 Minuten 30 Sekunden bis zum manuellen Eintrag.
- Simulator-Build erfolgreich mit Xcode 26.6, iPhone 17 Pro, iOS 26.4. Deutsche und englische Bildschirmaufnahmen in `docs/screenshots` visuell geprüft. Kein Zugriff auf reale Cloud-Konten und kein physischer PM5-Test.
- Signing-/General-Buildsettings, Scheme und Info.plist sind gegen die Sicherung vor der Änderung unverändert geprüft. Die temporäre XcodeGen-Vergleichsprüfung ist ebenfalls erfolgreich.

Aktuelle Ansichten: [Editor auf Englisch](screenshots/editor-en.png), [Abschnitt bearbeiten](screenshots/step-editor-de.png), [Intervalle](screenshots/interval-editor-de.png), [eigene Einheit](screenshots/custom-workout-de.png), [leerer Plan](screenshots/empty-plan-en.png).


## Ergänzung: Datum beim Nachtragen

Der manuelle Eintrag enthält eine native Auswahl für Trainingsdatum und Uhrzeit bis zum aktuellen Zeitpunkt. `WorkoutCompletion.date` enthält das gewählte Trainingsdatum; das neue optionale Feld `recordedAt` hält separat den Erfassungszeitpunkt fest. Alte Datensätze ohne dieses Feld bleiben lesbar. Zeitgestoppte Einheiten behalten ihre automatische Datierung.

Verlauf, Tagesdiagramm, Ruhetage und die Bestimmung der letzten Beschwerden verwenden das Trainingsdatum. Rückwirkende Einträge sind auch an Ruhetagen möglich, erlauben aber keinen neuen Trainingsstart. Eine ältere Rückmeldung hebt einen neueren offenen Beschwerden-Check-in nicht auf. Ungültige oder zukünftige Datumswerte, eine Rückdatierung zeitgestoppter Einheiten und Nachträge während eines aktiven Timers werden zurückgewiesen.


Prüfung der Datumserweiterung: 24 Core-Tests und 24 App-/Dateitests erfolgreich, einschließlich Persistenz, chronologischer Reihenfolge, Ruhetagen, Beschwerden-Check-in, ungültigen Datumswerten und CSV-/Sicherungs-Roundtrip. Der bestehende Einstieg mit manuellem Eintrag und der Timer-Ablauf sind erneut erfolgreich (`build/RowivoBackdatedWorkout.xcresult`). Der zusätzliche UI-Test wählt ein vergangenes Datum, speichert es, prüft die Anzeige im Verlauf und die deutsche Eingabemaske (`build/RowivoBackdatedWorkoutFinal.xcresult`, erfolgreich nach Korrektur des erwarteten Datumsformats im Test). Die Screenshots wurden visuell geprüft: [Datum beim Nachtragen](screenshots/manual-date-de.png), [rückdatierter Verlauf](screenshots/backdated-history-en.png).

Xcode-Projekt, geteilte Schemes, `Info.plist` und `project.yml` sind per Prüfsummenvergleich unverändert. Es war keine Projektgenerierung nötig.


## Ergänzung: Datum bestehender Einträge korrigieren

Unter Fortschritt besitzt jeder gespeicherte Eintrag die Aktion **Datum ändern**. Der Editor übernimmt das vorhandene Datum und erlaubt Änderungen an Datum und Uhrzeit bis jetzt. Erst Speichern übernimmt den Entwurf; Abbrechen verwirft ihn. Das gilt für manuelle, zeitgestoppte, PM5- und Teil-Einheiten, einschließlich älterer lokaler Datensätze und importierter Sicherungen.

`updateCompletionDate` prüft die unveränderte Ausgangsaufzeichnung und sperrt Änderungen während einer laufenden Einheit. Es aktualisiert ausschließlich das Trainingsdatum. Bei alten Einträgen ohne `recordedAt` wird der ursprüngliche Erfassungszeitpunkt vor der ersten Änderung gesichert. IDs, Dauer, Belastung, Beschwerden, Notizen, Abschlussstatus, Trainingsplan und PM5-Messwerte bleiben erhalten. Die ursprünglichen Sensorzeitstempel werden nicht verschoben. Ein korrigiertes Trainingsdatum darf später als der ursprüngliche Erfassungszeitpunkt liegen, solange es nicht in der Zukunft liegt.

Sortierung, Tagesdiagramm, Ruhetag und der neueste Beschwerden-Check-in folgen unmittelbar dem korrigierten Datum. Automatische Kopien berücksichtigen Änderungen am vollständigen Verlauf, auch wenn keine neue Einheit hinzukommt. Der Vergleich nach einem laufenden Export erkennt ebenfalls nachträgliche Korrekturen.


Prüfstand der Bearbeitung bestehender Daten: **28 App-/Dateitests erfolgreich** (`build/RowivoHistoryDateUnitsFinal.xcresult`). Die neuen Prüfungen decken alte manuelle, zeitgestoppte und PM5-Aufzeichnungen einschließlich Teil-Einheiten ab, außerdem Persistenz, unveränderte Messwerte und Notizen, chronologische Regeln, veraltete Entwürfe, Datumsgrenzen und automatische Dateikopien bei gleichbleibender Eintragszahl. Das PM5-Fixture schließt die flüchtige Messbasis wie bei einer gespeicherten Aufzeichnung ab.

**Zwei betroffene UI-Abläufe erfolgreich** (`build/RowivoHistoryDateEditCheck.xcresult`): Einstieg mit manuellem Eintrag sowie Nachtragen, bestehendes Datum ändern, Abbrechen, erneut bearbeiten und speichern. Der korrigierte Verlauf und der deutsche Editor wurden visuell geprüft: [bestehendes Datum bearbeiten](screenshots/history-date-editor-de.png), [korrigierter Verlauf](screenshots/corrected-history-en.png). Projekt-, Signing- und General-Einstellungen sind unverändert; es wurde kein Xcode-Projekt generiert.


## App-Review: Plan und Aufzeichnung, Datumszugang, Zurücksetzen

Die Ergebnisse des bereichsübergreifenden Reviews stehen in [app-review.md](app-review.md). `RecordedWorkoutCard` ist die gemeinsame Darstellung gespeicherter Einheiten für Heute, Plan und Fortschritt. Alle drei verwenden denselben Datumseditor und denselben transaktionalen Speicherpfad. Der Plan bleibt die unveränderte Vorgabe, der Verlauf zeigt jede tatsächliche Einheit einzeln; mehrere Teil-Einheiten werden nicht zu einer vermeintlichen Aufzeichnung addiert. Die Zuordnung erfolgt über `workoutID`.

`deleteAllData()` sperrt konkurrierende Dateivorgänge und Zustandsänderungen. Es entfernt lokale Rückfallkopien und temporäre Exportverzeichnisse, löscht den historischen Keychain-Eintrag des KI-Prototyps und alle SwiftData-Zustandsdatensätze. Anschließend werden Timer, PM5-Verbindung samt Gerätecache, Bookmarks, Statusmeldungen und der Zustand im Speicher zurückgesetzt. RootView wechselt ins Onboarding. Bei einer fehlgeschlagenen Bereinigung bleibt eine verständliche Fehlermeldung mit Wiederholungsmöglichkeit; die App meldet keinen erfolgreichen Reset. Bereits exportierte Kopien werden nicht geöffnet oder gelöscht. Ein verspäteter Abschluss des Dateidialogs setzt nach dem Reset keine Erfolgsmeldung.

Tests mit flüchtigen Profilen haben isolierte Dateiordner und löschen keine produktiven Schlüssel. Der Persistenztest verwendet eine eigene Datenbank und getrennte Staging-/Exportordner. Er prüft das Löschen einschließlich aktiver PM5-Aufzeichnung, Wiederöffnen, einen frischen leeren Plan und den Erhalt exportierter Sicherungen. Ein Fehlertest prüft die Wiederholung und weist konkurrierende Profiländerungen während des Löschens zurück.


Prüfstand des Reviews: 24 Core-Tests (`app-review-core-output.log`), 31 App-/Dateitests (`build/RowivoAppReviewValidation.xcresult`, App-Suite) und zehn UI-Abläufe (`build/RowivoAppReviewUI.xcresult`) erfolgreich. Die neuen UI-Abfragen wurden anhand der tatsächlichen nativen Hierarchie korrigiert (Stepper-Unterelemente und verschachtelte Alert-Buttons). Der letzte Screenshot-Durchgang führte außerdem zu expliziten Tagesmarkierungen im Verlaufsdiagramm. Die Datums- und Reset-Abläufe sind im abschließenden Lauf erneut erfolgreich (`build/RowivoAppReviewFinalDates.xcresult`, zwei Tests ohne Fehler). Screenshots und Abgrenzung zu noch offenen Hardware-/Cloud-Prüfungen stehen im Review-Dokument. Alle Projekt- und Signing-Einstellungen sind per Prüfsumme unverändert.


## Vollständiger Editor für gespeicherte Einheiten

`RecordedWorkoutEditorView` ersetzt den Datumsdialog. Ein `RecordedWorkoutEdit` enthält ausschließlich die editierbaren Felder: Name, Trainingsart, Datum, Dauer, Belastung, Beschwerden und Notiz. Textfelder behalten ungültige Eingaben als Entwurf und lassen sie vor dem Speichern korrigieren. Alle Eingaben sind vorausgefüllt; Abbrechen schreibt nichts.

`updateCompletion` prüft Eingaben und unveränderten Ausgangsdatensatz und ersetzt den vorhandenen Eintrag. IDs, Planreferenz, Herkunft, ursprünglicher Erfassungszeitpunkt und PM5-Messreihen bleiben erhalten. Nur tatsächliche Änderungen setzen das optionale `editedAt`. Ein unveränderter Speichervorgang ist ein No-op. Die Dauer bestimmt den Abschlussstatus neu; eine andere vollständige Aufzeichnung derselben Vorgabe hält diese weiterhin abgeschlossen. Änderungen am Beschwerden-Feld verwerfen einen zugehörigen früheren Check-in. Plan und gespeicherte Planversionen werden nicht umgeschrieben. Der frühere Datumsaufruf nutzt denselben Speicherpfad.

Dateiformat 4 ergänzt `edited_at_utc` und unterstützt mehrere durch Korrektur vollständig gewordene Aufzeichnungen derselben Planvorgabe. Sicherungen 1–3 bleiben lesbar. Automatische Kopien vergleichen den gesamten korrigierten Eintrag und erfassen auch Änderungen bei unveränderter Eintragszahl.

Die neue Darstellung wird aus allen drei Bereichen verwendet. Geänderte Namen erscheinen auch in Plan-Details, wo die Planüberschrift weiterhin die ursprüngliche Vorgabe benennt. Ein Stift im Toolbar öffnet die einzige Aufzeichnung direkt beziehungsweise eine Auswahl bei mehreren Aufzeichnungen. Der gemeinsame Knopf auf jeder Aufzeichnung heißt **Einheit bearbeiten**.

Prüfstand dieser Ergänzung:

- **24 Core-Tests** erfolgreich (`completion-editor-core-output.log`).
- **36 App-/Dateitests** erfolgreich (`build/RowivoFullCompletionEditUnits.xcresult`): vollständige Korrekturen und erneutes Öffnen der Datenbank, manuelle/Timer-/PM5-Daten, unveränderte IDs und Messreihen, Statuswechsel bei Dauerkorrekturen, Beschwerden-Check-in, ungültige und veraltete Entwürfe, No-op sowie automatische Datei- und CSV-Kopien ohne zusätzlichen Eintrag.
- **Vier unterschiedliche UI-Abläufe** erfolgreich: Datumskorrektur und Soll-Ist-Darstellung über alle drei Bereiche (`build/RowivoFullCompletionEditUI.xcresult`, die beiden betreffenden Tests); deutscher Editor mit Speichern und Wiederöffnen (`build/RowivoFullCompletionEditUIFinal.xcresult`, deutscher Test); vollständiger englischer Ablauf mit Abbrechen, Speichern, Wiederöffnen und Vergleich im Verlauf (`build/RowivoFullCompletionEditUIEnglish.xcresult`). Im englischen Test wurden die Betätigung des nativen Schalters und das Scrollen zum zunächst nicht sichtbaren Notizfeld korrigiert; der abschließende Lauf ist fehlerfrei.
- Deutsche und englische Screenshots sind visuell geprüft, einschließlich des zweizeiligen deutschen Dialogtitels: [Editor Deutsch](screenshots/completion-editor-de.png), [Rückmeldung Deutsch](screenshots/completion-feedback-de.png), [Editor Englisch](screenshots/completion-editor-en.png), [Rückmeldung Englisch](screenshots/completion-feedback-en.png), [gespeicherte Korrektur](screenshots/completion-corrected-en.png).
- Projektdatei, geteilte Schemes, Workspace-Datei, Info.plist und Projektvorlage sind per Prüfsumme unverändert (`build/completion-editor-settings-before.json`). Die Tests verwenden isolierte Daten; vorhandene Nutzerdaten werden nicht gelöscht.

## Native Übergänge zwischen Scrollinhalt und Leisten

`rowivoScrollEdges()` verwendet ab iOS 26 `.scrollEdgeEffectStyle(.soft, for: .vertical)`. Der bisherige deckende Hintergrund der Navigationsleiste entfällt, damit der systemeigene variable Blur sichtbar bleibt. Der gemeinsame Bildschirmstil übernimmt das für ScrollViews und Formulare; die zusätzlichen nativen Listen und Sheets verwenden denselben Modifier.

Die feste Aktions- beziehungsweise Statusleiste in den Trainingsdetails verwendet `safeAreaBar`, damit SwiftUI sowohl den Platz für die Buttons als auch den Scrollübergang berücksichtigt. Die Leiste hat keinen eigenen deckenden Farbhintergrund. Auf älteren iOS-Versionen werden `safeAreaInset` und native Materialien für diese Leiste sowie die Navigation verwendet. Eigene Blur-Verläufe, Schattenmasken oder UIKit-Overlays sind nicht erforderlich.

Grundlage: Apples [Scroll-View-Richtlinien](https://developer.apple.com/design/human-interface-guidelines/scroll-views), [ScrollEdgeEffectStyle](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle) und [safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)).

Simulator-Build und zwei bestehende UI-Abläufe erfolgreich (`build/RowivoNativeScrollEdges.xcresult`): deutscher Plan mit Scrollen und Zeilennavigation sowie vollständiger Bearbeitungsdialog mit Tastatur, Abbrechen, Speichern und erneutem Öffnen. Visuell geprüft: [Scrollränder im Plan](screenshots/scroll-edge-plan-de.png), [Dialogleiste](screenshots/scroll-edge-sheet-en.png) und [untere Trainingsleiste](screenshots/scroll-edge-bottom-bar-en.png). Signing, General und Projektdateien sind laut Prüfsummenvergleich unverändert. Der Material-Fallback ist mit iOS-18-Deployment-Target gebaut, jedoch nicht auf einem älteren Simulator ausgeführt.
