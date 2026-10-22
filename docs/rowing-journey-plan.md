# Ruderreise: Landschaft, Etappen und freischaltbare Orte

Stand: 21. Oktober 2026. Planungsentwurf, noch nicht implementiert.

## Ausgangspunkt und bestätigte Richtung

Lorenz möchte Rudern mit einem Spiel beziehungsweise einer Fortschrittsanimation verbinden: eine Fahrt durch schöne Landschaft auf ruhigem Wasser. Als Richtung gewählt: **spielerische Reise mit Etappen und freischaltbaren Orten**. Die folgenden Details sind Vorschläge für die erste Umsetzung.

## Erlebnis

Vor dem Training sieht man eine kleine Reisekarte mit dem aktuellen Ort und dem nächsten Ziel. Während der Einheit gleitet ein Boot durch eine ruhige, stilisierte Landschaft. Ufer, Spiegelungen und vorbeiziehende Orientierungspunkte machen die zurückgelegte Strecke sichtbar. Tempoänderungen wirken sanft auf die Bewegung; es sind keine Eingaben während des Ruderns erforderlich.

Eine Etappe darf über mehrere Einheiten dauern. Beim Speichern erhält man den tatsächlich erarbeiteten Reisefortschritt. Ein erreichter Anleger erscheint anschließend auf der Karte und erschließt den nächsten Streckenabschnitt. Pause und Ausruhen verlieren keinen Fortschritt. Freischaltungen richten sich nach kumuliertem Fortschritt, ohne tägliche Verpflichtung.

Beispiel einer ersten Welt: **Morgensee → Schilfbucht → Waldanleger → Insellichtung**. Die Orte sind fiktiv; die Streckenlängen werden nach dem Bewegungstest festgelegt. Ruhige Natur bleibt auch mit sichtbarem Spielziel der visuelle Schwerpunkt.

## Erster spielbarer Umfang

1. Ein See mit drei aufeinanderfolgenden Etappen und einer wiederverwendbaren Landschaftsszene.
2. Eine kompakte Reisekarte mit aktuellem Ort, freigeschalteten Orten und nächstem Ziel.
3. Optionaler Reisemodus im bestehenden Trainingsbildschirm. Der geplante Trainingsablauf bleibt maßgeblich; Restzeit, Phase, Pause und Beenden bleiben erreichbar. Die bisherige Trainingsanzeige bleibt wählbar.
4. Ein sichtbares Boot in leicht erhöhter Perspektive, sanft bewegtes Wasser und mehrere Landschaftsebenen. Die genaue Perspektive wird im visuellen Prototyp geprüft.
5. Gemessene Meter treiben die Reise an. Geräte liefern über PM5 und FTMS bereits gemeinsame Distanzdaten. Fehlende Distanz bleibt fehlend.
6. Nach dem Speichern: zurückgelegte Reisestrecke, nächster Ort und gegebenenfalls eine Freischaltung. Auch gespeicherte Teileinheiten zählen mit ihrer gemessenen Strecke.
7. Deutsche und englische Texte, lokal gebündelte Landschaftsassets und Offline-Nutzung.

Mehrere Welten, Bootsvarianten, Wetter und Tageszeiten sind spätere Erweiterungen. Wettbewerb, Ranglisten und zusätzliche Spielwährungen gehören nicht zum ersten Umfang.

## Regeln für Bewegung und Fortschritt

