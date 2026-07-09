<h1 align="center">AutoUpdater</h1>

<p align="center">
  Universelle Auto-Update-Engine für Shell-Scripts.
</p>

<!-- BADGES:START -->
<p align="center">
  <a href="https://github.com/7onnie/AutoUpdater/actions/workflows/test.yml"><img alt="CI" src="https://github.com/7onnie/AutoUpdater/actions/workflows/test.yml/badge.svg"></a>
  <a href="https://github.com/7onnie/AutoUpdater/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/7onnie/AutoUpdater?sort=semver"></a>
  <a href="https://github.com/7onnie/AutoUpdater/releases"><img alt="Total downloads" src="https://img.shields.io/github/downloads/7onnie/AutoUpdater/total.svg"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/7onnie/AutoUpdater"></a>
  <a href="https://buymeacoffee.com/7onnie"><img alt="Buy me a coffee" src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black"></a>
</p>
<!-- BADGES:END -->

Modulares System mit 3 Update-Modi für verschiedene Anwendungsfälle. Einfache Integration per Copy-Paste oder Bootstrap-Loader.

---

## Features

- ✅ 3 Update-Modi: GitHub Release, Git Pull, Direct Download
- ✅ Bootstrap-Loader (nur 30 Zeilen Code)
- ✅ Standalone-Version (komplett eingebettet)
- ✅ Automatische Versions-Prüfung
- ✅ Self-Replacing mit Backup & Rollback
- ✅ Cache für Offline-Betrieb (24h)
- ✅ Dry-Run & Verbose-Modus
- ✅ Archive-Support (tar.gz, zip)
- ✅ Dependencies mitbringen
- ✅ Private Repos via Token

---

## Quick Start

### Minimal-Beispiel (30 Zeilen)

```bash
#!/bin/bash
SCRIPT_VERSION="1.0.0"

# Update-Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Bootstrap
auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
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

auto_update

# Deine Script-Logik
echo "Script läuft (Version: $SCRIPT_VERSION)"
```

---

## Modi-Vergleich

| Modus | Use-Case | Komplexität |
|-------|----------|-------------|
| **github_release** | Kontrollierte Releases, Archive, private Repos | Mittel |
| **git_pull** | Mono-Repos, Team-Entwicklung | Niedrig |
| **direct_download** | Einfache Scripts, öffentliche URLs | Sehr niedrig |

---

## Installation

### Option 1: Bootstrap (empfohlen)

Kopiere `bootstrap/bootstrap_minimal.sh` in dein Script:

```bash
curl -sS https://raw.githubusercontent.com/7onnie/AutoUpdater/main/bootstrap/bootstrap_minimal.sh
```

### Option 2: Standalone

Kopiere `standalone/auto_update_standalone.sh` (komplett eingebettet, 400 Zeilen):

```bash
curl -sS https://raw.githubusercontent.com/7onnie/AutoUpdater/main/standalone/auto_update_standalone.sh
```

### Option 3: Als Submodule

```bash
git submodule add https://github.com/7onnie/AutoUpdater.git
source AutoUpdater/lib/auto_update_engine.sh
```

---

## Dokumentation

- 📘 [Setup Guide](docs/SETUP.md) - Token erstellen, erste Schritte
- 🚀 [Deployment Guide](docs/DEPLOYMENT.md) - CI/CD, automatische Releases
- 🔀 [Modes Comparison](docs/MODES.md) - Welcher Modus passt zu dir?
- 📦 [Migration Guide](docs/MIGRATION.md) - Bestehende Scripts migrieren

---

## Repository-Struktur

```
AutoUpdater/
├── lib/                    # Update-Engine Module
│   ├── auto_update_engine.sh          # Vollständige Engine
│   ├── auto_update_github_only.sh     # Nur GitHub Release
│   ├── auto_update_git_only.sh        # Nur Git Pull
│   └── auto_update_direct_only.sh     # Nur Direct Download
├── bootstrap/              # Bootstrap-Loader
│   ├── bootstrap_minimal.sh           # 30 Zeilen
│   └── bootstrap_with_fallback.sh     # 110 Zeilen mit Fallback
├── standalone/             # Standalone-Version
│   └── auto_update_standalone.sh      # 400 Zeilen Copy-Paste
├── examples/               # Beispiel-Scripts
├── docs/                   # Dokumentation
└── tests/                  # Test-Suite
```

---

## Testing

```bash
# Syntax-Check
bash -n dein_script.sh

# Dry-Run
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./dein_script.sh

# Test-Suite ausführen
./tests/test_all_modes.sh
```

---

## Beispiele

### GitHub Release Modus

```bash
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="scripts"
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
```

### Git Pull Modus

```bash
UPDATE_MODE="git_pull"
UPDATE_GIT_BRANCH="master"
```

### Direct Download Modus

```bash
UPDATE_MODE="direct_download"
UPDATE_DOWNLOAD_URL="https://raw.githubusercontent.com/7onnie/scripts/master/MeinScript.sh"
UPDATE_VERSION_URL="https://raw.githubusercontent.com/7onnie/scripts/master/VERSION"
```

---

## Roadmap

- [ ] SHA256-Checksummen für Verifizierung
- [ ] GPG-Signatur Support
- [ ] Prometheus Metrics Export
- [ ] Auto-Update für die Engine selbst
- [ ] Webhooks für Update-Benachrichtigungen
- [ ] Delta-Updates (nur Änderungen)

---

## Contributing

Contributions sind willkommen! Bitte:

1. Fork das Repository
2. Erstelle einen Feature-Branch (`git checkout -b feature/awesome-feature`)
3. Commit deine Änderungen (`git commit -am 'Add awesome feature'`)
4. Push zum Branch (`git push origin feature/awesome-feature`)
5. Erstelle einen Pull Request

---

## Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/7onnie/AutoUpdater/issues)
- **Diskussionen:** [GitHub Discussions](https://github.com/7onnie/AutoUpdater/discussions)

---

## Changelog

### v1.0.0 (2026-01-26)

- Initial Release
- 3 Update-Modi (GitHub Release, Git Pull, Direct Download)
- Bootstrap-Loader (minimal + fallback)
- Standalone-Version
- Vollständige Dokumentation
- Test-Suite
- GitHub Actions Workflows
- Beispiele für alle Modi

---

Made with ❤️ by the AutoUpdater Contributors
