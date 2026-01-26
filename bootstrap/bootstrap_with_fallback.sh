#!/bin/bash
# ==========================================
# AUTO-UPDATE BOOTSTRAP - MIT FALLBACK
# ==========================================
# Version: 1.0.0
# Lädt Update-Engine von GitHub mit Fallback-Updater
# Ca. 110 Zeilen
#
# VERWENDUNG:
# Kopiere diesen Code-Block in dein Script
# ==========================================

auto_update() {
    # Konfiguration
    local ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/master/lib/auto_update_engine.sh"
    local CACHE_DIR="/tmp/auto_update_cache"
    local CACHE_FILE="$CACHE_DIR/engine.sh"
    local CACHE_LIFETIME=1440  # 24 Stunden

    mkdir -p "$CACHE_DIR" 2>/dev/null

    # Versuche Bootstrap
    if [[ -f "$CACHE_FILE" && -n "$(find "$CACHE_FILE" -mmin -"$CACHE_LIFETIME" 2>/dev/null)" ]]; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    if curl -sS --max-time 30 "$ENGINE_URL" -o "$CACHE_FILE" 2>/dev/null; then
        source "$CACHE_FILE" && _auto_update_main "$UPDATE_MODE" && return 0
    fi

    # Bootstrap fehlgeschlagen - Fallback-Updater
    echo "⚠️  Engine nicht erreichbar - nutze Fallback-Updater"
    _fallback_updater
}

_fallback_updater() {
    # Minimaler GitHub Release Updater als Fallback
    command -v curl &> /dev/null || { echo "❌ curl nicht gefunden"; return 1; }

    local github_user="${UPDATE_GITHUB_USER:-}"
    local github_repo="${UPDATE_GITHUB_REPO:-}"
    local github_token="${UPDATE_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
    local release_tag="${UPDATE_RELEASE_TAG:-latest}"

    [[ -z "$github_user" || -z "$github_repo" ]] && echo "❌ UPDATE_GITHUB_USER/REPO fehlen" && return 1

    local api_url
    [[ "$release_tag" == "latest" ]] && api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/latest" || api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/tags/${release_tag}"

    local curl_headers=()
    [[ -n "$github_token" ]] && curl_headers+=("-H" "Authorization: Bearer $github_token")
    curl_headers+=("-H" "Accept: application/vnd.github.v3+json")

    echo "ℹ️  Prüfe auf Updates (Fallback)..."
    local release_info
    release_info=$(curl -sS --max-time 30 "${curl_headers[@]}" "$api_url" 2>&1)
    [[ $? -ne 0 ]] && echo "❌ GitHub API nicht erreichbar" && return 1

    local remote_version asset_url

    if command -v python3 &> /dev/null; then
        remote_version=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tag_name', ''))" 2>/dev/null)
        asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=data.get('assets', []); print(assets[0]['browser_download_url'] if assets else '')" 2>/dev/null)
    elif command -v jq &> /dev/null; then
        remote_version=$(echo "$release_info" | jq -r '.tag_name // empty')
        asset_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url // empty')
    else
        echo "❌ python3 oder jq erforderlich"
        return 1
    fi

    [[ -z "$remote_version" ]] && echo "❌ Remote-Version nicht ermittelbar" && return 1

    local current_version="${SCRIPT_VERSION:-unknown}"
    local current_clean="${current_version#v}"
    local remote_clean="${remote_version#v}"

    if [[ "$current_clean" == "$remote_clean" ]]; then
        echo "✅ Script ist aktuell ($current_version)"
        return 0
    elif [[ "$current_clean" > "$remote_clean" ]]; then
        echo "⚠️  Lokale Version ($current_version) ist neuer als Remote ($remote_version)"
        return 0
    fi

    echo "ℹ️  Update verfügbar: $current_version → $remote_version"

    [[ -z "$asset_url" ]] && echo "❌ Kein Asset gefunden" && return 1

    echo "ℹ️  Lade Update herunter..."
    local temp_download="/tmp/auto_update_download_$$"

    curl -sS --max-time 30 -L "${curl_headers[@]}" "$asset_url" -o "$temp_download" || {
        echo "❌ Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    }

    # Backup
    local backup_path="${0}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$0" "$backup_path" 2>/dev/null

    # Replace
    if cat "$temp_download" > "$0"; then
        chmod +x "$0"
        rm -f "$temp_download"
        echo "✅ Update auf Version $remote_version abgeschlossen"
        echo "ℹ️  Script wird neu gestartet..."
        exec "$0" "$@"
    else
        echo "❌ Script-Update fehlgeschlagen"
        [[ -f "$backup_path" ]] && cp "$backup_path" "$0"
        rm -f "$temp_download"
        return 1
    fi
}

# ANLEITUNG:
# Gleiche Verwendung wie bootstrap_minimal.sh, aber mit Fallback-Funktion
# die auch funktioniert wenn das AutoUpdater-Repo nicht erreichbar ist.
