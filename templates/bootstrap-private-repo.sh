#!/bin/bash
# ==========================================
# AUTO-UPDATE BOOTSTRAP (für private Repos)
# ==========================================
# Dieser Bootstrap-Code wird vom Migration-Script
# automatisch in migrierten Scripts eingefügt.
#
# WICHTIG: Für Internal Share Token hardcoden!
# GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
# ==========================================

# Auto-Update Konfiguration
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="{{GITHUB_USER}}"           # Wird vom Migration-Script ersetzt
UPDATE_GITHUB_REPO="{{GITHUB_REPO}}"           # Wird vom Migration-Script ersetzt
UPDATE_RELEASE_TAG="latest"
{{ARCHIVE_CONFIG}}# Wird vom Migration-Script ersetzt (nur wenn DEP vorhanden)
GITHUB_TOKEN=""                         # Leer für GitHub, hardcoded für Internal Share

# ==========================================
# AUTO-UPDATE BOOTSTRAP (Minimal)
# ==========================================

auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440  # 24 Stunden

    mkdir -p "$CACHE_DIR" 2>/dev/null

    # Cache-Check
    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    # Engine herunterladen
    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update Engine nicht erreichbar. Script läuft ohne Update-Check weiter."
        return 1
    fi
}

# Auto-Update durchführen
auto_update

# ==========================================
# ORIGINAL SCRIPT CODE BELOW
# ==========================================
