#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - STANDALONE VERSION
# ==========================================
# Version: 1.1.0
#
# VERWENDUNG: Copy-Paste in dein Script
#
# Kopiere alles zwischen den Markierungen
# "BEGIN AUTO-UPDATE ENGINE" und "END AUTO-UPDATE ENGINE"
# an den Anfang deines Scripts.
# ==========================================

# ==========================================
# BEGIN AUTO-UPDATE ENGINE
# ==========================================

# Konfiguration (anpassen!)
# UPDATE_MODE="github_release"  # oder "git_pull", "direct_download", "disabled"
# UPDATE_GITHUB_USER="dein_user"
# UPDATE_GITHUB_REPO="dein_repo"
# UPDATE_RELEASE_TAG="latest"
# GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Optional

# Globale Update-Konfiguration
UPDATE_VERBOSE="${UPDATE_VERBOSE:-0}"
UPDATE_DRY_RUN="${UPDATE_DRY_RUN:-0}"
UPDATE_LOG="${UPDATE_LOG:-}"
UPDATE_CACHE_DIR="${UPDATE_CACHE_DIR:-/tmp/auto_update_cache}"
UPDATE_CACHE_LIFETIME="${UPDATE_CACHE_LIFETIME:-1440}"
UPDATE_TIMEOUT="${UPDATE_TIMEOUT:-30}"
UPDATE_BACKUP="${UPDATE_BACKUP:-1}"

