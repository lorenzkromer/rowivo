# Coach-Zugang ohne technische Einrichtung

Historische Recherche vom 3. September 2026. **KI ist auf Nutzerwunsch vorerst aus Rowivo entfernt.** Die folgende Diskussion ist pausiert und kein aktueller Implementierungsauftrag. Rowivo verwendet die manuelle Trainingsplanung; eine Kontoanbindung ist nicht implementiert.

## Kontoverknüpfung: Was die vorhandenen Integrationen belegen

Xcode unterstützt die Anmeldung mit ChatGPT- und Claude-Konten. Das bestätigt
Lorenz' Beobachtung. Die Dokumentation beschreibt diese Funktionen innerhalb der
Coding Intelligence von Xcode; daraus folgt kein allgemeiner Login-Zugang für
beliebige iPhone-Apps. [Apple: Setting up coding intelligence](https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence)

Anthropic erlaubt laut Agent-SDK-Dokumentation einen eigenen Claude.ai-Login und
die Nutzung von Abo-Limits in Drittprodukten nur nach vorheriger Freigabe. Die
Claude-Code-Regeln erlauben außerdem, die unveränderte Claude-Code-Anwendung
bereitzustellen, in der sich Nutzer selbst anmelden. Das erklärt, weshalb solche
Konten in Entwicklungswerkzeugen verwendbar sein können. Es ist keine allgemeine
Freigabe, deren Sitzungstokens für Rowivos eigenen Chat zu übernehmen.
[Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview),
[Authentifizierung und Produktintegration](https://code.claude.com/docs/en/legal-and-compliance)

Der neuere Hilfeartikel zur Agent-SDK-Nutzung erwähnt Drittanbieter-Anwendungen
und pausierte Änderungen an der Abrechnung. Er ersetzt nicht die notwendige
Freigabe für eine eigene Kontoanbindung. Deshalb keine Aussage, Claude-Abos seien
grundsätzlich in allen Drittanwendungen verboten oder für Rowivo frei nutzbar.
[Anthropic: Agent SDK mit einem Claude-Abo](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)

OpenAI dokumentiert den Codex App Server für die Einbettung von Codex in eigene
Clients, einschließlich eines von Codex verwalteten ChatGPT-Logins. Das ist eine
konkrete Integrationsmöglichkeit für Codex; ein allgemeiner Swift-Login, der ein
ChatGPT-Abo für Rowivos beliebige Modellanfragen freischaltet, wurde in den
geprüften offiziellen Quellen nicht gefunden. Eine eigene Integration wäre
gesondert auf Produktumfang, Laufzeit und unterstützte Nutzung zu prüfen.
[Codex App Server](https://learn.chatgpt.com/docs/app-server),
[Authentifizierung](https://learn.chatgpt.com/docs/auth)

Eine ChatGPT-Erweiterung kann umgekehrt Rowivo-Werkzeuge bereitstellen: ChatGPT
authentifiziert sich gegenüber unserem Dienst. Das Gespräch läuft dann in
ChatGPT. Dieser OAuth-Ablauf ist nicht die Anmeldung eines ChatGPT-Kontos in
unserem nativen Coach. [OpenAI: Plugin-Authentifizierung](https://developers.openai.com/plugins/build/auth)

## Empfehlung für Rowivo

Nutzerinnen aktivieren den Coach in Rowivo, stimmen dem beschriebenen
Datenaustausch zu und beginnen zu schreiben. Ein eigener Provider-Account,
API-Schlüssel und eine Modellbezeichnung gehören nicht in diesen Ablauf.

Ein Rowivo-Backend würde die API-Anfragen an Anthropic oder OpenAI übernehmen.
Der Provider-Schlüssel bleibt auf dem Server. Rowivo trägt die Nutzungskosten;
Freikontingent, Kostenlimit und ein mögliches Bezahlmodell sind noch festzulegen.
Die App erhält eine eigene unkomplizierte Anmeldung, beispielsweise über Apple,
falls das Konten- und Abrechnungsmodell sie erfordert.

Profil, Plan und Trainingsverlauf bleiben primär auf dem iPhone. Für eine
Coach-Nachricht wird nur der freigegebene Kontext übermittelt. Da dabei künftig
auch unser Server beteiligt wäre, müssen Einwilligung und Datenschutzhinweise
diesen Weg korrekt beschreiben. Optionale Dateisicherungen bleiben davon
unabhängig. Eine Speicherung vollständiger Trainingsdaten auf unserem Server
ist dafür nicht erforderlich.

Die alternative Nutzung eines bestehenden Abos ist zunächst außerhalb der App
möglich: exportierte Trainingsdaten selbst in Claude oder ChatGPT besprechen.
Ein automatischer Rückweg für Planänderungen wäre ein zusätzliches Feature.
