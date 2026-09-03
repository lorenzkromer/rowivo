# Rudertrainer: Trainingsplan & App-Konzept

Stand: 2. September 2026

## Ausgangslage

- Gerät: Concept2 mit PM5 (Bluetooth, dokumentiertes Protokoll)
- Person: 33 Jahre, 175 cm, 110 kg, kompletter Anfänger am Rudergerät, früher sportlich
- Ziel: Abnehmen, Muskulatur erhalten bzw. wieder aufbauen
- Zusätzlich: eigene iPhone-App mit Apple-Watch-Integration, die den Plan steuert

## Grundsätze

- Der Gewichtsverlust hängt vor allem an der Ernährung. Ein Defizit von 500–700 kcal/Tag ergibt ca. 0,5–0,7 kg pro Woche. Eine Rudereinheit liefert davon 300–500 kcal.
- Rudern ist gelenkschonend und trainiert den ganzen Körper, aber Sehnen, unterer Rücken und Knie brauchen einige Wochen Eingewöhnung. Nicht übertreiben am Anfang.
- Vorher ein kurzer Check beim Hausarzt (Blutdruck, Belastbarkeit) ist bei diesem Gewicht und nach längerer Pause sinnvoll.

## Technik und Einstellungen

- Bewegungsablauf: Beine drücken → Oberkörper leicht zurück → Arme ziehen. Rückweg in umgekehrter Reihenfolge. Griff locker halten.
- Nicht nach Dämpfer gehen, sondern den **Drag Factor** auf 110–125 einstellen (PM5: Menü → More Options → Display Drag Factor). Dämpfer 10 ist der häufigste Anfängerfehler.
- Schlagzahl im Grundlagentraining: 20–22 Schläge/Min. Lieber kräftig als hektisch.

## Regeln für alle Einheiten

- 3–5 Min locker einrudern, 3 Min ausrudern
- Zwischen zwei Einheiten immer ein Ruhetag
- Steigern nur, wenn die Vorwoche ohne Rücken- oder Knieprobleme lief. Sonst Woche wiederholen.
- Grundlage: Puls 120–140, man kann noch sprechen
- Intervalle "hart": Schlagzahl 26–28, Puls darf auf 160+ gehen. "Locker": Schlagzahl 18, weiterrudern, nicht stoppen.

## 8-Wochen-Plan

### Phase 1: Technik (Woche 1–2), 3 × pro Woche

| | Woche 1 | Woche 2 |
|---|---|---|
| Mo / Mi / Fr | 4 × 5 Min, 2 Min Pause | 4 × 6 Min, 90 Sek Pause |
| Schlagzahl | 18–20 | 20–22 |
| Puls | egal, Fokus Technik | unter 140 |

Ziel: sauberer Bewegungsablauf, kein Muskelkater im Rücken.

### Phase 2: Grundlage (Woche 3–6), 3–4 × pro Woche

| | Woche 3 | Woche 4 | Woche 5 | Woche 6 |
|---|---|---|---|---|
| Tag A: Grundlage | 20 Min | 25 Min | 30 Min | 30 Min |
| Tag B: Intervalle | 6 × 1/1 Min | 6 × 1/1 Min | 8 × 1/1 Min | 8 × 1/1 Min |
| Tag C: Grundlage | 20 Min | 25 Min | 25 Min | 30 Min |
| Tag D (optional) | – | – | 20 Min locker | 20 Min locker |

### Phase 3: Aufbau (Woche 7–8), 4 × pro Woche

| | Woche 7 | Woche 8 |
|---|---|---|
| Tag A: Grundlage | 35 Min | 40 Min |
| Tag B: Intervalle | 4 × 4 Min, 3 Min Pause | 5 × 4 Min, 3 Min Pause |
| Tag C: Grundlage | 30 Min | 35 Min |
| Tag D: locker + Kraft | 20 Min + 15 Min Kraft | 20 Min + 15 Min Kraft |

Kraft ohne Geräte: Kniebeugen, Liegestütze (an der Wand oder auf Knien starten), Plank, Rudern mit Fitnessband. Je 3 Sätze à 10–12 Wiederholungen.

### Danach

- Basis nach Woche 8: ca. 2,5 Std pro Woche
- Ab dann zyklisch: 3 Wochen steigern, 1 Woche leichter
- Realistische Erwartung bis Woche 8: 4–6 kg weniger, wenn die Ernährung mitspielt

## App-Konzept

### Komponenten

| Komponente | Aufgabe | Technik |
|---|---|---|
| Concept2 PM5 | Schläge, Watt, Split, Distanz, Zeit | Bluetooth LE, Concept2-Service `CE060000-…` (Rowing Status, Stroke Data) |
| Apple Watch | Puls, Zielzone anzeigen, Haptik bei Zonenverlassen | WatchKit, `HKWorkoutSession` (Typ Rudern), WatchConnectivity |
| iPhone-App | Plan-Engine, Live-Workout, Verlauf, Gewicht | SwiftUI, CoreBluetooth, SwiftData |
| HealthKit | Workouts speichern, Gewicht und Puls lesen | HealthKit |

Kein Cloud-Backend nötig, alles lokal.

### Datenfluss

- PM5 → iPhone (Bluetooth): Live-Werte mehrmals pro Sekunde
- Apple Watch ↔ iPhone (WatchConnectivity): Puls hoch, Steuerbefehle und Zielzone runter
- iPhone ↔ HealthKit: Workouts schreiben, Gewicht lesen (z. B. automatisch von einer Waage)

### Plan-Engine

Reine Logik, kein Framework. Kennt den 8-Wochen-Plan als Datenstruktur, weiß, welche Einheit heute dran ist, und wertet danach aus.

Startregeln:

1. Nächste Woche nur freischalten, wenn alle Einheiten der Vorwoche absolviert wurden.
2. Wenn der Puls bei Grundlageneinheiten dauerhaft über der Zone lag, Dauer nicht erhöhen.

Pro Einheit gibt die App vor: z. B. "Heute 25 Min, Puls 120–140, Schlagzahl 20–22", zeigt live, ob man drin ist, und passt die Folgewoche an.

### Watch-App

Zeigt nur das Nötigste: aktuelle Zielzone, Puls, Restzeit. Tippt an, wenn der Puls aus der Zone fällt. Startet und beendet die Workout-Session, damit das Workout sauber in Apple Health landet.

### Umsetzungsreihenfolge

1. iPhone-App mit fest verdrahtetem Plan und manueller "Einheit erledigt"-Eingabe (ein Wochenende)
2. PM5-Anbindung: Live-Werte anzeigen, Einheit automatisch abschließen
3. Watch-App mit Workout-Session und Pulszone
4. Adaptive Regeln und Verlaufsgrafiken

Nach Schritt 1 ist die App bereits nutzbar, während parallel nach dem Plan trainiert wird.

### Hinweis

Für Concept2 gibt es mit ErgData eine fertige App. Die eigene App lohnt sich wegen des individuellen, adaptiven Plans und als Lernprojekt.