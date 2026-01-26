# Update-Modi Vergleich

Welcher Update-Modus passt zu deinem Use-Case?

---

## Übersicht

AutoUpdater unterstützt 3 verschiedene Update-Modi:

| Modus | Komplexität | Dependencies | Use-Case |
|-------|-------------|--------------|----------|
| **github_release** | Mittel | curl, python3/jq | Kontrollierte Releases, Archive, private Repos |
| **git_pull** | Niedrig | git | Mono-Repos, Team-Entwicklung, schnelle Updates |
| **direct_download** | Sehr niedrig | curl | Einfache Scripts, öffentliche URLs, minimal |

---

## GitHub Release Modus

### Beschreibung

Lädt Script von GitHub Releases via GitHub API. Unterstützt Archive (tar.gz, zip) mit Dependencies.

### Konfiguration

```bash
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"
UPDATE_RELEASE_TAG="latest"  # oder "v1.0.0"
UPDATE_ASSET_NAME="MeinScript.sh"  # Optional
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Für private Repos
```

### Features

| Feature | Unterstützt | Beschreibung |
|---------|-------------|--------------|
| **Version-Check** | ✅ Ja | Via Release-Tag (v1.0.0, v2.1.3) |
| **Archive** | ✅ Ja | tar.gz, zip mit Dependencies |
| **Private Repos** | ✅ Ja | Via GitHub Token |
| **Offline-fähig** | ✅ Ja | 24h API-Cache |
| **Multiple Assets** | ✅ Ja | Wähle spezifisches Asset aus |
| **Pre-Releases** | ✅ Ja | Beta/Alpha Releases |
| **Dependencies** | ✅ Ja | DEP-Ordner wird extrahiert |

### Vorteile

- ✅ Kontrollierte Releases (Semantic Versioning)
- ✅ Kann zusätzliche Dateien mitbringen
- ✅ Funktioniert für standalone Scripts (kein Git nötig)
- ✅ Changelog direkt im Release
- ✅ Release-History auf GitHub
- ✅ API-Cache für Offline-Betrieb

### Nachteile

- ❌ Erfordert manuelles Erstellen von Releases
- ❌ GitHub Token für private Repos
- ❌ Etwas höherer Setup-Aufwand
- ❌ python3 oder jq erforderlich für JSON-Parsing

### Anwendungsfälle

**Ideal für:**
- Installer/Setup-Scripts mit Dependencies
- Scripts die auf mehreren Systemen verteilt werden
- Private Scripts mit kontrolliertem Zugriff
- Production Scripts mit Versionskontrolle
- Scripts die offline funktionieren müssen (Cache)

**Beispiele:**
- Backup-Script mit Config-Files und Libraries
- Deployment-Tool mit Templates
- Installer mit Binaries und Assets

### Einrichtung

```bash
# 1. GitHub Release erstellen
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Initial release" \
  MeinScript.sh

# 2. Script konfigurieren
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="mein-repo"

# 3. Testen
./MeinScript.sh
```

### Archive mit Dependencies

```bash
# Package erstellen
mkdir -p package/DEP
cp MeinScript.sh package/
cp -r libs/* package/DEP/
tar -czf MeinScript.tar.gz -C package .

# Release mit Archive
gh release create v1.0.0 MeinScript.tar.gz

# Script Config
UPDATE_ASSET_NAME="MeinScript.tar.gz"
UPDATE_IS_ARCHIVE=1
```

---

## Git Pull Modus

### Beschreibung

Führt `git pull` auf dem Repository aus, in dem das Script liegt. Ideal für Mono-Repos.

### Konfiguration

```bash
UPDATE_MODE="git_pull"
UPDATE_GIT_REPO_PATH="/path/to/repo"  # Optional, auto-detect
UPDATE_GIT_BRANCH="master"  # oder "main", "develop"
```

### Features

| Feature | Unterstützt | Beschreibung |
|---------|-------------|--------------|
| **Version-Check** | ✅ Ja | Via Git-Commits (SHA) |
| **Archive** | ❌ Nein | Direkter Git-Pull |
| **Private Repos** | ✅ Ja | Via Git-Credentials (SSH/HTTPS) |
| **Offline-fähig** | ❌ Nein | Benötigt Git-Zugriff |
| **Multiple Files** | ✅ Ja | Aktualisiert komplettes Repo |
| **Pre-Releases** | ✅ Ja | Via Branches (develop, staging) |
| **Dependencies** | ✅ Ja | Im selben Repo |

