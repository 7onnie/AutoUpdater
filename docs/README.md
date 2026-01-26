# AutoUpdater

**Universelle Auto-Update-Engine für Shell-Scripts**

Modulares System mit 3 Update-Modi für verschiedene Anwendungsfälle. Einfache Integration per Copy-Paste oder Bootstrap-Loader.

---

## Quick Start

### 1. Wähle deinen Update-Modus

| Modus | Anwendungsfall | Komplexität |
|-------|----------------|-------------|
| **github_release** | Scripts mit Dependencies, kontrollierte Releases | Mittel |
| **git_pull** | Scripts in Git Mono-Repos, Team-Entwicklung | Niedrig |
| **direct_download** | Einfache standalone Scripts, öffentliche URLs | Sehr niedrig |

### 2. Bootstrap oder Standalone?

**Bootstrap (empfohlen):**
- Nur 30 Zeilen Code in deinem Script
- Lädt Engine von GitHub (mit 24h Cache)
- Automatische Updates der Engine selbst

**Standalone:**
- 400 Zeilen Code eingebettet
- Keine externen Dependencies
- Funktioniert offline

### 3. Minimal-Beispiel

```bash
#!/bin/bash
SCRIPT_VERSION="1.0.0"

# Update-Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Bootstrap (30 Zeilen)
auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/lib/auto_update_engine.sh"
    local CACHE_FILE="/tmp/auto_update_cache/engine.sh"

    mkdir -p "$(dirname "$CACHE_FILE")"

    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -1440 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update nicht verfügbar"
        return 1
    fi
}

# Update durchführen
auto_update

# Deine Script-Logik
echo "Script läuft (Version: $SCRIPT_VERSION)"
```

---

## Features

### Alle Modi

- ✅ Automatische Versions-Prüfung
- ✅ Self-Replacing (Script ersetzt sich selbst)
- ✅ Automatischer Backup vor Update
- ✅ Rollback bei Fehler
- ✅ Dry-Run Modus für Testing
- ✅ Verbose-Modus für Debugging
- ✅ Konfigurierbare Timeouts
- ✅ Cache für Offline-Betrieb

### GitHub Release Modus

- ✅ GitHub API Integration
- ✅ Token-Authentifizierung (private Repos)
- ✅ Archive-Support (tar.gz, zip)
- ✅ Dependencies mitbringen (DEP-Ordner)
- ✅ Spezifische Assets auswählen
- ✅ Tag-basierte Versions-Kontrolle

### Git Pull Modus

- ✅ Automatisches git pull
- ✅ Lokale Änderungs-Erkennung
- ✅ Commit-Differenz Anzeige
- ✅ Nutzt bestehende Git-Credentials
- ✅ Auto-Restart nach Update

### Direct Download Modus

- ✅ Direkter Download von URLs
- ✅ Optional: Version-Check via separate URL
- ✅ Shebang-Validierung
- ✅ Minimale Dependencies (nur curl)

---

## Repository-Struktur

```
AutoUpdater/
├── lib/
│   ├── auto_update_engine.sh           # Vollständige Engine (alle Modi)
│   ├── auto_update_github_only.sh      # Nur GitHub Release
│   ├── auto_update_git_only.sh         # Nur Git Pull
│   └── auto_update_direct_only.sh      # Nur Direct Download
├── bootstrap/
│   ├── bootstrap_minimal.sh            # 30 Zeilen Bootstrap
│   └── bootstrap_with_fallback.sh      # 110 Zeilen mit Fallback
├── standalone/
│   └── auto_update_standalone.sh       # 400 Zeilen Copy-Paste Version
├── examples/
│   ├── example_bootstrap_minimal.sh    # Bootstrap-Beispiel
│   ├── example_bootstrap_fallback.sh   # Bootstrap + Fallback
│   ├── example_standalone.sh           # Standalone-Beispiel
│   ├── example_github_release.sh       # GitHub Release Modus
│   ├── example_git_pull.sh             # Git Pull Modus
│   └── example_direct_download.sh      # Direct Download Modus
├── docs/
│   ├── README.md                       # Diese Datei
│   ├── SETUP.md                        # Token-Setup, Erste Schritte
│   ├── DEPLOYMENT.md                   # CI/CD, GitHub Actions
│   ├── MODES.md                        # Modi-Vergleich, Entscheidungshilfe
│   └── MIGRATION.md                    # Bestehende Scripts migrieren
└── tests/
    └── test_all_modes.sh               # Automatische Tests
```

---

## Nächste Schritte

