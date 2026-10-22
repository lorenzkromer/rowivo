# Eigene Dateien und Cloud-Kopien

Rowivo speichert weiterhin in seiner lokalen SwiftData-Datenbank. Zusätzlich kann der Nutzer Dateien in seinem eigenen Speicher ablegen. Rowivo benötigt dafür keinen Cloud-Account, keinen eigenen Server und keine Zugangsdaten zu Google oder Microsoft.

## Nutzung

Unter **Einstellungen → Deine Daten → Dateien & Cloud-Kopien**:

1. **Ordner auswählen** öffnet die iOS-Dateiauswahl. Möglich sind lokale Ordner, iCloud Drive und die verfügbaren Orte anderer Dateianbieter. Für Google Drive oder Microsoft OneDrive muss die jeweilige App installiert, angemeldet und in der Dateien-App aktiviert sein.
2. **Jetzt Kopie speichern** legt im gewählten Ordner einen neuen Unterordner mit Zeitpunkt und eindeutiger Kennung an. Vorherige Ordner werden nicht überschrieben.
3. Optional **Nach jeder gespeicherten Einheit kopieren** einschalten. Dies aktualisiert auch nach Planänderungen. Bei einem fehlgeschlagenen Versuch bleibt der Auftrag offen und wird beim nächsten Öffnen beziehungsweise Vordergrundwechsel erneut versucht.
4. **Dateien exportieren …** exportiert die Dateien einmalig über den Systemdialog. Hierfür wird keine Ordnerfreigabe gespeichert. Das ist auch die Alternative für Anbieter, deren iOS-Erweiterung keine dauerhafte Ordnerfreigabe unterstützt. Bei wiederholtem Export in denselben Ordner gelten die Namens- und Ersetzungsdialoge des Anbieters.
5. **Trennen** entfernt die gespeicherte Ordnerfreigabe und beendet weitere automatische Kopien. Bestehende Dateien beim Anbieter bleiben erhalten.

Eine bestätigte Dateischreiboperation bedeutet, dass die Dateien an den Anbieter übergeben wurden. Sie bestätigt keinen Upload auf dessen Server. Offline-Verhalten, Upload-Warteschlange, Dateiversionen und Speicherplatz bestimmt der Anbieter. Die App zeigt den Zeitpunkt der letzten Übergabe und offene Änderungen an.

Cloud-Kopien sind zunächst ausgeschaltet. Auch die automatische Kopie ist nach einer Ordnerwahl zunächst aus. Während eines laufenden Trainings wird weder exportiert noch wiederhergestellt; die PM5-Aufzeichnung bleibt lokal und wird nicht durch Cloud-I/O verzögert.

## Lokal alles löschen

**Einstellungen → Profil und Daten löschen** entfernt nach Bestätigung das lokale Profil einschließlich Plan, Aufzeichnungen, Notizen, PM5-Messreihen, alter Chatfelder und aktiver Einheiten. Die Löschfunktion entfernt außerdem alle privaten Wiederherstellungskopien, Rowivo-Stagingordner für Dateiexporte und einen gegebenenfalls noch vorhandenen Schlüssel des früheren KI-Prototyps. Die gespeicherte Cloud-Freigabe wird verworfen und Rowivo zeigt das Onboarding.

Exporte in selbst gewählten Ordnern werden nicht gelöscht. Eine laufende Dateiübertragung sperrt das Zurücksetzen; umgekehrt sperrt das Zurücksetzen Dateiaktionen und Schreibzugriffe auf Trainingsdaten. Bei einem Fehler wird der Vorgang als unvollständig gemeldet und kann wiederholt werden. Flüchtige Testprofile verwenden separate private Dateiordner und greifen beim Zurücksetzen nicht auf echte gespeicherte Zugangsdaten zu.

## Dateiformat 4

| Datei | Inhalt |
|---|---|
| `profile.csv` | Name, Ziel, Erfahrung, Häufigkeit, Zeitbudget |
| `plan.csv` | Aktueller Plan, eine Zeile je Trainingsabschnitt |
| `sessions.csv` | Eine Zeile je gespeicherter Einheit, Rückmeldungen, Notiz und PM5-Zusammenfassung |
| `rower_samples.csv` | Eine Zeile je empfangenem Messpunkt; Verknüpfung über `session_id` |
| `training.rowivo` | Versioniertes JSON mit Profil, aktuellem Plan, Planversionen und vollständigem Trainingsverlauf zur Wiederherstellung |
| `README.txt` | Beschreibung von Format, Einheiten und Verwendung |
| `complete.json` | Markiert ein vollständig geschriebenes Dateiset beim Export in einen gemerkten Ordner |

