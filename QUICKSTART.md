# AutoUpdater - Quick Start

Schnelle Übersicht für sofortigen Einsatz.

---

## 1. Auf GitHub veröffentlichen

### Automatisch (empfohlen)

```bash
cd /Users/user/ZS_Share/AutoUpdater
./deploy_to_github.sh
```

Das Script führt dich durch alle Schritte:
- ✅ URLs aktualisieren
- ✅ Git Remote konfigurieren
- ✅ Code pushen
- ✅ Release erstellen

### Manuell

```bash
# 1. Erstelle Repository auf github.com/new
#    Name: AutoUpdater
#    Visibility: Public
#    DO NOT initialize with README

# 2. Remote hinzufügen
git remote add origin https://github.com/DEIN_USER/AutoUpdater.git

# 3. Pushen
git branch -M main
git push -u origin main

# 4. Tag erstellen
git tag v1.0.0
git push origin v1.0.0
```

Siehe [DEPLOYMENT_STEPS.md](DEPLOYMENT_STEPS.md) für Details.

---

## 2. In eigenes Script integrieren

### Bootstrap-Version (30 Zeilen)

```bash
#!/bin/bash
SCRIPT_VERSION="1.0.0"

# Update-Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="DEIN_USER"
UPDATE_GITHUB_REPO="dein-repo"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Bootstrap
auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/DEIN_USER/AutoUpdater/main/lib/auto_update_engine.sh"
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
echo "Script läuft v$SCRIPT_VERSION"
```

---

## 3. Release erstellen

### Für dein eigenes Script

```bash
# 1. Script in Git-Repo
cd ~/mein-script-repo
git add MeinScript.sh
git commit -m "Add auto-update"
git push

# 2. Release erstellen
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Mit Auto-Update" \
  MeinScript.sh

# 3. Testen
./MeinScript.sh
```

---

## 4. Testing

```bash
# Dry-Run (nur prüfen)
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./mein_script.sh

# Version senken zum Testen
sed -i '' 's/SCRIPT_VERSION="1.0.0"/SCRIPT_VERSION="0.9.0"/' mein_script.sh
./mein_script.sh  # Sollte Update durchführen
```

---

## Modi-Übersicht

| Modus | Für | Konfiguration |
|-------|-----|---------------|
| **github_release** | Production Scripts | `UPDATE_MODE="github_release"`<br>`UPDATE_GITHUB_USER="user"`<br>`UPDATE_GITHUB_REPO="repo"` |
| **git_pull** | Team-Development | `UPDATE_MODE="git_pull"`<br>`UPDATE_GIT_BRANCH="main"` |
| **direct_download** | Einfache Scripts | `UPDATE_MODE="direct_download"`<br>`UPDATE_DOWNLOAD_URL="https://..."` |

---

## Dateien-Übersicht

| Datei | Verwendung |
|-------|------------|
| `bootstrap/bootstrap_minimal.sh` | Copy-Paste (30 Zeilen) |
| `bootstrap/bootstrap_with_fallback.sh` | Mit Fallback (110 Zeilen) |
| `standalone/auto_update_standalone.sh` | Komplett eingebettet (450 Zeilen) |
| `lib/auto_update_engine.sh` | Komplette Engine (source) |
| `examples/example_*.sh` | Funktionierende Beispiele |

---

## Wichtige URLs

Nach GitHub-Deployment:

```
Repository:    https://github.com/DEIN_USER/AutoUpdater
Engine URL:    https://raw.githubusercontent.com/DEIN_USER/AutoUpdater/main/lib/auto_update_engine.sh
Bootstrap URL: https://raw.githubusercontent.com/DEIN_USER/AutoUpdater/main/bootstrap/bootstrap_minimal.sh
Docs:          https://github.com/DEIN_USER/AutoUpdater/tree/main/docs
```

---

## Dokumentation

- **Setup:** [docs/SETUP.md](docs/SETUP.md) - Token, erste Schritte
- **Deployment:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - CI/CD, Releases
- **Modi:** [docs/MODES.md](docs/MODES.md) - Welcher Modus?
- **Migration:** [docs/MIGRATION.md](docs/MIGRATION.md) - Bestehende Scripts

---

## Support

- **Fragen:** [GitHub Discussions](https://github.com/DEIN_USER/AutoUpdater/discussions)
- **Bugs:** [GitHub Issues](https://github.com/DEIN_USER/AutoUpdater/issues)
- **Dokumentation:** [docs/README.md](docs/README.md)

---

## Checkliste

- [ ] AutoUpdater auf GitHub gepusht
- [ ] Release v1.0.0 erstellt
- [ ] Bootstrap-URLs aktualisiert (falls nötig)
- [ ] GitHub Actions aktiviert
- [ ] Test-Script erstellt und getestet
- [ ] Eigenes Script migriert
- [ ] Release für eigenes Script erstellt
- [ ] Update funktioniert

---

**Fertig?** Dann bist du ready to auto-update! 🚀
