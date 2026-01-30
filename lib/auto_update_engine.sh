#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - CORE MODULE
# ==========================================
# Version: 1.1.0
# Author: Claude Code
# Repository: https://github.com/7onnie/AutoUpdater
#
# Universelle Auto-Update-Funktion für Shell-Scripts
# Unterstützt 3 Update-Modi:
# - github_release: GitHub Releases mit Assets
# - git_pull: Git Repository Updates
# - direct_download: Direkter Download einzelner Dateien
#
# Verwendung:
#   source auto_update_engine.sh
#   _auto_update_main <mode> [options]
# ==========================================

# ==========================================
# GLOBALE KONFIGURATION
# ==========================================

# Verbose-Modus (0=aus, 1=an)
UPDATE_VERBOSE="${UPDATE_VERBOSE:-0}"

# Dry-Run Modus (0=aus, 1=an)
UPDATE_DRY_RUN="${UPDATE_DRY_RUN:-0}"

# Log-Datei (leer = kein Logging)
UPDATE_LOG="${UPDATE_LOG:-}"

# Cache-Verzeichnis
UPDATE_CACHE_DIR="${UPDATE_CACHE_DIR:-/tmp/auto_update_cache}"

# Cache-Lifetime in Minuten (1440 = 24 Stunden)
UPDATE_CACHE_LIFETIME="${UPDATE_CACHE_LIFETIME:-1440}"

# Timeout für curl in Sekunden
UPDATE_TIMEOUT="${UPDATE_TIMEOUT:-30}"

# Backup bei Self-Replace (0=aus, 1=an)
UPDATE_BACKUP="${UPDATE_BACKUP:-1}"

# ==========================================
# UTILITY FUNKTIONEN
# ==========================================

_log() {
    local level="$1"
    shift
    local message="$*"

    # Console-Output
    case "$level" in
        INFO)  echo "ℹ️  $message" ;;
        SUCCESS) echo "✅ $message" ;;
        WARN)  echo "⚠️  $message" ;;
        ERROR) echo "❌ $message" ;;
        DEBUG) [[ "$UPDATE_VERBOSE" == "1" ]] && echo "🔍 $message" ;;
    esac

    # Log-Datei
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

    # Prüfe Alter der Cache-Datei
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

    # Backup erstellen
    local backup_path
    backup_path=$(_backup_script "$script_path")

    # Neue Version schreiben
    if echo "$new_content" > "$script_path"; then
        chmod +x "$script_path"
        _log SUCCESS "Script erfolgreich aktualisiert"

        # Backup aufräumen (nur letztes behalten)
        find "$(dirname "$script_path")" -name "$(basename "$script_path").backup.*" -type f | sort -r | tail -n +4 | xargs rm -f 2>/dev/null

        return 0
    else
        _log ERROR "Script-Update fehlgeschlagen"
        _rollback_script "$script_path" "$backup_path"
        return 1
    fi
}

_extract_version_from_script() {
    local script_path="$1"
    local version_pattern="${2:-SCRIPT_VERSION=}"

    grep "^${version_pattern}" "$script_path" | head -n1 | cut -d'"' -f2 | tr -d "'"
}

_compare_versions() {
    local current="$1"
    local remote="$2"

    # Bereinige Versions-String (entferne v-Prefix, etc.)
    current="${current#v}"
    remote="${remote#v}"

    if [[ "$current" == "$remote" ]]; then
        return 0  # Gleiche Version
    fi

    # Einfacher lexikalischer Vergleich
    if [[ "$current" < "$remote" ]]; then
        return 1  # Update verfügbar
    fi

    return 2  # Current ist neuer (sollte nicht passieren)
}

# ==========================================
# GITHUB RELEASE UPDATE MODE
# ==========================================