CSV: UTF-8 mit BOM, Komma als Trennzeichen, konsequent zitierte Felder, CRLF-Zeilenenden, Dezimalpunkt, Zeitstempel als UTC/ISO 8601. Die Spaltennamen bleiben auf Englisch stabil; Einheiten stehen im Namen. `schema_version` ist derzeit 5. Seit Version 2 enthalten `plan.csv` und `sessions.csv` die Spalte `workout_name`; bisherige Spalten behalten ihre Reihenfolge. Namen ohne eigenen Wert bleiben leer. Format 2 erlaubt leere Pläne, leere Blöcke und frei zusammengestellte Einheiten. Indizes beginnen bei null. Fehlende Messungen bleiben leer; sie werden nicht mit null oder geschätzten Werten ersetzt. `recorded_at_utc` bleibt der Erfassungszeitpunkt. Die seit Version 3 vorhandene Spalte `trained_at_utc` enthält das Trainingsdatum einschließlich Uhrzeit. Beim Nachtragen wird es vom Nutzer gewählt; bei älteren Einträgen und zeitgestoppten Einheiten wird das bisher gespeicherte Datum verwendet. Ein unbekannter historischer Trainingsbeginn wird nicht erfunden.

Format 4 ergänzt als letzte Spalte `edited_at_utc` in `sessions.csv`. Sie bleibt bei unveränderten Aufzeichnungen leer. Bearbeitungen ersetzen den Eintrag mit derselben `session_id` und setzen den Änderungszeitpunkt; Planreferenz, Erfassungszeitpunkt, Herkunft und PM5-Messreihen bleiben erhalten. `finished_plan` wird aus der korrigierten Dauer und der ursprünglichen Sollzeit berechnet. Korrekturen können mehrere eigenständige Aufzeichnungen derselben Planvorgabe vollständig machen; Format 4 unterstützt diesen Fall. Die IDs der Aufzeichnungen müssen weiterhin eindeutig sein. Der Plan zählt die Vorgabe nur einmal als erledigt.

Text, der als Tabellenformel interpretiert werden könnte, erhält im CSV ein vorangestelltes Apostroph. Das ursprüngliche Textfeld bleibt in der Sicherung unverändert. Die `.rowivo`-Datei ist JSON, kein verschlüsseltes oder geschlossenes Datenformat; Datumsfelder im JSON verwenden den Foundation-Zeitbezug (Sekunden seit 1. Januar 2001 UTC). Für eigene Auswertungen sind die CSV-Zeitstempel einfacher.

Enthalten sind auch Trainingsnotizen, Beschwerden und gegebenenfalls vom PM5 empfangener Puls. Nicht enthalten sind Cloud-Bookmarks, aktive Timer und noch nicht abgeschlossene Messreihen. Historische Chat-, Schlüssel- und Freigabefelder werden ebenfalls nicht exportiert. Die App hat keinen aktiven KI-Zugang.

## Wiederherstellen

**Sicherung auswählen …** öffnet eine `.rowivo`-Datei. Rowivo liest und validiert sie zuerst, dann zeigt die App Name, Sicherungsdatum und Anzahl der Einheiten. Erst **Dieses Training wiederherstellen** ersetzt das lokale Profil, den Plan und den Verlauf. CSV-Änderungen werden nicht zurückimportiert.

Vor dem Ersetzen wird ein vorhandener Trainingsstand im privaten App-Speicher gesichert. Über **Vorherigen Trainingsstand wiederherstellen** lässt sich diese Kopie ebenfalls prüfen und zurückholen. Ein Fehler beim Lesen, Validieren, Anlegen der Rückfallkopie oder Speichern verändert den bisherigen Trainingsstand nicht. Ein laufendes Training sperrt die Wiederherstellung. Die Cloud-Ordnerfreigabe wird zurückgesetzt. Historische lokale Chatfelder bleiben erhalten; frühere KI-Freigaben und Vorschläge werden nicht wieder aktiviert.

Der Einstieg bietet **Vorhandenes Training wiederherstellen**, damit ein neues iPhone ohne vorherige Profilerstellung wiederhergestellt werden kann. Aktuell werden Sicherungen in Formatversion 5 geschrieben; Version 1 bis 4 bleiben importierbar. Frühere App-Versionen weisen Format 5 als neueres Format zurück. Im JSON ist `date` das Trainingsdatum und das optionale Feld `recordedAt` der Erfassungszeitpunkt. Fehlt `recordedAt` in älteren Daten, wird zunächst deren bisheriges Datum für beide Angaben verwendet. Bei der ersten Bearbeitung wird dieses ursprüngliche Datum als `recordedAt` bewahrt. Datum, Name, Trainingsart, Dauer, Belastung, Beschwerden und Notizen können im gespeicherten Eintrag korrigiert werden. Das optionale Feld `editedAt` hält die letzte tatsächliche Änderung fest; ein unveränderter Speichervorgang setzt es nicht neu. Auch ein nach vorne korrigiertes Trainingsdatum überschreibt den ursprünglichen Erfassungszeitpunkt nicht. Es gilt ein Limit von 64 MB pro Sicherungsdatei. Fremde, beschädigte und neuere Formate werden mit einer verständlichen Meldung abgewiesen. Die Validierung prüft unter anderem eindeutige IDs, Verweise, Abschnittsdauern und plausible Messfelder.