### Vorteile

- ✅ Kein Release-Overhead (direkt aus Git)
- ✅ Nutzt bestehende Git-Credentials
- ✅ Kein Token im Script nötig
- ✅ Ideal für Team-Entwicklung
- ✅ Branch-Support (develop, staging, master)
- ✅ Automatisches Update aller Scripts im Repo

### Nachteile

- ❌ Benötigt Git auf Zielsystem
- ❌ Aktualisiert komplettes Repo (nicht einzelne Dateien)
- ❌ Funktioniert nicht für standalone Scripts
- ❌ Lokale Änderungen verhindern Update
- ❌ Kein Offline-Betrieb

### Anwendungsfälle

**Ideal für:**
- Scripts innerhalb eines Git Mono-Repos
- Team-Scripts in gemeinsamem Repository
- Entwicklungsumgebung mit Git
- Schnelle Updates ohne Release-Prozess
- Scripts die häufig aktualisiert werden

**Beispiele:**
- Team-Tooling in shared Repo
- Development-Scripts im Projekt-Repo
- Admin-Scripts auf Servern mit Git

### Einrichtung

```bash
# 1. Script in Git-Repo platzieren
cd ~/mein-repo
git init
cp MeinScript.sh .
git add MeinScript.sh
git commit -m "Add script"
git remote add origin git@github.com:7onnie/mein-repo.git
git push -u origin master

# 2. Script konfigurieren
UPDATE_MODE="git_pull"
UPDATE_GIT_BRANCH="master"

# 3. Testen
./MeinScript.sh  # Führt git fetch/pull aus
```

### Workflow

```bash
# Entwicklung
vim MeinScript.sh
git commit -am "Add feature"
git push

# Script aktualisiert sich automatisch bei nächstem Aufruf
./MeinScript.sh  # Pulled update, startet neu
```

---

## Direct Download Modus

### Beschreibung

Lädt Script direkt von URL herunter. Minimalistisch, kein GitHub API, kein Git.

### Konfiguration

```bash
UPDATE_MODE="direct_download"
UPDATE_DOWNLOAD_URL="https://raw.githubusercontent.com/7onnie/repo/master/MeinScript.sh"
UPDATE_VERSION_URL="https://raw.githubusercontent.com/7onnie/repo/master/VERSION"  # Optional
```

### Features

| Feature | Unterstützt | Beschreibung |
|---------|-------------|--------------|
| **Version-Check** | 🟡 Optional | Via separate VERSION-Datei |
| **Archive** | ❌ Nein | Nur einzelne Datei |
| **Private Repos** | 🟡 Mit Token | Token in URL einbetten |
| **Offline-fähig** | ❌ Nein | Kein Cache |
| **Multiple Files** | ❌ Nein | Nur Script selbst |
| **Pre-Releases** | ❌ Nein | Keine Versions-Logik |
| **Dependencies** | ❌ Nein | Nur Script |

### Vorteile

- ✅ Sehr einfach, minimaler Code
- ✅ Funktioniert ohne GitHub API Token
- ✅ Keine Release-Erstellung nötig
- ✅ Nur curl erforderlich
- ✅ Schnellster Update-Modus
- ✅ Funktioniert mit beliebigen URLs

### Nachteile

- ❌ Keine Dependencies (nur Script selbst)
- ❌ Kein automatisches Versions-Tracking
- ❌ Kein Cache (online erforderlich)
- ❌ Für private Repos: Token in URL sichtbar
- ❌ Keine Release-History

### Anwendungsfälle

**Ideal für:**
- Einfache, standalone Scripts
- Öffentliche Scripts ohne Authentifizierung
- Scripts auf embedded Systems (minimal dependencies)
- Quick & Dirty Updates
- Testing/Prototyping

**Beispiele:**
- Utility-Scripts für öffentliche Nutzung
- Scripts auf IoT-Devices
- Minimal-Scripts ohne Dependencies

### Einrichtung

```bash
# 1. Script in öffentlichem GitHub Repo
git add MeinScript.sh
git commit -m "Add script"
git push origin master

# 2. Raw URL kopieren
# https://raw.githubusercontent.com/7onnie/repo/master/MeinScript.sh

# 3. Script konfigurieren
UPDATE_MODE="direct_download"
UPDATE_DOWNLOAD_URL="https://raw.githubusercontent.com/7onnie/repo/master/MeinScript.sh"

# 4. Optional: VERSION Datei
echo "1.0.0" > VERSION
git add VERSION
git commit -m "Add version file"
git push

UPDATE_VERSION_URL="https://raw.githubusercontent.com/7onnie/repo/master/VERSION"

# 5. Testen
./MeinScript.sh
```

