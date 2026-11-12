#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - DIRECT DOWNLOAD ONLY
# ==========================================
# Version: 1.1.0
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

_preserve_sensitive_vars() {
    local old_script="$1"
    local new_content="$2"

    # Extrahiere GITHUB_TOKEN aus altem Script
    local old_token=""
    if [[ -f "$old_script" ]]; then
        old_token=$(grep -E '^GITHUB_TOKEN=' "$old_script" | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    fi

    # Extrahiere GITHUB_TOKEN aus der neuen, ausgelieferten Version
    local new_token=""
    new_token=$(echo "$new_content" | grep -E '^GITHUB_TOKEN=' | head -1 | cut -d'"' -f2 2>/dev/null || echo "")

    if [[ -n "$new_token" ]]; then
        # Ein rotierter Token wurde ausgeliefert: er hat Vorrang vor dem alten Token,
        # sonst wäre Token-Rotation über ein Release nie möglich (Issue #1).
        _log DEBUG "Neuer GitHub-Token in ausgelieferter Version erkannt, wird übernommen"
    elif [[ -n "$old_token" ]]; then
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
        return 0
    else
        _log ERROR "Script-Update fehlgeschlagen"
        [[ -f "$backup_path" ]] && cp "$backup_path" "$script_path"
        return 1
    fi
}

_au_split_version() {
    # Zerlegt "v1.10.0" in _AU_VER_FIELDS=(1 10 0). Rueckgabe 1 bei unlesbarer Version.
    local v="$1" f
    _AU_VER_FIELDS=()
    v="${v#[vV]}"
    case "$v" in
        ""|.*|*.|*..*) return 1 ;;
    esac
    local IFS='.'
    read -r -a _AU_VER_FIELDS <<< "$v"
    [[ ${#_AU_VER_FIELDS[@]} -gt 0 ]] || return 1
    for f in "${_AU_VER_FIELDS[@]}"; do
        [[ "$f" =~ ^[0-9]+$ ]] || return 1
    done
    return 0
}

# Rueckgabe: 0 = gleich, 1 = Remote neuer (Update), 2 = lokal neuer,
#            3 = Version nicht lesbar (KEIN Update, Meldung auf stderr).
# Feldweise numerisch; fehlende Felder = 0; fuehrendes v/V und Nullen ignoriert.
# Reines Bash 3.2 (kein sort -V, keine assoziativen Arrays).
_compare_versions() {
    local -a cur rem
    if ! _au_split_version "$1"; then
        echo "FEHLER: Lokale Version nicht lesbar: '$1' — kein Update" >&2
        return 3
    fi
    cur=("${_AU_VER_FIELDS[@]}")
    if ! _au_split_version "$2"; then
        echo "FEHLER: Remote-Version nicht lesbar: '$2' — kein Update" >&2
        return 3
    fi
    rem=("${_AU_VER_FIELDS[@]}")

    local n=${#cur[@]} i a b
    [[ ${#rem[@]} -gt $n ]] && n=${#rem[@]}
    for ((i = 0; i < n; i++)); do
        a="${cur[i]:-0}"
        b="${rem[i]:-0}"
        # fuehrende Nullen entfernen (kein Oktal, kein Ueberlauf)
        while [[ ${#a} -gt 1 && "${a:0:1}" == "0" ]]; do a="${a:1}"; done
        while [[ ${#b} -gt 1 && "${b:0:1}" == "0" ]]; do b="${b:1}"; done
        if [[ ${#a} -lt ${#b} ]]; then
            return 1
        elif [[ ${#a} -gt ${#b} ]]; then
            return 2
        elif [[ "$a" < "$b" ]]; then
            return 1
        elif [[ "$a" > "$b" ]]; then
            return 2
        fi
    done
    return 0
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
            elif [[ $version_cmp -eq 3 ]]; then
                _log ERROR "Version nicht lesbar (lokal '$current_version', remote '$remote_version') — Update abgebrochen" >&2
                return 1
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
