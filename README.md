# zLoader

Ein gemeinsames privates Repository für App, Website, AltSource-Feed und Admin.
Der Arbeitsordner für alle Projekt-Chats ist
`/Users/renewittern/Workspace/Apps:Software/zloader`.

| Bereich | Pfad | Dokumentation |
| --- | --- | --- |
| iOS-App und Xcode-Projekt | `zloader-app/` | [App-README](zloader-app/README.md) |
| Website, Feed, Admin und Release-Pipeline | `zloader-altsource/` | [AltSource-README](zloader-altsource/README.md) |

## Lokal arbeiten

Am Repository-Stamm zuerst `git submodule update --init --recursive` ausführen.
Danach die App-Befehle aus `zloader-app/`, die Website-Befehle aus
`zloader-altsource/` starten. Beispielsweise:

```sh
cd zloader-app
sh zLoader/scripts/build-unsigned.sh
```

```sh
cd zloader-altsource
python3 scripts/release_pipeline.py download
python3 scripts/build.py
python3 -m unittest discover -s tests -v
```

Die GitHub-Actions am Repository-Stamm berücksichtigen diese Arbeitsordner.
Der kanonische App-Build unterstützt den Doppelpunkt in `Apps:Software`:
`build-unsigned.sh` baut die aktuellen Arbeitsdateien in einem projektspezifischen
macOS-Benutzercache und kopiert die Ergebnisse zurück. Direkte Xcode-Builds am
Originalpfad unterliegen weiterhin der Doppelpunkt-Beschränkung der Toolchain.
Die Workflows innerhalb von `zloader-altsource/.github/` gehören zum öffentlichen
Veröffentlichungsziel und werden dort weiterhin verwendet.

## Öffentliches Veröffentlichungsziel

`origin` bleibt das private Repository `zynthec-dev/zloader-app`.
Das öffentliche Repository `zynthec-dev/zloader-altsource` enthält weiterhin nur
Website, Feed und Admin sowie öffentliche Release-Dateien. Seine bestehende
Cloudflare-Anbindung und Admin-Uploads bleiben darüber erreichbar.

Vor AltSource-Änderungen neue öffentliche Katalog-Commits übernehmen, damit
Uploads aus dem Admin nicht überschrieben werden. Dazu zuerst eigene Änderungen
committen oder anderweitig sicher beiseitelegen:

```sh
git subtree pull --prefix=zloader-altsource https://github.com/zynthec-dev/zloader-altsource.git main
```

Zum Vorbereiten einer Veröffentlichung ausschließlich den Unterordner abspalten:

```sh
git subtree split --prefix=zloader-altsource -b publish/altsource
git ls-tree --name-only publish/altsource
git merge-base --is-ancestor 81456b1 publish/altsource
```

Vor dem Push den abgespaltenen Baum prüfen: Er muss `catalog/`, `site/`,
`scripts/` und die AltSource-Konfiguration enthalten. `zloader-app/`,
`zLoader/`, `Dependencies/` und private App-Historie dürfen nicht enthalten sein.
Nur diesen geprüften Veröffentlichungsbranch an das öffentliche Ziel senden:

```sh
git push https://github.com/zynthec-dev/zloader-altsource.git publish/altsource:main
```

Niemals `HEAD`, den Entwicklungsbranch, `--all` oder `--mirror` an das öffentliche
Ziel pushen. Neue App-Releases folgen zusätzlich der Policy in
`zloader-app/AGENTS.md`; die Migration veröffentlicht selbst nichts.

## Migration vom 31. Oktober 2026

Die bisherigen Git-Historien wurden ohne Umschreiben importiert:

- App: `234a42f0` auf `zloader-development`, einschließlich des lokalen Commits für 0.8.6.
- AltSource: `81456b1`, einschließlich der beiden zuvor lokal fehlenden Katalog-Commits.
- App-Branches, Tags, Reflogs und der zusätzliche Entwicklungs-Worktree bleiben erhalten.
- Historische Branches behalten ihre ursprüngliche Dateistruktur. Neue Entwicklungsbranches vom migrierten `zloader-development` abzweigen.
- AltSource-Branches und Remote-Refs liegen unter `refs/migration/altsource/`; Tags sind unter `altsource/` namensräumlich getrennt.
- Die originale AltSource-Git-Verwaltung und der ursprüngliche App-Index liegen als lokale Rückfallsicherung unter `.git/migration-backups/`. Sie gehören nicht zum veröffentlichten Inhalt.
- Die vorhandene Übersetzungsänderung bleibt uncommittet. Ihre SHA-256-Prüfsumme wurde vor und nach dem Umzug verglichen.
- Bestehende Build-Produkte, lokale Konfigurationen und IPA-Dateien bleiben an ihrem bisherigen Platz innerhalb der Unterordner.

Die beiden Unterordner besitzen keine eigenen Git-Repositories mehr.
Die gepinnten Drittanbieter-Submodule bleiben reguläre Submodule.
