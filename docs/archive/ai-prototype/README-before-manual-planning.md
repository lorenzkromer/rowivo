# Rowivo

Eine iPhone-App für individuelles Rudertraining mit einem persönlichen KI-Coach. Nutzer erarbeiten im Gespräch ihren Trainingsplan und entwickeln ihn anhand ihrer Trainingsdaten und Rückmeldungen weiter. Concept2 PM5 liefert per Bluetooth die Messwerte; Apple Watch ist als weitere Anbindung geplant.

Der Name **Rowivo** wurde am 3. September 2026 festgelegt. Die App soll international und für mehrere Nutzer angeboten werden.

## Projektgrundlage

Das [Originalkonzept vom 2. September 2026](docs/konzept.md) enthält den ursprünglichen Trainingsplan und die erste Produktidee. Es ist unverändert als Ausgangspunkt abgelegt. Dieses README bildet die anschließend besprochene Produktrichtung ab: KI-Coaching, individuelle Pläne und internationale Veröffentlichung. Der Achtwochenplan dient als Startvorlage.

Stand: **Erster nativer iOS-Prototyp implementiert und im Simulator geprüft** (3. September 2026).

## App starten

1. `Rowivo.xcodeproj` in Xcode öffnen.
2. Scheme **Rowivo** und einen iPhone-Simulator auswählen, dann Run starten.
3. Für ein echtes iPhone ist Lorenz' Development Team bereits hinterlegt. Mindestversion: iOS 18.

Die Oberfläche ist auf Deutsch und Englisch verfügbar. Ohne API-Schlüssel funktionieren Profil, Trainingsplan, Timer, PM5-Aufzeichnung, manuelle Einträge und Verlauf. Für den echten Coach in **Einstellungen → Deine Coach-Verbindung** einen eigenen Anthropic-API-Schlüssel hinterlegen und die beschriebene Datenweitergabe aktivieren. Der Schlüssel liegt im iPhone-Schlüsselbund; die API-Nutzung wird über das eigene Anthropic-Konto abgerechnet. Standardmodell ist `claude-sonnet-4-6`, in den Einstellungen änderbar.

Die aktuelle direkte API-Anbindung ist für den persönlichen Prototyp gedacht. Ein öffentlich nutzbares Backend mit Anmeldung und Nutzungslimits ist noch nicht implementiert.

Für einen Zugang ohne API-Schlüssel empfehlen wir einen über Rowivo bereitgestellten Coach. Die geprüften Möglichkeiten einer Claude-/ChatGPT-Kontoverknüpfung und ihre Grenzen stehen in [Coach-Zugang](docs/coach-access.md).

## Implementierter Umfang

- Profil mit Ziel, Erfahrung, zwei oder drei Einheiten je Block und 15–60 Minuten Zeitbudget.
- Acht Trainingsblöcke mit Einrudern, Arbeitsphasen, Pausen und Ausrudern; Zeitbudget inklusive aller Abschnitte.
- Tagesübersicht, vollständiger Plan, Einheitenansicht und Timer mit Pause und Fortsetzung. Der Timerzustand überlebt einen App-Neustart.
- Concept2 PM5 per CoreBluetooth: Geräteauswahl, Live-Distanz, Tempo /500 m, Schlagzahl, Schlagleistung und Puls, sofern am PM5 verfügbar. Automatischer Wiederverbindungsversuch bei Abbruch.
- Lokale PM5-Messreihen, erfasste Distanz, Durchschnittstempo und Verlaufsgrafik pro Einheit. Pausen und Messlücken werden berücksichtigt.
- Manuelle und zeitgestoppte Trainingsprotokolle, Belastungsfeedback, Beschwerden und Notizen. Teil-Einheiten schließen das geplante Training nicht ab.
- Ruhetag zwischen Trainings; nach gemeldeten Beschwerden ist zusätzlich ein persönlicher Check-in erforderlich.
- Anthropic-Chat mit ausgewähltem Trainingskontext, verständlichen Verbindungsfehlern und erneutem Senden.
- Vier geprüfte KI-Vorschläge: nächste Einheit kürzen, nächste Einheit lockerer gestalten, letzten abgeschlossenen Block wiederholen oder Häufigkeit auf zwei Einheiten reduzieren. Übernahme erfolgt erst nach Bestätigung; alte Vorschläge können geänderte Pläne nicht überschreiben.
- SwiftData-Speicherung von Profil, Planversionen, Chat, Trainingsverlauf und laufender Einheit; Schlüssel separat im Keychain.
- Optionaler Export in eigene lokale/Cloud-Ordner: vier CSV-Tabellen und eine JSON-Trainingssicherung, manuell oder nach gespeicherten Einheiten/Planänderungen. Einmaliger Dateiexport ohne gemerkten Ordner und Wiederherstellung mit Vorschau und lokaler Rückfallkopie.
- Verlaufsgrafik, Planänderungsverlauf, App-Icon und deutsche/englische Texte einschließlich Bluetooth-Berechtigung.

