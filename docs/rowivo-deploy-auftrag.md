# Auftrag: Rowivo-Website aufnehmen und produktiv deployen

Ziel-Repository: `/Users/lorenz/development/kromerlorenz-infrastructure`.
Auftraggeber: Lorenz Kromer. Lorenz hat Aufnahme und Produktionsdeploy ausdrücklich
autorisiert. Der Deploy-Token ist laut Lorenz im Rowivo-Repository hinterlegt.
Secrets nur über die vorgesehenen Secret-Mechanismen verwenden, niemals ausgeben.

## Was bereits verifiziert ist

- Rowivo-Quelle: `https://github.com/lorenzkromer/rowivo`, Branch `main`,
  Commit `f3e208d` (bereits gepusht).
- Statische Website liegt in `website/`; Docker-Build-Kontext ist dieses
  Verzeichnis. `Dockerfile`, `nginx.conf` und Healthcheck sind vorhanden.
- Zieldomain: `rowivo.kromerlorenz.at`, öffentlich ohne Login.
- Deutsche und englische Seiten kündigen „Verfügbar ab Dezember 2026“ an.
- Astro check, Build und Inhalts-/Linkprüfung sowie 24 Browser-/Viewport-
  Kombinationen bestanden am 05.10.2026.
- Keine Cookies, Analytics, externen Ressourcen oder Client-Skripte.
- Impressum und Datenschutz vorhanden. Hostingtext beschreibt Hetzner/EU,
  zentrale Logs mit 30 Tagen Retention und Microsoft 365 für Geschäftsmail.

## Das Problem

Die Website ist versioniert und gepusht, aber noch nicht in die Plattform
aufgenommen. Bisher wurden weder Produktionsstack noch Image-/Deploy-Workflow
für Rowivo eingerichtet. Ein Git-Push veröffentlicht sie daher noch nicht.

## Das benötigte Ergebnis

1. Zuerst die Repository-Regeln und `AUFNAHME.md` lesen. Aufnahme vollständig
   durchführen: Stack, HOSTS-Zuordnung, Deploy-Workflow, Bestand und Übersicht.
2. Website-Image aus dem genannten Commit bauen, gemäß Infrastrukturvorgabe
   auf Schwachstellen prüfen und in GHCR bereitstellen. Den Rowivo-Build-
   Workflow mit SHA-Tag und passendem repository_dispatch einrichten; vorhandenen
   Deploy-Token nutzen. Änderungen im Rowivo-Repository mit dessen Agenten abstimmen.
3. Produktionsdeploy mit TLS unter `rowivo.kromerlorenz.at` durchführen.
   Keine öffentlichen Containerports; bestehendes Traefik-Netzwerk verwenden.
4. HTTPS, Sprachseiten, Rechtsseiten, Redirects, Assets, 404 und Sicherheitsheader
   prüfen. Logging/GeoIP/Retention mit dem Website-Datenschutz abgleichen.
5. Erst nach erfolgreichem Deploy Blackbox-Probe aktivieren und Status auf
   „in Betrieb“ setzen. Dokumentation im selben Arbeitsschritt nachziehen.

## Rahmen

- Du bist nicht allein in den Repositories. Fremde Änderungen erhalten und
  vorhandene Änderungen berücksichtigen.
- Commit und Push auf Infrastruktur-main sind für diesen Auftrag autorisiert,
  ebenso der dadurch ausgelöste Rowivo-Deploy.
- Andere Websites, bestehende Stacks und App-/Xcode-Einstellungen nicht verändern.
- Stand 14.10.2026: Die Jev-/TypeSafe-Funktion wurde aus dem aktuellen Quellstand
  entfernt; die zugehörigen offenen Anbieterfragen sind für diesen Stand entfallen.
- Kein Store-/TestFlight-Link ohne bestätigte URL und kein Tracking hinzufügen.

## Rückmeldung

1. Öffentliche URL und Ergebnis der HTTPS-/Seiten-/Headerprüfungen.
2. Image-Tag, Workflow-/Deploy-Ergebnis und aktivierte Monitoring-Probe.
3. Commit-Hashes aller beteiligten Repositories.
4. Verbleibende Hindernisse, insbesondere Abweichungen der Hostingangaben.

Bei Ausführung in Herdr abschließend:
`herdr notification show "kromerlorenz-infrastructure fertig" --sound done`.
