#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - DIRECT DOWNLOAD ONLY
# ==========================================
# Version: 1.0.0
# Kompakte Version nur für direkte Downloads
# ==========================================

UPDATE_VERBOSE="${UPDATE_VERBOSE:-0}"
UPDATE_DRY_RUN="${UPDATE_DRY_RUN:-0}"
UPDATE_TIMEOUT="${UPDATE_TIMEOUT:-30}"
UPDATE_BACKUP="${UPDATE_BACKUP:-1}"

_log() {
    local level="$1"
    shift
    case "$level" in
        INFO)  echo "ℹ️  $*" ;;
        SUCCESS) echo "✅ $*" ;;
        WARN)  echo "⚠️  $*" ;;
        ERROR) echo "❌ $*" ;;
        DEBUG) [[ "$UPDATE_VERBOSE" == "1" ]] && echo "🔍 $*" ;;
    esac
}

_backup_script() {
    local script_path="$1"
    [[ "$UPDATE_BACKUP" != "1" ]] && return 0

    local backup_path="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$script_path" "$backup_path" 2>/dev/null; then
        echo "$backup_path"
        return 0
    fi
    return 1
}

_self_replace() {
    local script_path="$1"
    local new_content="$2"

    [[ "$UPDATE_DRY_RUN" == "1" ]] && _log INFO "[DRY-RUN] Würde Script aktualisieren: $script_path" && return 0

    local backup_path
    backup_path=$(_backup_script "$script_path")

    if echo "$new_content" > "$script_path"; then
        chmod +x "$script_path"
        _log SUCCESS "Script erfolgreich aktualisiert"
        return 0
    else
        _log ERROR "Script-Update fehlgeschlagen"
        [[ -f "$backup_path" ]] && cp "$backup_path" "$script_path"
        return 1
    fi
}

_compare_versions() {
    local current="${1#v}"
    local remote="${2#v}"

    [[ "$current" == "$remote" ]] && return 0
    [[ "$current" < "$remote" ]] && return 1
    return 2
}

auto_update_direct() {
    # Dependencies
    command -v curl &> /dev/null || { _log ERROR "curl nicht gefunden"; return 1; }

    # Konfiguration
    local download_url="${UPDATE_DOWNLOAD_URL:-}"
    local version_url="${UPDATE_VERSION_URL:-}"

    [[ -z "$download_url" ]] && _log ERROR "UPDATE_DOWNLOAD_URL erforderlich" && return 1

    _log DEBUG "Download URL: $download_url"

    # Version-Check (optional)
    if [[ -n "$version_url" ]]; then
        _log INFO "Prüfe Remote-Version..."

        local remote_version
        remote_version=$(curl -sS --max-time "$UPDATE_TIMEOUT" "$version_url" 2>/dev/null | tr -d '"\n ')

        if [[ -n "$remote_version" ]]; then
            local current_version="${SCRIPT_VERSION:-unknown}"

            _compare_versions "$current_version" "$remote_version"
            local version_cmp=$?

            if [[ $version_cmp -eq 0 ]]; then
                _log SUCCESS "Script ist bereits aktuell ($current_version)"
                return 0
            elif [[ $version_cmp -eq 2 ]]; then
                _log WARN "Lokale Version ($current_version) ist neuer als Remote ($remote_version)"
                return 0
            fi

            _log INFO "Update verfügbar: $current_version → $remote_version"
        fi
    else
        _log INFO "Lade Update herunter (keine Versions-Prüfung)..."
    fi

    # Download
    local temp_download="/tmp/auto_update_download_$$"

    curl -sS --max-time "$UPDATE_TIMEOUT" -L "$download_url" -o "$temp_download" || {
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    }

    # Validierung
    if ! head -n1 "$temp_download" | grep -q '^#!/.*sh'; then
        _log ERROR "Heruntergeladene Datei ist kein Shell-Script"
        rm -f "$temp_download"
        return 1
    fi

    # Script ersetzen
    _self_replace "$0" "$(cat "$temp_download")" || { rm -f "$temp_download"; return 1; }
    rm -f "$temp_download"

    _log SUCCESS "Update abgeschlossen"
    _log INFO "Script wird neu gestartet..."

    [[ "$UPDATE_DRY_RUN" != "1" ]] && exec "$0" "$@"
    return 0
}

# Direkter Aufruf
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Direct Download Update Module v1.0.0"
    echo "Verwendung: source auto_update_direct_only.sh && auto_update_direct"
    exit 1
fi
