# Rowivo

Rowivo ist eine iPhone-App für selbst zusammengestelltes Rudertraining: Einheiten planen, mit Concept2 PM5 oder kompatiblen FTMS-Geräten rudern und Fortschritte verfolgen. Profil, Plan und Aufzeichnungen werden lokal gespeichert. Auf Wunsch lassen sie sich als CSV und wiederherstellbare Trainingssicherung in eigenen Dateien oder Cloud-Ordnern ablegen.

Stand: 14. Oktober 2026. **Rowivo konzentriert sich auf selbst geplantes Rudertraining.** Neue Nutzer beginnen mit einem leeren Plan. Die bisherige Vorlage aus acht Trainingsblöcken ist beim Einstieg optional; vorhandene Pläne bleiben erhalten. Das unveränderte [Originalkonzept](docs/konzept.md) dokumentiert den Ausgangspunkt, dieses README die aktuelle Produktrichtung.

## App starten

1. `Rowivo.xcodeproj` in Xcode öffnen.
2. Scheme **Rowivo** und einen iPhone-Simulator oder ein iPhone auswählen, dann Run starten.
3. Mindestversion: iOS 18. Lorenz' Signing- und General-Einstellungen sind im Projekt hinterlegt.

Die App ist auf Deutsch und Englisch verfügbar. Für manuelles Planen und Training sind kein API-Schlüssel und kein Anbieter-Konto erforderlich. Das vorhandene Xcode-Projekt kann direkt verwendet werden. Vor einer Projektgenerierung gelten die Sicherungs- und Vergleichsregeln in [AGENTS.md](AGENTS.md); `python3 scripts/check-project-settings.py` prüft die Einstellungen in einer temporären Projektkopie.

## Training selbst gestalten

Unter **Plan → +** eine Einheit anlegen, optional benennen und einem Trainingsblock zuordnen. Jeder Abschnitt hat einen Typ (Einrudern, Rudern, Pause, Ausrudern), eine Dauer in Minuten und Sekunden und beim Rudern eine Belastung. Abschnitte lassen sich hinzufügen, entfernen und sortieren. Über **Intervalle hinzufügen** entstehen wiederholte Ruder- und Pausenabschnitte.

Unaufgezeichnete Einheiten lassen sich bearbeiten oder löschen. **Einheit duplizieren** erstellt eine unabhängige Kopie mit neuen IDs. Auch bereits aufgezeichnete Einheiten können so erneut verwendet werden; ihre ursprüngliche Definition und ihr Verlauf bleiben erhalten. **Planoptionen → Plan sortieren** ändert die Reihenfolge innerhalb der Blöcke. Der Editor erlaubt außerdem, eine unaufgezeichnete Einheit in einen anderen Block zu verschieben. Blöcke können hinzugefügt, verschoben und leer gelöscht werden.

Ein Entwurf wird erst beim Speichern übernommen. Während eines laufenden oder pausierten Trainings sind Planänderungen gesperrt. Veraltete Entwürfe überschreiben keine neueren Änderungen. Jede gespeicherte Planänderung erscheint im lokalen Versionsverlauf.

Die App bietet die nächste offene Einheit in Planreihenfolge an. Nach einer Einheit heute oder gestern erscheint vor dem nächsten Start ein bestätigbarer Hinweis. Ein erneutes Training bleibt möglich, auf iPhone und Watch. Der persönliche Check-in nach gemeldeten Beschwerden bleibt separat bestehen. Beim Nachtragen lassen sich Datum und Uhrzeit des absolvierten Trainings wählen, auch an einem Ruhetag. Verlauf und Trainingshinweis verwenden dieses Trainingsdatum. Bereits gespeicherte Einträge lassen sich unter **Heute**, in den **Plan-Details** und unter **Fortschritt** über **Einheit bearbeiten** vollständig korrigieren: Name, Trainingsart, Datum und Uhrzeit, Dauer in Minuten und Sekunden, Belastung, Beschwerden und Notizen. Der Dialog ist mit den vorhandenen Angaben befüllt. **Speichern** aktualisiert denselben Eintrag, **Abbrechen** verwirft den Entwurf. Das gilt auch für ältere Nachträge sowie Timer- und PM5-Einheiten. Teil-Einheiten erscheinen im Verlauf, schließen die geplante Einheit aber nicht ab. Die optionale Vorlage ist nicht sportmedizinisch validiert.

Dauerkorrekturen aktualisieren auch den Abschlussstatus im Plan. Der ursprüngliche Plan und Geräte-Messreihen bleiben als Referenz erhalten; bearbeitete Einträge sind gekennzeichnet.

