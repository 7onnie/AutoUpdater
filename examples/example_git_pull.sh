#!/bin/bash
# ==========================================
# BEISPIEL: GIT PULL MODUS
# ==========================================
# Demonstriert Updates via Git Pull
# Für Scripts in Git Mono-Repos
# ==========================================

SCRIPT_VERSION="1.0.0"
SCRIPT_VERSION_DATE="20260126"

# ==========================================
# AUTO-UPDATE KONFIGURATION
# ==========================================
UPDATE_MODE="git_pull"

# Git Konfiguration
# UPDATE_GIT_REPO_PATH="/path/to/repo"  # Optional, wird auto-detected
UPDATE_GIT_BRANCH="master"  # oder "main", "develop", etc.

# ==========================================
# AUTO-UPDATE ENGINE (Bootstrap)
# ==========================================

if [[ -f "$(dirname "$0")/../lib/auto_update_git_only.sh" ]]; then
    source "$(dirname "$0")/../lib/auto_update_git_only.sh"
    auto_update_git
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
    echo "Beispiel: Git Pull Update-Modus"
    echo "Version: $SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    echo "Git Pull Modus - Features:"
    echo ""
    echo "✓ Automatischer git pull bei Script-Start"
    echo "✓ Prüft auf lokale Änderungen (verhindert Überschreiben)"
    echo "✓ Zeigt Commit-Differenz (current → remote)"
    echo "✓ Nutzt bestehende Git-Credentials"
    echo "✓ Kein Token im Script nötig"
    echo "✓ Auto-Restart nach Update"
    echo ""

    echo "Anwendungsfälle:"
    echo "- Scripts innerhalb eines Git Mono-Repos"
    echo "- Entwicklungsumgebung mit Git"
    echo "- Team-Scripts in gemeinsamem Repository"
    echo "- Schnelle Updates ohne Release-Overhead"
    echo ""

    echo "Voraussetzungen:"
    echo "- Script muss in Git-Repository liegen"
    echo "- Git muss installiert sein"
    echo "- Remote-Repository konfiguriert"
    echo "- Keine uncommitted Änderungen"
    echo ""

    echo "Setup:"
    echo "1. Script in Git-Repo platzieren"
    echo "2. UPDATE_MODE='git_pull' setzen"
    echo "3. Optional: Branch anpassen (UPDATE_GIT_BRANCH='develop')"
    echo ""

    echo "Verhalten:"
    echo "- Bei Start: git fetch origin $UPDATE_GIT_BRANCH"
    echo "- Wenn remote ahead: git pull origin $UPDATE_GIT_BRANCH"
    echo "- Wenn lokale Änderungen: Warnung, kein Update"
    echo "- Nach Update: exec \$0 (Neustart)"
    echo ""

    echo "✅ Script abgeschlossen"
}

main "$@"
