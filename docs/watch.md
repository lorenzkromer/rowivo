# Rowivo auf Apple Watch

Stand: 4. September 2026. Die erste Companion-Version benötigt iOS 18 und watchOS 11 oder neuer. Oberfläche: Deutsch und Englisch.

## Verwenden

1. Rowivo auf dem iPhone einrichten und einen Trainingsplan anlegen.
2. Rowivo über die Watch-App des iPhones auf der gekoppelten Apple Watch installieren. Für die Entwicklung in Xcode das Scheme **RowivoWatch** und die gekoppelte Watch auswählen; die iPhone-App ebenfalls installieren/starten.
3. Rowivo auf beiden Geräten öffnen. Unter **Heute → Einstellungen → Apple Watch** zeigt das iPhone den Verbindungsstatus und bietet eine Synchronisierung an.
4. Auf der Watch die nächste Einheit starten. Abschnitt, verbleibende Zeit und Gesamtfortschritt verfolgen, pausieren oder fortsetzen.
5. **Einheit beenden** pausiert zuerst die Aufzeichnung am iPhone. Danach die Belastung direkt über die fünf Zahlen 1–5 wählen, Beschwerden und optional eine Notiz eingeben und speichern. Der Zurück-Pfeil führt zur pausierten Einheit. Ganz unten lässt sich die aktuelle Aufzeichnung einschließlich ihrer PM5-Daten nach Bestätigung löschen; Plan und frühere Aufzeichnungen bleiben erhalten. Alle Angaben lassen sich anschließend mit dem bestehenden Einheiten-Editor am iPhone korrigieren.

Kürzere Aufzeichnungen werden als Teil-Einheit gespeichert; die geplante Einheit bleibt offen. Ruhetage und der bestehende Beschwerden-Check-in gelten auch beim Start über die Watch.

Das iPhone bleibt in der Nähe und übernimmt Speicherung und PM5-Verbindung. PM5-Distanz, Tempo, Schlagzahl und der vom PM5 gemeldete Puls werden bei Verfügbarkeit angezeigt. Die Watch misst weiterhin keinen eigenen Puls. Der optionale native Trainingsmodus verwendet jetzt HealthKit; Details stehen unten. Start/Pause steuern Rowivos Timer, nicht den PM5. Der Monitor bleibt im Modus **Just Row**.

## Verbindung und Daten

`Shared/WatchTransport.swift` kapselt Apples WatchConnectivity. `updateApplicationContext` überträgt den neuesten Zustand für spätere Zustellung; unmittelbare Nachrichten liefern Live-Werte und bestätigte Steueraktionen. Die Watch aktualisiert bei geöffneter App alle fünf Sekunden. PM5-Livewerte werden höchstens einmal pro Sekunde gesendet.

Die Watch erhält nur die nächste/aktive Einheit, Timerzustand und aktuelle PM5-Werte. Der vollständige Verlauf und das Profil bleiben auf dem iPhone. Eine lokale Kopie des letzten Trainingszustands ermöglicht die Anzeige ohne Verbindung. Beim Löschen des Profils überträgt das iPhone einen leeren Zustand; die Watch entfernt ihre Kopie, sobald sie diesen empfängt. Eine ausgeschaltete oder getrennte Watch kann bis dahin noch den letzten Zustand anzeigen.

Ohne aktuellen Kontakt sind Steueraktionen gesperrt. Der Timer rechnet mit dem zuletzt bestätigten Zeitanker lokal weiter, bis maximal zum Planende. Messwerte bleiben als letzter Stand gekennzeichnet. Eine zwischenzeitliche Pause am iPhone wird beim nächsten Sync abgeglichen. Es werden keine Offline-Steueraktionen für spätere Ausführung eingereiht. Aktionen enthalten eine Anfragen-ID, die konkrete Einheit, einen Zustands-Token und einen Zeitstempel. Das iPhone lehnt veraltete Aktionen, falsche Einheiten und ungültiges Feedback ab. Planänderung, Timeränderung, Zurücksetzen und ein iPhone-App-Neustart machen frühere Steuerzustände ungültig. Wiederholte Anfragen derselben ID erhalten innerhalb des begrenzten Empfangscaches dasselbe Ergebnis.

Die Watch bestätigt Änderungen erst nach einer Antwort des iPhones. Nach einem Zeitlimit zeigt sie eine fehlende Bestätigung; vor erneutem Versuch soll der Zustand am iPhone geprüft werden. Die Speicherung verwendet denselben transaktionalen Pfad wie die iPhone-Oberfläche und erhält vorhandene PM5-Messreihen. Hintergrund-/Bluetooth-Verfügbarkeit wird durch iOS bestimmt. Haptische Abschnittshinweise funktionieren bei aktiver Watch-Oberfläche; eine Hintergrund-Workout-Session wird noch nicht gestartet.