Die Planübersicht zeigt die Sollzeit und bei vorhandenen Aufzeichnungen die zuletzt tatsächlich trainierte Zeit. In den Details stehen alle Aufzeichnungen mit Datum, tatsächlicher Dauer und Rückmeldung über dem ursprünglichen Trainingsablauf. Auf **Heute** sind das nächste geplante Training und die letzte Aufzeichnung getrennt. Zielintensität und selbst eingeschätzte Belastung sind unterschiedliche Angaben.

## Profil bearbeiten

Unter **Einstellungen → Dein Profil → Profil bearbeiten** lassen sich Name, Ziel, Rudererfahrung und Standarddauer ändern. Abbrechen verwirft den Entwurf. Speichern aktualisiert die Angaben; der vorhandene Plan, Aufzeichnungen und eine laufende Einheit bleiben erhalten. Die Standarddauer wird für neue Einheiten verwendet. Ein zwischenzeitlich geändertes Profil kann nicht durch einen alten Entwurf überschrieben werden.

## Profil und Daten löschen

Unter **Heute → Einstellungen → Profil und Daten löschen** lässt sich Rowivo nach Bestätigung vollständig neu einrichten. Profil, Plan, Verlauf, Notizen, Gerätedaten, laufendes Training, lokale Rückfallkopien, temporäre Exportdateien und frühere Zugangsdaten werden entfernt. Cloud-Ordner werden getrennt. Anschließend erscheint direkt das Onboarding; ein neues Profil beginnt ohne alte Einträge.

Bereits selbst exportierte Dateien bleiben in ihrem Speicherort erhalten. Während einer Dateiübertragung wartet die Löschfunktion auf deren Abschluss. Bei einem Fehler zeigt die App an, dass das Löschen noch nicht vollständig abgeschlossen ist.

## Training verfolgen

- Tagesübersicht, Plan, Trainingsablauf und Timer mit Pause und Fortsetzung nach App-Neustart.
- Manuelle Einträge oder zeitgestoppte Einheiten mit Belastung, Beschwerden und Notizen.
- Concept2 PM5 und kompatible FTMS-Rudergeräte über Bluetooth: Distanz, Tempo /500 m, Schlagzahl sowie Leistung und Puls, soweit vom Monitor verfügbar.
- Lokale Geräte-Messreihen mit Kennzeichnung von Pausen und Messlücken, Zusammenfassung und Verlaufsgrafik.
- Vollständig antippbare Planzeilen, deutsche und englische Oberfläche.

## Rudergerät verbinden

1. Rowivo auf einem echten iPhone starten; Bluetooth ist im Simulator nicht verfügbar.
2. Bluetooth-Verbindung am Gerät aktivieren, beim PM5 **Verbinden / Connect** öffnen. Gegebenenfalls andere Trainings-Apps trennen.
3. In Rowivo **Heute → Rudergerät verbinden → Rudergeräte suchen** öffnen und den Monitor auswählen.
4. Freies Rudern am Gerät wählen, beim PM5 **Einfach rudern / Just Row**, die Einheit in Rowivo starten und rudern.
5. Anschließend das Feedback speichern. Die Messwerte sind unter **Fortschritt → Geräteaufzeichnung ansehen** erreichbar.

Rowivo führt den Ablauf am iPhone. Die App programmiert das Training noch nicht auf dem PM5; Start und Pause steuern den Monitor nicht. Nur empfangene Zähleränderungen während der laufenden Einheit werden aufgezeichnet. Fehlende Meter werden nicht geschätzt. Nach erzwungenem Beenden muss die Funkverbindung erneut aufgebaut werden.

FTMS-Geräte werden beim Verbinden auf Ruderdaten geprüft. Bluetooth allein garantiert keine Kompatibilität. Fehlende Werte bleiben leer. Die Bluetooth-Implementierung ist gebaut und mit Protokolldaten geprüft; einzelne FTMS-Modelle brauchen noch den Hardwaretest. Details: [Unterstützte Anbindungen und Prüfanleitung](docs/rowers.md). Der vollständige Funk-, Hintergrund- und Sperrbildschirmtest am echten iPhone mit PM5 steht noch aus: [PM5-Prüfanleitung](docs/pm5.md).

## Apple Watch

