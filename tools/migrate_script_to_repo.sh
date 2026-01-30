#!/bin/bash
# ==========================================
# SCRIPT MIGRATION TOOL
# ==========================================
# Migriert einzelne Scripts aus dem Mono-Repo
# in eigene private GitHub Repositories mit
# automatischen Releases.
#
# Author: Claude Code
# Version: 1.0.0
# Repository: https://github.com/7onnie/AutoUpdater
# ==========================================

set -e  # Exit on error

# ==========================================
# KONFIGURATION
# ==========================================

SCRIPT_VERSION="1.0.0"
GITHUB_USER="7onnie"  # Default GitHub User
DEFAULT_LOCAL_PATH="$HOME/script-repos"
AUTOUPDATER_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$AUTOUPDATER_ROOT/templates"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# UTILITY FUNKTIONEN
# ==========================================

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

show_help() {
    cat <<EOF
Script Migration Tool v$SCRIPT_VERSION

Migriert Scripts aus dem Mono-Repo in eigene GitHub Repositories.

VERWENDUNG:
    $0 [OPTIONS]

OPTIONS:
    --script PATH           Pfad zum Script im Mono-Repo (erforderlich)
    --repo-name NAME        GitHub Repository-Name (erforderlich)
    --local-path PATH       Lokaler Clone-Pfad (default: ~/script-repos)
    --private               Private Repository erstellen (default)
    --public                Public Repository erstellen
    --installer-mode        Erstelle zusätzlich Installer-Script für Share
    --share-token TOKEN     GitHub Token für Installer (nur mit --installer-mode)
    --help                  Diese Hilfe anzeigen

BEISPIEL:
    # CLI-Modus
    $0 \\
      --script ~/ZS_Share/Scripte/Shell/MeinScript.sh \\
      --repo-name mein-script-installer \\
      --private

    # Interaktiver Modus
    $0

VORAUSSETZUNGEN:
    - GitHub authentifiziert (gh auth login)
    - gh CLI installiert (brew install gh)
    - Script muss vorbereitet sein:
      * SCRIPT_VERSION="x.y.z" im Header
      * AutoUpdater Bootstrap eingefügt
      * UPDATE_GITHUB_REPO konfiguriert

DOKUMENTATION:
    Siehe: $AUTOUPDATER_ROOT/docs/SCRIPT_MIGRATION.md

EOF
}

# ==========================================
# VALIDIERUNGS-FUNKTIONEN
# ==========================================

check_dependencies() {
    log_info "Prüfe Dependencies..."

    local missing=0

    if ! command -v gh &> /dev/null; then
        log_error "gh CLI nicht gefunden. Installiere mit: brew install gh"
        missing=1
    fi

    if ! command -v git &> /dev/null; then
        log_error "git nicht gefunden. Installiere mit: brew install git"
        missing=1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl nicht gefunden"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi

    log_success "Alle Dependencies vorhanden"
}

validate_script() {
    local script_path="$1"

    log_info "Validiere Script: $script_path"

    # Existiert Script?
    if [[ ! -f "$script_path" ]]; then
        log_error "Script nicht gefunden: $script_path"
        exit 1
    fi

    # Ist es eine Shell-Script?
    if ! head -n1 "$script_path" | grep -q '^#!/.*sh'; then
        log_error "Keine Shell-Script Shebang gefunden"
        exit 1
    fi

    # Hat SCRIPT_VERSION?
    if ! grep -q '^SCRIPT_VERSION=' "$script_path"; then
        log_error "SCRIPT_VERSION nicht gefunden im Script"
        log_info "Bitte ändere VERSION= zu SCRIPT_VERSION=\"x.y.z\""
        exit 1
    fi

    # Hat auto_update Funktion?
    if ! grep -q 'auto_update()' "$script_path"; then
        log_warn "auto_update() Funktion nicht gefunden"
        log_info "Bootstrap sollte manuell eingefügt worden sein"
        read -p "Trotzdem fortfahren? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "Script-Validierung erfolgreich"
}

