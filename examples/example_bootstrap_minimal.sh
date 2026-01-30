#!/bin/bash
# ==========================================
# BEISPIEL: BOOTSTRAP MINIMAL
# ==========================================
# Demonstriert die Verwendung des minimalen
# Bootstrap-Loaders ohne Fallback
# ==========================================

SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="github_release"
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="AutoUpdater"
UPDATE_RELEASE_TAG="latest"
UPDATE_ASSET_NAME=""  # Leer = erstes Asset verwenden
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Aus Umgebungsvariable

# Optional: Debugging
UPDATE_VERBOSE=1
UPDATE_DRY_RUN=1

# ==========================================
# AUTO-UPDATE BOOTSTRAP (MINIMAL)
# ==========================================

auto_update() {
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440

    mkdir -p "$CACHE_DIR" 2>/dev/null

    # Cache-Check
    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    # Neu laden
    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        echo "⚠️  Auto-Update Engine nicht erreichbar. Script läuft ohne Update-Check weiter."
        return 1
    fi
}

# ==========================================
# MAIN SCRIPT LOGIC
# ==========================================

main() {
    echo "=========================================="
    echo "Beispiel-Script mit Bootstrap Minimal"
    echo "Version: $SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    # Auto-Update durchführen
    auto_update

    echo ""
    echo "Script-Logik wird ausgeführt..."
    echo ""
    echo "Dieses Script demonstriert:"
    echo "- Minimalen Bootstrap-Loader (nur 30 Zeilen)"
    echo "- Lädt Update-Engine von GitHub"
    echo "- 24h Cache für Offline-Betrieb"
    echo "- Kein Fallback (Script läuft weiter bei Fehler)"
    echo ""
    echo "Verwendung:"
    echo "  ./example_bootstrap_minimal.sh"
    echo ""
    echo "✅ Script abgeschlossen"
}

main "$@"
