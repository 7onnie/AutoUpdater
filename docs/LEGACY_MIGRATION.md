# Legacy Script Migration Guide

Anleitung zur Migration von Scripts mit eigenem Update-System (z.B. `self_update()`) auf AutoUpdater.

---

## Übersicht

Viele bestehende Scripts haben bereits ein eigenes Update-System. Beispiel: `Install_Service.command` nutzt eine `self_update()` Funktion die von GitHub lädt und sich selbst ersetzt.

**Ziel:** Auf AutoUpdater migrieren OHNE dass User ihre Scripts manuell anpassen müssen.

**Lösung:** Übergangs-Version erstellen die BEIDE Systeme unterstützt.

---

## Strategie: Sanfte Migration

### Phase 1: Übergangs-Version (v2.0.0)

Erstelle eine Version die **beide** Update-Systeme unterstützt:

```bash
#!/bin/bash
SCRIPT_VERSION="2.0.0"

# ... User-Variablen ...

# ==========================================
# NEUES AUTO-UPDATE SYSTEM (AutoUpdater)
# ==========================================
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="backup-server-installer"
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

# ==========================================
# LEGACY KOMPATIBILITÄT (für alte Scripts)
# ==========================================
# Alte Scripts rufen self_update() auf.
# Diese Funktion leitet einfach an auto_update() weiter.

self_update() {
    echo "ℹ️  Legacy self_update() erkannt, nutze neues AutoUpdater System..."
    auto_update
}

# ==========================================
# HAUPT-LOGIK
# ==========================================

# Auto-Update durchführen (neues System)
auto_update

# Deine original main() Funktion
main "$@"
```

**Was passiert:**
1. Alte Scripts (mit `self_update` am Ende) laden v2.0.0
2. v2.0.0 hat `self_update()` Wrapper → ruft `auto_update()` auf
3. Script ersetzt sich selbst mit v2.0.0
4. Ab jetzt nutzt es AutoUpdater!

### Phase 2: Alte Funktion entfernen (v2.1.0+)

Nach ein paar Wochen/Monaten wenn alle Scripts updated haben:

```bash
#!/bin/bash
SCRIPT_VERSION="2.1.0"

# ... nur noch auto_update(), kein self_update() mehr ...

auto_update

main "$@"
```

---

## DEP-Ordner Kompatibilität ✅

AutoUpdater unterstützt DEP-Ordner **out-of-the-box**!

### Altes System (self_update)

```bash
# --- C. DEP ORDNER ---
DEP_UPDATE=$(find "$TMP_DIR" -name "DEP" -type d | head -n 1)
if [ -n "$DEP_UPDATE" ]; then
    rm -rf "${SCRIPT_DIR}/DEP"
    cp -R "$DEP_UPDATE" "${SCRIPT_DIR}/"
    echo " -> Engine (DEP) entpackt."
fi
```

### Neues System (AutoUpdater Engine)

```bash
# Zusätzliche Dateien kopieren (Dependencies, etc.)
if [[ -d "$extract_dir/DEP" ]]; then
    local dep_target="$(dirname "$0")/DEP"
    _log INFO "Kopiere Dependencies nach $dep_target"
    mkdir -p "$dep_target"
    cp -r "$extract_dir/DEP/"* "$dep_target/" 2>/dev/null
fi
```

**Identische Funktionalität!** Kein Unterschied für den User.

---

## Token-Preservation ✅

Auch das wird von beiden Systemen unterstützt!

### Altes System

```bash
# Token retten
sed -i.bak "s/GITHUB_TOKEN=\"github_pat_.*\"/GITHUB_TOKEN=\"${GITHUB_TOKEN}\"/" "$NEW_SCRIPT"
rm -f "${NEW_SCRIPT}.bak"
```

### Neues System (AutoUpdater Engine v1.1.0+)

```bash
_preserve_sensitive_vars() {
    local old_script="$1"
    local new_content="$2"

    # Extrahiere GITHUB_TOKEN aus altem Script
    local old_token=""
    if [[ -f "$old_script" ]]; then
        old_token=$(grep -E '^GITHUB_TOKEN=' "$old_script" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi

    # Token in neue Version einsetzen
    if [[ -n "$old_token" && "$old_token" != "" ]]; then
        new_content=$(echo "$new_content" | sed "s|^GITHUB_TOKEN=\"[^\"]*\"|GITHUB_TOKEN=\"$old_token\"|g")
    fi

    echo "$new_content"
}
```

**Token bleibt erhalten** - egal ob altes oder neues System!

---

## Step-by-Step: Install_Service.command migrieren

### Schritt 1: Übergangs-Version vorbereiten

Öffne das Script und füge AutoUpdater Bootstrap hinzu:

```bash
vim /Users/user/ZS_Share/Scripte/Auto_BU_SSD/Install_Service.command
```

**Nach den User-Variablen** (Zeile ~10), **VOR** der `self_update()` Funktion:

