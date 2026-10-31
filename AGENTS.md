# Vorgaben für alle zLoader-Chats

## Gemeinsames Repository

- Ab sofort ausschließlich im Repository `/Users/renewittern/Workspace/Apps:Software/zloader` arbeiten. Das gilt für alle bestehenden und neuen Chats dieses Projekts.
- `zloader-app/` enthält die iOS-App einschließlich Xcode-Projekt, Build-Skripten und gepinnten Abhängigkeiten. Zusätzlich gilt dort `zloader-app/AGENTS.md`.
- `zloader-altsource/` enthält Website, Feed, Admin, Cloudflare-Konfiguration und Release-Pipeline.
- Beide Ordner gehören zum selben Git-Repository. Keine neuen separaten Repositories oder Klone an den alten Pfaden unter `Workspace/Projekte` anlegen.
- Git-Befehle für das Gesamtprojekt am Repository-Stamm ausführen; Build- und Testbefehle im jeweiligen Unterordner. Abhängigkeiten am Stamm mit `git submodule update --init --recursive` initialisieren.
- Offene Änderungen anderer Chats erhalten. Insbesondere wurde die vorhandene Änderung an `zloader-app/zLoader/Features/Resources/Localizable.xcstrings` uncommittet übernommen.
- Das Monorepo und seine vollständige Git-Historie bleiben privat. `origin` ist weiterhin `zynthec-dev/zloader-app`. Niemals das gesamte Repository nach `zynthec-dev/zloader-altsource` pushen.
- Das öffentliche AltSource-Repo bleibt Veröffentlichungsziel. Änderungen von dort mit `git subtree pull --prefix=zloader-altsource https://github.com/zynthec-dev/zloader-altsource.git main` übernehmen. Nur den abgespaltenen AltSource-Teil veröffentlichen; Ablauf und Prüfungen stehen in `README.md`.
- Abgeschlossene eigene Änderungen lokal committen; bestehende fremde Änderungen nicht mit aufnehmen. Eine Migration allein löst keinen Release oder Deployment aus.

## Design

- Gemeinsame Designsprache von zynthec.: ruhig, klar, einheitlich und performant.
- Fester Akzent `#40B5AD`, darauf Text und Symbole `#102C2A`. Keine auswählbaren Akzentfarben oder Farb-Themes. Darstellung Hell, Dunkel, Automatisch; eigene Hintergrundbilder sind möglich.
- Hell: Hintergrund `#F0F1F3`, Karten `#FFFFFF`, Eingaben/Seitenleiste `#F5F5F7`, Text `#1D1D1F`, sekundärer Text `#62626B`, Rahmen `#DEDEE3`.
- Dunkel: Hintergrund `#1C1C1E`, Karten `#2C2C2E`, Eingaben/Seitenleiste `#242426`, Text `#F2F2F7`, sekundärer Text `#B9BBC2`, Rahmen `#424247`.
- Systemschrift verwenden. Fließtext und kleine Links neutral halten; Markenfarbe gezielt für Aktionen und Auswahl einsetzen. Statusfarben und originale Logos erhalten.
- Gemeinsame Komponenten mit gleichen Größen, Abständen, Symbolen und Textrollen verwenden. Kartenradius 12, kompakte Elemente 6–8 logische Einheiten; passende Aktionen pillenförmig.
- Responsive Layouts ohne Überlagerungen oder abgeschnittene Beschriftungen. Native Bedienkonventionen, Fensterknöpfe, Tastaturbedienung, zugängliche Beschriftungen und ausreichenden Kontrast erhalten.
- Keine aufwendigen Pflicht-Glaseffekte, leuchtenden Rahmen oder animierten Hintergründe. Designänderungen müssen Zustand und laufende Arbeit erhalten.