extract_version() {
    local script_path="$1"
    grep '^SCRIPT_VERSION=' "$script_path" | head -1 | cut -d'"' -f2 | tr -d "'"
}

validate_github_auth() {
    log_info "Prüfe GitHub Authentifizierung..."

    # Prüfe gh auth status
    if ! gh auth status &>/dev/null; then
        log_error "GitHub Authentifizierung fehlgeschlagen"
        log_info "Bitte authentifiziere dich mit: gh auth login"
        exit 1
    fi

    log_success "GitHub Authentifizierung erfolgreich"
}

check_repo_exists() {
    local repo_name="$1"

    if gh repo view "$GITHUB_USER/$repo_name" &>/dev/null; then
        log_error "Repository existiert bereits: $GITHUB_USER/$repo_name"
        log_info "Wähle einen anderen Namen oder lösche das bestehende Repo"
        exit 1
    fi
}

# ==========================================
# INTERAKTIVER MODUS
# ==========================================

interactive_mode() {
    echo ""
    echo "=========================================="
    echo "  Script Migration - Interaktiver Modus"
    echo "=========================================="
    echo ""

    # Script-Pfad
    read -p "Script-Pfad (vollständig): " SCRIPT_PATH
    SCRIPT_PATH="${SCRIPT_PATH/#\~/$HOME}"  # Expand ~

    # Validiere Script
    validate_script "$SCRIPT_PATH"

    # Extrahiere Script-Name
    local script_name=$(basename "$SCRIPT_PATH")
    local default_repo_name="${script_name%.sh}"

    # Repository-Name
    read -p "Repository-Name [$default_repo_name]: " REPO_NAME
    REPO_NAME="${REPO_NAME:-$default_repo_name}"

    # Private/Public
    read -p "Private Repository? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        REPO_VISIBILITY="public"
    else
        REPO_VISIBILITY="private"
    fi

    # Local Path
    read -p "Lokaler Clone-Pfad [$DEFAULT_LOCAL_PATH]: " LOCAL_PATH
    LOCAL_PATH="${LOCAL_PATH:-$DEFAULT_LOCAL_PATH}"
    LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"  # Expand ~

    echo ""
    echo "Zusammenfassung:"
    echo "  Script:     $SCRIPT_PATH"
    echo "  Repository: $GITHUB_USER/$REPO_NAME"
    echo "  Visibility: $REPO_VISIBILITY"
    echo "  Local:      $LOCAL_PATH/$REPO_NAME"
    echo ""

    read -p "Fortfahren? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Abgebrochen"
        exit 0
    fi
}

# ==========================================
# MIGRATION-FUNKTIONEN
# ==========================================

create_github_repo() {
    local repo_name="$1"
    local visibility="$2"

    log_info "Erstelle GitHub Repository: $GITHUB_USER/$repo_name ($visibility)"

    local visibility_flag="--private"
    if [[ "$visibility" == "public" ]]; then
        visibility_flag="--public"
    fi

    if gh repo create "$repo_name" \
        "$visibility_flag" \
        --description "Auto-migrated from Scripte Mono-Repo" \
        --clone=false; then
        log_success "Repository erstellt"
        return 0
    else
        log_error "Repository-Erstellung fehlgeschlagen"
        exit 1
    fi
}