- Grundlage ist die bereits geprüfte Distanz aus `RowerRecording`, nicht der rohe Gesamtzähler des Monitors. Meter vor Trainingsbeginn zählen dadurch nicht zur Reise.
- Die Darstellung interpoliert zwischen empfangenen Messungen. Die sichtbare Reiseentfernung darf die tatsächlich erfasste Distanz nicht überschreiten. Schlagzahl kann eine dekorative Ruderbewegung steuern, ersetzt jedoch keine Meter.
- Bei manueller oder automatischer Pause hält der Reisefortschritt an. Bei fehlenden aktuellen Distanzdaten hält die Vorwärtsbewegung an und die Anzeige erklärt den Verbindungszustand. Wasser und Umgebung dürfen sanft weiter animieren.
- Bei Wiederverbindung, Zählerrücksetzung oder App-Neustart gelten die vorhandenen Regeln für Messlücken. Fehlende Meter werden nicht nachträglich geschätzt.
- Aktuelle Bewegung ist eine Vorschau. Erst erfolgreich gespeicherte Trainings schreiben dauerhaften Fortschritt gut. Wiederholtes Speichern oder Öffnen darf keine doppelte Gutschrift erzeugen.
- Bei Verwerfen entfällt die Vorschau. Ein Absturz darf bereits gesicherten Trainings- und Reisevorschauzustand nicht doppelt zählen.
- Vorschlag für nachträgliches Löschen: Reisestrecke aus den verbleibenden berechtigten Aufzeichnungen neu berechnen; bereits erreichte Orte bleiben als Entdeckungen erhalten. Diese Produktregel ist vor Implementierung zu bestätigen und ausdrücklich zu testen.
- Vorschlag für den Einstieg: Reise ab Aktivierung beginnen. Vorhandene Trainings werden nicht ungefragt angerechnet. Historische Anrechnung kann später als ausdrückliche Option hinzukommen.
- Ohne Distanzdaten bleibt die normale Trainingsanzeige verfügbar. Ein eigener, als zeitbasiert gekennzeichneter Reisemodus ist ein möglicher zweiter Schritt; Zeit wird dabei nicht als gemessene Distanz ausgegeben.

## Technische Anknüpfungspunkte

| Vorhandener Bereich | Verwendung für die Reise |
| --- | --- |
| `Packages/RowivoCore/Sources/RowivoCore/Rower.swift` | Gemeinsame PM5-/FTMS-Messwerte, gesammelte Distanz und Behandlung von Messlücken |
| `Rowivo/Data/RowivoStore.swift` | Lebenszyklus der Einheit, Pause, Wiederaufnahme, Speicherung und Verwerfen |
| `Rowivo/Views/ActiveWorkoutView.swift` | Einbettung der Szene sowie weiterhin sichtbare Trainingssteuerung |
| `Rowivo/Views/ProgressViewScreen.swift` | Möglicher Einstieg in Reisekarte und entdeckte Orte |

Reiseregeln sollen als reine, unabhängig prüfbare Logik in RowivoCore entstehen. Die Szene liest den Trainingszustand und verändert weder Gerätezähler noch Trainingsuhr. Rendering und Sensorempfang bleiben voneinander getrennt; die vorhandene sekundengenaue Timeransicht reicht allein nicht für eine flüssige Szene.

Für den ersten Stil ist SpriteKit mit Landschaftsebenen ein Kandidat. Apple dokumentiert SpriteKit für 2D-Szenen: https://developer.apple.com/documentation/spritekit. Falls der visuelle Prototyp räumliche 3D-Landschaften erfordert, RealityKit separat prüfen. SceneKit ist von Apple als veraltet eingestuft und wird für den Neubeginn nicht vorgesehen: https://developer.apple.com/videos/play/wwdc2025/288/.

Vor dem Bauen wird entschieden, wie berechtigte Einheiten und Entdeckungen persistent referenziert werden. Das muss Löschung, Wiederherstellung und wiederholten Import eindeutig behandeln. Änderungen an Datenhaltung oder Sicherungsformat werden erst nach Lesen von `AUFNAHME.md` im Infrastruktur-Repository samt dort verlangter Meldungen geplant und umgesetzt; in dieser Bestandsaufnahme wurde keine Datenhaltung geändert. Bestehende Sicherungen müssen weiterhin lesbar bleiben. Kein XcodeGen-Lauf ist für diese Planung erforderlich.

## Umsetzung in drei Schritten

1. **Bewegungsprototyp:** eine Landschaft, ein Boot, simulierte Messdaten für langsames/schnelles Rudern, Pause und Messlücke. Auf einem echten iPhone während des Ruderns Perspektive, Lesbarkeit, Akkuverbrauch und Bewegungsgefühl beurteilen. Simulation schreibt keine Trainingsdaten.
2. **Erste reale Etappe:** Szene an die vorhandene Aufzeichnung anbinden, sichere Gutschrift beim Speichern, Fortsetzung über mehrere Einheiten und eine Freischaltung umsetzen. Sensor- und Lebenszyklusregeln zuerst stabilisieren.
3. **Kleine vollständige Reise:** drei Etappen, Reisekarte, Texte und Übergänge ergänzen. Danach gemeinsamen TestFlight-Build für den bestehenden App-Stand und die Reise vorbereiten.

## Abnahmekriterien

