# Rowivo – App-Review

Stand: 3. September 2026. Review von Einstieg, Heute, Plan und Editor, laufendem Training, Rückmeldung, Verlauf, PM5-Oberflächen, Einstellungen und Dateiabläufen. Die genannten Korrekturen sind umgesetzt; echte Hardware und Cloud-Konten sind davon getrennte Prüfungen.

## Ergänzung: vollständige Bearbeitung gespeicherter Einheiten

Der erste Review hatte den Bedarf zu eng auf das Datum begrenzt. Inzwischen ersetzt **Einheit bearbeiten** den reinen Datumsdialog überall: Heute, Plan-Details und Fortschritt. Bei einer Aufzeichnung ist auch der Stift oben in den Plan-Details verfügbar; bei mehreren Einträgen bietet er eine Auswahl.

Bearbeitbar sind Name, Trainingsart, Datum und Uhrzeit, tatsächliche Dauer, Belastung, Beschwerden und Notizen. Der Dialog übernimmt alle vorhandenen Eingaben und speichert Änderungen im selben Eintrag. Abbrechen verändert nichts. Dauerkorrekturen aktualisieren den Planstatus, Rückmeldungen den Beschwerden-Check-in. Ursprüngliche Planvorgabe und PM5-Messreihen bleiben erhalten. Bearbeitete Aufzeichnungen sind gekennzeichnet.

Die Ergänzung ist mit **24 Core-Tests, 36 App-/Dateitests und vier betroffenen UI-Abläufen** geprüft. Die Persistenztests korrigieren alle Felder manueller, zeitgestoppter und PM5-Aufzeichnungen, öffnen die Datenbank erneut und prüfen den unveränderten Ursprung sowie Datei- und CSV-Kopien. Die UI-Prüfung deckt Abbrechen, Speichern, erneutes Öffnen, Datumskorrektur und dieselbe Aufzeichnung in Heute, Plan und Fortschritt ab. Deutsche und englische Screenshots sind visuell geprüft: [vollständiger Editor](screenshots/completion-editor-de.png), [Rückmeldung und Notizen](screenshots/completion-feedback-de.png), [gespeicherte Korrektur](screenshots/completion-corrected-en.png). Testnachweise stehen im letzten Abschnitt von [implementation.md](implementation.md). Signing und General sind unverändert.

## Behobene Unstimmigkeiten

| Bereich | Befund | Ergebnis |
|---|---|---|
| Plan und tatsächliches Training | Nach dem Speichern blieb nur die Sollzeit sichtbar. | Planzeilen nennen die geplante und zuletzt aufgezeichnete Dauer. Die Details zeigen Aufzeichnungen und ursprünglichen Ablauf getrennt. |
| Mehrere Aufzeichnungen | Eine teilweise absolvierte Einheit blieb offen, ohne dass ihre Ergebnisse im Plan sichtbar waren. | Alle zugehörigen Aufzeichnungen erscheinen einzeln. Die Übersicht nennt ihre Anzahl; ein Hinweis erklärt, wann die Einheit weiter offen bleibt. |
| Datum bearbeiten | Die Aktion war ausschließlich im Verlauf verfügbar. | Bei jeder Aufzeichnung in Heute, Plan-Details und Fortschritt führt „Einheit bearbeiten“ zum gemeinsamen Editor. Er unterstützt auch ältere Einträge, Timer- und PM5-Aufzeichnungen. |
| Heute | Das nächste Training konnte mit den zuletzt gespeicherten Ergebnissen verwechselt werden. | „Als Nächstes geplant“ und „Zuletzt aufgezeichnet“ zeigen getrennte Inhalte. |
| Rückmeldung | Planintensität und subjektive Belastung waren nicht klar unterschieden; ein Text suggerierte automatische Anpassungen. | „Zielintensität“ bezeichnet die Vorgabe, „Deine Belastung“ die Selbsteinschätzung. Beim Nachtragen sind Sollzeit und tatsächliche Dauer sichtbar. |
| Zeitangaben | Die Summe im Verlauf schnitt Sekunden ab; ein Ruhehinweis versprach pauschal „morgen“. | Die Gesamtzeit behält Sekunden. Hinweise verwenden das berechnete nächste Trainingsdatum. Die Diagrammachse zeigt auch bei einer einzelnen Einheit Kalendertage statt Uhrzeiten. |
| Logo | Im Toolbar-Element fehlte seitlicher Innenabstand. | Je zwölf Punkte horizontaler Innenabstand und acht Punkte zwischen Symbol und Schrift. |
| Profil und Daten | Kein vollständiger lokaler Neustart verfügbar. | Einstellungen bieten eine bestätigte Löschaktion mit Rückkehr ins Onboarding. Auch Wiederherstellungskopien, temporäre Exporte, frühere Zugangsdaten, Gerätecache und aktive Einheiten werden entfernt. |

## Verhalten nach dem Review

