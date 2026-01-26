#!/bin/bash
# ==========================================
# BEISPIEL: DIRECT DOWNLOAD MODUS
# ==========================================
# Demonstriert direkte Downloads von URLs
# Minimalistisch, für einzelne Scripts
# ==========================================

SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="direct_download"

# Download URL (raw.githubusercontent.com für GitHub)
UPDATE_DOWNLOAD_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/examples/example_direct_download.sh"

# Optional: URL für Version-Check
# UPDATE_VERSION_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/VERSION"

# ==========================================
# AUTO-UPDATE ENGINE (Bootstrap)
# ==========================================

if [[ -f "$(dirname "$0")/../lib/auto_update_direct_only.sh" ]]; then
    source "$(dirname "$0")/../lib/auto_update_direct_only.sh"
    auto_update_direct
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
    echo "Beispiel: Direct Download Update-Modus"
    echo "Version: $SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    echo "Direct Download Modus - Features:"
    echo ""
    echo "✓ Direkter Download von beliebiger URL"
    echo "✓ Keine GitHub API, keine Git-Dependencies"
    echo "✓ Funktioniert mit raw.githubusercontent.com"
    echo "✓ Optional: Version-Check via separate URL"
    echo "✓ Minimaler Overhead (nur curl)"
    echo "✓ Validierung: Prüft auf Shell-Script Shebang"
    echo ""

    echo "Anwendungsfälle:"
    echo "- Einfache, standalone Scripts"
    echo "- Öffentliche Scripts ohne Authentifizierung"
    echo "- Scripts die auf embedded Systems laufen"
    echo "- Minimale Dependencies (nur curl)"
    echo "- Quick & Dirty Updates"
    echo ""

    echo "Setup für öffentliche GitHub Scripts:"
    echo "1. Script in public Repository pushen"
    echo "2. Raw URL kopieren:"
    echo "   https://raw.githubusercontent.com/USER/REPO/BRANCH/script.sh"
    echo "3. In UPDATE_DOWNLOAD_URL eintragen"
    echo ""

    echo "Optional: Version-Check"
    echo "1. VERSION Datei im Repo erstellen (enthält nur Version, z.B. '1.0.0')"
    echo "2. Raw URL in UPDATE_VERSION_URL eintragen"
    echo "3. Script vergleicht lokale mit Remote-Version"
    echo ""

    echo "Vorteile:"
    echo "+ Sehr einfach, minimaler Code"
    echo "+ Funktioniert ohne GitHub API Token"
    echo "+ Schnell, keine Release-Erstellung nötig"
    echo ""

    echo "Nachteile:"
    echo "- Keine Dependencies, nur Script selbst"
    echo "- Kein Versions-Tracking (außer mit separater VERSION Datei)"
    echo "- Für private Repos: Token in URL nötig"
    echo ""

    echo "✅ Script abgeschlossen"
}

main "$@"
