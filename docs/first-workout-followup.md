# Korrekturen nach dem ersten Training mit Build 2

Die Änderungen sind in Build 3 umgesetzt. Der signierte Entwicklungsbuild ist auf dem echten iPhone und der echten Apple Watch installiert; ein neuer TestFlight-Build wurde nicht hochgeladen.

## Bedienung und Planung

- Der aktive iPhone-Bildschirm wird mit einer konkreten Einheit präsentiert. Pause/Fortsetzen und Beenden liegen in einer nativen Safe-Area-Leiste und bleiben beim Scrollen erreichbar.
- Zwei beschriftete Ringe unterscheiden Gesamtfortschritt und aktuelle Phase. Die Gesamtzeit zählt aufwärts, die Phase zeigt ihre Restzeit.
- Der Rückblick hält den Timer ausdrücklich manuell an, damit Leistung am Gerät während des Ausfüllens nicht automatisch fortsetzt. Speicherfehler erscheinen im Formular selbst.
- Die Tastaturaktion im Einheiten-Editor erhält vertikalen Innenabstand. Ein weiterer konkreter „Weiter“-Button über einer Tastatur ist im aktuellen Quellstand nicht identifizierbar; dafür ist bei erneutem Auftreten ein Screenshot nötig.
- Neue Startervorlagen begrenzen Erholungsphasen auf 60 Sekunden, ohne die eingesparte Zeit zusätzlich als Rudern zu verteilen. Bereits vorhandene und aufgezeichnete Einheiten werden nicht umgeschrieben. Vorhandene Pausen lassen sich in **Plan → offene Einheit → Bearbeiten → Erholungsphase** ändern.

## Optionale Watt-Automatik

**Einstellungen → Während des Trainings → Automatisch pausieren**. Standardmäßig aus; Grenzwert zunächst 6 W, einstellbar von 1 bis 50 W. Sechs Sekunden mit gemessener Leistung darunter pausieren, zwei Sekunden mit mindestens vier Watt darüber setzen fort. Manuelle Pausen und der Rückblick bleiben angehalten. Geplante Erholungsphasen werden nicht automatisch pausiert.

Fehlende Leistung ist nicht null Watt. Unterbrechungen oder fehlende Messwerte setzen den Erkennungszeitraum zurück. Ohne aktuelle Watt-Daten kann die Automatik nicht reagieren; beim PM5 können nach ausbleibenden Schlägen Watt-Angaben fehlen. Es gibt kein automatisches endgültiges Beenden oder Speichern.

## Kalender und PDF

**Plan → Einheit → Zum Kalender hinzufügen** öffnet Apples Ereignisdialog. Datum, Uhrzeit, Wiederholungen und Zielkalender sind dort wählbar. Rowivo liest keine persönlichen Kalender und erzeugt keinen abonnierten Kalender-Feed. Spätere Änderungen im Plan aktualisieren einen angelegten Termin nicht automatisch.

**Aufgezeichnete Einheit → Als PDF teilen**, erreichbar in Heute, Plan und Fortschritt. Das PDF enthält Datum, tatsächliche und geplante Dauer, Belastung, Notizen, verfügbare Gerätesummen und Hinweise auf Lücken. Notizen laufen bei Bedarf über mehrere Seiten. Teilen erfolgt über den iOS-Dialog. Temporäre PDFs verwenden die bestehende lokale Exportbereinigung; exportierte Kopien bleiben beim Empfänger bzw. Dateianbieter.

## Watch

Siehe [Watch-Dokumentation](watch.md): lokale Zeitfortschreibung, Refresh-Timeout, native Workout-Session nach optionaler Health-Freigabe und Phasenhaptik. Steuerbefehle benötigen weiterhin die Bestätigung des iPhones.

## Erneut am Gerät prüfen

1. Start am iPhone, danach Pause/Fortsetzen auf der Watch; anschließend Start auf Watch und Speichern am iPhone.
2. Watch-Trainingsmodus aktivieren, Handgelenk mehrfach senken, Phasenwechsel mit Ton-/Stumm-Einstellung prüfen.
3. Kurz die Verbindung trennen: Timer läuft weiter, Werte werden nicht als live ausgegeben. Wiederverbinden und tatsächlichen Zustand abgleichen.
4. Watt-Automatik einschalten: kurze Leistungseinbrüche, länger unter 6 W, Wiederanlauf ab 10 W, geplante Erholung, manuelle Pause und offener Rückblick.
5. Gespeicherte Watch-Session in Health prüfen, verworfene Einheit auf fehlenden Health-Eintrag prüfen.
6. Ein PDF mit eigener Notiz teilen und einen Kalendereintrag im gewünschten Kalender prüfen.

Apple: [Kalenderdialog ohne Kalender-Lesezugriff](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui).

## Automatisierte Prüfung

- 39 Core-Tests: `build/first-workout/core-final.log`.
- 51 App-Tests einschließlich gegenseitiger Watch-/iPhone-Steuerung und Watt-Automatik: `build/first-workout/FinalUnit.xcresult`.
- iPhone-UI: Pause/Fortsetzen/Verwerfen in `PhoneTests.xcresult`; Start/Teil-Einheit/Speichern/PDF-Teilen und Kalender-Abbrechen in `PhoneRetest.xcresult`. Beide liegen unter `build/first-workout/`.
- PDF-Seitenumbrüche mit langen Notizen und Umlauten/Emoji getestet; erste und letzte Seite eines zwölfseitigen Tests visuell geprüft. Ein Testmarker mit Unterstrichen wurde von PDFKit in getrennte Textblöcke zerlegt; der Marker wurde für die Extraktionsprüfung alphanumerisch gewählt. Der Inhalt war auch zuvor vollständig gerendert. Letzter PDF-Test: `FinalCheck.xcresult`.
- Watch-Offlinetimer mit gesperrten Steuertasten erfolgreich in `WatchTests.xcresult`. Im selben Lauf stürzte der XCTest-Runner beim Start des anderen Tests in `XCUIApplicationMonitor` ab; der gezielte Wiederholungslauf für aktive Anzeige und Bedienelemente ist in `WatchActiveRetest.xcresult` erfolgreich.
- Projekteinstellungsabgleich ohne Regenerieren des Arbeitsprojekts erfolgreich: `settings-final.log`.