## Prüfung

- 27 Core-Tests: unter anderem Nachrichtenformat, Größen-/Versionsgrenzen, Timer und Messwertalter.
- 42 App-/Dateitests: einschließlich Watch-Start/Pause/Fortsetzen/Speichern, Wiederöffnen der Datenbank, veralteter Aktionen, Reset, Ruhetag/Check-in und Erhalt der PM5-Aufzeichnung.
- Zwei betroffene iPhone-UI-Abläufe: vollständiges Bearbeiten gespeicherter Einheiten sowie Timer/Pause/Fortsetzen.
- Vier Watch-UI-Abläufe mit isolierten Darstellungsdaten: nächste Einheit, aktives Training, gesperrte Offline-Steuerung und Einrichtungshinweis auf Deutsch/Englisch.
- Ein vollständiger Ablauf über echte WatchConnectivity zwischen gekoppelten Simulatoren: nächste Einheit empfangen, starten, pausieren, fortsetzen, beenden und Speichern vom iPhone bestätigen lassen. Erfolgreich: `build/RowivoWatchConfirmationFinal.xcresult`, einschließlich sichtbarer Speicherbestätigung nach Rückkehr aus dem Feedback.

Testnachweise: `build/RowivoWatchPhoneValidation.xcresult`, `build/RowivoWatchPairedValidation.xcresult` (vier UI-Tests erfolgreich, opt-in Verbindungstest übersprungen), `watch-core-final-output.log`. Darstellungs-Fixtures prüfen keine Funkverbindung. `testPairedPhoneSessionRoundTrip` ist deshalb ein eigener opt-in Test: nur mit `ROWIVO_LIVE_PAIR=1` und zuvor explizit gestarteter iPhone-App mit `--uitesting --seed-profile --enable-watch-connection`. Diese Flags verwenden eine flüchtige Datenbank. Ein gewöhnlicher Testlauf überspringt diesen Test.

Der Verbindungstest fand einen Swift-6-Threadingfehler in den WatchConnectivity-Antwort-Closures. Explizit `@Sendable` markierte Callbacks wechseln jetzt innerhalb eines Tasks zum MainActor; anschließend war der vollständige Ablauf erfolgreich. Nach einem Neustart des gekoppelten Simulator-Paars war die zuvor ausbleibende Live-Erreichbarkeit wieder vorhanden. Der UI-Test wartet vor Folgeaktionen auf die Bestätigung und Freigabe des jeweiligen Knopfs.

Visuell geprüfte Screenshots: [Nächste Einheit](screenshots/watch-ready-de.png), [Training](screenshots/watch-active-en.png), [Offline-Steuerung](screenshots/watch-offline-de.png), [Speichern über das gekoppelte iPhone](screenshots/watch-saved-paired-en.png).

## Noch am echten Gerät prüfen

- Installation und Erstverbindung mit Lorenz' Signing-Team, Watch und iPhone.
- Start, Pause, Fortsetzen, Feedback und Wiederöffnen der gespeicherten Einheit.
- PM5 während laufender Einheit, Displaysperre und Handgelenk-Absenken; keine nachträgliche Schätzung fehlender Messwerte.
- Bluetooth-/Watch-Verbindungsunterbrechung und Wiederverbindung; keine verspätete Steuerung einer neuen Einheit.
- Änderungen am iPhone bei offenem Watch-Feedback und Profil-Reset mit zeitweise getrennter Watch.
- Kleine Watch-Displays, große Schrift und VoiceOver.

## Xcode-Einstellungen

Das vorhandene Projekt wurde um das Watch-App-Target, sein UI-Test-Target, das Einbetten der Watch-App und das Scheme **RowivoWatch** erweitert. Vor der Generierung wurden die bisherigen Einstellungen abgeglichen und unter `build/watch-project-before/` gesichert. Bestehende Debug-/Release-Einstellungen, iPhone-Info.plist und das ursprüngliche Rowivo-Scheme bleiben erhalten. `scripts/check-project-settings.py` prüft weiterhin die Übereinstimmung mit `project.yml` ausschließlich in einer temporären Kopie.

## Rückblick: direkte Auswahl und Verwerfen

Die Belastung verwendet fünf direkt antippbare Zahlen mit ausgewähltem Zustand für VoiceOver und einer ausgeschriebenen Beschreibung. Der Zurück-Pfeil schließt den Rückblick und belässt die Einheit pausiert. **Aufzeichnung löschen** steht als dezente Aktion unten und öffnet die native watchOS-Bestätigung. Erst die bestätigte `discard`-Anfrage verwirft die pausierte Aufzeichnung samt aktuellen PM5-Daten auf dem iPhone. Dafür gelten dieselben Schutzregeln gegen veraltete Zustände wie beim Speichern. Bereits gespeicherte Einträge und der Plan werden nicht verändert. Beide Apps müssen für diese neue Aktion aktualisiert sein.

