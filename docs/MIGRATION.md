# Migration Guide

Bestehende Scripts auf AutoUpdater migrieren.

---

## Inhaltsverzeichnis

1. [Vorbereitung](#vorbereitung)
2. [Bootstrap-Integration](#bootstrap-integration)
3. [Standalone-Integration](#standalone-integration)
4. [Auto_BU_SSD Migration](#auto_bu_ssd-migration)
5. [Testing nach Migration](#testing-nach-migration)
6. [Batch-Migration](#batch-migration)

---

## Vorbereitung

### 1. Script analysieren

```bash
# Prüfe ob Script bereits ein Update-System hat
grep -i "update\|auto.*update" MeinScript.sh

# Prüfe Dependencies
grep -E "^(source|\.)" MeinScript.sh

# Prüfe ob Script in Git-Repo liegt
git rev-parse --show-toplevel 2>/dev/null
```

### 2. Backup erstellen

```bash
# Lokales Backup
cp MeinScript.sh MeinScript.sh.backup

# Versionskontrolle
git add MeinScript.sh
git commit -m "Backup: Before AutoUpdater migration"
```

### 3. Versions-Info hinzufügen (falls nicht vorhanden)

```bash
# Am Anfang des Scripts einfügen
SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="$(date +%Y%m%d)"
```

---

## Bootstrap-Integration

### Schritt 1: Update-Modus wählen

Siehe [MODES.md](MODES.md) für Entscheidungshilfe.

```bash
# Für meisten Fälle:
UPDATE_MODE="github_release"

# Für Git Mono-Repos:
UPDATE_MODE="git_pull"

# Für einfache Scripts:
UPDATE_MODE="direct_download"
```

### Schritt 2: Konfiguration am Script-Anfang

Füge NACH dem Shebang und NACH der Version-Info ein:

```bash
#!/bin/bash

# ==========================================
# SCRIPT METADATA
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
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440

    mkdir -p "$CACHE_DIR" 2>/dev/null

    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update Engine nicht erreichbar. Script läuft ohne Update-Check weiter."
        return 1
    fi
}

# ==========================================
# [HIER BEGINNT DEIN ORIGINAL-CODE]
# ==========================================

# Auto-Update durchführen (vor main-Logik!)
auto_update

# Deine original Script-Logik
# ...
```

### Schritt 3: Testen

```bash
# Syntax-Check
bash -n MeinScript.sh

# Dry-Run
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./MeinScript.sh

# Normaler Lauf
./MeinScript.sh
```

---

## Standalone-Integration

Für Scripts die offline funktionieren müssen oder ohne Bootstrap.

### Schritt 1: Standalone-Code kopieren

```bash
# Öffne standalone/auto_update_standalone.sh
# Kopiere alles zwischen "BEGIN AUTO-UPDATE ENGINE" und "END AUTO-UPDATE ENGINE"
```

### Schritt 2: In Script einfügen

```bash
#!/bin/bash

SCRIPT_VERSION="1.0.0"

# Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# ==========================================
# BEGIN AUTO-UPDATE ENGINE (ca. 400 Zeilen)
# ==========================================
# [HIER STANDALONE-CODE EINFÜGEN]
# ==========================================
# END AUTO-UPDATE ENGINE
# ==========================================

# Auto-Update durchführen
auto_update

# Deine Script-Logik
# ...
```

### Schritt 3: Testen

```bash
# Prüfe Dateigröße (sollte ca. 400 Zeilen mehr sein)
wc -l MeinScript.sh

# Test
./MeinScript.sh
```

---

## Auto_BU_SSD Migration

Für Scripts die das alte Auto_BU_SSD System nutzen.

### Schritt 1: Altes System identifizieren

```bash
# Suche nach Auto_BU_SSD Code
grep -A 20 "Auto.Update" MeinScript.sh
```

Typisches Muster:

```bash
# Alt (Auto_BU_SSD)
if [[ "$AutoUpdate" == "true" ]]; then
    # ... komplexer Update-Code ...
fi
```

### Schritt 2: Alten Code entfernen

```bash
# Entferne alle Zeilen zwischen Auto-Update Markierungen
sed -i '' '/# Auto.Update/,/fi # End Auto.Update/d' MeinScript.sh
```

**Oder manuell:**

1. Öffne Script in Editor
2. Lösche kompletten Auto-Update Block
3. Lösche DEP-Ordner Logik (wird von AutoUpdater übernommen)
4. Lösche `exec "$0"` calls (wird von AutoUpdater übernommen)

### Schritt 3: Neuen AutoUpdater einfügen

Siehe [Bootstrap-Integration](#bootstrap-integration)

### Schritt 4: Konfiguration anpassen

**Auto_BU_SSD Mapping:**

| Auto_BU_SSD | AutoUpdater |
|-------------|-------------|
| `AutoUpdate=true` | `UPDATE_MODE="github_release"` |
| `GitHubUser` | `UPDATE_GITHUB_USER` |
| `GitHubRepo` | `UPDATE_GITHUB_REPO` |
| `GITHUB_TOKEN` | `GITHUB_TOKEN` (gleich) |
| `ReleaseTag` | `UPDATE_RELEASE_TAG` |

### Schritt 5: DEP-Ordner

AutoUpdater extrahiert DEP-Ordner automatisch aus Archives.

```bash
# Erstelle Archive mit DEP
mkdir -p release_package/DEP
cp MeinScript.sh release_package/
cp -r DEP/* release_package/DEP/
tar -czf MeinScript.tar.gz -C release_package .

# Release
gh release create v1.0.0 MeinScript.tar.gz

# Im Script
UPDATE_ASSET_NAME="MeinScript.tar.gz"
UPDATE_IS_ARCHIVE=1
```

### Schritt 6: Vergleichstest

```bash
# Teste altes Script
./MeinScript.sh.backup

# Teste neues Script
./MeinScript.sh

# Vergleiche Verhalten
diff <(./MeinScript.sh.backup 2>&1) <(./MeinScript.sh 2>&1)
```

---

## Testing nach Migration

### 1. Funktions-Test

```bash
# Script ausführbar?
./MeinScript.sh

# Exit-Code korrekt?
echo $?  # Sollte 0 sein
```

### 2. Update-Test

```bash
# Dry-Run
UPDATE_DRY_RUN=1 UPDATE_VERBOSE=1 ./MeinScript.sh

# Prüfe ob Update erkannt wird
# Version im Script senken
sed -i '' 's/SCRIPT_VERSION="1.0.0"/SCRIPT_VERSION="0.9.0"/' MeinScript.sh

# Sollte Update durchführen
./MeinScript.sh
```

### 3. Offline-Test

```bash
# Internet deaktivieren oder:
# Engine-URL auf ungültige URL setzen
ENGINE_URL="https://invalid.url/engine.sh"

# Sollte Warnung zeigen aber weiterlaufen
./MeinScript.sh
```

### 4. Performance-Test

```bash
# Zeitmessung
time ./MeinScript.sh

# Sollte < 1 Sekunde sein (mit Cache)
# Ohne Cache: 2-3 Sekunden
```

### 5. Cache-Test

```bash
# Cache löschen
rm -rf /tmp/auto_update_cache/

# Erste Ausführung (lädt Engine)
time ./MeinScript.sh  # ~2-3s

# Zweite Ausführung (nutzt Cache)
time ./MeinScript.sh  # ~0.1s
```

---

## Batch-Migration

Für viele Scripts auf einmal.

### Schritt 1: Migrationsskript erstellen

**`migrate_all.sh`**

```bash
#!/bin/bash

SCRIPTS_DIR="$1"
UPDATE_MODE="${2:-github_release}"
GITHUB_USER="${3:-7onnie}"
GITHUB_REPO="${4:-scripts}"

if [[ -z "$SCRIPTS_DIR" ]]; then
    echo "Usage: $0 <scripts_dir> [update_mode] [github_user] [github_repo]"
    exit 1
fi

# Bootstrap-Template
BOOTSTRAP_TEMPLATE="$(cat <<'EOF'

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="UPDATE_MODE_PLACEHOLDER"
UPDATE_GITHUB_USER="GITHUB_USER_PLACEHOLDER"
UPDATE_GITHUB_REPO="GITHUB_REPO_PLACEHOLDER"
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# ==========================================
# AUTO-UPDATE BOOTSTRAP
# ==========================================

auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440

    mkdir -p "$CACHE_DIR" 2>/dev/null

    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update Engine nicht erreichbar."
        return 1
    fi
}

# Auto-Update durchführen
auto_update

EOF
)"

# Ersetze Platzhalter
BOOTSTRAP_TEMPLATE="${BOOTSTRAP_TEMPLATE//UPDATE_MODE_PLACEHOLDER/$UPDATE_MODE}"
BOOTSTRAP_TEMPLATE="${BOOTSTRAP_TEMPLATE//GITHUB_USER_PLACEHOLDER/$GITHUB_USER}"
BOOTSTRAP_TEMPLATE="${BOOTSTRAP_TEMPLATE//GITHUB_REPO_PLACEHOLDER/$GITHUB_REPO}"

# Migriere alle Scripts
find "$SCRIPTS_DIR" -name "*.sh" -type f | while read -r script; do
    echo "Migriere: $script"

    # Backup
    cp "$script" "${script}.backup"

    # Prüfe ob Script bereits SCRIPT_VERSION hat
    if ! grep -q "SCRIPT_VERSION=" "$script"; then
        # Füge Version nach Shebang ein
        sed -i '' '1 a\
\
SCRIPT_VERSION="1.0.0"\
SCRIPT_VERSION_DATE="'$(date +%Y%m%d)'"
' "$script"
    fi

    # Füge Bootstrap nach Version ein
    awk -v bootstrap="$BOOTSTRAP_TEMPLATE" '
        /^SCRIPT_VERSION/ {
            print
            if (!done) {
                print bootstrap
                done=1
            }
            next
        }
        {print}
    ' "${script}.backup" > "$script"

    # Syntax-Check
    if bash -n "$script"; then
        echo "✅ $script migrated"
        rm "${script}.backup"
    else
        echo "❌ $script failed - restoring backup"
        mv "${script}.backup" "$script"
    fi
done

echo "Migration abgeschlossen!"
```

### Schritt 2: Migration durchführen

```bash
# Migriere alle Scripts im Ordner
./migrate_all.sh ~/Scripts github_release 7onnie mein-repo

# Teste eines der migrierten Scripts
~/Scripts/MeinScript.sh
```

### Schritt 3: Commit

```bash
cd ~/Scripts
git add .
git commit -m "Migrate to AutoUpdater"
git push
```

---

## Häufige Probleme

### "SCRIPT_VERSION not found"

```bash
# Füge am Script-Anfang hinzu:
SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"
```

### "UPDATE_GITHUB_USER not set"

```bash
# Konfiguration überprüfen
grep UPDATE_GITHUB_ MeinScript.sh

# Sollte gesetzt sein:
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"
```

### "python3 or jq required"

```bash
# Installiere python3
brew install python3  # macOS
apt-get install python3  # Linux

# Oder installiere jq
brew install jq  # macOS
apt-get install jq  # Linux
```

### Script startet nach Update in Endlosschleife

```bash
# Problem: Version wird nach Update nicht aktualisiert
# Lösung: Prüfe dass SCRIPT_VERSION im heruntergeladenen Script gesetzt ist

# Debug
UPDATE_VERBOSE=1 ./MeinScript.sh
```

### Update funktioniert nicht (private Repo)

```bash
# Token setzen
export GITHUB_TOKEN="github_pat_XXX"

# Testen
./MeinScript.sh
```

---

## Checkliste

Nach Migration überprüfen:

- [ ] `SCRIPT_VERSION` gesetzt
- [ ] `UPDATE_MODE` konfiguriert
- [ ] `UPDATE_GITHUB_USER` und `UPDATE_GITHUB_REPO` gesetzt (für github_release)
- [ ] Token gesetzt (für private Repos)
- [ ] Bootstrap-Code eingefügt
- [ ] `auto_update` wird vor main-Logik aufgerufen
- [ ] Syntax-Check erfolgreich (`bash -n script.sh`)
- [ ] Script läuft ohne Fehler
- [ ] Update-Test erfolgreich (Version senken, testen)
- [ ] Backup erstellt
- [ ] Committed und gepusht

---

## Best Practices

### DO

- ✅ Backup vor Migration erstellen
- ✅ Syntax-Check nach Migration
- ✅ Version im Script setzen
- ✅ Update-Test durchführen
- ✅ Schrittweise migrieren (nicht alle auf einmal)

### DON'T

- ❌ Direkt in Production migrieren
- ❌ Ohne Backup arbeiten
- ❌ Versions-Info vergessen
- ❌ Token im Script hardcoden (außer für private Scripts)

---

## Rollback

Falls Migration fehlschlägt:

```bash
# Backup wiederherstellen
cp MeinScript.sh.backup MeinScript.sh

# Oder via Git
git checkout MeinScript.sh
```

---

## Nächste Schritte

- **Release erstellen:** [DEPLOYMENT.md](DEPLOYMENT.md)
- **Testing:** Siehe [Testing nach Migration](#testing-nach-migration)
- **Weitere Scripts:** Batch-Migration für alle Scripts
