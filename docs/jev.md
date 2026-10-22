# Jev entfernt

Stand: 14. Oktober 2026. Die experimentelle Jev-/TypeSafe-Integration wurde auf Wunsch von Lorenz entfernt, weil sie keinen ausreichenden Mehrwert bietet.

Aus dem aktuellen Quellstand entfernt: Vorschlagsoberfläche, API-Zugang, Netzwerkclient, Planübernahme, Vorschlagslogik, zugehörige Tests und ausführbare Experimente einschließlich lokaler Schlüsseldatei. Website und Datenschutztexte beschreiben diese Funktion nicht mehr.

Beim Start einer regulären App-Sitzung werden frühere Anbieter-Schlüssel aus dem iPhone-Schlüsselbund gelöscht. Fehlgeschlagene Löschung wird angezeigt und beim nächsten Start erneut versucht. Profil, Plan, Trainingsaufzeichnungen und vorhandene Versionsverläufe bleiben erhalten. In-Memory-Testläufe löschen keine echten Zugangsdaten.

Der [damalige Vergleich](archive/jev/FINDINGS.md), alte Screenshots und Release-Nachweise bleiben historische Belege. Build 5 enthält noch Jev; für die Entfernung auf Geräten ist ein neuer Build nötig. Website-Änderungen sind lokal vorbereitet und noch nicht veröffentlicht.

Prüfung am 14.10.2026: 39 Core-Tests und 56 App-Tests erfolgreich, einschließlich Schlüsselbereinigung, Wiederholbarkeit, Fehlerbehandlung und unverändertem Trainingsbestand. Website-Typecheck und Build erfolgreich; 24 Browser-Prüfungen in DE/EN bei vier Bildschirmbreiten bestanden. Das bestehende Xcode-Projekt wurde gezielt um die entfernten Quelldateien bereinigt und nicht regeneriert.