## Technische Umsetzung

- `ArchiveFiles` koordiniert Dateioperationen auf einem separaten Actor mit `NSFileCoordinator` und Security-scoped URLs. Ein iOS-Bookmark merkt ausschließlich den ausgewählten Ordner; veraltete Bookmarks werden bei erfolgreicher Auflösung erneuert.
- Jede automatische oder manuell ausgelöste Ordnerkopie erhält einen eindeutigen neuen Ordner. Die Dateien werden einzeln atomar geschrieben; `complete.json` folgt zuletzt. Ein fehlgeschlagener Versuch entfernt nur seinen eigenen neu angelegten Ordner. Andere Dateien werden nicht gelöscht.
- Die Sicherung ist unabhängig von den CSV-Dateien vollständig wiederherstellbar. Die Reihenfolge, in der einzelne Dateien auf Cloud-Servern erscheinen, liegt beim Anbieter.
- `TrainingArchive` ist eine explizite Projektion der Trainingsdaten. Ein vollständiger Dump des App-Zustands würde unter anderem Berechtigungsdaten enthalten und wird deshalb nicht verwendet.
- Automatische Exporte setzen eine bestehende Freigabe und ausdrückliches Einschalten voraus. Das Kennzeichen für offene Änderungen bleibt in SwiftData erhalten. Alle Änderungen bestehender Einträge, etwa an Dauer, Rückmeldung oder Datum, lösen ebenfalls eine neue Kopie aus. Beim Exportabschluss wird der gesamte Trainingsverlauf verglichen, damit eine zwischenzeitliche Korrektur bei gleicher Eintragszahl nicht verloren geht. Ein während eines Exports geänderter Trainingsstand wird nicht irrtümlich als aktuell gesichert markiert.
- Exporte sind unabhängige Sicherungsstände. Es gibt keine Zusammenführung konkurrierender Änderungen und keine laufende Synchronisierung mehrerer Geräte.

## Prüfung

Automatisierte Tests prüfen CSV-Zeichen, Unicode, Zahlen, fehlende Werte, Formeltext, Sicherungs-Roundtrip, ausgeschlossene private Felder, inkompatible/beschädigte Daten, echte koordinierte Dateioperationen mit zwei getrennten Sicherungsständen, automatische Kopien nach Freigabe, nicht erreichbare Ordner, lokale Rückfallkopien und die Sperre während eines Trainings. UI-Tests prüfen die ausgeschaltete Voreinstellung, Abbruch der Ordnerwahl und den Einstieg ohne Profil. Der vollständige Export in den lokalen iOS-Dateianbieter mit anschließendem Öffnen, Prüfen und Wiederherstellen der Sicherung ist im Simulator erfolgreich. Der aktualisierte Prüfstand ist im [Implementierungsstand](implementation.md) dokumentiert.

Reale iCloud-, Google-Drive- und OneDrive-Konten wurden hier nicht verbunden. Die jeweilige Provider-Erweiterung, langfristige Ordnerfreigabe, Offline-Upload und Wiederherstellung auf einem zweiten Gerät müssen am echten iPhone geprüft werden. Die lokalen Dateitests belegen keinen erfolgten Cloud-Upload.

## Quellen

- [Apple: Ordnerzugriff mit Document Picker und Bookmarks](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [Apple: Cloud-Anbieter in der Dateien-App einrichten](https://support.apple.com/en-us/102238)

## Format 5: weitere Rudergeräte

`source` unterscheidet `pm5`, `ftms`, `manual` und `app_timer`. Die bisherigen `pm5_*`-CSV-Spalten heißen `device_*`; die Datei `pm5_samples.csv` heißt nun `rower_samples.csv`. Reihenfolge und Bedeutung der bisherigen Spalten bleiben erhalten, `stroke_count` ergänzt die Messreihe am Ende. Schlagfrequenz kann Dezimalstellen enthalten; FTMS-Leistung wird als vorzeichenbehafteter Wert gespeichert. Fehlende Gerätezeit oder Distanz bleibt leer. Die App-Zeit ersetzt keine fehlende Gerätezeit. Im JSON bleiben `pm5` und `currentPM5Recording` als historische Schlüssel bestehen; der neue optionale `protocolKind` ist `ftms`, fehlende Herkunft bedeutet Concept2. Sicherungen 1–4 und lokale Altbestände bleiben lesbar.
