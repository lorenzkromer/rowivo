# Rowivo: Dein erster Test nach dem Training

Für Lorenz · 4. September 2026 · etwa 10–15 Minuten

Der heutige Test gilt für den **installierten TestFlight-Build**. Die gerade in Entwicklung befindlichen Änderungen an Profil und Trainingshinweisen sind erst nach Installation eines neuen Builds testbar. Ein fehlender Profil-Editor im heutigen Build ist daher noch kein Fehler.

## Kurz festhalten

- Datum und Uhrzeit: ____________________
- Rowivo-Version / Build (Einstellungen): ____________________
- iPhone / iOS: ____________________
- Watch / watchOS: ____________________
- PM5-Firmware, falls bekannt: ____________________
- Gestartet und gespeichert über: iPhone / Watch
- Bluetooth-Unterbrechung oder gesperrtes Display während des Trainings? ____________________

## 1. Ist deine Einheit wirklich gespeichert?

- [ ] Nach dem Speichern erscheint genau eine Aufzeichnung mit passendem Datum und Uhrzeit.
- [ ] Name, tatsächliche Dauer, Belastung, Beschwerden und Notiz entsprechen deiner Eingabe.
- [ ] Auf **Heute**, in den **Plan-Details** und unter **Fortschritt** findest du dieselbe Einheit mit denselben Angaben.
- [ ] Geplante Dauer und tatsächlich trainierte Dauer sind klar auseinanderzuhalten.
- [ ] Bei vorzeitigem Ende ist die Aufzeichnung als Teileinheit erkennbar; die geplante Vorgabe bleibt offen.
- [ ] Die Watch zeigt nach dem Speichern eine Bestätigung und keine weiterlaufende alte Einheit.
- [ ] Rowivo schließen und erneut öffnen: Die Aufzeichnung ist weiterhin vorhanden. Erst schließen, nachdem das Speichern bestätigt wurde.

## 2. Sind die Messwerte plausibel?

- [ ] Die Geräteaufzeichnung zeigt deinen PM5 und eine plausible Distanz.
- [ ] Die Verlaufsgrafik enthält Messpunkte; Pace, Schlagfrequenz und Leistung passten während des Trainings ungefähr zur Anzeige am PM5.
- [ ] Falls Puls vorhanden ist: Er stammt aktuell vom Rudergerät, zum Beispiel über einen am PM5 verbundenen Brustgurt. Die Watch misst den Puls für Rowivo noch nicht selbst.
- [ ] Falls du die App pausiert und weitergerudert hast: Diese Meter zählen nicht zur aufgezeichneten App-Distanz.
- [ ] Falls die Verbindung länger weg war: Bereits erfasste Daten bleiben vorhanden, Messlücken sind erkennbar, es gibt keinen großen Distanzsprung.

**Ein Unterschied zum PM5-Gesamtzähler ist nicht automatisch ein Fehler:** Rowivo zählt nur beobachtete Zähleränderungen während der laufenden App-Einheit. Vorher geruderte Meter, manuelle App-Pausen und verlorene Verbindungsabschnitte fehlen bewusst. Gerätezeit und App-Dauer können ebenfalls abweichen. Am besten den PM5-Abschlussbildschirm fotografieren, solange er noch verfügbar ist.

## 3. Kannst du einen Tippfehler korrigieren?

- [ ] „Einheit bearbeiten“ öffnen: Alle vorhandenen Angaben sind vorausgefüllt.
- [ ] Probeweise eine Notiz ändern und **Abbrechen**: Der ursprüngliche Eintrag bleibt erhalten.
- [ ] Erneut öffnen, eine echte Korrektur speichern, etwa die Notiz: Derselbe Eintrag wird aktualisiert; es entsteht kein Duplikat.
- [ ] Datum, Uhrzeit, Name, Trainingsart, Dauer, Belastung und Beschwerden sind im Editor erreichbar.
- [ ] Nach erneutem Öffnen und in den anderen Ansichten ist die Änderung sichtbar.
- [ ] Die ursprünglichen Geräte-Messwerte bleiben durch die Bearbeitung unverändert.

Wenn du die Dauer zu Testzwecken verkürzt, kann die Vorgabe wieder als offen erscheinen. Das ist beabsichtigt. Danach die richtige Dauer wiederherstellen. Durch eine Beschwerde-Testangabe kann im heutigen Build ein Check-in erforderlich werden; für den normalen Test reicht eine Notizänderung.

## 4. Hast du eine brauchbare Kopie deiner Daten?

- [ ] Unter **Einstellungen → Deine Daten → Dateien & Cloud-Kopien** einen Export erstellen.
- [ ] Die Kopie enthält `sessions.csv`, eine Datei mit den Geräte-Messpunkten und `training.rowivo`.
- [ ] In `sessions.csv` steht die Einheit mit Trainingsdatum und tatsächlicher Dauer; fehlende Sensorwerte sind leer.
- [ ] Bei Cloud-Speicherung die Dateien in der Dateien-App öffnen. Für den tatsächlichen Upload möglichst auch auf einem zweiten Gerät nachsehen.

Je nach installiertem Build heißt die Messpunktdatei noch `pm5_samples.csv` oder bereits `rower_samples.csv`. Nicht jedes CSV-Programm stellt Kommas und Dezimalpunkte automatisch richtig dar.

**Wiederherstellung und vollständiges Löschen bitte separat testen**, idealerweise auf einem zweiten Gerät bzw. mit einem Testprofil und einer zuvor geprüften Sicherung. Für heute musst du deinen echten Trainingsstand nicht zurücksetzen.

## 5. Was hat dich bei der Bedienung gestört?

- [ ] Musstest du mehrfach tippen, um eine Zeile oder einen Button zu treffen?
- [ ] War klar, ob du den Plan, eine laufende Einheit oder eine gespeicherte Aufzeichnung bearbeitest?
- [ ] Wurde Inhalt von Toolbar, unterer Leiste, Tastatur oder einem Sheet verdeckt?
- [ ] Waren Zahlen auf der Watch während des Trainings lesbar und Buttons gut erreichbar?
- [ ] Gab es einen Moment, in dem du nicht wusstest, ob Speichern oder Pausieren funktioniert hat?

## So schickst du mir einen Fund

**Bereich:** iPhone / Watch / PM5 / Export  
**Was wollte ich machen?** …  
**Meine Schritte:** 1. … 2. … 3. …  
**Erwartet:** …  
**Passiert:** …  
**Immer oder einmalig?** …  
**Screenshot oder Bildschirmaufnahme:** …

Am wichtigsten sind verlorene oder doppelte Aufzeichnungen, falsche Messsummen und eine unklare Speicherbestätigung. Abstände, Texte und kleine Bedienungsdetails kannst du danach gesammelt notieren.

## Erst mit dem nächsten Build

- Profil bearbeiten, abbrechen und speichern; Plan und Verlauf bleiben erhalten.
- Nach kürzlich erfolgtem Training erneut starten: Hinweis bewusst bestätigen oder abbrechen, auf iPhone und Watch.
- Nach bestätigtem Start pausieren, fortsetzen und speichern: keine erneute Ruhetag-Sperre beim Abschluss.
