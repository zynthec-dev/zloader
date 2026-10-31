# Projektwissen

> Gemeinsame Agent- und Designvorgaben: `/Users/renewittern/Workspace/AGENTS.md`.
> Diese Datei bewahrt bestehendes Projektwissen; sie definiert kein eigenes Design oder Agent-Profil.

## Gemeinsames Repository

- Ab sofort ausschließlich im Repository `/Users/renewittern/Workspace/Apps:Software/zloader` arbeiten. Das gilt für alle bestehenden und neuen Chats dieses Projekts.
- `zloader-app/` enthält die iOS-App einschließlich Xcode-Projekt, Build-Skripten und gepinnten Abhängigkeiten. Zusätzlich gilt dort `zloader-app/PROJECT-NOTES.md`.
- `zloader-altsource/` enthält Website, Feed, Admin, Cloudflare-Konfiguration und Release-Pipeline.
- Beide Ordner gehören zum selben Git-Repository. Keine neuen separaten Repositories oder Klone an den alten Pfaden unter `Workspace/Projekte` anlegen.
- Git-Befehle für das Gesamtprojekt am Repository-Stamm ausführen; Build- und Testbefehle im jeweiligen Unterordner. Abhängigkeiten am Stamm mit `git submodule update --init --recursive` initialisieren.
- Offene Änderungen anderer Chats erhalten. Insbesondere wurde die vorhandene Änderung an `zloader-app/zLoader/Features/Resources/Localizable.xcstrings` uncommittet übernommen.
- Das Monorepo und seine vollständige Git-Historie bleiben privat. `origin` ist weiterhin `zynthec-dev/zloader-app`. Niemals das gesamte Repository nach `zynthec-dev/zloader-altsource` pushen.
- Das öffentliche AltSource-Repo bleibt Veröffentlichungsziel. Änderungen von dort mit `git subtree pull --prefix=zloader-altsource https://github.com/zynthec-dev/zloader-altsource.git main` übernehmen. Nur den abgespaltenen AltSource-Teil veröffentlichen; Ablauf und Prüfungen stehen in `README.md`.
- Abgeschlossene eigene Änderungen lokal committen; bestehende fremde Änderungen nicht mit aufnehmen. Eine Migration allein löst keinen Release oder Deployment aus.
