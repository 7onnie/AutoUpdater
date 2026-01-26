#!/bin/bash
# ==========================================
# BEISPIEL: GITHUB RELEASE MODUS
# ==========================================
# Demonstriert Updates via GitHub Releases
# Für Scripts mit Dependencies und Archive
# ==========================================

SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="github_release"

# GitHub Konfiguration
UPDATE_GITHUB_USER="7onnie"
UPDATE_GITHUB_REPO="AutoUpdater"
UPDATE_RELEASE_TAG="latest"  # oder spezifischer Tag wie "v1.0.0"

# Optional: Spezifisches Asset
# UPDATE_ASSET_NAME="MyScript.sh"  # oder "MyScript.tar.gz" für Archive

# Token für private Repos (optional)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Aus Umgebungsvariable

# Archive-Handling (falls tar.gz oder zip)
# UPDATE_IS_ARCHIVE=1

# ==========================================
# AUTO-UPDATE ENGINE (Bootstrap)
# ==========================================

if [[ -f "$(dirname "$0")/../lib/auto_update_github_only.sh" ]]; then
    source "$(dirname "$0")/../lib/auto_update_github_only.sh"
    auto_update_github
elif [[ -f "$(dirname "$0")/../lib/auto_update_engine.sh" ]]; then
    source "$(dirname "$0")/../lib/auto_update_engine.sh"
    _auto_update_main "$UPDATE_MODE"
else
    echo "⚠️  Update-Engine nicht gefunden"
fi

# ==========================================
# MAIN SCRIPT LOGIC
# ==========================================

main() {
    echo "=========================================="
    echo "Beispiel: GitHub Release Update-Modus"
    echo "Version: $SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    echo "GitHub Release Modus - Features:"
    echo ""
    echo "✓ Lädt Script von GitHub Release"
    echo "✓ Versionskontrolle über Release-Tags"
    echo "✓ Unterstützt Archive (tar.gz, zip)"
    echo "✓ Kann zusätzliche Dateien (Dependencies) mitbringen"
    echo "✓ Funktioniert mit privaten Repos (via Token)"
    echo "✓ API-Cache für Offline-Betrieb (24h)"
    echo ""

    echo "Anwendungsfälle:"
    echo "- Scripts mit Dependencies (Bibliotheken, Configs)"
    echo "- Kontrollierte Releases (Semantic Versioning)"
    echo "- Scripts die auf mehreren Systemen verteilt werden"
    echo "- Private Scripts mit Token-Authentifizierung"
    echo ""

    echo "Setup:"
    echo "1. GitHub Release erstellen:"
    echo "   gh release create v1.0.0 --title 'Version 1.0.0' MeinScript.sh"
    echo ""
    echo "2. Konfiguration anpassen:"
    echo "   UPDATE_GITHUB_USER='dein_user'"
    echo "   UPDATE_GITHUB_REPO='dein_repo'"
    echo "   UPDATE_RELEASE_TAG='latest'"
    echo ""
    echo "3. Optional: Token für private Repos:"
    echo "   export GITHUB_TOKEN='github_pat_XXX'"
    echo ""

    echo "✅ Script abgeschlossen"
}

main "$@"
