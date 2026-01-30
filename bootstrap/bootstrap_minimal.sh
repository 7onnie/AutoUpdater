#!/bin/bash
# ==========================================
# AUTO-UPDATE BOOTSTRAP - MINIMAL
# ==========================================
# Version: 1.0.0
# Lädt Update-Engine von GitHub und führt sie aus
# Kein Fallback - nur 30 Zeilen
#
# VERWENDUNG:
# Kopiere diesen Code-Block in dein Script und passe
# die Konfiguration an. Rufe dann auto_update auf.
# ==========================================

auto_update() {
    # Konfiguration
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440  # 24 Stunden in Minuten

    # Cache-Verzeichnis erstellen
    mkdir -p "$CACHE_DIR" 2>/dev/null

    # Cache-Check (24h gültig)
    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        # Cache noch gültig - direkt laden und ausführen
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    # Cache abgelaufen oder nicht vorhanden - neu laden
    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        # Erfolgreich geladen - ausführen
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    else
        # Download fehlgeschlagen
        echo "⚠️  Auto-Update Engine nicht erreichbar. Script läuft ohne Update-Check weiter."
        return 1
    fi
}

# ANLEITUNG:
# 1. Kopiere diesen Code-Block an den Anfang deines Scripts
# 2. Setze vor dem auto_update Aufruf: UPDATE_MODE="github_release" (oder "git_pull", "direct_download")
# 3. Setze weitere Konfigurationsvariablen (siehe Dokumentation)
# 4. Rufe auto_update auf
#
# Beispiel:
#
# #!/bin/bash
# SCRIPT_VERSION="1.0.0"
#
# # Update-Konfiguration
# UPDATE_MODE="github_release"
# UPDATE_GITHUB_USER="7onnie"
# UPDATE_GITHUB_REPO="scripts"
# UPDATE_RELEASE_TAG="latest"
# GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Aus Umgebungsvariable
#
# # [HIER DEN auto_update CODE EINFÜGEN]
#
# # Update durchführen
# auto_update
#
# # Deine Script-Logik
# echo "Script läuft..."