- Geplante Einheiten sind eine Reihenfolge, bisher ohne festen Kalendertermin. Beim Nachtragen wird das tatsächliche Datum gewählt; bei Aufzeichnungen lässt es sich anschließend korrigieren.
- Im gemeinsamen Editor lassen sich auch Dauer, Belastung und weitere Angaben ändern. Die ursprünglichen PM5-Messzeitpunkte bleiben erhalten. Sortierung, Ruhezeit und Check-in beziehen sich auf das korrigierte Trainingsdatum.
- Eine Einheit mit Aufzeichnungen behält ihre ursprüngliche Definition. Für geänderte Vorgaben kann sie dupliziert werden. Das schützt den Soll-Ist-Vergleich.
- Während einer laufenden oder pausierten Einheit sind Datums- und Planänderungen gesperrt; die Oberfläche erklärt das. Der bestätigte vollständige Reset entfernt auch ein aktives Training.
- Eine Aufzeichnung unterhalb der Sollzeit bleibt eine Teileinheit. Erst eine vollständig absolvierte Einheit schließt die Vorgabe ab. Mehrere Teileinheiten werden nicht automatisch zusammengerechnet.
- Die Löschaktion entfernt Daten in Rowivo. Selbst exportierte Kopien bleiben im gewählten Speicher erhalten; der Dialog nennt diese Grenze ausdrücklich. Beim neuen Einstieg sind Cloud-Kopien wieder ausgeschaltet.

## Verifikation

- **24 Core-Tests erfolgreich**: Modelle, Planregeln, Timer, CSV und PM5-Parser (`app-review-core-output.log`).
- **31 App-/Dateitests erfolgreich**: echte Persistenz, Datumsänderungen, mehrere Aufzeichnungen pro Planvorgabe, Dateisicherungen, Reset einschließlich aktiver PM5-Daten, Löschfehler und Wiederholung (`build/RowivoAppReviewValidation.xcresult`, App-Test-Suite). In diesem ersten Lauf benötigten zwei neue UI-Selektoren eine Anpassung an die native iOS-26-Hierarchie; die App-Tests waren vollständig erfolgreich.
- **10 UI-Abläufe erfolgreich** (`build/RowivoAppReviewUI.xcresult`): neuer Einstieg und manueller Plan, deutscher Editor und Intervalle, Plan-Tippflächen, Scrollen, Nachtragen mit Datumskorrektur und Abbruch, 27 tatsächliche gegenüber 30 geplanten Minuten, dieselbe Aufzeichnung über Heute/Plan/Fortschritt, Timer, PM5-Einstieg, Wiederherstellungsdialog und Reset mit neuem Profil. Die Datumskorrektur und der Reset sind nach der abschließenden Darstellungskorrektur erneut erfolgreich (`build/RowivoAppReviewFinalDates.xcresult`, zwei Tests).
- Der einmalige Export durch den nativen Dateianbieter wurde in dieser Runde nicht erneut ausgeführt. Der vorhandene Nachweis bleibt in `docs/file-storage.md`; die koordinierten Datei-, Sicherungs- und Reset-Tests sind erneut erfolgreich.
- Neue Texte sind vollständig auf Deutsch und Englisch vorhanden. Die Screenshots wurden visuell geprüft. Signing, General, Projektdatei, geteilte Schemes, Info.plist und Projektvorlage sind per Prüfsummenvergleich unverändert; es gab keine Projektgenerierung.

Screenshots: [Soll-Ist-Vergleich](screenshots/review-plan-actual-en.png), [deutsche Trainingsdetails](screenshots/review-plan-actual-de.png), [Logo-Abstand](screenshots/review-today-de.png), [letzte Aufzeichnung auf Heute](screenshots/review-today-recorded-en.png), [Löschbestätigung](screenshots/review-delete-de.png), [erneutes Onboarding](screenshots/review-onboarding-de.png), [korrigierter Verlauf](screenshots/review-history-en.png).

## Verbleibende Prüfungen und Produktgrenzen

- Concept2 PM5: echter Verbindungsaufbau, Funkabbrüche, Sperrbildschirm und Hintergrundempfang auf iPhone und PM5 müssen vor Veröffentlichung geprüft werden. Simulator- und Parserprüfungen ersetzen das nicht.
- Eigene Cloud: echte iCloud-, Google-Drive- und OneDrive-Erweiterungen, dauerhafte Ordnerfreigaben und Uploads auf einem zweiten Gerät bleiben zu prüfen. Bisherige Kopien sind Sicherungen, keine Gerätesynchronisierung.
- Bedienungshilfen und Layout: VoiceOver, große Schrift sowie weitere iPhone-Größen benötigen einen eigenen Durchgang. Der aktuelle visuelle Durchgang verwendet Deutsch und Englisch auf dem iPhone-17-Pro-Simulator.
- Profiländerungen nach dem Einstieg und das Löschen einzelner Verlaufseinträge sind noch nicht umgesetzt.
- Frei terminierbare geplante Einheiten, weitere Sprachen, HealthKit und Apple Watch sind zusätzliche Produktarbeit. Der KI-Zugang bleibt aus der App entfernt.

Signing, General, geteilte Schemes, Info.plist und Projektvorlage werden bei diesem Review nicht verändert.