1. **Setup:** [SETUP.md](SETUP.md) - GitHub Token erstellen, Repository konfigurieren
2. **Modus wählen:** [MODES.md](MODES.md) - Welcher Modus passt zu deinem Use-Case?
3. **Integration:** [MIGRATION.md](MIGRATION.md) - Bestehendes Script migrieren
4. **Deployment:** [DEPLOYMENT.md](DEPLOYMENT.md) - CI/CD, automatische Releases

---

## Konfiguration

### Umgebungsvariablen

```bash
# Alle Modi
UPDATE_VERBOSE=1              # Aktiviere Debug-Output
UPDATE_DRY_RUN=1              # Nur prüfen, nicht aktualisieren
UPDATE_LOG="/path/to/log"     # Log-Datei
UPDATE_BACKUP=1               # Backup vor Update (Standard: 1)
UPDATE_TIMEOUT=30             # curl Timeout in Sekunden

# GitHub Release Modus
UPDATE_GITHUB_USER="user"
UPDATE_GITHUB_REPO="repo"
UPDATE_RELEASE_TAG="latest"   # oder "v1.0.0"
UPDATE_ASSET_NAME="script.sh" # Optional: spezifisches Asset
GITHUB_TOKEN="github_pat_XXX" # Für private Repos

# Git Pull Modus
UPDATE_GIT_REPO_PATH="/path"  # Optional, wird auto-detected
UPDATE_GIT_BRANCH="master"    # oder "main", "develop"

# Direct Download Modus
UPDATE_DOWNLOAD_URL="https://..." # Raw URL zum Script
UPDATE_VERSION_URL="https://..."  # Optional: Version-Check URL
```

---

## Testing

```bash
# Dry-Run (nur prüfen, nicht aktualisieren)
UPDATE_DRY_RUN=1 ./mein_script.sh

# Verbose-Modus (Debug-Output)
UPDATE_VERBOSE=1 ./mein_script.sh

# Update deaktivieren
UPDATE_MODE="disabled" ./mein_script.sh

# Alle Tests ausführen
./tests/test_all_modes.sh
```

---

## Sicherheit

### Token-Handling

**Empfohlen:** Umgebungsvariable
```bash
export GITHUB_TOKEN="github_pat_XXX"
./mein_script.sh
```

**Alternativ:** Im Script (nur für private Scripts!)
```bash
GITHUB_TOKEN="github_pat_XXX"  # Warnung wird ausgegeben
```

### Validierung

- Scripts werden auf Shebang geprüft (`#!/bin/bash`)
- Backups werden vor jedem Update erstellt
- Rollback bei fehlgeschlagenem Update
- Cache-Dateien haben begrenzte Lebensdauer (24h)

---

## Troubleshooting

### "GitHub API nicht erreichbar"
- Prüfe Internetverbindung
- Prüfe GitHub Token (falls private Repos)
- Cache-Datei wird verwendet falls verfügbar

### "curl nicht gefunden"
- Installiere curl: `brew install curl` (macOS) oder `apt-get install curl` (Linux)

### "python3 oder jq erforderlich"
- Installiere python3: `brew install python3` (macOS)
- Oder installiere jq: `brew install jq` (macOS)

### "Git-Repository nicht gefunden"
- Script muss in einem Git-Repository liegen (für git_pull Modus)
- Prüfe mit `git status`

### Update funktioniert nicht
```bash
# Debug aktivieren
UPDATE_VERBOSE=1 ./mein_script.sh

# Cache löschen
rm -rf /tmp/auto_update_cache/

# Dry-Run testen
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./mein_script.sh
```

---

## Verbesserungen gegenüber bestehenden Lösungen

### vs. Auto_BU_SSD

| Feature | Auto_BU_SSD | AutoUpdater |
|---------|-------------|-------------|
| **Modi** | 1 (GitHub) | 3 (GitHub, Git, Direct) |
| **Token-Sicherheit** | Hardcoded | Umgebungsvariable + Warnung |
| **Offline-fähig** | Nein | Ja (24h Cache) |
| **Rollback** | Nein | Ja (automatisch) |
| **Error-Handling** | exit (stoppt Script) | return (Script läuft weiter) |
| **Debugging** | Nein | Verbose + Dry-Run + Logging |
| **Bootstrap** | Nein | Ja (30 Zeilen) |
| **Standalone** | Nein | Ja (400 Zeilen) |

---

## Lizenz

MIT License - Frei verwendbar für kommerzielle und private Projekte.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/7onnie/AutoUpdater/issues)
- **Dokumentation:** [docs/](docs/)
- **Beispiele:** [examples/](examples/)

---

## Changelog

### v1.0.0 (2026-01-26)
- Initial Release
- 3 Update-Modi (GitHub Release, Git Pull, Direct Download)
- Bootstrap-Loader (minimal + fallback)
- Standalone Version
- Vollständige Dokumentation
- Beispiel-Scripts für alle Modi