### Version-Check ohne VERSION-Datei

Ohne `UPDATE_VERSION_URL` wird bei jedem Aufruf die neueste Version heruntergeladen (kein Versions-Vergleich).

```bash
# Immer aktualisieren (kein Check)
UPDATE_MODE="direct_download"
UPDATE_DOWNLOAD_URL="https://..."
# UPDATE_VERSION_URL nicht gesetzt
```

---

## Entscheidungsbaum

```
Brauche ich Dependencies/Archive?
├─ JA → github_release
└─ NEIN
   ├─ Liegt Script in Git-Repo?
   │  ├─ JA → git_pull
   │  └─ NEIN
   │     ├─ Öffentliches Script?
   │     │  ├─ JA → direct_download
   │     │  └─ NEIN → github_release (mit Token)
   │     └─ Sehr einfaches Script?
   │        ├─ JA → direct_download
   │        └─ NEIN → github_release
   └─ Viele Scripts im gleichen Repo?
      ├─ JA → git_pull
      └─ NEIN → github_release
```

---

## Feature-Matrix

| Feature | github_release | git_pull | direct_download |
|---------|----------------|----------|-----------------|
| **Setup-Komplexität** | Mittel | Niedrig | Sehr niedrig |
| **Dependencies** | ✅ Ja | ✅ Ja (im Repo) | ❌ Nein |
| **Offline-Cache** | ✅ 24h | ❌ Nein | ❌ Nein |
| **Private Repos** | ✅ Token | ✅ Git Auth | 🟡 Token in URL |
| **Versions-Check** | ✅ Ja | ✅ Commits | 🟡 Optional |
| **Release-Overhead** | ❌ Hoch | ✅ Keine | ✅ Keine |
| **Archive-Support** | ✅ Ja | ❌ Nein | ❌ Nein |
| **Multi-File** | ✅ Assets | ✅ Repo | ❌ Nein |
| **Benötigt Git** | ❌ Nein | ✅ Ja | ❌ Nein |
| **Benötigt Python/jq** | ✅ Ja | ❌ Nein | ❌ Nein |
| **Standalone** | ✅ Ja | ❌ Nein | ✅ Ja |

---

## Performance-Vergleich

```bash
# Zeitmessung (erste Ausführung)
time UPDATE_MODE="github_release" ./script.sh  # ~2-3 Sekunden
time UPDATE_MODE="git_pull" ./script.sh         # ~1-2 Sekunden
time UPDATE_MODE="direct_download" ./script.sh  # ~0.5-1 Sekunde

# Mit Cache (github_release)
time ./script.sh  # ~0.1 Sekunden (aus Cache)
```

---

## Empfehlungen

### Production Scripts

**Wähle:** `github_release`

**Warum:**
- Kontrollierte Releases
- Versionierung
- Offline-Cache
- Archive mit Dependencies

### Team-Development

**Wähle:** `git_pull`

**Warum:**
- Kein Release-Overhead
- Nutzt bestehendes Git-Workflow
- Automatische Updates

### Public Utilities

**Wähle:** `direct_download`

**Warum:**
- Minimale Dependencies
- Kein Token nötig
- Einfachste Integration

### Private Tools (standalone)

**Wähle:** `github_release`

**Warum:**
- Token-Authentifizierung
- Kann auf Systemen ohne Git laufen
- Cache für Offline-Betrieb

---

## Modi kombinieren

Du kannst mehrere Modi in einem Repo nutzen:

```bash
# Script A: GitHub Release (Production)
UPDATE_MODE="github_release"

# Script B: Git Pull (Development)
UPDATE_MODE="git_pull"

# Script C: Direct Download (Public)
UPDATE_MODE="direct_download"
```

---

## Nächste Schritte

- **Setup:** [SETUP.md](SETUP.md) - Ersten Modus einrichten
- **Deployment:** [DEPLOYMENT.md](DEPLOYMENT.md) - Releases automatisieren
- **Migration:** [MIGRATION.md](MIGRATION.md) - Bestehendes Script migrieren