_update_github_release() {
    _log DEBUG "Starte GitHub Release Update-Modus"

    # Dependencies prüfen
    if ! _check_dependencies curl; then
        return 1
    fi

    # Konfiguration aus Umgebungsvariablen
    local github_user="${UPDATE_GITHUB_USER:-}"
    local github_repo="${UPDATE_GITHUB_REPO:-}"
    local github_token="${GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
    local release_tag="${UPDATE_RELEASE_TAG:-latest}"
    local asset_name="${UPDATE_ASSET_NAME:-}"
    local is_archive="${UPDATE_IS_ARCHIVE:-0}"

    # Validierung
    if [[ -z "$github_user" || -z "$github_repo" ]]; then
        _log ERROR "UPDATE_GITHUB_USER und UPDATE_GITHUB_REPO müssen gesetzt sein"
        return 1
    fi

    # Warnung bei hardcoded Token
    if [[ -n "$github_token" && "$github_token" == github_pat_* ]]; then
        _log WARN "GitHub Token ist im Script hardcoded - erwäge Nutzung von Umgebungsvariablen"
    fi

    # API URL konstruieren
    local api_url
    if [[ "$release_tag" == "latest" ]]; then
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/latest"
    else
        api_url="https://api.github.com/repos/${github_user}/${github_repo}/releases/tags/${release_tag}"
    fi

    _log DEBUG "API URL: $api_url"

    # Cache-Check
    local cache_file
    cache_file=$(_get_cache_file "github_${github_user}_${github_repo}_${release_tag}")

    # Headers für API-Request
    local curl_headers=()
    if [[ -n "$github_token" ]]; then
        curl_headers+=("-H" "Authorization: Bearer $github_token")
    fi
    curl_headers+=("-H" "Accept: application/vnd.github.v3+json")

    # Release-Info abrufen
    _log INFO "Prüfe auf Updates..."
    local release_info
    release_info=$(curl -sS --max-time "$UPDATE_TIMEOUT" "${curl_headers[@]}" "$api_url" 2>&1)

    if [[ $? -ne 0 ]]; then
        _log ERROR "GitHub API nicht erreichbar: $release_info"

        # Versuche Cache zu nutzen
        if _is_cache_valid "$cache_file"; then
            _log INFO "Nutze gecachte Release-Info"
            release_info=$(cat "$cache_file")
        else
            return 1
        fi
    else
        # Cache aktualisieren
        mkdir -p "$UPDATE_CACHE_DIR"
        echo "$release_info" > "$cache_file"
    fi

    # Release-Info parsen (Python oder jq)
    local remote_version asset_url

    if command -v python3 &> /dev/null; then
        remote_version=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tag_name', ''))" 2>/dev/null)

        if [[ -n "$asset_name" ]]; then
            # Suche nach spezifischem Asset
            # Für private Repos: Nutze API-URL statt browser_download_url
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=[a for a in data.get('assets', []) if a['name']=='${asset_name}']; print(assets[0]['url'] if assets else '')" 2>/dev/null)
            else
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=[a for a in data.get('assets', []) if a['name']=='${asset_name}']; print(assets[0]['browser_download_url'] if assets else '')" 2>/dev/null)
            fi
        else
            # Nimm erstes Asset
            if [[ -n "$github_token" ]]; then
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=data.get('assets', []); print(assets[0]['url'] if assets else '')" 2>/dev/null)
            else
                asset_url=$(echo "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); assets=data.get('assets', []); print(assets[0]['browser_download_url'] if assets else '')" 2>/dev/null)
            fi
        fi
    elif command -v jq &> /dev/null; then
        remote_version=$(echo "$release_info" | jq -r '.tag_name // empty')

        if [[ -n "$asset_name" ]]; then
            # Für private Repos: Nutze API-URL statt browser_download_url
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

    # Versions-Vergleich
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

    # Asset herunterladen
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
        # Für API-URLs: Nur Authorization + octet-stream Accept
        if [[ -n "$github_token" ]]; then
            download_headers+=("-H" "Authorization: Bearer $github_token")
        fi
        download_headers+=("-H" "Accept: application/octet-stream")
    else
        # Für normale URLs: Alle Headers
        download_headers=("${curl_headers[@]}")
    fi

    if ! curl -sS --max-time "$UPDATE_TIMEOUT" -L "${download_headers[@]}" "$asset_url" -o "$temp_download"; then
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    fi

    # Archive entpacken oder Script direkt ersetzen
    if [[ "$is_archive" == "1" || "$asset_name" == *.tar.gz || "$asset_name" == *.zip ]]; then
        _log INFO "Entpacke Archive..."

        local extract_dir="/tmp/auto_update_extract_$$"
        mkdir -p "$extract_dir"

        if [[ "$asset_name" == *.tar.gz ]]; then
            # Entpacken mit Fehler-Logging
            if ! tar -xzf "$temp_download" -C "$extract_dir" 2>&1; then
                _log ERROR "Fehler beim Entpacken des Archives"
                rm -rf "$temp_download" "$extract_dir"
                return 1
            fi
            _log DEBUG "Extracted to: $extract_dir"
            _log DEBUG "Extract dir contents: $(ls -la "$extract_dir" 2>/dev/null | head -20)"
        elif [[ "$asset_name" == *.zip ]]; then
            if ! unzip -q "$temp_download" -d "$extract_dir" 2>&1; then
                _log ERROR "Fehler beim Entpacken des Archives"
                rm -rf "$temp_download" "$extract_dir"
                return 1
            fi
        fi

        # Suche nach Script in extrahiertem Inhalt (.sh oder .command)
        local script_file
        script_file=$(find "$extract_dir" -type f -name "*.sh" | head -n1)
        _log DEBUG "Found .sh files: $(find "$extract_dir" -type f -name '*.sh')"
        if [[ -z "$script_file" ]]; then
            script_file=$(find "$extract_dir" -type f -name "*.command" | head -n1)
            _log DEBUG "Found .command files: $(find "$extract_dir" -type f -name '*.command')"
        fi

        if [[ -z "$script_file" ]]; then
            _log ERROR "Kein Shell-Script im Archive gefunden (.sh oder .command)"
            _log DEBUG "All files in extract_dir: $(find "$extract_dir" -type f)"
            rm -rf "$temp_download" "$extract_dir"
            return 1
        fi

        # Script ersetzen
        if ! _self_replace "$0" "$(cat "$script_file")"; then
            rm -rf "$temp_download" "$extract_dir"
            return 1
        fi

        # Zusätzliche Dateien kopieren (Dependencies, etc.)
        if [[ -d "$extract_dir/DEP" ]]; then
            local dep_target="$(dirname "$0")/DEP"
            _log INFO "Kopiere Dependencies nach $dep_target"
            mkdir -p "$dep_target"
            cp -r "$extract_dir/DEP/"* "$dep_target/" 2>/dev/null
        fi

        rm -rf "$temp_download" "$extract_dir"

    else
        # Direkter Script-Replace
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

# ==========================================
# GIT PULL UPDATE MODE
# ==========================================

_update_git_pull() {
    _log DEBUG "Starte Git Pull Update-Modus"

    # Dependencies prüfen
    if ! _check_dependencies git; then
        return 1
    fi

    # Konfiguration
    local repo_path="${UPDATE_GIT_REPO_PATH:-}"
    local branch="${UPDATE_GIT_BRANCH:-master}"

    # Wenn kein Repo-Path angegeben, versuche aus Script-Location zu ermitteln
    if [[ -z "$repo_path" ]]; then
        repo_path=$(cd "$(dirname "$0")" && git rev-parse --show-toplevel 2>/dev/null)
    fi

    if [[ -z "$repo_path" || ! -d "$repo_path/.git" ]]; then
        _log ERROR "Kein Git-Repository gefunden"
        return 1
    fi

    _log DEBUG "Repository: $repo_path"

    # Wechsel ins Repo
    cd "$repo_path" || return 1

    # Aktuellen Commit speichern
    local current_commit
    current_commit=$(git rev-parse HEAD)

    _log INFO "Prüfe auf Updates..."

    # Fetch ohne Pull (nur prüfen)
    if ! git fetch origin "$branch" --quiet 2>/dev/null; then
        _log ERROR "Git fetch fehlgeschlagen"
        return 1
    fi

    # Remote Commit
    local remote_commit
    remote_commit=$(git rev-parse "origin/$branch")

    if [[ "$current_commit" == "$remote_commit" ]]; then
        _log SUCCESS "Repository ist bereits auf dem neuesten Stand"
        return 0
    fi

    _log INFO "Update verfügbar: ${current_commit:0:7} → ${remote_commit:0:7}"

    # Prüfe auf lokale Änderungen
    if ! git diff --quiet || ! git diff --cached --quiet; then
        _log ERROR "Lokale Änderungen vorhanden - Update abgebrochen"
        _log INFO "Committe oder stashe deine Änderungen zuerst"
        return 1
    fi

    if [[ "$UPDATE_DRY_RUN" == "1" ]]; then
        _log INFO "[DRY-RUN] Würde git pull durchführen"
        return 0
    fi

    # Pull durchführen
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

# ==========================================
# DIRECT DOWNLOAD UPDATE MODE
# ==========================================

_update_direct_download() {
    _log DEBUG "Starte Direct Download Update-Modus"

    # Dependencies prüfen
    if ! _check_dependencies curl; then
        return 1
    fi

    # Konfiguration
    local download_url="${UPDATE_DOWNLOAD_URL:-}"
    local version_url="${UPDATE_VERSION_URL:-}"

    if [[ -z "$download_url" ]]; then
        _log ERROR "UPDATE_DOWNLOAD_URL muss gesetzt sein"
        return 1
    fi

    _log DEBUG "Download URL: $download_url"

    # Wenn Version-URL angegeben, erst Version prüfen
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

    # Download
    local temp_download="/tmp/auto_update_download_$$"

    if ! curl -sS --max-time "$UPDATE_TIMEOUT" -L "$download_url" -o "$temp_download"; then
        _log ERROR "Download fehlgeschlagen"
        rm -f "$temp_download"
        return 1
    fi

    # Validierung: Ist es ein Shell-Script?
    if ! head -n1 "$temp_download" | grep -q '^#!/.*sh'; then
        _log ERROR "Heruntergeladene Datei ist kein Shell-Script"
        rm -f "$temp_download"
        return 1
    fi

    # Script ersetzen
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

# ==========================================
# MAIN ENTRY POINT
# ==========================================

_auto_update_main() {
    local mode="$1"

    _log DEBUG "Auto-Update Engine gestartet (Modus: $mode)"

    # Cache-Verzeichnis erstellen
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

# Wenn direkt ausgeführt (nicht gesourced), zeige Hilfe
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Auto-Update Engine v1.0.0"
    echo ""
    echo "Diese Datei ist zum Sourcing in andere Scripts gedacht."
    echo "Verwendung:"
    echo "  source auto_update_engine.sh"
    echo "  _auto_update_main <mode>"
    echo ""
    echo "Modi: github_release, git_pull, direct_download, disabled"
    exit 1
fi
