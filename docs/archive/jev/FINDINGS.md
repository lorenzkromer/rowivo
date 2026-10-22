# Erster Live-Vergleich, 18. September 2026

30 synthetische Fälle, alle API-Aufrufe erfolgreich. Zurückgegebenes Modell:
`jev-1.13.0` (angefragt als `jev-latest`). Keine App-Integration vorgenommen.

| Verfahren | Übereinstimmung mit vorläufigem Soll | Rückfragen |
|---|---:|---:|
| Strukturierte Regeln ohne Textauswertung | 18/30 | 6/30 |
| Jev, direkte Auswahl | 27/30 | 11/30 |
| Jev mit Schwelle 0,8 und Beschwerdeprüfung | 17/30 | 23/30 |

Rückfragen sind ein eigener Ausgang, keine automatisch falsche Antwort. Die Tabelle
zählt sie nur dann als Übereinstimmung, wenn die vorläufige Sollantwort ebenfalls
eine Rückfrage ist. Alle sieben Vorschläge, die die Schwelle passieren, stimmen mit
dem Soll überein. Diese kleine Stichprobe belegt keine Zuverlässigkeit der Schwelle.

## Beobachtungen

- Jev erkennt aktuelle Beschwerden in deutschen und englischen Notizen trotz
  widersprechendem strukturiertem `discomfort: false` (14, 28).
- Verneinte und vergangene Beschwerden werden in den enthaltenen Fällen richtig
  eingeordnet (17–19). Auch die zwei Anweisungsversuche im Freitext ändern die
  erwartete Rohentscheidung nicht (29–30).
- Fall 03: Zwei verfügbare Termine statt drei führen roh zu `keep` (Confidence 0,32),
  erwartet wurde `frequency`.
- Fall 20: Der Wunsch nach zwei statt drei Terminen im Text führt ebenfalls zu
  `keep` (0,28). Strukturierte Verfügbarkeit bleibt im Fall bei drei Terminen.
- Fall 13: Eine explizite Korrektur der Belastungszahl im Text führt zu `clarify`
  (0,33), erwartet wurde `ease`. Hier ist die Rückfrage vertretbar; die Sollantwort
  braucht fachliche beziehungsweise produktseitige Prüfung.
- Die Schwelle 0,8 verwandelt zwölf passende Rohentscheidungen in zusätzliche
  Rückfragen und fängt zwei unpassende `keep`-Entscheidungen ab. Sie wurde vor dem
  Lauf festgelegt und nach Sichtung der Ergebnisse nicht angepasst.

Median der gemessenen Requestdauer: 0,806 Sekunden. Summe: 24,267 Sekunden.
Tokenverbrauch des vollständigen Laufs: 19.685 Input, 1.669 Output. Ein separater
erfolgreicher Zugangstest ist darin nicht enthalten. Geldkosten wurden nicht ermittelt.

## Grenzen und nächster Schritt

Das ist ein Machbarkeitssignal für Feedbackinterpretation, kein Nachweis guter
Trainingspläne. Die Sollantworten sind nicht unabhängig fachlich geprüft. Die Baseline
versteht absichtlich keine Notizen; die Beispiele begünstigen damit den Textversteher.
Profil und Verlauf sind konstant. Mehrwöchige Planung und Planerzeugung wurden nicht
getestet. Einzelne Fälle mischen aktuelle Textkorrekturen mit strukturierten Angaben,
ohne deren zeitliche Priorität ausdrücklich festzulegen.

Vor einer App-Integration: Sollantworten unabhängig prüfen, die zeitliche Bedeutung
von Profil/Verfügbarkeit/Feedback klären und neue zurückgehaltene Fälle ergänzen.
Dann separate Fragen zu Zeit pro Einheit, Terminen pro Woche und wahrgenommener
Belastung gegen diese direkte Gesamtauswahl vergleichen. Schwellen anhand separater
Entwicklungsdaten wählen; nicht diese 30 Fälle gleichzeitig optimieren und als Test
ausgeben. Vorschläge zunächst nur zur manuellen Übernahme anbieten.

## Historische lokale Rohdaten

- `results/20260918-104530-1789721130898260000.json`
- `results/20260918-104530-1789721130898260000.md`

Die hier genannten lokalen Rohdaten und ausführbaren Experimente wurden am 14.10.2026 entfernt. Beim ursprünglichen Lauf waren die Ergebnisse von Git ausgeschlossen. Das JSON enthält Frage, Datensatz-Hash,
Modell, Schwelle, Verteilungen, Tokenverbrauch und Laufzeiten. Der API-Key ist in keinem
Bericht enthalten.
