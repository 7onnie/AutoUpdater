# Setup Guide

Schritt-für-Schritt Anleitung zur Einrichtung von AutoUpdater.

---

## Inhaltsverzeichnis

1. [GitHub Token erstellen](#github-token-erstellen)
2. [AutoUpdater Repository Setup](#autoupdater-repository-setup)
3. [Erstes Script mit Auto-Update](#erstes-script-mit-auto-update)
4. [Ersten Release erstellen](#ersten-release-erstellen)
5. [Testing](#testing)
6. [Token-Verwaltung](#token-verwaltung)

---

## GitHub Token erstellen

### Wofür brauche ich einen Token?

- **Öffentliche Repos:** Kein Token nötig (außer für höhere API Rate-Limits)
- **Private Repos:** Token zwingend erforderlich
- **Empfehlung:** Immer Token verwenden für bessere Rate-Limits (5000 statt 60 Requests/Stunde)

### Schritt 1: GitHub Settings öffnen

1. Gehe zu [github.com](https://github.com) und melde dich an
2. Klicke auf dein Profil-Bild (oben rechts)
3. **Settings** → **Developer settings** (ganz unten in der Sidebar)
4. **Personal access tokens** → **Tokens (classic)**

### Schritt 2: Neuen Token erstellen

1. Klicke auf **Generate new token** → **Generate new token (classic)**
2. **Note:** Vergib einen aussagekräftigen Namen, z.B. "AutoUpdater Scripts"
3. **Expiration:** Wähle Gültigkeit (empfohlen: 90 days oder No expiration für Production)

### Schritt 3: Scopes auswählen

**Für öffentliche Repos:**
```
✓ public_repo  (Nur öffentliche Repositories)
```

**Für private Repos:**
```
✓ repo  (Full control of private repositories)
  ✓ repo:status
  ✓ repo_deployment
  ✓ public_repo
  ✓ repo:invite
  ✓ security_events
```

### Schritt 4: Token kopieren

1. Klicke auf **Generate token**
2. **WICHTIG:** Kopiere den Token SOFORT (wird nur einmal angezeigt!)
3. Token hat Format: `ghp_...` (classic) oder `github_pat_...` (fine-grained)

```bash
# Beispiel:
github_pat_11XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Schritt 5: Token sicher speichern

**Option 1: Umgebungsvariable (empfohlen)**

```bash
# In ~/.zshrc oder ~/.bashrc
export GITHUB_TOKEN="github_pat_XXX"

# Neu laden
source ~/.zshrc
```

**Option 2: Keychain (macOS)**

```bash
# Token in Keychain speichern
security add-generic-password -a "$USER" -s "github_token" -w "github_pat_XXX"

# Token aus Keychain lesen
GITHUB_TOKEN=$(security find-generic-password -a "$USER" -s "github_token" -w)
```

**Option 3: Im Script (nur für private Scripts!)**

```bash
# Nur wenn Script selbst privat ist!
GITHUB_TOKEN="github_pat_XXX"  # AutoUpdater gibt Warnung aus
```

---

## AutoUpdater Repository Setup

### Option A: Dieses Repo verwenden (empfohlen)

```bash
# Klone AutoUpdater Repository
cd ~/ZS_Share
git clone https://github.com/7onnie/AutoUpdater.git

# Prüfe Struktur
cd AutoUpdater
ls -la
```

### Option B: Eigenes AutoUpdater Repo erstellen

```bash
# Falls du eigene Anpassungen machen möchtest
cd /Users/user/ZS_Share/AutoUpdater

# Git initialisieren (falls noch nicht geschehen)
git init
git add .
git commit -m "Initial: AutoUpdater v1.0.0"

# Auf GitHub pushen
gh repo create AutoUpdater --public --source=. --remote=origin --push

# Oder manuell:
# 1. Erstelle Repo auf github.com
# 2. git remote add origin https://github.com/DEIN_USER/AutoUpdater.git
# 3. git push -u origin master
```

### Verifizierung

Prüfe dass Bootstrap-URL erreichbar ist:

```bash
curl -sI https://raw.githubusercontent.com/7onnie/AutoUpdater/master/lib/auto_update_engine.sh

# Sollte "200 OK" zurückgeben
```

---

## Erstes Script mit Auto-Update

### Schritt 1: Neues Script erstellen

```bash
# Erstelle neues Script
touch ~/MeinScript.sh
chmod +x ~/MeinScript.sh
```

### Schritt 2: Bootstrap einfügen

Öffne das Script und füge ein:

```bash
#!/bin/bash
# ==========================================
# MEIN SCRIPT
# ==========================================

SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"  # ANPASSEN!
UPDATE_GITHUB_REPO="mein-repo"  # ANPASSEN!
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Aus Umgebungsvariable

# ==========================================
# AUTO-UPDATE BOOTSTRAP
# ==========================================

auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440

    mkdir -p "$CACHE_DIR" 2>/dev/null

    # Cache-Check (24h)
    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    # Download & Execute
    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update Engine nicht erreichbar. Script läuft ohne Update-Check weiter."
        return 1
    fi
}

# ==========================================
# MAIN LOGIC
# ==========================================

main() {
    # Auto-Update durchführen
    auto_update

    # Deine Script-Logik
    echo "Hallo von MeinScript v$SCRIPT_VERSION"
    echo "Hier kommt deine eigentliche Funktionalität..."
}

main "$@"
```

### Schritt 3: Script in Git-Repo

```bash
# Neues Repo erstellen
mkdir ~/mein-repo
cd ~/mein-repo
git init

# Script hinzufügen
cp ~/MeinScript.sh .
git add MeinScript.sh
git commit -m "Initial: MeinScript v1.0.0"

# Auf GitHub pushen
gh repo create mein-repo --public --source=. --remote=origin --push
```

---

## Ersten Release erstellen

### Via GitHub CLI (gh)

```bash
cd ~/mein-repo

# Release mit Script als Asset
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Erste Version mit Auto-Update" \
  MeinScript.sh

# Prüfen
gh release list
gh release view v1.0.0
```

### Via GitHub Web-UI

1. Gehe zu deinem Repository auf github.com
2. **Releases** → **Create a new release**
3. **Tag:** `v1.0.0` (muss mit v beginnen!)
4. **Title:** `Version 1.0.0`
5. **Description:** Changelog eingeben
6. **Attach binaries:** `MeinScript.sh` hochladen
7. **Publish release**

### Via API (curl)

```bash
# Release erstellen
RELEASE_ID=$(curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/7onnie/mein-repo/releases \
  -d '{
    "tag_name": "v1.0.0",
    "name": "Version 1.0.0",
    "body": "Erste Version",
    "draft": false,
    "prerelease": false
  }' | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

# Asset hochladen
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @MeinScript.sh \
  "https://uploads.github.com/repos/7onnie/mein-repo/releases/$RELEASE_ID/assets?name=MeinScript.sh"
```

---

## Testing

### 1. Lokales Testing

```bash
# Erste Version testen (sollte "bereits aktuell" sagen)
./MeinScript.sh

# Version ändern und testen
sed -i '' 's/SCRIPT_VERSION="1.0.0"/SCRIPT_VERSION="0.9.0"/' MeinScript.sh
./MeinScript.sh  # Sollte Update auf 1.0.0 durchführen
```

### 2. Dry-Run Testing

```bash
# Nur prüfen, nicht aktualisieren
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./MeinScript.sh
```

### 3. Cache Testing

```bash
# Ohne Cache (immer neu laden)
rm -rf /tmp/auto_update_cache/
./MeinScript.sh

# Mit Cache (24h gültig)
./MeinScript.sh  # Nutzt gecachte Engine
```

### 4. Offline Testing

```bash
# Internet deaktivieren, dann:
./MeinScript.sh  # Sollte Cache nutzen

# Cache löschen und erneut versuchen
rm -rf /tmp/auto_update_cache/
./MeinScript.sh  # Sollte Warnung zeigen, aber weiterlaufen
```

---

## Token-Verwaltung

### Token rotieren

```bash
# Alten Token widerrufen auf github.com
# Neuen Token erstellen (siehe oben)
# Umgebungsvariable aktualisieren

export GITHUB_TOKEN="github_pat_NEW"

# In ~/.zshrc speichern
echo 'export GITHUB_TOKEN="github_pat_NEW"' >> ~/.zshrc
```

### Token-Berechtigung prüfen

```bash
# Teste API-Zugriff
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user

# Sollte deine User-Info zurückgeben
```

### Token-Sicherheit

**DO:**
- ✅ Token in Umgebungsvariable speichern
- ✅ Token mit minimalen Scopes erstellen
- ✅ Token regelmäßig rotieren (alle 90 Tage)
- ✅ Token in Keychain/Vault speichern (Production)

**DON'T:**
- ❌ Token in öffentlichen Repos commiten
- ❌ Token in Logs ausgeben
- ❌ Token per Email/Chat teilen
- ❌ "No expiration" für Test-Token

---

## Troubleshooting

### "Permission denied"

```bash
# Script ausführbar machen
chmod +x MeinScript.sh
```

### "GitHub API rate limit exceeded"

```bash
# Token verwenden (erhöht Limit von 60 auf 5000/h)
export GITHUB_TOKEN="github_pat_XXX"

# Aktuelles Limit prüfen
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/rate_limit
```

### "Release not found"

```bash
# Prüfe ob Release existiert
gh release list

# Prüfe Tag-Name (muss exakt übereinstimmen)
# v1.0.0 ≠ 1.0.0
```

### "Asset not found"

```bash
# Prüfe Assets im Release
gh release view v1.0.0

# UPDATE_ASSET_NAME exakt anpassen (case-sensitive!)
UPDATE_ASSET_NAME="MeinScript.sh"  # Nicht meinscript.sh
```

---

## Nächste Schritte

- **CI/CD einrichten:** [DEPLOYMENT.md](DEPLOYMENT.md) - Automatische Releases
- **Modus wechseln:** [MODES.md](MODES.md) - Alternative Update-Modi
- **Produktion:** [MIGRATION.md](MIGRATION.md) - Mehr Scripts migrieren