Die Startvorlage berücksichtigt Zeitbudget und Häufigkeit. Ziel und Erfahrung stehen dem Coach zusätzlich als Kontext zur Verfügung. Freie KI-Erzeugung beliebiger Trainingsprogramme ist noch nicht enthalten. Der Prototyp verwendet keine festen Pulszonen, Kalorien- oder Gewichtsverlustversprechen und keine automatischen harten Belastungssteigerungen. Die ursprüngliche Vorlage wurde dafür vereinfacht; sie ist nicht sportmedizinisch validiert.

Apple Watch, HealthKit, öffentliche Konten und weitere Sprachen folgen in späteren Schritten.

## Mit deinem Concept2 PM5 trainieren

1. Rowivo auf einem echten iPhone starten. Im Simulator ist Bluetooth nicht verfügbar.
2. Am PM5 **Verbinden / Connect** öffnen; gegebenenfalls die Verbindung zu ErgData oder einer anderen App trennen.
3. In Rowivo unter **Heute → PM5 verbinden → Meinen PM5 suchen** den Monitor anhand seiner Nummer auswählen. Bluetooth beim ersten Mal erlauben. Die Verbindung ist auch in der Trainingsansicht über das Funksymbol erreichbar.
4. Am PM5 **Einfach rudern / Just Row** wählen, die Einheit in Rowivo starten und losrudern.
5. Am Ende das Feedback speichern. Die erfassten PM5-Werte erscheinen unter **Fortschritt → PM5-Aufzeichnung ansehen**.

Rowivo führt die Abschnitte am iPhone. Der Plan wird noch nicht auf den PM5 programmiert; Start/Pause in Rowivo steuert den Monitor nicht. Aufgezeichnet werden nur empfangene Zähleränderungen während der laufenden App-Einheit. Verspätete Verbindung, Unterbrechung und Zählerreset werden als Lücke markiert; fehlende Meter werden nicht geschätzt. Bei Abbruch wird bis zu 20 Sekunden erneut verbunden, danach ist eine manuelle Suche möglich.

PM5-Messwerte werden standardmäßig lokal gespeichert. Sie sind in freiwilligen Dateiexporten enthalten und werden nicht automatisch an Anthropic gesendet. Eine aktive Verbindung darf im Hintergrund Messdaten empfangen. Erzwungenes Beenden der App beendet die Funkverbindung; beim Wiederöffnen bleiben gespeicherte Werte erhalten und es muss erneut verbunden werden.

Die Bluetooth-Implementierung ist gebaut und mit Protokollfixtures geprüft. Der vollständige Funk- und Sperrbildschirmtest mit einem echten iPhone und PM5 steht noch aus; siehe [PM5-Prüfanleitung](docs/pm5.md).

## Eigene Cloud und CSV

Unter **Einstellungen → Deine Daten → Dateien & Cloud-Kopien** einen Ordner in iCloud Drive, auf dem iPhone oder bei einem in der Dateien-App aktivierten Anbieter auswählen. Google Drive und Microsoft OneDrive werden über deren iOS-Dateianbieter angesprochen; Installation, Anmeldung und unterstützte Dateifunktionen liegen beim Anbieter.

Der Export enthält `profile.csv`, `plan.csv`, `sessions.csv`, `pm5_samples.csv` und eine zusätzliche `training.rowivo`-Sicherung für Profil, Pläne und Verlauf. Automatische Kopien sind optional und zunächst aus. Chat, Schlüssel und Freigaben werden nicht exportiert. Frühere Ordnerkopien bleiben erhalten.

Das ist eine Sicherung mit offenen Auswertungsdateien; es gibt keinen laufenden Datenabgleich zwischen Geräten. Rowivo zeigt die Übergabe an den Speicheranbieter, nicht einen unprüfbaren Server-Upload. Auch ein neues iPhone kann über den Einstieg eine Sicherung wiederherstellen. Details: [Dateiformat, Ablauf und Grenzen](docs/file-storage.md).

## Entwicklung und Prüfung

Das Xcode-Projekt wird aus `project.yml` mit XcodeGen erzeugt; das generierte Projekt ist direkt enthalten. Keine externen Swift-Paketabhängigkeiten. Die Trainingslogik liegt im lokalen Paket `Packages/RowivoCore`.

