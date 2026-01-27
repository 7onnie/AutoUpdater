# AutoUpdater - GitHub Deployment Steps

Schritt-für-Schritt Anleitung um AutoUpdater auf GitHub zu veröffentlichen.

---

## Schritt 1: GitHub Repository erstellen

### Option A: Via GitHub CLI (wenn gh installiert ist)

```bash
cd /Users/user/ZS_Share/AutoUpdater

# Repository erstellen und direkt pushen
gh repo create AutoUpdater --public --source=. --remote=origin --push
```

### Option B: Manuell via GitHub.com

1. Gehe zu [github.com/new](https://github.com/new)
2. **Repository name:** `AutoUpdater`
3. **Description:** `Universelle Auto-Update-Engine für Shell-Scripts`
4. **Visibility:** Public ✅
5. **DO NOT initialize** with README, .gitignore, or license (existieren bereits)
6. Klicke **Create repository**
7. Kopiere die Repository-URL (z.B. `https://github.com/DEIN_USER/AutoUpdater.git`)

---

## Schritt 2: Remote konfigurieren und pushen

```bash
cd /Users/user/ZS_Share/AutoUpdater

# Remote hinzufügen (ERSETZE DEIN_USER mit deinem GitHub Username!)
git remote add origin https://github.com/DEIN_USER/AutoUpdater.git

# Prüfen
git remote -v

# Pushen
git push -u origin main
```

**Falls Main-Branch nicht existiert:**
```bash
# Branch umbenennen von master zu main (falls nötig)
git branch -M main
git push -u origin main
```

---

## Schritt 3: Bootstrap-URLs aktualisieren

**NUR erforderlich wenn dein GitHub User NICHT "7onnie" ist!**

Falls dein Repository unter einem anderen User liegt (z.B. `github.com/DEIN_USER/AutoUpdater`), müssen die Bootstrap-URLs aktualisiert werden:

```bash
cd /Users/user/ZS_Share/AutoUpdater

# Ersetze 7onnie mit deinem User (macOS)
find . -type f \( -name "*.sh" -o -name "*.md" \) -exec sed -i '' 's/7onnie\/AutoUpdater/DEIN_USER\/AutoUpdater/g' {} +

# Commit
git add .
git commit -m "Update: Bootstrap URLs mit korrektem GitHub User"
git push
```

**Für Linux:**
```bash
find . -type f \( -name "*.sh" -o -name "*.md" \) -exec sed -i 's/7onnie\/AutoUpdater/DEIN_USER\/AutoUpdater/g' {} +
```

---

## Schritt 4: Ersten Release erstellen

### Option A: Via GitHub CLI

```bash
cd /Users/user/ZS_Share/AutoUpdater

# Tag erstellen
git tag -a v1.0.0 -m "Initial release: AutoUpdater v1.0.0"
git push origin v1.0.0

# Release erstellen (mit Assets)
gh release create v1.0.0 \
  --title "AutoUpdater v1.0.0" \
  --notes "$(cat <<'EOF'
# AutoUpdater v1.0.0

Erste öffentliche Version der universellen Auto-Update-Engine für Shell-Scripts.

## Features

- ✅ 3 Update-Modi: GitHub Release, Git Pull, Direct Download
- ✅ Bootstrap-Loader (nur 30 Zeilen)
- ✅ Standalone-Version (450 Zeilen)
- ✅ Vollständige Dokumentation
- ✅ Test-Suite mit 15+ Tests
- ✅ GitHub Actions Workflows

## Installation

```bash
# Bootstrap minimal (30 Zeilen)
curl -sS https://raw.githubusercontent.com/$(git config remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/master/bootstrap/bootstrap_minimal.sh

# Dokumentation
https://github.com/$(git config remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/blob/master/docs/README.md
```

## Quick Start

Siehe [Setup Guide](https://github.com/$(git config remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/blob/master/docs/SETUP.md)
EOF
)" \
  lib/auto_update_engine.sh \
  lib/auto_update_github_only.sh \
  lib/auto_update_git_only.sh \
  lib/auto_update_direct_only.sh \
  bootstrap/bootstrap_minimal.sh \
  bootstrap/bootstrap_with_fallback.sh \
  standalone/auto_update_standalone.sh
```

### Option B: Manuell via GitHub.com

1. Gehe zu deinem Repository auf GitHub
2. Klicke auf **Releases** (rechte Sidebar)
3. Klicke **Create a new release**
4. **Choose a tag:** `v1.0.0` (wird neu erstellt)
5. **Release title:** `AutoUpdater v1.0.0`
6. **Description:** Kopiere die Release Notes von oben
7. **Attach binaries:** Lade folgende Dateien hoch:
   - `lib/auto_update_engine.sh`
   - `lib/auto_update_github_only.sh`
   - `lib/auto_update_git_only.sh`
   - `lib/auto_update_direct_only.sh`
   - `bootstrap/bootstrap_minimal.sh`
   - `bootstrap/bootstrap_with_fallback.sh`
   - `standalone/auto_update_standalone.sh`
8. Klicke **Publish release**

---

## Schritt 5: GitHub Actions aktivieren

GitHub Actions sollten automatisch aktiviert sein. Prüfe:

1. Gehe zu **Actions** Tab in deinem Repository
2. Du solltest den "Test Suite" Workflow sehen
3. Falls nicht aktiviert, klicke **Enable workflows**

### Ersten Test-Run triggern

```bash
# Kleines Update committen um Workflow zu triggern
cd /Users/user/ZS_Share/AutoUpdater
echo "" >> README.md
git add README.md
git commit -m "Trigger: Test workflow"
git push

# Check Workflow Status
# Gehe zu github.com/DEIN_USER/AutoUpdater/actions
```

---

## Schritt 6: Verifizierung

### Prüfe dass alles funktioniert:

1. **Repository erreichbar:**
   ```bash
   curl -I https://github.com/DEIN_USER/AutoUpdater
   # Sollte 200 OK zurückgeben
   ```

2. **Raw Bootstrap-URL erreichbar:**
   ```bash
   curl -sS https://raw.githubusercontent.com/DEIN_USER/AutoUpdater/main/bootstrap/bootstrap_minimal.sh | head -5
   # Sollte Shebang und Kommentare zeigen
   ```

3. **Engine-URL erreichbar:**
   ```bash
   curl -I https://raw.githubusercontent.com/DEIN_USER/AutoUpdater/main/lib/auto_update_engine.sh
   # Sollte 200 OK zurückgeben
   ```

4. **Release existiert:**
   ```bash
   curl -sS https://api.github.com/repos/DEIN_USER/AutoUpdater/releases/latest | grep tag_name
   # Sollte "v1.0.0" zeigen
   ```

---

## Schritt 7: Test-Script erstellen

Erstelle ein Test-Script um die Integration zu testen:

```bash
cd ~
cat > test_autoupdater.sh <<'EOF'
#!/bin/bash

SCRIPT_VERSION="1.0.0"

# Update-Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="DEIN_USER"  # ANPASSEN!
UPDATE_GITHUB_REPO="AutoUpdater"
UPDATE_RELEASE_TAG="latest"

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

echo "✅ Test erfolgreich! AutoUpdater funktioniert."
EOF

chmod +x test_autoupdater.sh

# Testen
UPDATE_VERBOSE=1 ./test_autoupdater.sh
```

---

## Troubleshooting

### "fatal: Authentication failed"

```bash
# SSH verwenden statt HTTPS
git remote set-url origin git@github.com:DEIN_USER/AutoUpdater.git
git push -u origin main
```

### "Branch main does not exist"

```bash
# Branch umbenennen
git branch -M main
git push -u origin main
```

### "Permission denied (publickey)"

```bash
# SSH-Key generieren und zu GitHub hinzufügen
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
# Kopiere Output und füge bei GitHub ein: Settings > SSH Keys > New SSH Key
```

### "gh: command not found"

```bash
# GitHub CLI installieren
# macOS:
brew install gh

# Linux:
# Siehe https://github.com/cli/cli/blob/trunk/docs/install_linux.md

# Nach Installation:
gh auth login
```

---

## Nächste Schritte

Nach erfolgreichem Deployment:

1. **README-Badge hinzufügen:**
   - Gehe zu Actions > Test Suite Workflow
   - Klicke auf "..." > "Create status badge"
   - Kopiere Markdown und füge in README.md ein

2. **Topics hinzufügen:**
   - Gehe zu Repository Settings
   - Topics: `shell`, `bash`, `auto-update`, `deployment`, `scripts`

3. **Weitere Scripts migrieren:**
   - Siehe [docs/MIGRATION.md](docs/MIGRATION.md)

4. **Community Features aktivieren:**
   - Issues Template erstellen
   - Discussions aktivieren
   - Security Policy hinzufügen

---

## Fertig! 🎉

Dein AutoUpdater ist jetzt auf GitHub und ready to use!

Repository-URL: `https://github.com/DEIN_USER/AutoUpdater`

Teile es mit:
```bash
echo "Check out my AutoUpdater project: https://github.com/DEIN_USER/AutoUpdater"
```