- Ein Teststrom mit 500 gültig erfassten Metern führt zu genau 500 Metern Reisevorschau und nach erfolgreichem Speichern zu genau einer Gutschrift.
- Pause, veraltete Werte, Funkabbruch und zurückgesetzte Zähler erzeugen keine zusätzlichen Reisemeter. Glättung erzeugt keinen dauerhaften Vorsprung.
- Verwerfen, Speicherfehler, erneutes Speichern, App-Neustart und wiederholter Import erzeugen keine doppelte Gutschrift.
- Eine gespeicherte Teileinheit setzt die Reise korrekt fort, ohne die geplante Einheit als abgeschlossen umzudeuten.
- Ein Etappenziel stoppt oder beendet das Training nicht. Überschüssige Meter fließen in die nächste Etappe; mehrere im Training erreichte Ziele werden korrekt behandelt.
- Profilreset, Löschen von Aufzeichnungen und Wiederherstellung entsprechen den vorher vereinbarten Fortschrittsregeln.
- Pause und Beenden sind auf kleinen iPhones und bei großer Schrift dauerhaft erreichbar. VoiceOver kann Phase, Zeit und Reisestatus lesen. „Bewegung reduzieren“ bietet einen ruhigen Fortschrittszustand.
- Szene läuft nur bei sichtbarer aktiver App; Hintergrundaufnahme und Watch-Steuerung behalten ihr Verhalten. Wärme und Akku werden an einer vollständigen echten Trainingseinheit beurteilt.

## Bestandsaufnahme: sinnvolle Updates davor oder daneben

- Der Arbeitsstand enthält umfangreiche noch nicht eingecheckte Änderungen, unter anderem FTMS und Watch. Diese Änderungen vor der Featureumsetzung thematisch sichern und prüfen; nicht durch Projektgenerierung überschreiben.
- README nennt als letzten belegten TestFlight-Upload 0.1.0 Build 5 vom 23. September 2026. Dieser Build enthält noch die entfernte Jev-Testfunktion. Ein neuer Build aus dem geprüften Arbeitsstand ist ein konkretes nächstes Releaseziel; aktuelle App-Store-Connect-Verfügbarkeit wurde hier nicht geprüft.
- Gerätetests für PM5/FTMS, Wiederverbindung und Hintergrundempfang sowie größere Schrift und VoiceOver haben unmittelbaren Nutzen für die Reise. Vorhandene positive Watch-Gerätetests in `first-workout-followup.md` berücksichtigen und gezielt ergänzen.
- Dokumentationsstände zusammenführen: ältere Reviews führen beispielsweise Profilbearbeitung und Löschen noch als offen, obwohl spätere Ergänzungen ihre Implementierung beschreiben. Testnachweise stets dem tatsächlich geprüften Stand zuordnen.
- RowivoCore verwendet keine externen Swift-Pakete. Es gibt dort derzeit keine fremden Paketversionen anzuheben. Die Website besitzt einen eigenen npm-Abhängigkeitsstand und wird separat beurteilt.

Read-only-Abfrage mit `npm outdated --json` am 21. Oktober 2026: Astro 7.2.2 → 7.4.1, `@astrojs/check` 0.9.10 → 0.9.12, Playwright 1.63.0 → 1.64.1, Prettier 3.9.9 → 3.9.10, Astro-Prettier-Plugin 1.0.1 → 1.1.1 und Sharp 0.35.4 → 0.35.5 sind mögliche Updates. TypeScript 6.0.3 → 7.0.2 ist ein eigener Versionssprung und braucht einen Kompatibilitätscheck. Die Versionen wurden nicht geändert; Verfügbarkeit allein belegt keine Kompatibilität.

Aktuelle Prüfung: `swift test --package-path Packages/RowivoCore` erfolgreich, **39 Tests ohne Fehler**. App-/UI-Tests und Website-Build wurden in dieser Bestandsaufnahme nicht erneut ausgeführt.

## Noch vor Umsetzung zu entscheiden

- Landschaftsstil und Kameraperspektive anhand des Prototyps.
- Etappenlängen und Anteil des Bildschirms für Landschaft beziehungsweise Trainingswerte.
- Löschregel für erreichte Orte, Start ab Aktivierung und Umfang eines späteren Zeitmodus.
- Persistenzmodell und Aufnahme in Sicherungen nach dem vorgeschriebenen Infrastruktur-Abgleich.