**Xcode-Einstellungen erhalten:** Team, Bundle-ID (`at.kromerlorenz.rowivo`) und unterstützte Geräte sind mit Lorenz' Änderungen in Xcode abgeglichen. Für normale Builds ist keine Generierung nötig. Nach weiteren Änderungen in **Signing & Capabilities** oder **General** zuerst die Vorlage abgleichen und den folgenden Prüfbefehl ausführen. Er generiert ausschließlich in einer temporären Kopie und meldet Einstellungen, die überschrieben würden. Erst nach erfolgreicher Prüfung und Sicherung des vorhandenen Projekts neu generieren. `Rowivo/Info.plist` wird als Quelldatei gepflegt und von XcodeGen nicht neu geschrieben. Der vollständige Ablauf steht in `AGENTS.md`.

```sh
python3 scripts/check-project-settings.py
swift test --package-path Packages/RowivoCore
xcodebuild -project Rowivo.xcodeproj -scheme Rowivo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Für App- und Oberflächentests in Xcode **Product → Test** ausführen. Die UI-Tests verwenden ein flüchtiges App-Profil; der Dateiablauf erzeugt zusätzlich sechs Testdateien im lokalen Dateianbieter des Simulators. Dafür einen Simulator ohne Cloud-Anmeldung verwenden und die Testdateien vor einer Wiederholung entfernen oder einen frischen Simulator wählen. SwiftData-Persistenz wird zusätzlich mit einer separaten Datenbank geprüft.

Prüfstand: **21 Core-Tests, 20 App-/API-/Dateitests und 6 UI-Abläufe erfolgreich** auf Xcode 26.6, iPhone 17 Pro Simulator mit iOS 26.4. Die API-Tests verwenden kontrollierte HTTP-Antworten; ein Live-Test mit einem echten Anthropic-Schlüssel steht noch aus. Details, technische Entscheidungen und Grenzen stehen in [docs/implementation.md](docs/implementation.md).

Zusätzlich wurden die Tippflächen im Plan korrigiert und die Texte in Deutsch und Englisch gestrafft. Zwei neue UI-Tests prüfen einzelne Tipps auf freie Flächen und Zeilenränder sowie die Auswahl nach dem Scrollen. Die fünf betroffenen UI-Abläufe (Plan, Einstieg, manuelles Eintragen, Timer und Coach-Einrichtung) wurden erfolgreich geprüft; Signing und General blieben unverändert.

Simulatoransichten mit Testprofil: [Plan auf Deutsch](docs/screenshots/plan-de.png), [Plan auf Englisch](docs/screenshots/plan-en.png), [Eigene Daten auf Deutsch](docs/screenshots/storage-de.png), [Wiederherstellung auf Deutsch](docs/screenshots/restore-de.png), [PM5 verbinden auf Deutsch](docs/screenshots/pm5-connection-de.png), [Heute auf Deutsch](docs/screenshots/today-de.png), [Coach auf Deutsch](docs/screenshots/coach-de.png), [Einstieg auf Englisch](docs/screenshots/welcome-en.png), [Training auf Englisch](docs/screenshots/workout-en.png).

## Marke und Sprachen

Rowivo bleibt als Markenname in allen Sprachen gleich. Vorgeschlagene Untertitel:

- Englisch: **Your personal rowing coach**
- Deutsch: **Dein persönlicher Rudercoach**

Deutsch und Englisch sind umgesetzt. Als weitere Sprachstaffel ist vorgeschlagen, aber noch nicht abschließend festgelegt:

| Zeitpunkt | Sprachen |
|---|---|
| Entwicklung und erste Beta | Englisch als Basissprache, Deutsch |
| Erster internationaler Release | Zusätzlich Spanisch und Französisch |
| Nächste Erweiterung | Portugiesisch, zunächst Brasilien, und Italienisch |
| Danach | Weitere Sprachen nach tatsächlicher Nachfrage |

Zur Sprachunterstützung gehören Oberfläche, Coach, Trainingsanweisungen, Watch-Anzeigen und Store-Seite. Einheiten, Datumsformate und Wochenbeginn werden regional berücksichtigt. Coach-Antworten werden pro freigegebener Sprache geprüft. Länderfreigabe und angebotene Sprachen werden getrennt geplant.

## Zielbild

- iPhone-App mit SwiftUI und lokaler Speicherung über SwiftData.
- Persönlicher Coach über die Anthropic-API: Ziele, Erfahrung, Zeit und Einschränkungen erfragen; Trainingspläne vorschlagen, anpassen und erklären.
- Plan-Engine als reine, unabhängig von Oberfläche und Geräten prüfbare Logik. Sie prüft strukturierte Planvorschläge anhand festgelegter Trainingsregeln, bevor Änderungen nach Bestätigung übernommen werden.
- Nutzerprofil, Trainingsverlauf und aktuelle Planversion strukturiert speichern und gezielt als Kontext für den Coach bereitstellen.
- Gespeicherte Einheiten auch offline ausführen; Timer und Trainingsablauf bleiben lokal.
- Concept2 PM5 über Bluetooth LE für Trainingsdaten.
- Apple Watch für Puls, Zielzone, Restzeit und haptische Hinweise.
- HealthKit für Trainingsaufzeichnung und Gesundheitsdaten gemäß erteilten Berechtigungen.

Für die öffentliche App ist ein kleines Backend mit Anmeldung und Nutzungslimits als Architektur vorgeschlagen. Es schützt den gemeinsamen Anthropic-API-Schlüssel. Die konkrete Backend- und Kontolösung ist noch offen. Für einen persönlichen Prototyp wäre alternativ ein eigener API-Schlüssel im iPhone-Schlüsselbund möglich.

Chatnachrichten und ausgewählte Trainingsinformationen werden bei Anthropic verarbeitet. Die App soll offenlegen, welche Daten übertragen werden, und dafür eine ausdrückliche Zustimmung einholen. Die bisherige Annahme „alles lokal, kein Backend“ aus dem Originalkonzept gilt damit nicht mehr als Zielarchitektur.

## Umsetzung in vier Schritten

### 1. Coach und nutzbarer Plan auf dem iPhone

- Nutzerprofil und Chat mit dem Coach einführen.
- Den Achtwochenplan als strukturierte Startvorlage abbilden.
- Individuelle Pläne und Änderungen strukturiert vorschlagen, prüfen und nach Bestätigung speichern.
- Aktuellen Trainingsplan und nächste vorgesehene Einheit anzeigen.
- Aufbau und Vorgaben einer Einheit einschließlich Ein- und Ausrudern anzeigen.
- Eine Einheit manuell als erledigt markieren und Rückmeldungen zum Training erfassen.
- Profil, Chat, Planversionen und Trainingsfortschritt lokal speichern und nach einem Neustart wiederherstellen.

Dieser erste Schritt soll ohne Verbindung zum PM5 oder zur Apple Watch nutzbar sein.

### 2. Concept2 PM5

Geräteverbindung, Live-Werte und lokale Aufzeichnung sind implementiert. Physischer PM5-Test, Programmierung des Monitors und Abschluss anhand seines Workout-Status stehen noch aus. Das Speichern erfolgt derzeit nach dem Feedback in Rowivo.

### 3. Apple Watch und HealthKit

Workout-Session, Pulsübertragung, Zielzonen, Restzeit und Haptik integrieren. Die Zuständigkeit für das Speichern eines Trainings muss eindeutig sein, damit kein doppelter HealthKit-Eintrag entsteht.

### 4. Auswertung der Messdaten

Die Auswertung der Zielzoneneinhaltung und Verlaufsgrafiken ergänzen. Freigegebene Messdaten als zusätzlichen Kontext für begründete Plananpassungen durch den Coach nutzen.

## Offene Punkte für die Detailplanung

- **Trainingsrhythmus:** Im Prototyp sind Wochen flexibel lange Trainingsblöcke mit zwei oder drei Einheiten und mindestens einem Ruhetag dazwischen. Ein späterer Plan mit vier Einheiten braucht weiterhin eine konsistente Erholungsregel.
- **Wochenabschluss:** Der Prototyp enthält nur Pflicht-Einheiten. Optionale Einheiten brauchen bei späterer Einführung eine separate Abschlussregel.
- **Pausen und Intervalle:** Der Prototyp führt Pausen als eigene Abschnitte; nach dem letzten Arbeitsintervall folgt direkt das Ausrudern. Die spätere Steuerung auf dem PM5 muss diese Abschnitte abbilden.
- **Anpassung:** „Dauerhaft über der Zone“ braucht eine messbare Definition und eine Regel für fehlende Pulswerte. Der erste manuelle MVP liefert diese Messwerte noch nicht.
- **Trainingsregeln:** Grenzen für Belastungssteigerung, Erholung und den Umgang mit Beschwerden fachlich festlegen. Diese Regeln werden von der App geprüft; ein korrektes Datenformat allein belegt keine fachlich geeignete Trainingsempfehlung.
- **Unterbrechungen:** Verhalten bei ausgelassenen Einheiten, längeren Trainingspausen und manuell wiederholten Wochen festlegen.
- **Plattform:** iOS 18 als Mindestversion ist umgesetzt. Echtes iPhone, PM5 und Watch müssen bei der Geräteintegration geprüft werden; die watchOS-Mindestversion bleibt offen.
- **Veröffentlichung:** Sprachstaffel und erste Länder anhand von Übersetzungsqualität, Support und regionaler API-Verfügbarkeit festlegen. Backend, Anmeldung und Kostenmodell konkretisieren.
- **Marke:** Der Name ist gewählt; Domain-, Marken- und Store-Verfügbarkeit sind noch nicht abschließend geprüft.