Die Companion-App zeigt die nächste Einheit, Abschnittszeiten und verfügbare Gerätemesswerte. Start, Pause, Fortsetzen und Feedback funktionieren direkt am Handgelenk; das gekoppelte iPhone bestätigt die Aktionen und speichert die Aufzeichnung. Ohne Verbindung sind Änderungen gesperrt. Installation und Status stehen unter **Einstellungen → Apple Watch**; für die Entwicklung gibt es das Scheme **RowivoWatch** (watchOS 11+). Watch-Pulsmessung bleibt offen. Der optionale native Trainingsmodus nutzt HealthKit, um die Watch-Session aktiv zu halten und auf Wunsch in Health zu speichern. Der vollständige Steuerungs- und Speicherablauf ist zwischen gekoppelten Simulatoren erfolgreich geprüft; der Test mit echter Watch und PM5 bleibt offen. Details: [Apple-Watch-Integration](docs/watch.md).

## Dateien und eigene Cloud

Unter **Einstellungen → Deine Daten → Dateien & Cloud-Kopien** können Nutzer einen eigenen Ordner wählen oder einmalig Dateien exportieren. Verfügbare Speicherorte kommen aus der iOS-Dateien-App, darunter iCloud Drive und aktivierte Erweiterungen von Google Drive oder Microsoft OneDrive.

Vier CSV-Tabellen dienen der eigenen Auswertung; `training.rowivo` enthält die vollständige Trainingssicherung. Dateiformat 5 ergänzt FTMS-Herkunft, optionale Gerätemesswerte und herstellerneutrale CSV-Namen (`rower_samples.csv`, `device_*`). Sicherungen aus Version 1 bis 4 bleiben lesbar. Wiederherstellen zeigt eine Vorschau und erhält eine lokale Rückfallkopie. Automatische Kopien sind optional. Es gibt keine Zusammenführung mehrerer Geräte; der Dateianbieter übernimmt den Upload. Details: [Dateiformat und Cloud-Kopien](docs/file-storage.md).

## Entwicklung und Prüfung

- `Rowivo/`: SwiftUI, SwiftData, CoreBluetooth und koordinierter Dateizugriff.
- `RowivoWatch/` und `Shared/`: Watch-Oberfläche, bestätigte Steuerung und WatchConnectivity.
- `Packages/RowivoCore/`: Modelle, manuelle Planvalidierung, Vorlage, Timer, PM5-/FTMS-Parser und CSV.
- `Tests/RowivoTests/`: Speicherung, Bearbeitung, Migration, PM5 und Dateisicherungen.
- `Tests/RowivoUITests/`: Einstieg, manuelle Planung, Plan-Tippflächen, Timer, PM5 und Dateidialoge.

Core-Tests: `swift test --package-path Packages/RowivoCore`. App- und UI-Tests: in Xcode **Product → Test**. UI-Tests verwenden flüchtige Trainingsdaten. Der Dateitest erzeugt sechs Dateien im lokalen Dateianbieter; dafür einen Simulator ohne Cloud-Anmeldung verwenden und vor Wiederholung einen leeren Testordner wählen.

Prüfstand des vollständigen Einheiten-Editors: **24 Core-, 36 App-/Dateitests und vier betroffene UI-Abläufe erfolgreich**, einschließlich Speichern, Abbrechen und erneutem Öffnen auf Deutsch und Englisch. Der vorherige bereichsübergreifende [App-Review](docs/app-review.md) umfasst zehn UI-Abläufe und beschreibt die verbleibenden Prüfungen. Technische Entscheidungen und Testnachweise: [Implementierungsstand](docs/implementation.md).

## Weitere Entwicklung

Deutsch und Englisch bilden den Start für die internationale App. Als nächste Sprachen sind Spanisch und Französisch, später Portugiesisch und Italienisch vorgeschlagen. Länderfreigabe, Übersetzungen und Support werden getrennt geplant. Rowivo bleibt als Markenname in allen Sprachen gleich.

Nach dem ersten physischen PM5-Test stehen erneute Gerätetests der Korrekturen aus, weitere Bedienungshilfen- und Gerätegrößentests, die Unterlagen für die Veröffentlichung. PM5-Programmierung und eigenständige Watch-Aufzeichnung ohne iPhone bleiben spätere Erweiterungen. Der frühere Chat-Prototyp bleibt außerhalb des App-Targets im [Archiv](docs/archive/ai-prototype/README.md).

## Aktueller TestFlight-Test

Am 23. September 2026 wurde **Version 0.1.0, Build 5** erfolgreich in App Store Connect hochgeladen. Apple hat die Verarbeitung gestartet; die endgültige TestFlight-Verfügbarkeit ist noch nicht bestätigt. Dieser historische Build enthält noch die inzwischen entfernte Jev-Testfunktion. Der aktuelle Quellstand benötigt einen neuen Build. [Release-Nachweis](docs/releases/0.1.0-5.md) und [abhakbare Testcheckliste](docs/releases/0.1.0-5-checklist.html). Monetarisierung ist vorerst zurückgestellt.
