#!/bin/bash
# ==========================================
# BEISPIEL: STANDALONE VERSION
# ==========================================
# Demonstriert Copy-Paste Standalone-Version
# Komplette Engine eingebettet, kein Bootstrap
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
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Hinweis: Hier würde normalerweise die komplette
# Standalone-Engine eingefügt werden (siehe standalone/auto_update_standalone.sh)
# Für dieses Beispiel laden wir sie per Source

# Temporärer Workaround für Beispiel
if [[ -f "$(dirname "$0")/../lib/auto_update_engine.sh" ]]; then
    source "$(dirname "$0")/../lib/auto_update_engine.sh"

    # Rufe Update-Funktion auf
    _auto_update_main "$UPDATE_MODE"
else
    echo "ℹ️  Update-Engine nicht gefunden - nutze für echte Standalone-Version:"
    echo "    Copy-Paste aus standalone/auto_update_standalone.sh"
fi

# ==========================================
# MAIN SCRIPT LOGIC
# ==========================================

main() {
    echo "=========================================="
    echo "Beispiel-Script Standalone"
    echo "Version: $SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    echo "Script-Logik wird ausgeführt..."
    echo ""
    echo "Standalone-Version:"
    echo "- Komplette Engine im Script eingebettet"
    echo "- Keine externen Dependencies"
    echo "- Ca. 400 Zeilen Code"
    echo "- Für Scripts die offline funktionieren müssen"
    echo ""
    echo "Verwendung:"
    echo "  1. Öffne standalone/auto_update_standalone.sh"
    echo "  2. Kopiere alles zwischen BEGIN und END"
    echo "  3. Füge in dein Script ein"
    echo "  4. Passe Konfiguration an"
    echo "  5. Rufe auto_update auf"
    echo ""
    echo "✅ Script abgeschlossen"
}

main "$@"
