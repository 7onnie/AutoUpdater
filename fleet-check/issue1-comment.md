## Messung abgeschlossen (rein lesend, kein Merge/Commit)

**(a) Liegt der Fix in `main`? NEIN.**

`main` (HEAD `313824c`) enthält weiterhin die fehlerhafte `_preserve_sensitive_vars()` in `lib/auto_update_engine.sh:135-153`:

```bash
_preserve_sensitive_vars() {
    local old_script="$1"
    local new_content="$2"

    # Extrahiere GITHUB_TOKEN aus altem Script
    local old_token=""
    if [[ -f "$old_script" ]]; then
        old_token=$(grep -E '^GITHUB_TOKEN=' "$old_script" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi

    # Wenn Token vorhanden und nicht leer, in neue Version einsetzen
    if [[ -n "$old_token" && "$old_token" != "" ]]; then
        _log DEBUG "Preserving GitHub token in updated version"
        new_content=$(echo "$new_content" | sed "s|^GITHUB_TOKEN=\"[^\"]*\"|GITHUB_TOKEN=\"$old_token\"|g")
    fi

    echo "$new_content"
}
```

Der alte Token wird bedingungslos in `new_content` eingesetzt, sobald er nicht leer ist — ein rotierter Token in der neu ausgelieferten Version wird nie berücksichtigt. Das ist exakt der gemeldete Defekt, unverändert auf `main`.

**Ein Fix existiert bereits, ist aber nicht gemerged:** Branch `fix/token-rotation-precedence`, Commit `686be0c` ("fix(engine): rotierter GITHUB_TOKEN im Release hat Vorrang vor Carry-Forward (#1)"), Autor 7onnie, Datum 2026-09-03. Er prüft zuerst, ob `new_content` bereits einen nicht-leeren `GITHUB_TOKEN` trägt (dann gewinnt dieser), und fällt nur sonst auf den alten Carry-Forward zurück. Identisch angewendet in allen 4 Fundstellen: `lib/auto_update_engine.sh`, `lib/auto_update_github_only.sh`, `lib/auto_update_direct_only.sh`, `standalone/auto_update_standalone.sh`, plus Regressionstest `tests/test_credential_rotation.sh` (neu, eingebunden über `bin/suite.sh`).

**(b) Offene Branches/PRs:**
- Branch `fix/token-rotation-precedence` (1 Commit `686be0c`, 2026-09-03) — **kein PR dafür vorhanden** (`gh pr list --state all` zeigt nur PR #2, gemerged 2026-08-31, unabhängiges Thema `timeout-minutes`).
- `git merge-base --is-ancestor origin/main origin/fix/token-rotation-precedence` bestätigt: Branch ist reiner Fast-Forward von `main`, d.h. sauber mergebar ohne Konflikte.

**(c) Flotten-Liste** (per `git clone` + `grep -rn` gegen die 5 genannten Repos):

| Repo | Datei:Zeile | Gleicher Defekt? |
|---|---|---|
| `AutoUpdaterWin` | `lib/auto_update_helpers.ps1:95-127` (`Preserve-GitHubToken`) | **JA** — unabhängig in PowerShell nachgebaut, überschreibt `$NewContent`s Token bedingungslos mit `$oldToken`, sobald dieser dem PAT-Muster entspricht. Gleicher Fehler, gleiche Ursache. |
| `MacAdmin` | `MacAdmin.sh:286` (`auto_update()`) | **Nein, aber indirekt betroffen** — lädt `lib/auto_update_engine.sh` zur Laufzeit live von `AutoUpdater@main` (mit 24h-Cache) und sourced es, statt den Mechanismus zu duplizieren. Erbt den Bug/Fix automatisch von `main` — sobald dort gemerged ist, ist MacAdmin ohne eigene Änderung mit versorgt. |
| `PrinterScripts` | – | **Nein** — kein Self-Replace/Token-Carry-Forward-Mechanismus gefunden; `Auto_PrinterInstall.sh` nutzt `GITHUB_TOKEN` nur zur Laufzeit für API-Downloads, ersetzt aber kein Script mit gemergter Konfiguration. |
| `AutoUpdaterAppleScript` | – | **Nein** — gleiches Bild, kein Carry-Forward-Mechanismus vorhanden. |
| `tomedo-Setup` | – | **Nein** — kein Auto-Update-Mechanismus im Repo vorhanden. |

**(d) Urteil: Arbeit liegt auf Branch `fix/token-rotation-precedence` (Commit `686be0c`), nur Merge fehlt.**

Der Fix ist inhaltlich vorhanden, fast-forward-mergebar und mit Regressionstest versehen — es fehlt lediglich das Öffnen/Mergen eines PR gegen `main`. Zusätzlich sollte ein Folgeauftrag den identisch nachgebauten Defekt in `7onnie/AutoUpdaterWin` (`lib/auto_update_helpers.ps1`, `Preserve-GitHubToken`) mit derselben Logik reparieren, da dieser eigenständigen Code darstellt und vom Merge in `AutoUpdater` nicht mitprofitiert.

_Hinweis am Rande, außerhalb des Auftragsumfangs:_ mehrere Repos (`PrinterScripts`, `MacAdmin`, `AutoUpdaterAppleScript`) enthalten Klartext-GitHub-PATs als Embedded-Fallback direkt im Quellcode. Das ist unabhängig vom hier untersuchten Carry-Forward-Bug, aber im Kontext „Token-Rotation" separat erwähnenswert.
