# Rudergeräte verbinden

Stand: 4. September 2026. Rowivo unterstützt zwei Anbindungen: Concept2 PM5 und Bluetooth FTMS Rower Data. Die FTMS-Implementierung ist mit Protokollfixtures geprüft; eine Kompatibilitätszusage für einzelne Geräte gibt es erst nach einem Test am jeweiligen Modell und Firmwarestand.

## Einrichtung

1. Rowivo auf einem echten iPhone öffnen. Bluetooth funktioniert nicht im Simulator.
2. Am Gerät die Bluetooth-Verbindung aktivieren, beim PM5 **Verbinden / Connect** öffnen. Andere verbundene Trainings-Apps gegebenenfalls trennen.
3. **Heute → Rudergerät verbinden → Rudergeräte suchen** öffnen, den Bluetooth-Zugriff erlauben und das Gerät auswählen. Alternativ: **Einstellungen → Dein Rudergerät**.
4. Freies Rudern am Gerät wählen, beim PM5 **Einfach Rudern / Just Row**. Die Einheit in Rowivo starten und rudern.
5. Anschließend speichern. Die Geräteaufzeichnung bleibt bei der Einheit unter Heute, Plan und Fortschritt erreichbar.

Die Suche zeigt PM5-Kandidaten sowie Geräte, die den FTMS-Dienst anbieten. FTMS wird auch für andere Fitnessgeräte verwendet. Rowivo prüft deshalb beim Verbinden, ob die Rower-Data-Characteristic Benachrichtigungen unterstützt. Andernfalls erscheint ein entsprechender Hinweis. Geräte mit ausschließlich einem herstellereigenen Protokoll werden nicht automatisch unterstützt; Bluetooth allein genügt nicht. Ein PM5 mit beiden Diensten verwendet weiterhin die Concept2-Anbindung.

Rowivo steuert den Ablauf auf dem iPhone, weder Geräteprogramme noch Widerstand. Bei manueller Pause werden neue Messwerte nicht zur Aufzeichnung addiert. Die Watch erhält die verfügbaren Werte über das iPhone. Watch-Pulsmessung und HealthKit sind weiterhin nicht enthalten.

## Messwerte und Speicherung

Distanz, Gerätezeit, Pace /500 m, Schlagfrequenz, Leistung und Puls werden übernommen, soweit das Gerät sie sendet. FTMS-Schlagfrequenz behält halbe Schläge pro Minute; die übermittelte Schlaganzahl wird ebenfalls gespeichert. Nicht verfügbare Werte erscheinen als **—** und bleiben im CSV leer. Gerätezeit wird nicht durch die App-Zeit ersetzt. Distanz wird nicht aus Pace oder Leistung hochgerechnet. Auch Einheiten mit ausschließlich Schlagdaten lassen sich speichern.

Vor Trainingsbeginn vorhandene Zählerstände zählen nicht mit. Nur aufeinanderfolgende empfangene Änderungen während des laufenden App-Timers werden addiert. Bei Pause, Verbindungsabbruch, Zählerreset oder Neustart wird eine neue Ausgangsmessung verwendet. Verlorene Abschnitte werden nicht geschätzt. Durchschnittspace benötigt sowohl Distanz als auch Gerätezeit über dieselben Messabschnitte.

Daten bleiben lokal und können in eigene Dateien exportiert werden. Dateiformat **5** verwendet herstellerneutrale `device_*`-Spalten und `rower_samples.csv`; die Spalte `source` unterscheidet `pm5`, `ftms`, `manual` und `app_timer`. Bestehende PM5-Aufzeichnungen und Sicherungen der Versionen 1–4 bleiben lesbar. Ältere App-Versionen können neue Sicherungen nicht importieren. Details: [Dateiformat](file-storage.md).

## Technische Umsetzung

- `RowerConnection` in der bestehenden Projektdatei `PM5Connection.swift`: Discovery, Protokollauswahl, Subscriptions, Timeout, Reconnect, Gerätebindung je Einheit. Die Dateien bleiben an ihren bisherigen Projektpfaden; keine Projektregenerierung nötig.
- `RowerSnapshot` / `RowerRecording`: gemeinsame optionale Messwerte und Protokollherkunft. Die historischen JSON-Schlüssel `pm5` und `currentPM5Recording` bleiben aus Kompatibilitätsgründen bestehen; bei fehlender Herkunft gilt Concept2.
- FTMS: Service `1826`, Characteristic `2AD1`, ausschließlich Notifications; keine Control-Point-Schreibzugriffe. Variable Felder werden anhand der Flags dekodiert, alle Feldbreiten und die Gesamtlänge geprüft. Widerstand belegt gemäß aktuellem GATT Supplement ein Byte.
- Mehrteilige Records werden bis `More Data = 0` zusammengesetzt. Veraltete, beschädigte oder widersprüchliche Fragmente werden nicht mit neuen Werten vermischt. Optionale Werte werden nicht in den nächsten Record übernommen.
- Vorhandene Concept2-Parser und Messwertpaarung bleiben erhalten. Der PM5 erhält weiterhin die vorhandene 1-Hz-Konfiguration.

## Test am echten Gerät

Für PM5 weiterhin die [PM5-Prüfanleitung](pm5.md) verwenden. Für jedes FTMS-Modell Modellname und Firmware notieren und Folgendes prüfen:

1. Finden, Verbinden und welche Messwerte tatsächlich angeboten werden.
2. Zwei Minuten rudern: angezeigte Pace, Schlagfrequenz, Leistung und Puls mit dem Gerät vergleichen. Schon vor App-Start vorhandene Meter dürfen nicht mitgezählt werden.
3. App pausieren, weiter rudern, fortsetzen: Pausenmeter fehlen in der aufgezeichneten Strecke.
4. Verbindung unterbrechen und erneut herstellen; Gerät zurücksetzen: keine negativen oder sprunghaft erhöhten Gesamtsummen, Lücke sichtbar.
5. iPhone sperren und weiterrudern: nach Entsperren Messreihe und Watch-Anzeige prüfen. Hintergrundverhalten muss am echten Gerät bestätigt werden.
6. Speichern, App neu öffnen, CSV exportieren und Sicherung wiederherstellen: Protokollherkunft und fehlende Werte bleiben korrekt.
7. Falls vorhanden, ein FTMS-Fahrrad auswählen: ohne Rower Data darf es nicht als verbundenes Rudergerät akzeptiert werden.

## Primärquellen

- [Bluetooth Fitness Machine Service 1.0](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/), Abschnitte 4.8 und 4.19.
- [Bluetooth GATT Specification Supplement](https://btprodspecificationrefs.blob.core.windows.net/gatt-specification-supplement/GATT_Specification_Supplement.pdf), Stand 2026-02-05, Abschnitt 3.212.
- [Bluetooth Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/index-en.html).
