#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - GITHUB RELEASE ONLY
# ==========================================
# Version: 1.1.0
# Kompakte Version nur für GitHub Release Updates
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

_preserve_sensitive_vars() {
    local old_script="$1"
    local new_content="$2"

    # Extrahiere GITHUB_TOKEN aus altem Script
    local old_token=""
    if [[ -f "$old_script" ]]; then
        old_token=$(grep -E '^GITHUB_TOKEN=' "$old_script" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi

    # Wenn Token vorhanden und nicht leer, in neue Version einsetzen
    if [[ -n "$old_token" && "$old_token" != "" ]]; then
        _log DEBUG "Preserving GitHub token in updated version"

        # Token in new_content ersetzen
        # Matcht: GITHUB_TOKEN="" oder GITHUB_TOKEN="ghp_xxx"
        new_content=$(echo "$new_content" | sed "s|^GITHUB_TOKEN=\"[^\"]*\"|GITHUB_TOKEN=\"$old_token\"|g")
    fi

    # Rückgabe des (ggf. modifizierten) Contents
    echo "$new_content"
}

_self_replace() {
    local script_path="$1"
    local new_content="$2"

    [[ "$UPDATE_DRY_RUN" == "1" ]] && _log INFO "[DRY-RUN] Würde Script aktualisieren: $script_path" && return 0

    # NEU: Sensitive Variablen preserven
    new_content=$(_preserve_sensitive_vars "$script_path" "$new_content")

    local backup_path
    backup_path=$(_backup_script "$script_path")

    if echo "$new_content" > "$script_path"; then
        chmod +x "$script_path"
        _log SUCCESS "Script erfolgreich aktualisiert"
        find "$(dirname "$script_path")" -name "$(basename "$script_path").backup.*" -type f | sort -r | tail -n +4 | xargs rm -f 2>/dev/null
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

auto_update_github() {
    # Dependencies
    command -v curl &> /dev/null || { _log ERROR "curl nicht gefunden"; return 1; }

    # Konfiguration
    local github_user="${UPDATE_GITHUB_USER:-}"
    local github_repo="${UPDATE_GITHUB_REPO:-}"
    local github_token="${GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
    local release_tag="${UPDATE_RELEASE_TAG:-latest}"
    local asset_name="${UPDATE_ASSET_NAME:-}"

    [[ -z "$github_user" || -z "$github_repo" ]] && _log ERROR "UPDATE_GITHUB_USER und UPDATE_GITHUB_REPO erforderlich" && return 1

    # API URL
    local api_url
    if [[ "$release_tag" == "latest" ]]; then
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/latest"
    else
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/tags/${release_tag}"
    fi

    # Headers
    local curl_headers=()
    [[ -n "$github_token" ]] && curl_headers+=("-H" "Authorization: Bearer $github_token")
    curl_headers+=("-H" "Accept: application/vnd.github.v3+json")

    # Release-Info abrufen
    _log INFO "Prüfe auf Updates..."
    local release_info
    release_info=$(curl -sS --max-time "$UPDATE_TIMEOUT" "${curl_headers[@]}" "$api_url" 2>&1)

    [[ $? -ne 0 ]] && _log ERROR "GitHub API nicht erreichbar" && return 1

    # Parse mit Python oder jq
    local remote_version asset_url

    if command -v python3 &> /dev/null; then
        remote_version=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tag_name', ''))" 2>/dev/null)

        if [[ -n "$asset_name" ]]; then
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=[a for a in data.get('assets', []) if a['name']=='${asset_name}']; print(assets[0]['url'] if assets else '')" 2>/dev/null)
            else
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=[a for a in data.get('assets', []) if a['name']=='${asset_name}']; print(assets[0]['browser_download_url'] if assets else '')" 2>/dev/null)
            fi
        else
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=data.get('assets', []); print(assets[0]['url'] if assets else '')" 2>/dev/null)
            else
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=data.get('assets', []); print(assets[0]['browser_download_url'] if assets else '')" 2>/dev/null)
            fi
        fi
    elif command -v jq &> /dev/null; then
        remote_version=$(echo "$release_info" | jq -r '.tag_name // empty')

        if [[ -n "$asset_name" ]]; then
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | jq -r ".assets[] | select(.name==\"${asset_name}\") | .url // empty")
            else
                asset_url=$(echo "$release_info" | jq -r ".assets[] | select(.name==\"${asset_name}\") | .browser_download_url // empty")
            fi
        else
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | jq -r '.assets[0].url // empty')
            else
                asset_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url // empty')
            fi
        fi
    else
        _log ERROR "Weder python3 noch jq gefunden"
        return 1
    fi

    [[ -z "$remote_version" ]] && _log ERROR "Remote-Version nicht ermittelbar" && return 1

    # Versions-Vergleich
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

    # Download
    [[ -z "$asset_url" ]] && _log ERROR "Kein Asset im Release gefunden" && return 1

    _log INFO "Lade Update herunter..."
    local temp_download="/tmp/auto_update_download_$$"

    # Für API-URLs (private Repos): Setze Accept Header für Binary Download
    local download_headers=("${curl_headers[@]}")
    if [[ "$asset_url" == *"api.github.com"* ]]; then
        download_headers+=("-H" "Accept: application/octet-stream")
    fi

    curl -sS --max-time "$UPDATE_TIMEOUT" -L "${download_headers[@]}" "$asset_url" -o "$temp_download" || {
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    }

    # Archive-Handling
    if [[ "$asset_name" == *.tar.gz || "$asset_name" == *.zip ]]; then
        local extract_dir="/tmp/auto_update_extract_$$"
        mkdir -p "$extract_dir"

        if [[ "$asset_name" == *.tar.gz ]]; then
            tar -xzf "$temp_download" -C "$extract_dir" 2>/dev/null
        elif [[ "$asset_name" == *.zip ]]; then
            unzip -q "$temp_download" -d "$extract_dir" 2>/dev/null
        fi

        local script_file
        script_file=$(find "$extract_dir" \( -name "*.sh" -o -name "*.command" \) -type f | head -n1)

        [[ -z "$script_file" ]] && _log ERROR "Kein Shell-Script im Archive (.sh oder .command)" && rm -rf "$temp_download" "$extract_dir" && return 1

        _self_replace "$0" "$(cat "$script_file")" || { rm -rf "$temp_download" "$extract_dir"; return 1; }

        # Dependencies kopieren
        if [[ -d "$extract_dir/DEP" ]]; then
            local dep_target="$(dirname "$0")/DEP"
            _log INFO "Kopiere Dependencies nach $dep_target"
            mkdir -p "$dep_target"
            cp -r "$extract_dir/DEP/"* "$dep_target/" 2>/dev/null
        fi

        rm -rf "$temp_download" "$extract_dir"
    else
        # Direkter Replace
        _self_replace "$0" "$(cat "$temp_download")" || { rm -f "$temp_download"; return 1; }
        rm -f "$temp_download"
    fi

    _log SUCCESS "Update auf Version $remote_version abgeschlossen"
    _log INFO "Script wird neu gestartet..."

    [[ "$UPDATE_DRY_RUN" != "1" ]] && exec "$0" "$@"
    return 0
}

# Direkter Aufruf
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GitHub Release Update Module v1.0.0"
    echo "Verwendung: source auto_update_github_only.sh && auto_update_github"
    exit 1
fi