```bash
# ==========================================
# 1. KONFIGURATION
# ==========================================
RSYNC_USER="rsyncd"
RSYNC_PASS="rsyncd"
PORT="8730"
FOLDER_NAME="tomatenbackup"

# ==========================================
# 1.5 VERSION (NEU!)
# ==========================================
SCRIPT_VERSION="2.0.0"  # Erste AutoUpdater Version

# ==========================================
# 2. AUTO-UPDATE (NEU!)
# ==========================================
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="backup-server-installer"  # Passe an!
UPDATE_RELEASE_TAG="latest"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

# ==========================================
# 3. ALTE UPDATE / INSTALLER ENGINE (WRAPPER)
# ==========================================
self_update() {
    # Legacy-Wrapper: Leitet an neues System weiter
    echo "ℹ️  Nutze neues AutoUpdater System..."
    auto_update
}
```

**Behalte den Rest des Scripts!** Die `main()` Funktion etc. bleiben unverändert.

**Am Ende des Scripts** (Zeile ~148):

```bash
# START
auto_update  # NEU: Erstes Update-System
self_update  # ALT: Für Kompatibilität (ruft auto_update auf)
main "$@"
```

### Schritt 2: Migration durchführen

```bash
cd /Users/user/ZS_Share/AutoUpdater

./tools/migrate_script_to_repo.sh \
  --script /Users/user/ZS_Share/Scripte/Auto_BU_SSD/Install_Service.command \
  --repo-name backup-server-installer \
  --installer-mode \
  --share-token "ghp_DEIN_TOKEN_HIER"
```

**Tool macht:**
1. ✅ Migriert Script zu GitHub (ohne Token)
2. ✅ Erstellt `.old` Backup im Original-Ordner
3. ✅ Erstellt Installer im Original-Ordner (mit Token)
4. ✅ Lokales Repo: `~/script-repos/backup-server-installer`

### Schritt 3: Teste altes Script

Alte Scripts (v1.x) sollten jetzt automatisch auf v2.0.0 updaten:

```bash
# Simuliere altes Script (ohne AutoUpdater)
cd /tmp
cp /Users/user/ZS_Share/Scripte/Auto_BU_SSD/Install_Service.command.old test_old.sh

# Setze Version zurück auf 1.0.0 (simuliert altes Script)
sed -i '' 's/SCRIPT_VERSION="2.0.0"/SCRIPT_VERSION="1.0.0"/' test_old.sh

# Teste Update
./test_old.sh
```

**Erwartetes Verhalten:**
1. Altes Script lädt v2.0.0 von GitHub
2. v2.0.0 hat `self_update()` Wrapper
3. Script ersetzt sich mit v2.0.0
4. Ab jetzt nutzt es AutoUpdater ✅

### Schritt 4: Installer auf Share kopieren

```bash
# Kopiere Installer (mit Token!) auf Share
cp /Users/user/ZS_Share/Scripte/Auto_BU_SSD/Install_Service.command \
   /Volumes/ZS_Share/Scripts/Install_Service.command
```

Fertig! Kollegen nutzen den Installer auf Share.

---

## Häufige Probleme

### "self_update() not found" nach Update

**Grund:** Neue Version hat keinen `self_update()` Wrapper mehr.

**Lösung:** Behalte `self_update()` Wrapper mindestens 3-6 Monate in allen Releases.

### DEP-Ordner fehlt nach Update

**Grund:** Script nutzt nicht UPDATE_IS_ARCHIVE=1.

**Lösung:** In Script konfigurieren:

```bash
UPDATE_MODE="github_release"
UPDATE_ASSET_NAME="BackupServer.tar.gz"  # Dein Archive-Name
UPDATE_IS_ARCHIVE=1  # Wichtig für DEP-Unterstützung!
```

### Token geht verloren nach Update

**Grund:** AutoUpdater Engine < v1.1.0.

**Lösung:** Prüfe AutoUpdater Version:

```bash
grep "Version:" /Users/user/ZS_Share/AutoUpdater/lib/auto_update_engine.sh
# Sollte: Version: 1.1.0 oder höher
```

---

## Best Practices

### DO

- ✅ Übergangs-Version mit beiden Systemen
- ✅ `self_update()` Wrapper für 3-6 Monate behalten
- ✅ Testen mit alten Script-Versionen
- ✅ SCRIPT_VERSION ab v2.0.0 verwenden

### DON'T

- ❌ Sofort auf nur-AutoUpdater wechseln
- ❌ Alte Funktionen zu früh entfernen
- ❌ DEP-Ordner vergessen zu konfigurieren
- ❌ Token-Preservation nicht testen

---

## Timeline-Vorschlag

| Phase | Dauer | Version | Inhalt |
|-------|-------|---------|--------|
| **Übergang** | 2-4 Wochen | v2.0.0 | Beide Systeme, self_update() Wrapper |
| **Stabilisierung** | 2-3 Monate | v2.1.0-2.5.0 | Weiterhin self_update() Wrapper |
| **Cleanup** | Ab Monat 4 | v3.0.0 | Nur noch auto_update(), self_update() entfernt |

---

## Zusammenfassung

**Legacy-Migration ist einfach und sicher:**

1. ✅ AutoUpdater Bootstrap hinzufügen
2. ✅ `self_update()` Wrapper erstellen → leitet an `auto_update()` weiter
3. ✅ Release v2.0.0 erstellen
4. ✅ Alte Scripts updaten automatisch
5. ✅ DEP-Ordner funktioniert wie vorher
6. ✅ Token bleibt erhalten

**Kein Breaking Change für User!** Alles passiert automatisch beim nächsten Update.

---

**Version:** 1.0.0
**Letzte Änderung:** 2026-01-30
**AutoUpdater:** v1.1.0+
