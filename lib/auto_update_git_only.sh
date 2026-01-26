#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - GIT PULL ONLY
# ==========================================
# Version: 1.0.0
# Kompakte Version nur für Git Repository Updates
# ==========================================

UPDATE_VERBOSE="${UPDATE_VERBOSE:-0}"
UPDATE_DRY_RUN="${UPDATE_DRY_RUN:-0}"

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

auto_update_git() {
    # Dependencies
    command -v git &> /dev/null || { _log ERROR "git nicht gefunden"; return 1; }

    # Konfiguration
    local repo_path="${UPDATE_GIT_REPO_PATH:-}"
    local branch="${UPDATE_GIT_BRANCH:-master}"

    # Auto-detect Repository
    if [[ -z "$repo_path" ]]; then
        repo_path=$(cd "$(dirname "$0")" && git rev-parse --show-toplevel 2>/dev/null)
    fi

    [[ -z "$repo_path" || ! -d "$repo_path/.git" ]] && _log ERROR "Kein Git-Repository gefunden" && return 1

    _log DEBUG "Repository: $repo_path"

    # In Repo wechseln
    cd "$repo_path" || return 1

    # Aktueller Commit
    local current_commit
    current_commit=$(git rev-parse HEAD)

    _log INFO "Prüfe auf Updates..."

    # Fetch
    git fetch origin "$branch" --quiet 2>/dev/null || { _log ERROR "Git fetch fehlgeschlagen"; return 1; }

    # Remote Commit
    local remote_commit
    remote_commit=$(git rev-parse "origin/$branch")

    if [[ "$current_commit" == "$remote_commit" ]]; then
        _log SUCCESS "Repository ist bereits aktuell"
        return 0
    fi

    _log INFO "Update verfügbar: ${current_commit:0:7} → ${remote_commit:0:7}"

    # Prüfe lokale Änderungen
    if ! git diff --quiet || ! git diff --cached --quiet; then
        _log ERROR "Lokale Änderungen vorhanden - Update abgebrochen"
        _log INFO "Committe oder stashe deine Änderungen zuerst"
        return 1
    fi

    [[ "$UPDATE_DRY_RUN" == "1" ]] && _log INFO "[DRY-RUN] Würde git pull durchführen" && return 0

    # Pull
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

# Direkter Aufruf
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Git Pull Update Module v1.0.0"
    echo "Verwendung: source auto_update_git_only.sh && auto_update_git"
    exit 1
fi