setup_local_repo() {
    local script_path="$1"
    local repo_name="$2"
    local local_path="$3"

    log_info "Setup lokales Repository..."

    local repo_dir="$local_path/$repo_name"

    # Erstelle Verzeichnis
    mkdir -p "$repo_dir"

    # Kopiere Script
    local script_name=$(basename "$script_path")
    cp "$script_path" "$repo_dir/$script_name"

    log_success "Script kopiert nach: $repo_dir/$script_name"

    # README erstellen
    cat > "$repo_dir/README.md" <<EOF
# $repo_name

Auto-migrated from Scripte Mono-Repo.

## Installation

\`\`\`bash
# Download latest version
curl -L -o $script_name https://github.com/$GITHUB_USER/$repo_name/releases/latest/download/$script_name
chmod +x $script_name
\`\`\`

## Usage

\`\`\`bash
./$script_name
\`\`\`

## Auto-Update

This script includes AutoUpdater and will automatically check for updates on each run.

## Development

Edit locally and push changes:

\`\`\`bash
cd $repo_dir
vim $script_name
# Change SCRIPT_VERSION="x.y.z"
git add $script_name
git commit -m "Update: Description"
git push
\`\`\`

GitHub Actions will automatically create a release when the version changes.
EOF

    log_success "README erstellt"
}

setup_github_action() {
    local local_path="$1"
    local repo_name="$2"

    log_info "Setup GitHub Action für Auto-Release..."

    local repo_dir="$local_path/$repo_name"
    local workflow_dir="$repo_dir/.github/workflows"

    mkdir -p "$workflow_dir"

    # Kopiere Workflow-Template
    if [[ -f "$TEMPLATE_DIR/github-action-auto-release.yml" ]]; then
        cp "$TEMPLATE_DIR/github-action-auto-release.yml" "$workflow_dir/auto-release.yml"
        log_success "GitHub Action konfiguriert"
    else
        log_error "Workflow-Template nicht gefunden: $TEMPLATE_DIR/github-action-auto-release.yml"
        exit 1
    fi
}

git_init_and_push() {
    local local_path="$1"
    local repo_name="$2"
    local version="$3"

    log_info "Initialisiere Git und pushe..."

    local repo_dir="$local_path/$repo_name"
    local script_name=$(ls "$repo_dir"/*.sh | head -1 | xargs basename)

    cd "$repo_dir"

    # Git init
    git init -b main

    # Git config
    git config user.name "Migration Tool"
    git config user.email "migration@autoupdater.local"

    # Add & Commit
    git add .
    git commit -m "Initial: $script_name v$version

Auto-migrated from Scripte Mono-Repo.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

    # Add remote
    git remote add origin "https://github.com/$GITHUB_USER/$repo_name.git"

    # Push
    if git push -u origin main; then
        log_success "Code gepusht zu GitHub"
        return 0
    else
        log_error "Git push fehlgeschlagen"
        exit 1
    fi
}

create_initial_release() {
    local repo_name="$1"
    local version="$2"
    local local_path="$3"

    log_info "Erstelle initialen Release: v$version"

    local repo_dir="$local_path/$repo_name"
    local script_name=$(ls "$repo_dir"/*.sh | head -1 | xargs basename)

    cd "$repo_dir"

    # Erstelle Git Tag
    git tag -a "v$version" -m "Release version $version"
    git push origin "v$version"

    # Erstelle Release
    cat > /tmp/release_notes.md <<EOF
# Initial Release v$version

Auto-migrated from Scripte Mono-Repo.

## Installation

\`\`\`bash
curl -L -o $script_name https://github.com/$GITHUB_USER/$repo_name/releases/download/v$version/$script_name
chmod +x $script_name
\`\`\`

## Features

- AutoUpdater integrated
- Automatic version checking
- Self-updating on new releases

## Usage

\`\`\`bash
./$script_name
\`\`\`
EOF

    if gh release create "v$version" \
        --title "$script_name v$version" \
        --notes-file /tmp/release_notes.md \
        "$repo_dir/$script_name"; then
        log_success "Release v$version erstellt"
        rm -f /tmp/release_notes.md
        return 0
    else
        log_error "Release-Erstellung fehlgeschlagen"
        exit 1
    fi
}

# ==========================================
# STATUS-REPORT
# ==========================================

show_status_report() {
    local repo_name="$1"
    local version="$2"
    local local_path="$3"

    local script_name=$(ls "$local_path/$repo_name"/*.sh | head -1 | xargs basename)

    echo ""
    echo "=========================================="
    echo "✅ Migration erfolgreich!"
    echo "=========================================="
    echo ""
    echo "Repository:  https://github.com/$GITHUB_USER/$repo_name"
    echo "Release:     https://github.com/$GITHUB_USER/$repo_name/releases/tag/v$version"
    echo "Local:       $local_path/$repo_name"
    echo ""
    echo "Nächste Schritte:"
    echo ""
    echo "1. Token für Internal Share setzen:"
    echo "   cd $local_path/$repo_name"
    echo "   vim $script_name"
    echo "   # Ändere: GITHUB_TOKEN=\"your_token_here\""
    echo "   cp $script_name /Volumes/ZS_Share/Scripts/$script_name"
    echo ""
    echo "2. Öffne in SublimeMerge:"
    echo "   open -a \"Sublime Merge\" $local_path/$repo_name"
    echo ""
    echo "3. Editiere Script:"
    echo "   vim $local_path/$repo_name/$script_name"
    echo "   # Ändere SCRIPT_VERSION=\"x.y.z\" für neues Feature"
    echo ""
    echo "4. Commit & Push:"
    echo "   git add $script_name"
    echo "   git commit -m \"Update: Feature X\""
    echo "   git push"
    echo ""
    echo "5. GitHub Action erstellt automatisch Release v{neue_version}!"
    echo ""
    echo "=========================================="
}

# ==========================================
# MAIN
# ==========================================

main() {
    # Parse CLI-Argumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            --script)
                SCRIPT_PATH="$2"
                shift 2
                ;;
            --repo-name)
                REPO_NAME="$2"
                shift 2
                ;;
            --local-path)
                LOCAL_PATH="$2"
                shift 2
                ;;
            --private)
                REPO_VISIBILITY="private"
                shift
                ;;
            --public)
                REPO_VISIBILITY="public"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unbekannte Option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Defaults setzen
    LOCAL_PATH="${LOCAL_PATH:-$DEFAULT_LOCAL_PATH}"
    REPO_VISIBILITY="${REPO_VISIBILITY:-private}"

    echo ""
    echo "=========================================="
    echo "  Script Migration Tool v$SCRIPT_VERSION"
    echo "=========================================="
    echo ""

    # Check dependencies
    check_dependencies

    # Interaktiver Modus wenn keine Parameter
    if [[ -z "$SCRIPT_PATH" || -z "$REPO_NAME" ]]; then
        interactive_mode
    else
        # CLI-Modus: Validiere Input
        validate_script "$SCRIPT_PATH"
    fi

    # Validate GitHub Auth
    validate_github_auth

    # Check if repo exists
    check_repo_exists "$REPO_NAME"

    # Extract Version
    VERSION=$(extract_version "$SCRIPT_PATH")
    if [[ -z "$VERSION" ]]; then
        log_error "Konnte SCRIPT_VERSION nicht extrahieren"
        exit 1
    fi
    log_info "Erkannte Version: $VERSION"

    # Expand ~ in paths
    SCRIPT_PATH="${SCRIPT_PATH/#\~/$HOME}"
    LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"

    # === MIGRATION START ===

    # 1. Create GitHub Repo
    create_github_repo "$REPO_NAME" "$REPO_VISIBILITY"

    # 2. Setup Local Repo
    setup_local_repo "$SCRIPT_PATH" "$REPO_NAME" "$LOCAL_PATH"

    # 3. Setup GitHub Action
    setup_github_action "$LOCAL_PATH" "$REPO_NAME"

    # 4. Git Init & Push
    git_init_and_push "$LOCAL_PATH" "$REPO_NAME" "$VERSION"

    # 5. Create Initial Release
    create_initial_release "$REPO_NAME" "$VERSION" "$LOCAL_PATH"

    # === MIGRATION COMPLETE ===

    # Show Status Report
    show_status_report "$REPO_NAME" "$VERSION" "$LOCAL_PATH"

    exit 0
}

# Run main
main "$@"