# Utility Funktionen
_log() {
    local level="$1"
    shift
    local message="$*"

    case "$level" in
        INFO)  echo "ℹ️  $message" ;;
        SUCCESS) echo "✅ $message" ;;
        WARN)  echo "⚠️  $message" ;;
        ERROR) echo "❌ $message" ;;
        DEBUG) [[ "$UPDATE_VERBOSE" == "1" ]] && echo "🔍 $message" ;;
    esac

    if [[ -n "$UPDATE_LOG" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$UPDATE_LOG"
    fi
}

_check_dependencies() {
    local deps=("$@")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            _log ERROR "Erforderliche Abhängigkeit nicht gefunden: $dep"
            return 1
        fi
    done
    return 0
}

_get_cache_file() {
    local cache_key="$1"
    echo "$UPDATE_CACHE_DIR/${cache_key// /_}.cache"
}

_is_cache_valid() {
    local cache_file="$1"

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    if [[ -n "$(find "$cache_file" -mmin -"$UPDATE_CACHE_LIFETIME" 2>/dev/null)" ]]; then
        return 0
    fi

    return 1
}

_backup_script() {
    local script_path="$1"

    if [[ "$UPDATE_BACKUP" != "1" ]]; then
        return 0
    fi

    local backup_path="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"

    if cp "$script_path" "$backup_path" 2>/dev/null; then
        _log DEBUG "Backup erstellt: $backup_path"
        echo "$backup_path"
        return 0
    else
        _log WARN "Backup konnte nicht erstellt werden"
        return 1
    fi
}

_rollback_script() {
    local script_path="$1"
    local backup_path="$2"

    if [[ -f "$backup_path" ]]; then
        _log WARN "Rollback wird durchgeführt..."
        if cp "$backup_path" "$script_path"; then
            _log SUCCESS "Rollback erfolgreich"
            return 0
        fi
    fi

    _log ERROR "Rollback fehlgeschlagen"
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

    if [[ "$UPDATE_DRY_RUN" == "1" ]]; then
        _log INFO "[DRY-RUN] Würde Script aktualisieren: $script_path"
        return 0
    fi

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
        _rollback_script "$script_path" "$backup_path"
        return 1
    fi
}

_compare_versions() {
    local current="$1"
    local remote="$2"

    current="${current#v}"
    remote="${remote#v}"

    if [[ "$current" == "$remote" ]]; then
        return 0
    fi

    if [[ "$current" < "$remote" ]]; then
        return 1
    fi

    return 2
}

# GitHub Release Update Mode
_update_github_release() {
    _log DEBUG "Starte GitHub Release Update-Modus"

    if ! _check_dependencies curl; then
        return 1
    fi

    local github_user="${UPDATE_GITHUB_USER:-}"
    local github_repo="${UPDATE_GITHUB_REPO:-}"
    local github_token="${GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
    local release_tag="${UPDATE_RELEASE_TAG:-latest}"
    local asset_name="${UPDATE_ASSET_NAME:-}"
    local is_archive="${UPDATE_IS_ARCHIVE:-0}"

    if [[ -z "$github_user" || -z "$github_repo" ]]; then
        _log ERROR "UPDATE_GITHUB_USER und UPDATE_GITHUB_REPO müssen gesetzt sein"
        return 1
    fi

    if [[ -n "$github_token" && "$github_token" == github_pat_* ]]; then
        _log WARN "GitHub Token ist im Script hardcoded - erwäge Nutzung von Umgebungsvariablen"
    fi

    local api_url
    if [[ "$release_tag" == "latest" ]]; then
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/latest"
    else
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/tags/${release_tag}"
    fi

    _log DEBUG "API URL: $api_url"

    local cache_file
    cache_file=$(_get_cache_file "github_${github_user}_${github_repo}_${release_tag}")

    local curl_headers=()
    if [[ -n "$github_token" ]]; then
        curl_headers+=("-H" "Authorization: Bearer $github_token")
    fi
    curl_headers+=("-H" "Accept: application/vnd.github.v3+json")

    _log INFO "Prüfe auf Updates..."
    local release_info
    release_info=$(curl -sS --max-time "$UPDATE_TIMEOUT" "${curl_headers[@]}" "$api_url" 2>&1)

    if [[ $? -ne 0 ]]; then
        _log ERROR "GitHub API nicht erreichbar: $release_info"

        if _is_cache_valid "$cache_file"; then
            _log INFO "Nutze gecachte Release-Info"
            release_info=$(cat "$cache_file")
        else
            return 1
        fi
    else
        mkdir -p "$UPDATE_CACHE_DIR"
        echo "$release_info" > "$cache_file"
    fi

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
        _log ERROR "Weder python3 noch jq gefunden - kann Release-Info nicht parsen"
        return 1
    fi

    if [[ -z "$remote_version" ]]; then
        _log ERROR "Konnte Remote-Version nicht ermitteln"
        return 1
    fi

    _log DEBUG "Remote-Version: $remote_version"

    local current_version="${SCRIPT_VERSION:-unknown}"
    _log DEBUG "Aktuelle Version: $current_version"

    _compare_versions "$current_version" "$remote_version"
    local version_cmp=$?

    if [[ $version_cmp -eq 0 ]]; then
        _log SUCCESS "Script ist bereits auf dem neuesten Stand ($current_version)"
        return 0
    elif [[ $version_cmp -eq 2 ]]; then
        _log WARN "Lokale Version ($current_version) ist neuer als Remote ($remote_version)"
        return 0
    fi

    _log INFO "Update verfügbar: $current_version → $remote_version"

    if [[ -z "$asset_url" ]]; then
        _log ERROR "Kein Asset gefunden im Release"
        return 1
    fi

    _log INFO "Lade Update herunter..."
    _log DEBUG "Asset URL: $asset_url"

    local temp_download="/tmp/auto_update_download_$$"

    # Für API-URLs (private Repos): Setze Accept Header für Binary Download
    local download_headers=()
    if [[ "$asset_url" == *"api.github.com"* ]]; then
        if [[ -n "$github_token" ]]; then
            download_headers+=("-H" "Authorization: Bearer $github_token")
        fi
        download_headers+=("-H" "Accept: application/octet-stream")
    else
        download_headers=("${curl_headers[@]}")
    fi

    if ! curl -sS --max-time "$UPDATE_TIMEOUT" -L "${download_headers[@]}" "$asset_url" -o "$temp_download"; then
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    fi

    if [[ "$is_archive" == "1" || "$asset_name" == *.tar.gz || "$asset_name" == *.zip ]]; then
        _log INFO "Entpacke Archive..."

        local extract_dir="/tmp/auto_update_extract_$$"
        mkdir -p "$extract_dir"

        if [[ "$asset_name" == *.tar.gz ]]; then
            tar -xzf "$temp_download" -C "$extract_dir" 2>/dev/null
        elif [[ "$asset_name" == *.zip ]]; then
            unzip -q "$temp_download" -d "$extract_dir" 2>/dev/null
        fi

        local script_file
        script_file=$(find "$extract_dir" -type f -name "*.sh" | head -n1)
        if [[ -z "$script_file" ]]; then
            script_file=$(find "$extract_dir" -type f -name "*.command" | head -n1)
        fi

        if [[ -z "$script_file" ]]; then
            _log ERROR "Kein Shell-Script im Archive gefunden (.sh oder .command)"
            rm -rf "$temp_download" "$extract_dir"
            return 1
        fi

        if ! _self_replace "$0" "$(cat "$script_file")"; then
            rm -rf "$temp_download" "$extract_dir"
            return 1
        fi

        if [[ -d "$extract_dir/DEP" ]]; then
            local dep_target="$(dirname "$0")/DEP"
            _log INFO "Kopiere Dependencies nach $dep_target"
            mkdir -p "$dep_target"
            cp -r "$extract_dir/DEP/"* "$dep_target/" 2>/dev/null
        fi

        rm -rf "$temp_download" "$extract_dir"

    else
        if ! _self_replace "$0" "$(cat "$temp_download")"; then
            rm -f "$temp_download"
            return 1
        fi

        rm -f "$temp_download"
    fi

    _log SUCCESS "Update auf Version $remote_version abgeschlossen"
    _log INFO "Script wird neu gestartet..."

    if [[ "$UPDATE_DRY_RUN" != "1" ]]; then
        exec "$0" "$@"
    fi

    return 0
}

# Git Pull Update Mode
_update_git_pull() {
    _log DEBUG "Starte Git Pull Update-Modus"

    if ! _check_dependencies git; then
        return 1
    fi

    local repo_path="${UPDATE_GIT_REPO_PATH:-}"
    local branch="${UPDATE_GIT_BRANCH:-master}"

    if [[ -z "$repo_path" ]]; then
        repo_path=$(cd "$(dirname "$0")" && git rev-parse --show-toplevel 2>/dev/null)
    fi

    if [[ -z "$repo_path" || ! -d "$repo_path/.git" ]]; then
        _log ERROR "Kein Git-Repository gefunden"
        return 1
    fi

    _log DEBUG "Repository: $repo_path"

    cd "$repo_path" || return 1

    local current_commit
    current_commit=$(git rev-parse HEAD)

    _log INFO "Prüfe auf Updates..."

    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        _log ERROR "Git fetch fehlgeschlagen"
        return 1
    fi

    local remote_commit
    remote_commit=$(git rev-parse "origin/$branch")

    if [[ "$current_commit" == "$remote_commit" ]]; then
        _log SUCCESS "Repository ist bereits auf dem neuesten Stand"
        return 0
    fi

    _log INFO "Update verfügbar: ${current_commit:0:7} → ${remote_commit:0:7}"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        _log ERROR "Lokale Änderungen vorhanden - Update abgebrochen"
        _log INFO "Committe oder stashe deine Änderungen zuerst"
        return 1
    fi

    if [[ "$UPDATE_DRY_RUN" == "1" ]]; then
        _log INFO "[DRY-RUN] Würde git pull durchführen"
        return 0
    fi

    _log INFO "Aktualisiere Repository..."

    if git pull origin "$branch" --quiet; then
        _log SUCCESS "Repository erfolgreich aktualisiert"
        _log INFO "Script wird neu gestartet..."
        exec "$0" "$@"
    else
        _log ERROR "Git pull fehlgeschlagen"
        return 1
    fi
}

# Direct Download Update Mode
_update_direct_download() {
    _log DEBUG "Starte Direct Download Update-Modus"

    if ! _check_dependencies curl; then
        return 1
    fi

    local download_url="${UPDATE_DOWNLOAD_URL:-}"
    local version_url="${UPDATE_VERSION_URL:-}"

    if [[ -z "$download_url" ]]; then
        _log ERROR "UPDATE_DOWNLOAD_URL muss gesetzt sein"
        return 1
    fi

    _log DEBUG "Download URL: $download_url"

    if [[ -n "$version_url" ]]; then
        _log INFO "Prüfe Remote-Version..."

        local remote_version
        remote_version=$(curl -sS --max-time "$UPDATE_TIMEOUT" "$version_url" 2>/dev/null | tr -d '"\n ')

        if [[ -n "$remote_version" ]]; then
            local current_version="${SCRIPT_VERSION:-unknown}"
            _log DEBUG "Aktuelle Version: $current_version"
            _log DEBUG "Remote-Version: $remote_version"

            _compare_versions "$current_version" "$remote_version"
            local version_cmp=$?

            if [[ $version_cmp -eq 0 ]]; then
                _log SUCCESS "Script ist bereits auf dem neuesten Stand ($current_version)"
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

    local temp_download="/tmp/auto_update_download_$$"

    if ! curl -sS --max-time "$UPDATE_TIMEOUT" -L "$download_url" -o "$temp_download"; then
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    fi

    if ! head -n1 "$temp_download" | grep -q '^#!/.*sh'; then
        _log ERROR "Heruntergeladene Datei ist kein Shell-Script"
        rm -f "$temp_download"
        return 1
    fi

    if ! _self_replace "$0" "$(cat "$temp_download")"; then
        rm -f "$temp_download"
        return 1
    fi

    rm -f "$temp_download"

    _log SUCCESS "Update abgeschlossen"
    _log INFO "Script wird neu gestartet..."

    if [[ "$UPDATE_DRY_RUN" != "1" ]]; then
        exec "$0" "$@"
    fi

    return 0
}

# Main Auto-Update Funktion
auto_update() {
    local mode="${UPDATE_MODE:-disabled}"

    _log DEBUG "Auto-Update Engine gestartet (Modus: $mode)"

    mkdir -p "$UPDATE_CACHE_DIR"

    case "$mode" in
        github_release)
            _update_github_release
            ;;
        git_pull)
            _update_git_pull
            ;;
        direct_download)
            _update_direct_download
            ;;
        disabled)
            _log DEBUG "Auto-Update ist deaktiviert"
            return 0
            ;;
        *)
            _log ERROR "Unbekannter Update-Modus: $mode"
            _log INFO "Unterstützte Modi: github_release, git_pull, direct_download, disabled"
            return 1
            ;;
    esac
}

# ==========================================
# END AUTO-UPDATE ENGINE
# ==========================================

# Ab hier beginnt dein Script-Code
# Beispiel:
#
# SCRIPT_VERSION="1.0.0"
# UPDATE_MODE="github_release"
# UPDATE_GITHUB_USER="dein_user"
# UPDATE_GITHUB_REPO="dein_repo"
#
# # Auto-Update durchführen
# auto_update
#
# # Deine Script-Logik
# main() {
#     echo "Script läuft..."
# }
#
# main "$@"