## Geräte-Build 3 (4. September 2026)

- Buildnummer in bestehendem Xcode-Projekt und `project.yml` auf 3 erhöht; Version bleibt 0.1.0. Kein XcodeGen-Lauf am Arbeitsprojekt.
- Debug-Build für das echte iPhone mit eingebetteter Watch-App erfolgreich (`build/first-workout/device-build3.log`).
- Watch-Code-Signatur und eingebettetes Provisioning-Profil enthalten beide `com.apple.developer.healthkit = true`; `workout-processing` und die Zwecktexte sind im Build enthalten.
- iPhone-Installation und Start erfolgreich; installierte Buildnummer 3 über CoreDevice bestätigt.
- Nach Beheben des Netzwerk-Timeouts ist die direkte Watch-Installation erfolgreich; installierte Buildnummer 3 über CoreDevice bestätigt. Health-Freigabe und Hintergrundbetrieb müssen nun am Gerät geprüft werden.

Für den kurzen gemeinsamen Test: Rowivo auf beiden Geräten öffnen, auf der Watch **Trainingsmodus aktivieren** wählen und die systemseitige Freigabe für Trainings erteilen. Dann eine kurze Einheit starten, Handgelenk senken und wieder anheben, Pause/Fortsetzen auf dem anderen Gerät prüfen und die Einheit bewusst speichern oder verwerfen. Nach Speichern die Watch-Aufzeichnung in Health prüfen; ein verworfener Test soll dort keinen Workout-Eintrag erzeugen.

## Bestätigter Gerätetest und Löschen gespeicherter Einheiten

Lorenz hat auf Build 3 bestätigt: Timer läuft bei gesenktem Handgelenk weiter; Pause/Fortsetzen zwischen iPhone und Watch, Phasenhinweise sowie Beenden/Speichern am iPhone und der Eintrag in Health funktionieren.

Dabei fiel die fehlende Löschaktion nach dem Speichern auf. Build 4 ergänzt **Einheit löschen** direkt an gespeicherten Aufzeichnungen in Heute, Plan und Fortschritt sowie im Bearbeiten-Dialog. Der native Bestätigungsdialog nennt die Einheit und erklärt, dass nur die Rowivo-Aufzeichnung samt Gerätedaten entfernt wird; vorhandene Health-Einträge und exportierte Kopien bleiben erhalten. Die geplante Einheit bleibt bestehen und wird ohne weitere vollständige Aufzeichnung wieder offen.

Die Löschung wird gespeichert, aktualisiert Statistiken, Watch-Zustand und künftige Exporte. Veraltete Bestätigungen, wiederholte Löschanfragen, laufende Trainings und Dateioperationen werden abgefangen. Andere Aufzeichnungen und Planrevisionen bleiben erhalten. Bestehende Health-Kopien sind derzeit nicht mit einer automatisch löschbaren Health-ID in Rowivo verknüpft.

Prüfung der Löschfunktion: 54 App-Tests erfolgreich (`build/first-workout/DeleteSavedSession.xcresult`). Der gezielte deutsche UI-Test prüft Abbrechen und Löschen sowohl von der Aufzeichnung als auch aus dem Editor (`build/first-workout/DeleteSavedUIFinal.xcresult`); der native Bestätigungsdialog wurde visuell geprüft. Die ersten UI-Läufe benötigten Korrekturen am Testselektor für den nativen Bestätigungsknopf und am Scrollen zur erst bei Bedarf geladenen Formularzeile.

Build 4 wurde erfolgreich signiert und auf dem echten iPhone installiert; CoreDevice bestätigt Version 0.1.0, Build 4. Der automatische Start war wegen des gesperrten iPhones nicht möglich. Die direkte Watch-Installation lief erneut in einen Netzwerk-Timeout. Die Löschkorrektur betrifft ausschließlich die iPhone-Oberfläche und den iPhone-Speicher; der Watch-Steuerungsablauf und das Nachrichtenformat wurden dafür nicht geändert. Eine erfolgreiche Installation von Build 4 auf der Watch ist nicht bestätigt.

## Kompaktere Aufzeichnungskarten

Auf Wunsch von Lorenz erscheint **Einheit löschen** nur noch unten im Bearbeiten-Screen. Heute, Plan und Fortschritt verwenden weiterhin dieselbe kompakte Aufzeichnungskarte. Der native Bestätigungsdialog für gespeicherte Einheiten bleibt erhalten.

Auch das Löschen leerer Blöcke, geplanter Trainings über „Plan organisieren“ und von Schritten im Trainingseditor verlangt jetzt eine Bestätigung. Die rot markierten Aktionen zum Trennen des Rudergeräts und des Exportordners fragen ebenfalls nach und erklären die Folgen. Vorhandene Bestätigungen für Verwerfen, Zurücksetzen und Wiederherstellen bleiben bestehen.

Der angepasste deutsche UI-Test prüft die fehlende Löschaktion auf der Karte sowie Abbrechen und bestätigtes Löschen im Editor erfolgreich (`build/first-workout/EditorOnlyDelete.xcresult`). Simulator-Build erfolgreich; diese Anpassung wurde noch nicht erneut auf das echte iPhone installiert. Buildnummer und Xcode-Projekteinstellungen bleiben unverändert.
