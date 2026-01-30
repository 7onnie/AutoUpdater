# Script-Migration Guide

Vollständige Anleitung zur Migration einzelner Scripts aus dem Scripte Mono-Repo in eigene private GitHub Repositories mit automatischen Releases.

## Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [Voraussetzungen](#voraussetzungen)
- [Token-Strategie](#token-strategie)
- [Setup](#setup)
- [Migration-Workflow](#migration-workflow)
- [Lokales Editing](#lokales-editing)
- [Version-Management](#version-management)
- [Token-Preservation](#token-preservation)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Sicherheit](#sicherheit)

---

## Übersicht

### Ziel

Migration einzelner Scripts aus dem zentralen Mono-Repo (`/Users/user/ZS_Share/Scripte`) in **eigene private GitHub Repositories** mit vollautomatischen Releases bei Version-Änderungen.

### End-Workflow

```bash
# 1. Lokales Editing
cd ~/script-repos/MeinScript
vim MeinScript.sh
# Ändere: SCRIPT_VERSION="1.0.1"

# 2. Commit & Push (via SublimeMerge)
git add MeinScript.sh
git commit -m "Add feature X"
git push

# 3. Automatisch auf GitHub:
# - GitHub Action erkennt VERSION="1.0.1"
# - Erstellt Release v1.0.1
# - Lädt Script als Asset hoch

# 4. User mit dem Script:
./MeinScript.sh
# → AutoUpdater prüft: "Update verfügbar: 1.0.0 → 1.0.1"
# → Script updated sich automatisch
```

### Vorteile

- ✅ Eigenes Repository pro Script (besseres Tracking)
- ✅ Automatische Releases bei Version-Änderung
- ✅ Auto-Update-Funktion in Scripts integriert
- ✅ Private Repos (sichere interne Scripts)
- ✅ Git-History pro Script
- ✅ SublimeMerge-Integration für lokales Editing

---

## Voraussetzungen

### AutoUpdater Version

**Mindestens v1.1.0 erforderlich!**

AutoUpdater v1.1.0+ enthält **Token-Preservation**, das verhindert, dass hardcoded Tokens bei Self-Updates verloren gehen.

Prüfe deine Version:

```bash
grep "Version:" /Users/user/ZS_Share/AutoUpdater/lib/auto_update_engine.sh
# Sollte zeigen: Version: 1.1.0 oder höher
```

### Tools

Folgende Tools müssen installiert sein:

```bash
# GitHub CLI
brew install gh
gh --version  # Mindestens v2.0.0

# Git
git --version  # Mindestens v2.30.0

# curl (meist vorinstalliert)
curl --version
```

### Repository-Zugriff

- GitHub Account: `7onnie`
- Berechtigung: Private Repos erstellen
- Token: Read/Write für Repos & Workflows

---

## Token-Strategie

### Problem

Scripts sollen AutoUpdater nutzen, um sich selbst zu aktualisieren. Bei **privaten Repos** benötigt der Download-Zugriff einen GitHub Token. User haben diesen Token meist nicht in ihrer Umgebung konfiguriert.

### Zwei Versionen

Das gleiche Script existiert in **zwei Versionen**:

#### Version A: GitHub (leerer Token)

```bash
GITHUB_TOKEN=""  # Leer auf GitHub
```

Diese Version wird auf GitHub gepusht und ist die "offizielle" Version.

#### Version B: Internal Share (hardcoded Token)

```bash
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Diese Version wird auf dem Internal Share abgelegt (z.B. `/Volumes/ZS_Share/Scripts/`) und hat den Token hardcoded. Kollegen können das Script direkt nutzen ohne Token-Setup.

### Token-Preservation (NEU in v1.1.0!)

**Problem gelöst:** Bei Self-Updates würde der hardcoded Token verloren gehen (GitHub-Version hat leeren Token).

**Lösung:** AutoUpdater Engine v1.1.0+ erkennt automatisch, dass ein Token vorhanden ist, und **preserviert** ihn:

1. Vor Update: Token aus aktuellem (altem) Script extrahieren
2. Nach Download: Neue Version von GitHub laden (mit leerem Token)
3. Vor Replace: Token in neue Version injizieren
4. Replace: Script mit preserviertem Token überschreiben

**Ergebnis:** Token bleibt bei Updates erhalten! ✅

### Sicherheit

**Ist ein hardcoded Token sicher?**

Ja, in diesem Kontext:

- Token ist **read-only** (nur `repo` Scope für private Repos)
- Repository ist **privat** (wer Zugriff auf Share hat, darf auch Repo lesen)
- Token ist **nicht** in öffentlichem Git (nur auf Internal Share)
- Kollegen auf Share sind **autorisiert**, das Script zu nutzen

**Wichtig:** Token NIEMALS committen oder in öffentliche Repos pushen!

---

## Setup

### 1. GitHub CLI authentifizieren

Das Migration-Tool nutzt `gh` CLI - **kein separater Token nötig**!

```bash
# Einmalig: GitHub CLI authentifizieren
gh auth login

# Folge den Prompts:
# - Where do you use GitHub? → GitHub.com
# - Protocol? → SSH (empfohlen) oder HTTPS
# - Authenticate? → Login with a web browser

# Validieren
gh auth status
```

**Fertig!** Nach `gh auth login` kann das Migration-Tool Repos erstellen, Workflows pushen etc.

### 2. Token für Scripts erstellen (Read-Only)

Die **migrierten Scripts** brauchen einen **separaten Token** (nur Read-Rechte):

1. Gehe zu: https://github.com/settings/tokens?type=beta
2. **New fine-grained token**
3. Konfiguration:
   - **Name:** `AutoUpdater Script Downloads (Read-Only)`
   - **Expiration:** 1 Jahr
   - **Repository access:** Nur spezifische Repos (die migrierten Scripts)
   - **Permissions:**
     - Repository: `Contents` (**Read only**) - nur Downloads
     - Repository: `Metadata` (Read)
4. **Generate token**
5. Dieser Token wird **hardcoded** in Scripts auf Internal Share

**Warum separater Token?**
- Migration-Tool: Nutzt `gh auth` (kein Token nötig)
- Script-Enduser: Brauchen Token für Private-Repo-Downloads (Read-only ausreichend)

### 3. Migration-Tool vorbereiten

```bash
cd /Users/user/ZS_Share/AutoUpdater
chmod +x tools/migrate_script_to_repo.sh

# Test-Ausführung
./tools/migrate_script_to_repo.sh --help
```

---

## Zusammenfassung: Authentifizierung

| Komponente | Methode | Rechte | Nutzer |
|------------|---------|--------|--------|
| **Migration-Tool** | `gh auth login` | Read/Write (via gh) | Maintainer (du) |
| **Script-Token** | Hardcoded Token | Read-only | Enduser (Kollegen) |

**Migration-Tool:** Nutzt `gh auth` - keine Token-Konfiguration nötig!
**Script-Token:** Nur für Private-Repo-Downloads (hardcoded auf Share)

---

## Migration-Workflow

### Schritt 1: Script vorbereiten (MANUELL)

**Wichtig:** Das Migration-Tool automatisiert **NICHT** die Script-Vorbereitung. Du musst das Script manuell vorbereiten:

#### 1.1 VERSION ändern

Öffne das Script im Mono-Repo:

```bash
vim ~/ZS_Share/Scripte/Shell/MeinScript.sh
```

Ändere `VERSION=` zu `SCRIPT_VERSION=`:

```bash
# Vorher:
# VERSION=0.2

# Nachher:
SCRIPT_VERSION="0.2"
```

**Wichtig:** Mit Quotes! (`"0.2"` nicht `0.2`)

#### 1.2 Bootstrap einfügen

Kopiere Bootstrap-Template:

```bash
cat /Users/user/ZS_Share/AutoUpdater/templates/bootstrap-private-repo.sh
```

Füge Bootstrap **NACH** User-Variables, **VOR** Main-Logic ein:

```bash
#!/bin/bash
# Script-Header
# SCRIPT_VERSION="0.2"
# VERSION_DATE=20220822
##########
########## Variables (User-Definable)
##########
USER_DEF_VAR="value"

##########
########## AUTO-UPDATE BOOTSTRAP (HIER EINFÜGEN!)
##########
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-script-installer"  # ← Anpassen!
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN=""  # Leer für GitHub

auto_update() {
    # ... Bootstrap Code ...
}

auto_update  # Auto-Update durchführen

##########
########## Programm-Start (Original-Code)
##########
echo "Script startet..."
```

#### 1.3 Bootstrap konfigurieren

Passe folgende Zeilen an:

```bash
UPDATE_GITHUB_REPO="mein-script-name"  # Gewünschter Repo-Name
```

#### 1.4 Speichern

Speichere das vorbereitete Script im Mono-Repo.

### Schritt 2: Migration-Tool ausführen

Jetzt startet die **automatische Migration**:

```bash
cd /Users/user/ZS_Share/AutoUpdater

./tools/migrate_script_to_repo.sh \
  --script ~/ZS_Share/Scripte/Shell/MeinScript.sh \
  --repo-name mein-script-installer \
  --private
```

**Oder interaktiv:**

```bash
./tools/migrate_script_to_repo.sh
# Script wird fragen nach:
# - Script-Pfad
# - Repository-Name
# - Private/Public
# - Local clone path
```

### Schritt 3: Tool führt aus

Das Tool macht automatisch:

1. ✅ Validiert Script (SCRIPT_VERSION vorhanden?)
2. ✅ Validiert Bootstrap (auto_update Funktion vorhanden?)
3. ✅ Extrahiert VERSION aus Script
4. ✅ Erstellt GitHub Repo (privat)
5. ✅ Erstellt `.github/workflows/auto-release.yml`
6. ✅ Git init, commit, push
7. ✅ Erstellt ersten Release `v{VERSION}`
8. ✅ Zeigt Status-Report

### Schritt 4: Status-Report

Nach erfolgreicher Migration:

```
==========================================
✅ Migration erfolgreich!
==========================================
Repository:  https://github.com/7onnie/mein-script-installer
Release:     https://github.com/7onnie/mein-script-installer/releases/tag/v0.2
Local:       ~/script-repos/mein-script-installer

Nächste Schritte:
1. Token für Internal Share setzen (siehe unten)
2. Öffne in SublimeMerge: ~/script-repos/mein-script-installer
3. Editiere MeinScript.sh
4. Ändere SCRIPT_VERSION="0.3" für neues Feature
5. Commit & Push → Automatischer Release v0.3!
```

### Schritt 5: Token für Internal Share setzen

**Jetzt kommt der wichtige Teil!**

Die **GitHub-Version** hat einen **leeren Token**. Für die **Internal Share-Version** musst du den Token hardcoden:

```bash
# 1. Lokales Script bearbeiten (NICHT gepushte Version!)
cd ~/script-repos/mein-script-installer
vim MeinScript.sh

# 2. Finde Zeile:
# GITHUB_TOKEN=""

# 3. Ersetze mit deinem Token:
# GITHUB_TOKEN="github_pat_XXX"

# 4. Speichern (NICHT committen! Diese Version ist nur für Share!)

# 5. Kopiere auf Internal Share
cp MeinScript.sh /Volumes/ZS_Share/Scripts/MeinScript.sh

# 6. Teste
/Volumes/ZS_Share/Scripts/MeinScript.sh
# ✅ Script läuft mit hardcoded Token
# ✅ Kann auf Updates prüfen (private Repo-Zugriff klappt)
```

**Wichtig:** Die lokale Git-Version behält den **leeren Token** (für GitHub). Nur die Share-Kopie hat den **hardcoded Token**.

---

## Lokales Editing

### Mit SublimeMerge

Öffne das Repository in SublimeMerge für bequemes lokales Editing:

```bash
# Repository in SublimeMerge öffnen
open -a "Sublime Merge" ~/script-repos/mein-script-installer
```

### Workflow

1. **Editiere Script** in bevorzugtem Editor:

   ```bash
   code ~/script-repos/mein-script-installer/MeinScript.sh
   # oder
   subl ~/script-repos/mein-script-installer/MeinScript.sh
   ```

2. **Änderungen:**
   - Füge Feature hinzu
   - **Wichtig:** Ändere `SCRIPT_VERSION="0.3"`

3. **In SublimeMerge:**
   - Stage changes
   - Commit: "Add feature: Automatic Rosetta detection"
   - Push to origin/main

4. **Auf GitHub** (automatisch nach ~30 Sekunden):
   - GitHub Action läuft
   - Erkennt VERSION 0.3 (vorher war 0.2)
   - Erstellt Tag v0.3
   - Erstellt Release v0.3
   - Lädt Script als Asset hoch

5. **User mit dem Script:**

   ```bash
   ./MeinScript.sh
   # → AutoUpdater prüft: "Update verfügbar: 0.2 → 0.3"
   # → Lädt neue Version
   # → Script startet neu mit v0.3
   ```

---

## Version-Management

### Versioning-Schema

Nutze **Semantic Versioning**:

```
MAJOR.MINOR.PATCH

1.0.0  → Initial Release
1.0.1  → Bugfix
1.1.0  → New Feature (backwards-compatible)
2.0.0  → Breaking Change
```

### Version ändern

```bash
# Im Script
SCRIPT_VERSION="1.0.1"

# Commit Message
git commit -m "Fix: Rosetta detection bug"

# Push
git push
```

### Auto-Release-Trigger

GitHub Action prüft bei **jedem Push zu `main`**:

1. Ist ein `*.sh` File geändert?
2. Wenn ja: Extrahiere `SCRIPT_VERSION`
3. Vergleiche mit letztem Release
4. Wenn unterschiedlich: Erstelle neuen Release

**Wichtig:** Nur bei VERSION-Änderung wird Release erstellt!

---

## Token-Preservation

### Wie funktioniert es?

AutoUpdater Engine v1.1.0+ enthält die Funktion `_preserve_sensitive_vars()`:

```bash
_preserve_sensitive_vars() {
    local old_script="$1"
    local new_content="$2"

    # Extrahiere Token aus altem Script
    local old_token=""
    if [[ -f "$old_script" ]]; then
        old_token=$(grep -E '^GITHUB_TOKEN=' "$old_script" | \
                    head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi

    # Wenn Token vorhanden, in neue Version einsetzen
    if [[ -n "$old_token" && "$old_token" != "" ]]; then
        _log DEBUG "Preserving GitHub token in updated version"
        new_content=$(echo "$new_content" | \
                      sed "s|^GITHUB_TOKEN=\"[^\"]*\"|GITHUB_TOKEN=\"$old_token\"|g")
    fi

    echo "$new_content"
}
```

Diese Funktion wird in `_self_replace()` aufgerufen **vor** dem Überschreiben des Scripts.

### Test

Validiere Token-Preservation:

```bash
# Erstelle Test-Script mit Token
cat > /tmp/test_preserve.sh <<'EOF'
#!/bin/bash
SCRIPT_VERSION="1.0.0"
GITHUB_TOKEN="ghp_TEST_TOKEN"
EOF

# Source Engine
source /Users/user/ZS_Share/AutoUpdater/lib/auto_update_engine.sh

# Simuliere neue Version OHNE Token
NEW='SCRIPT_VERSION="1.0.1"
GITHUB_TOKEN=""'

# Teste Preservation
RESULT=$(_preserve_sensitive_vars "/tmp/test_preserve.sh" "$NEW")

# Token sollte erhalten sein
echo "$RESULT" | grep 'GITHUB_TOKEN="ghp_TEST_TOKEN"'
# ✅ Token wurde preserviert!
```

---

## Troubleshooting

### Migration schlägt fehl

**Fehler:** `SCRIPT_VERSION nicht gefunden`

**Lösung:**

```bash
# Prüfe Script
grep 'SCRIPT_VERSION' MeinScript.sh

# Sollte zeigen:
# SCRIPT_VERSION="0.2"

# Falls VERSION= statt SCRIPT_VERSION=:
sed -i '' 's/^VERSION=/SCRIPT_VERSION=/' MeinScript.sh
```

**Fehler:** `auto_update Funktion nicht gefunden`

**Lösung:** Bootstrap wurde nicht eingefügt. Siehe [Schritt 1.2](#12-bootstrap-einfügen).

### GitHub Action schlägt fehl

**Fehler:** `No shell script found`

**Lösung:** Script-Name muss auf `.sh` enden.

**Fehler:** `No SCRIPT_VERSION found`

**Lösung:** Prüfe dass `SCRIPT_VERSION="x.y.z"` mit Quotes vorhanden ist.

### Token wird nicht preserviert

**Fehler:** Nach Update ist Token leer

**Lösung:**

```bash
# Prüfe AutoUpdater Version
grep "Version:" /Users/user/ZS_Share/AutoUpdater/lib/auto_update_engine.sh

# Muss mindestens 1.1.0 sein!
# Falls älter: Update AutoUpdater
```

### Release wird nicht erstellt

**Fehler:** Push zu GitHub, aber kein neuer Release

**Gründe:**

1. **VERSION nicht geändert:**
   - Prüfe: `git diff HEAD~1 MeinScript.sh | grep SCRIPT_VERSION`
   - Muss zeigen: `-SCRIPT_VERSION="0.2"` und `+SCRIPT_VERSION="0.3"`

2. **GitHub Action läuft nicht:**
   - Prüfe Workflow: https://github.com/7onnie/REPO/actions
   - Prüfe `.github/workflows/auto-release.yml` existiert

3. **Token-Permissions:**
   - GitHub Token benötigt `workflow` Scope

---

## Best Practices

### Script-Struktur

**Empfohlene Reihenfolge:**

```bash
#!/bin/bash
# ==========================================
# Script-Header
# ==========================================
# SCRIPT_VERSION="1.0.0"
# SCRIPT_VERSION_DATE="20260130"

# ==========================================
# Variables (User-Definable)
# ==========================================
USER_VAR="value"

# ==========================================
# AUTO-UPDATE BOOTSTRAP
# ==========================================
UPDATE_MODE="github_release"
# ... Bootstrap Code ...
auto_update

# ==========================================
# Main Script Logic
# ==========================================
main() {
    echo "Script läuft..."
}

main "$@"
```

### Commit Messages

Nutze **Conventional Commits**:

```bash
# Feature
git commit -m "feat: Add automatic Rosetta detection"

# Bugfix
git commit -m "fix: Correct IP address validation"

# Refactor
git commit -m "refactor: Simplify error handling"
```

### Testing vor Push

```bash
# Teste Script lokal
./MeinScript.sh

# Prüfe VERSION-Syntax
grep '^SCRIPT_VERSION=' MeinScript.sh

# Prüfe Bootstrap
grep 'auto_update()' MeinScript.sh
```

---

## Sicherheit

### Token-Handling

**DO:**

- ✅ Token in Umgebungsvariable `$GITHUB_TOKEN`
- ✅ Token mit minimalen Scopes (repo, workflow)
- ✅ Token mit Expiration (90 Tage)
- ✅ Fine-grained Tokens statt Classic
- ✅ Hardcoded Token nur auf Internal Share

**DON'T:**

- ❌ Token in Git committen
- ❌ Token in öffentlichen Repos
- ❌ Token mit unnötigen Scopes
- ❌ Token ohne Expiration

### Private Repos

**Warum privat?**

- Scripts enthalten oft interne Prozesse
- Hardcoded IPs/Hostnames
- Firmen-spezifische Konfiguration

**Zugriffskontrolle:**

- Nur Team-Members haben Zugriff
- Read-only Token für Script-Execution
- Write-Token nur für Maintainer

### Script-Security

**Vor Migration prüfen:**

```bash
# Keine hardcoded Passwörter
grep -i 'password=' MeinScript.sh

# Keine API-Keys
grep -i 'api_key=' MeinScript.sh

# Shellcheck
shellcheck MeinScript.sh
```

---

## Zusammenfassung

### Migration-Checkliste

- [ ] AutoUpdater v1.1.0+ installiert
- [ ] GitHub Token generiert und in `$GITHUB_TOKEN` gesetzt
- [ ] Script vorbereitet (VERSION → SCRIPT_VERSION, Bootstrap eingefügt)
- [ ] Migration-Tool ausgeführt
- [ ] Token für Internal Share hardcoded
- [ ] Share-Kopie erstellt
- [ ] Test: Script läuft und updated sich
- [ ] SublimeMerge-Integration getestet
- [ ] Version-Change-Workflow getestet

### Support

**Probleme oder Fragen?**

1. Prüfe [Troubleshooting](#troubleshooting)
2. Prüfe AutoUpdater Logs: `/tmp/auto_update_*.log`
3. Prüfe GitHub Actions: `https://github.com/7onnie/REPO/actions`

---

**Version:** 1.0.0
**Letzte Änderung:** 2026-01-30
**AutoUpdater:** v1.1.0+
