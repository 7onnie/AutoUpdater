# Deployment Guide

CI/CD Setup, automatische Releases und Deployment-Strategien für AutoUpdater.

---

## Inhaltsverzeichnis

1. [Manuelles Release erstellen](#manuelles-release-erstellen)
2. [GitHub Actions Workflows](#github-actions-workflows)
3. [Release-Strategien](#release-strategien)
4. [Version-Management](#version-management)
5. [Multi-Script Repos](#multi-script-repos)
6. [Rollback](#rollback)
7. [Monitoring](#monitoring)

---

## Manuelles Release erstellen

### Via GitHub CLI

```bash
# Einfacher Release
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Bug fixes and improvements" \
  MeinScript.sh

# Mit automatischem Changelog
gh release create v1.0.0 \
  --generate-notes \
  MeinScript.sh

# Pre-Release (Beta/Alpha)
gh release create v1.0.0-beta.1 \
  --prerelease \
  --title "Beta 1.0.0" \
  --notes "Beta version for testing" \
  MeinScript.sh

# Mit mehreren Assets
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "See CHANGELOG.md" \
  MeinScript.sh \
  Config.json \
  README.md
```

### Via Git Tags

```bash
# Lokalen Tag erstellen
git tag -a v1.0.0 -m "Version 1.0.0: Bug fixes"

# Zu GitHub pushen
git push origin v1.0.0

# Release aus Tag erstellen
gh release create v1.0.0 --notes "Version 1.0.0"
```

### Archive-Releases (mit Dependencies)

```bash
# Script mit Dependencies packen
mkdir -p release_package/DEP
cp MeinScript.sh release_package/
cp -r libs/* release_package/DEP/

# Archive erstellen
cd release_package
tar -czf ../MeinScript_v1.0.0.tar.gz .
cd ..

# Release mit Archive
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Includes dependencies in DEP/" \
  MeinScript_v1.0.0.tar.gz

# Im Script: UPDATE_IS_ARCHIVE=1 oder UPDATE_ASSET_NAME="MeinScript_v1.0.0.tar.gz"
```

---

## GitHub Actions Workflows

### 1. Automatisches Release bei Tag

**`.github/workflows/auto-release.yml`**

```yaml
name: Auto Release

on:
  push:
    tags:
      - 'v*'  # Triggert bei v1.0.0, v2.1.3, etc.

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Create Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${{ steps.version.outputs.VERSION }} \
            --title "Release ${{ steps.version.outputs.VERSION }}" \
            --generate-notes \
            MeinScript.sh

      - name: Upload additional assets
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Optional: Weitere Dateien hochladen
          if [ -f "README.md" ]; then
            gh release upload ${{ steps.version.outputs.VERSION }} README.md
          fi
```

**Verwendung:**

```bash
# Version committen
git commit -am "Bump version to 1.0.0"

# Tag erstellen und pushen
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions erstellt automatisch Release
```

### 2. Release mit Build-Step

**`.github/workflows/build-release.yml`**

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Build package
        run: |
          # Dependencies sammeln
          mkdir -p release_package/DEP
          cp MeinScript.sh release_package/

          # Optional: Dependencies installieren
          # pip install -r requirements.txt -t release_package/DEP/

          # Archive erstellen
          cd release_package
          tar -czf ../MeinScript.tar.gz .
          cd ..

      - name: Create Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${GITHUB_REF#refs/tags/} \
            --title "Release ${GITHUB_REF#refs/tags/}" \
            --generate-notes \
            MeinScript.tar.gz

      - name: Verify Release
        run: |
          gh release view ${GITHUB_REF#refs/tags/}
```

### 3. Multi-Script Release

Für Mono-Repos mit mehreren Scripts:

**`.github/workflows/multi-release.yml`**

```yaml
name: Multi-Script Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        script:
          - name: ScriptA
            file: scripts/ScriptA.sh
          - name: ScriptB
            file: scripts/ScriptB.sh
          - name: ScriptC
            file: scripts/ScriptC.sh

    steps:
      - uses: actions/checkout@v3

      - name: Create Release for ${{ matrix.script.name }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          TAG="${GITHUB_REF#refs/tags/}"
          RELEASE_TAG="${{ matrix.script.name }}_${TAG}"

          gh release create "$RELEASE_TAG" \
            --title "${{ matrix.script.name }} ${TAG}" \
            --notes "Release for ${{ matrix.script.name }}" \
            ${{ matrix.script.file }}
```

**Im Script:**
```bash
UPDATE_RELEASE_TAG="ScriptA_v1.0.0"  # Statt "latest"
```

### 4. Scheduled Releases

Automatische wöchentliche Releases:

**`.github/workflows/scheduled-release.yml`**

```yaml
name: Scheduled Release

on:
  schedule:
    - cron: '0 0 * * 0'  # Jeden Sonntag um Mitternacht
  workflow_dispatch:  # Manueller Trigger

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Gesamte Historie

      - name: Check if changes exist
        id: changes
        run: |
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          if [ -z "$LAST_TAG" ]; then
            echo "HAS_CHANGES=true" >> $GITHUB_OUTPUT
          else
            CHANGES=$(git diff --name-only $LAST_TAG HEAD -- '*.sh')
            if [ -n "$CHANGES" ]; then
              echo "HAS_CHANGES=true" >> $GITHUB_OUTPUT
            else
              echo "HAS_CHANGES=false" >> $GITHUB_OUTPUT
            fi
          fi

      - name: Bump version
        if: steps.changes.outputs.HAS_CHANGES == 'true'
        id: version
        run: |
          # Semantic versioning: MAJOR.MINOR.PATCH
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          LAST_VERSION=${LAST_TAG#v}

          # Patch-Version erhöhen
          PATCH=$(echo $LAST_VERSION | cut -d. -f3)
          NEW_PATCH=$((PATCH + 1))
          MAJOR=$(echo $LAST_VERSION | cut -d. -f1)
          MINOR=$(echo $LAST_VERSION | cut -d. -f2)

          NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"
          echo "VERSION=$NEW_VERSION" >> $GITHUB_OUTPUT

      - name: Create Release
        if: steps.changes.outputs.HAS_CHANGES == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git tag ${{ steps.version.outputs.VERSION }}
          git push origin ${{ steps.version.outputs.VERSION }}

          gh release create ${{ steps.version.outputs.VERSION }} \
            --title "Automated Release ${{ steps.version.outputs.VERSION }}" \
            --generate-notes \
            MeinScript.sh
```

### 5. Release mit Tests

**`.github/workflows/test-and-release.yml`**

```yaml
name: Test and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Shellcheck
        run: |
          sudo apt-get install -y shellcheck
          shellcheck MeinScript.sh

      - name: Run tests
        run: |
          # Deine Tests
          bash tests/test_script.sh

  release:
    needs: test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Create Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${GITHUB_REF#refs/tags/} \
            --title "Release ${GITHUB_REF#refs/tags/}" \
            --generate-notes \
            MeinScript.sh
```

---

## Release-Strategien

### 1. Tag-basiert (empfohlen)

```bash
# Entwicklung
git commit -am "Add new feature"
git push

# Release
git tag v1.0.0
git push origin v1.0.0  # Triggert Workflow
```

**Vorteile:**
- ✅ Klare Trennung Entwicklung/Release
- ✅ Einfaches Rollback via Tag
- ✅ Semantic Versioning

### 2. Branch-basiert

```bash
# Feature entwickeln
git checkout -b feature/new-stuff
git commit -am "Add new feature"
git push origin feature/new-stuff

# Release vorbereiten
git checkout -b release/v1.0.0
# Version bumpen, Changelog aktualisieren
git commit -am "Prepare release 1.0.0"
git push origin release/v1.0.0

# Merge und Release
git checkout master
git merge release/v1.0.0
git tag v1.0.0
git push origin master --tags
```

**Workflow:**
```yaml
on:
  push:
    branches:
      - 'release/*'
```

### 3. Manual Dispatch

**`.github/workflows/manual-release.yml`**

```yaml
name: Manual Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g. v1.0.0)'
        required: true
      prerelease:
        description: 'Is this a pre-release?'
        type: boolean
        default: false

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Create Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          PRERELEASE_FLAG=""
          if [ "${{ inputs.prerelease }}" == "true" ]; then
            PRERELEASE_FLAG="--prerelease"
          fi

          gh release create ${{ inputs.version }} \
            $PRERELEASE_FLAG \
            --title "Release ${{ inputs.version }}" \
            --generate-notes \
            MeinScript.sh
```

**Verwendung:** GitHub → Actions → Manual Release → Run workflow

---

## Version-Management

### Semantic Versioning

```
MAJOR.MINOR.PATCH (z.B. 1.2.3)

MAJOR: Breaking Changes (API-Änderungen)
MINOR: Neue Features (rückwärtskompatibel)
PATCH: Bug Fixes
```

### Version im Script

```bash
SCRIPT_VERSION="1.2.3"
SCRIPT_VERSION_DATE="20260126"
```

### Version automatisch bumpen

**`bump_version.sh`**

```bash
#!/bin/bash

SCRIPT_FILE="MeinScript.sh"
BUMP_TYPE="${1:-patch}"  # major, minor, patch

# Aktuelle Version lesen
CURRENT=$(grep 'SCRIPT_VERSION=' "$SCRIPT_FILE" | head -n1 | cut -d'"' -f2)
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)

# Bumpen
case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
TODAY=$(date +%Y%m%d)

# Script aktualisieren
sed -i '' "s/SCRIPT_VERSION=\".*\"/SCRIPT_VERSION=\"$NEW_VERSION\"/" "$SCRIPT_FILE"
sed -i '' "s/SCRIPT_VERSION_DATE=\".*\"/SCRIPT_VERSION_DATE=\"$TODAY\"/" "$SCRIPT_FILE"

echo "Bumped version: $CURRENT → $NEW_VERSION"
```

**Verwendung:**

```bash
# Patch (1.0.0 → 1.0.1)
./bump_version.sh patch
git commit -am "Bump version to $(grep SCRIPT_VERSION= MeinScript.sh | head -n1 | cut -d'"' -f2)"
git tag v1.0.1
git push origin master --tags

# Minor (1.0.1 → 1.1.0)
./bump_version.sh minor

# Major (1.1.0 → 2.0.0)
./bump_version.sh major
```

---

## Multi-Script Repos

### Strategie 1: Separates Release pro Script

```bash
# Release-Tags mit Script-Prefix
git tag ScriptA_v1.0.0
git tag ScriptB_v2.3.1
```

**Im Script:**
```bash
UPDATE_RELEASE_TAG="ScriptA_v1.0.0"  # Nicht "latest"!
```

### Strategie 2: Gemeinsame Version (Mono-Repo)

```bash
# Alle Scripts gleiche Version
git tag v1.0.0  # Released alle Scripts
```

**Workflow:**
```yaml
- name: Release all scripts
  run: |
    for script in scripts/*.sh; do
      gh release upload v1.0.0 "$script"
    done
```

---

## Rollback

### Release löschen

```bash
# Release und Tag löschen
gh release delete v1.0.0 --yes
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

### Auf alte Version zurück

```bash
# Altes Release als "latest" markieren
# Erstelle neues Release mit alter Version
gh release create v1.0.0-hotfix \
  --title "Rollback to 1.0.0" \
  --notes "Rolled back due to critical bug" \
  old_version/MeinScript.sh
```

### Emergency-Fix

```bash
# Hotfix-Branch
git checkout v1.0.0 -b hotfix/1.0.1
# Fix committen
git commit -am "Hotfix: Critical bug"
git tag v1.0.1
git push origin v1.0.1 --tags
```

---

## Monitoring

### Release-Webhooks

**Slack-Benachrichtigung:**

```yaml
- name: Notify Slack
  if: success()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'New release ${{ steps.version.outputs.VERSION }} created!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Download-Tracking

```bash
# Release-Downloads anzeigen
gh api repos/7onnie/mein-repo/releases/latest | \
  python3 -c "import sys, json; \
    assets = json.load(sys.stdin)['assets']; \
    [print(f\"{a['name']}: {a['download_count']} downloads\") for a in assets]"
```

### Status-Badge

In README.md:

```markdown
![Release](https://img.shields.io/github/v/release/7onnie/mein-repo)
![Downloads](https://img.shields.io/github/downloads/7onnie/mein-repo/total)
```

---

## Best Practices

### DO

- ✅ Semantic Versioning verwenden
- ✅ Changelog automatisch generieren (`--generate-notes`)
- ✅ Tests vor Release durchführen
- ✅ Pre-Releases für Beta-Versionen
- ✅ Assets mit klaren Namen
- ✅ Version im Script aktualisieren

### DON'T

- ❌ Releases überschreiben (erstelle neue Version)
- ❌ Breaking Changes in PATCH-Version
- ❌ Releases ohne Tests
- ❌ Token in Workflows hardcoden (nutze Secrets)
- ❌ Latest-Tag manuell verschieben

---

## Nächste Schritte

- **Modi verstehen:** [MODES.md](MODES.md)
- **Migration:** [MIGRATION.md](MIGRATION.md)
- **Advanced:** CI/CD für mehrere Repos, Matrix-Builds