Prüfung dieser Ergänzung: 27 Core-Tests und sieben Watch-Speichertests erfolgreich (`watch-feedback-core-output.log`, `build/WatchFeedbackPhoneFinal.xcresult`). Die beiden Verbindungstests für Verwerfen und vollständiges Speichern sind in `build/WatchFeedbackPairedFinal.xcresult` erfolgreich. Der dort zunächst mehrdeutige UI-Testselektor für den nativen Zurück-Knopf wurde korrigiert; Auswahl, Abbrechen der Löschbestätigung und Zurück-Navigation sind anschließend auf der 40-mm-Watch vollständig erfolgreich (`build/WatchFeedbackSmallUI.xcresult`). Screenshots: [49 mm](screenshots/watch-feedback-de.png), [40 mm](screenshots/watch-feedback-small-de.png). Für diese Ergänzung wurde kein Projekt generiert und keine Signing-/General-Einstellung geändert.

## Allgemeine Rudergeräte (4. September 2026)

Die Watch zeigt jetzt verfügbare PM5- oder FTMS-Messwerte unter „Rudergerät live“. Fehlende Distanz bleibt „—“, FTMS-Schlagfrequenz behält halbe Schläge. Die Verbindung zum Rudergerät läuft weiterhin über das iPhone. Beide Apps sollten zusammen aktualisiert werden. Siehe [Geräteanbindung](rowers.md).

## Weitere Einheit nach kurzem Abstand

Die ehemalige Ruhetag-Sperre ist nun ein bestätigbarer Hinweis. „Starten“ öffnet bei kürzlichem Training den nativen Dialog; „Trotzdem starten“ sendet eine ausdrücklich bestätigte Anfrage für den angezeigten Datenstand. Abbrechen startet nichts. Ein veralteter Dialog, eine getrennte Watch oder der weiterhin separate Beschwerden-Check-in können dadurch nicht übergangen werden. Nach erfolgreichem Start gelten normale Pause-, Fortsetzen- und Speicherfunktionen. Diese Änderung benötigt den nächsten Build auf beiden Geräten.

## Rückmeldungen aus dem ersten Training

- Der Watch-Timer tickt lokal statt bei fehlendem Live-Kontakt einzufrieren. Ein Refresh läuft nach acht Sekunden ab; ein verspäteter Callback kann keine neuere Anfrage überschreiben. Frische Push-Nachrichten zählen als Kontakt, alte Anwendungskontexte nicht.
- **Trainingsmodus aktivieren** fragt einmalig nach Schreibzugriff für Workouts in Apple Health. Eine echte `HKWorkoutSession` für Indoor-Rudern hält die Watch im Workout-Lebenszyklus. Die Freigabe ist optional. Es wird kein Lesezugriff auf die Health-Historie angefordert und kein eigener Watch-Puls übernommen.
- Bei aktiviertem Modus Rowivo auf der Watch öffnen. Eine laufende Einheit startet eine native Session ab diesem Zeitpunkt, nicht rückwirkend. Bestätigtes Speichern auf iPhone oder Watch speichert auch diese Watch-Aufzeichnung in Health; Verwerfen verwirft sie. Bei einer später geöffneten Watch enthält Health nur den dort erfassten Teil. Die Rowivo-Aufzeichnung bleibt auf dem iPhone maßgeblich.
- Manuelle und automatische Timerpausen werden an die native Session weitergegeben. Am Planende endet deren Laufzeit. Bei ausbleibender Verbindung lässt sich die lokale Watch-Aufzeichnung explizit verwerfen; die iPhone-Einheit wird dadurch nicht beendet.
- Phasenwechsel verwenden die native Watch-Benachrichtigungshaptik und den zugehörigen Systemton, soweit die Watch-Einstellungen Ton erlauben. Der iPhone-Ton lässt sich separat in den Einstellungen abschalten.
- Bereits gespeicherte Apple-Health-Workouts bleiben bei einem Rowivo-Profilreset erhalten. Die Health-Freigabe wird in den Systemeinstellungen verwaltet.

Neu im Watch-Target: HealthKit-Entitlement, Health-Zwecktexte und `WKBackgroundModes = workout-processing`. Bestehende Team-, Bundle-, Versions- und General-Einstellungen bleiben erhalten; es wurde kein Arbeitsprojekt regeneriert. Das Verhalten bei gesenktem Handgelenk und die Health-Berechtigung müssen am echten Gerät geprüft werden.

Apple-Referenzen: [Workout-Sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), [Hintergrund-Sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions).
