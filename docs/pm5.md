# Concept2 PM5 in Rowivo

Stand: 3. September 2026. Implementiert und mit Protokollfixtures sowie Simulator geprüft. Eine echte Bluetooth-Verbindung zu einem PM5 wurde in dieser Entwicklungsumgebung noch nicht hergestellt.

Seit 4. September unterstützt die gemeinsame Geräteanbindung zusätzlich FTMS. Diese Anleitung bleibt für PM5 gültig; siehe [Rudergeräte](rowers.md).

## Verbindung und Training

1. `Rowivo.xcodeproj` in Xcode öffnen, das eigene Development Team auswählen und die App auf einem echten iPhone mit iOS 18 oder neuer starten.
2. Profil anlegen. Am PM5 **Verbinden / Connect** öffnen. Falls ErgData oder eine andere App verbunden ist, zuerst diese App-Verbindung am PM5 trennen.
3. Unter **Heute → Rudergerät verbinden → Rudergeräte suchen** den Monitor anhand seiner Nummer wählen und den Bluetooth-Zugriff erlauben. Nach erfolgreicher Einrichtung erscheint **Rudergerät verbunden**.
4. Am PM5 **Einfach rudern / Just Row** wählen. Vor dem ersten Zug die geplante Einheit in Rowivo starten. Erst dann rudern.
5. Rowivo zeigt die Trainingsabschnitte am iPhone und die empfangenen PM5-Werte: Distanz, Tempo /500 m, Schläge/min und Leistung. Puls erscheint nur, wenn der PM5 einen gültigen Wert liefert, etwa von einem dort verbundenen Brustgurt.
6. Die Einheit in Rowivo beenden und das Feedback speichern. Unter **Fortschritt** stehen die PM5-Zusammenfassung und die Messpunkte im Verlauf.

Start und Pause in Rowivo steuern nur die App-Aufzeichnung. Der PM5 wird nicht automatisch programmiert, gestartet oder gestoppt. Bei einer manuellen App-Pause werden weiter empfangene PM5-Werte zwar angezeigt, aber nicht zum Trainingsprotokoll addiert. Geplante Erholungsabschnitte gehören weiterhin zur Einheit.

## Was gespeichert wird

- Gerätekennung und angezeigter Gerätename.
- Bis zu ein Messpunkt pro Sekunde mit App-Zeit, PM5-Zeit, Monitorzähler, erfasster Distanz und den jeweils verfügbaren Werten für Tempo, Schlagzahl, Leistung und Puls.
- Summe der tatsächlich beobachteten Distanz- und Zeitänderungen sowie daraus berechnetes Durchschnittstempo.
- Kennzeichnung bei verspätetem Verbinden, Verbindungs-/Messlücke oder Zählerreset. Fehlende Strecken werden nicht nachträglich geschätzt.

Die erste Messung dient als Ausgangspunkt. So werden bereits vor dem App-Start geruderte Meter nicht übernommen. Ein neues Gerät kann erst für die nächste Einheit verwendet werden. Ein reiner manueller Eintrag enthält keine PM5-Daten.

Alle diese Daten werden standardmäßig lokal gespeichert und sind in freiwilligen Dateiexporten für den eigenen Speicher enthalten. KI und Chat sind aus der aktiven App entfernt. Es werden keine Trainingsdaten an einen KI-Anbieter gesendet.

Während einer aktiven Verbindung ist Bluetooth-Empfang im Hintergrund konfiguriert. Beim erzwungenen Beenden der App endet die Verbindung. Gespeicherte Messungen bleiben erhalten; nach dem Neustart muss der PM5 erneut gesucht werden. Zwischenstände werden ungefähr alle fünf Sekunden bei eintreffenden Messungen und zusätzlich bei Pause, Hintergrundwechsel und Abschluss gespeichert. Ein Prozessabbruch kann die letzten circa fünf Sekunden verlieren.

## Noch ausstehender Test mit echtem Gerät

Diese Punkte lassen sich im Simulator nicht belegen:

1. Erstmalige Bluetooth-Freigabe: Die Suche läuft nach dem Erlauben an. Der angezeigte Gerätename passt zum eigenen PM5; dessen Bluetooth-Verbindung wird bestätigt.
2. Zwei Minuten Just Row: PM5 und Rowivo zeigen gleiches Tempo und gleiche Schlagzahl; Leistung wird empfangen. Ohne Brustgurt erscheint kein erfundener Puls. Eine gerätebedingte Aktualisierungsverzögerung von ungefähr einer Sekunde ist möglich.
3. App manuell pausieren, einige Züge rudern, App fortsetzen: Meter während der Pause dürfen nicht zur erfassten App-Distanz zählen.
4. iPhone für etwa eine Minute sperren und weiter rudern: Nach dem Entsperren auf vollständige Messreihe und plausible Distanz prüfen. Dieser Hintergrundtest ist vor einer verlässlichen Nutzung mit gesperrtem Display erforderlich.
5. Verbindung unterbrechen: Bereits erfasste Werte bleiben sichtbar, aktuelle Werte werden nicht als frisch angezeigt. Rowivo versucht bis zu 20 Sekunden erneut zu verbinden. Danach funktioniert die manuelle Suche. Bei Fortsetzung entsteht eine markierte Lücke.
6. PM5-Zähler zurücksetzen: Keine negative oder sprunghaft erhöhte Gesamtdistanz; neue Basis und Lückenhinweis.
7. Teil-Einheit speichern, App schließen und neu öffnen: Zusammenfassung und Messreihe sind vorhanden; die geplante Einheit bleibt offen.
8. Eine laufende Einheit verwerfen und neu starten: Daten der verworfenen Einheit werden nicht übernommen.

Nicht enthalten: Übertragung des Trainingsplans auf den PM5, Import seines Speichers oder Concept2-Logbuch-Sync, automatisches Speichern aufgrund eines PM5-Endstatus, Watch-Pulsmessung und HealthKit. Die [Watch-Companion-App](watch.md) zeigt die vom iPhone empfangenen PM5-Werte an.

## Technische Quellen

- [Concept2 Softwareentwicklung](https://www.concept2.de/support/software-development)
- [Concept2 PM CSAFE Communication Definition, Revision 0.34, Seiten 17–22](https://cms.concept2.de/sites/default/files/2026-03/Concept2%20PM%20CSAFE%20Communication%20Definition.pdf)
- [Concept2: Bedienung des PM5](https://www.concept2.com/support/monitors/pm5/how-to-use)
- [Apple: CoreBluetooth im Hintergrund](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
