#!/bin/bash
# ==========================================
# AUTOUPDATER - GITHUB DEPLOYMENT SCRIPT
# ==========================================
# Automatisiert das Deployment auf GitHub
# ==========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_DIR="/Users/user/ZS_Share/AutoUpdater"

echo -e "${BLUE}=========================================="
echo "AutoUpdater - GitHub Deployment"
echo "==========================================${NC}"
echo ""

# ==========================================
# SCHRITT 1: GitHub User abfragen
# ==========================================

echo -e "${YELLOW}Schritt 1: GitHub Konfiguration${NC}"
echo ""

read -p "Dein GitHub Username: " GITHUB_USER

if [[ -z "$GITHUB_USER" ]]; then
    echo -e "${RED}❌ GitHub Username erforderlich!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GitHub User: $GITHUB_USER${NC}"
echo ""

# ==========================================
# SCHRITT 2: Repository-URL
# ==========================================

REPO_NAME="AutoUpdater"
REPO_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"

echo -e "${YELLOW}Schritt 2: Repository-URL${NC}"
echo "URL: $REPO_URL"
echo ""

read -p "Ist diese URL korrekt? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "Gib die korrekte Repository-URL ein: " REPO_URL
fi

echo -e "${GREEN}✅ Repository-URL: $REPO_URL${NC}"
echo ""

# ==========================================
# SCHRITT 3: URLs aktualisieren
# ==========================================

echo -e "${YELLOW}Schritt 3: Bootstrap-URLs aktualisieren${NC}"
echo ""

if [[ "$GITHUB_USER" != "7onnie" ]]; then
    echo "Aktualisiere URLs von 7onnie auf $GITHUB_USER..."

    cd "$REPO_DIR"

    # Backup erstellen
    tar -czf "../AutoUpdater_backup_$(date +%Y%m%d_%H%M%S).tar.gz" .

    # URLs ersetzen (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find . -type f \( -name "*.sh" -o -name "*.md" \) -not -path "./.git/*" -exec sed -i '' "s/7onnie\/AutoUpdater/$GITHUB_USER\/AutoUpdater/g" {} +
    else
        # Linux
        find . -type f \( -name "*.sh" -o -name "*.md" \) -not -path "./.git/*" -exec sed -i "s/7onnie\/AutoUpdater/$GITHUB_USER\/AutoUpdater/g" {} +
    fi

    # Auch master -> main wenn nötig
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find . -type f \( -name "*.sh" -o -name "*.md" \) -not -path "./.git/*" -exec sed -i '' "s/AutoUpdater\/master/AutoUpdater\/main/g" {} +
    else
        find . -type f \( -name "*.sh" -o -name "*.md" \) -not -path "./.git/*" -exec sed -i "s/AutoUpdater\/master/AutoUpdater\/main/g" {} +
    fi

    # Commit
    git add .
    git commit -m "Update: Bootstrap URLs für $GITHUB_USER" || true

    echo -e "${GREEN}✅ URLs aktualisiert${NC}"
else
    echo -e "${GREEN}✅ URLs bereits korrekt (User ist 7onnie)${NC}"
fi

echo ""

# ==========================================
# SCHRITT 4: Remote konfigurieren
# ==========================================

echo -e "${YELLOW}Schritt 4: Git Remote konfigurieren${NC}"
echo ""

cd "$REPO_DIR"

# Prüfe ob Remote bereits existiert
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' existiert bereits:"
    git remote -v
    echo ""
    read -p "Remote überschreiben? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
        git remote add origin "$REPO_URL"
        echo -e "${GREEN}✅ Remote aktualisiert${NC}"
    else
        echo "Remote wird beibehalten"
    fi
else
    git remote add origin "$REPO_URL"
    echo -e "${GREEN}✅ Remote hinzugefügt${NC}"
fi

echo ""

# ==========================================
# SCHRITT 5: Branch vorbereiten
# ==========================================

echo -e "${YELLOW}Schritt 5: Branch vorbereiten${NC}"
echo ""

CURRENT_BRANCH=$(git branch --show-current)

if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "Aktueller Branch: $CURRENT_BRANCH"
    echo "Benenne um zu 'main'..."
    git branch -M main
    echo -e "${GREEN}✅ Branch umbenannt zu main${NC}"
else
    echo -e "${GREEN}✅ Branch ist bereits main${NC}"
fi

echo ""

# ==========================================
# SCHRITT 6: GitHub Repository erstellen
# ==========================================

echo -e "${YELLOW}Schritt 6: GitHub Repository${NC}"
echo ""
echo "Bitte erstelle jetzt das Repository auf GitHub:"
echo ""
echo -e "${BLUE}1. Gehe zu: https://github.com/new${NC}"
echo -e "${BLUE}2. Repository name: ${GREEN}AutoUpdater${NC}"
echo -e "${BLUE}3. Description: ${GREEN}Universelle Auto-Update-Engine für Shell-Scripts${NC}"
echo -e "${BLUE}4. Visibility: ${GREEN}Public${NC}"
echo -e "${BLUE}5. DO NOT initialize with README/gitignore/license${NC}"
echo -e "${BLUE}6. Klicke 'Create repository'${NC}"
echo ""

read -p "Drücke Enter wenn Repository erstellt wurde..." -r
echo ""

# ==========================================
# SCHRITT 7: Pushen
# ==========================================

echo -e "${YELLOW}Schritt 7: Code zu GitHub pushen${NC}"
echo ""

echo "Pushe zu $REPO_URL..."

if git push -u origin main; then
    echo -e "${GREEN}✅ Code erfolgreich gepusht!${NC}"
else
    echo -e "${RED}❌ Push fehlgeschlagen!${NC}"
    echo ""
    echo "Mögliche Lösungen:"
    echo "1. SSH statt HTTPS verwenden:"
    echo "   git remote set-url origin git@github.com:$GITHUB_USER/$REPO_NAME.git"
    echo "   git push -u origin main"
    echo ""
    echo "2. Token generieren und verwenden:"
    echo "   https://github.com/settings/tokens"
    exit 1
fi

echo ""

# ==========================================
# SCHRITT 8: Tag und Release
# ==========================================

echo -e "${YELLOW}Schritt 8: Release erstellen${NC}"
echo ""

# Tag erstellen
if ! git tag | grep -q "v1.0.0"; then
    git tag -a v1.0.0 -m "Initial release: AutoUpdater v1.0.0"
    echo -e "${GREEN}✅ Tag v1.0.0 erstellt${NC}"
fi

# Tag pushen
if git push origin v1.0.0; then
    echo -e "${GREEN}✅ Tag gepusht${NC}"
else
    echo -e "${YELLOW}⚠️  Tag konnte nicht gepusht werden (evtl. existiert bereits)${NC}"
fi

echo ""

# ==========================================
# SCHRITT 9: Release-Anleitung
# ==========================================

echo -e "${YELLOW}Schritt 9: GitHub Release${NC}"
echo ""

# Prüfe ob gh CLI verfügbar
if command -v gh &> /dev/null; then
    echo "GitHub CLI gefunden! Soll ich automatisch ein Release erstellen?"
    read -p "Release mit gh CLI erstellen? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh release create v1.0.0 \
            --title "AutoUpdater v1.0.0" \
            --notes "Initial release: Universelle Auto-Update-Engine für Shell-Scripts" \
            lib/auto_update_engine.sh \
            lib/auto_update_github_only.sh \
            lib/auto_update_git_only.sh \
            lib/auto_update_direct_only.sh \
            bootstrap/bootstrap_minimal.sh \
            bootstrap/bootstrap_with_fallback.sh \
            standalone/auto_update_standalone.sh

        echo -e "${GREEN}✅ Release erstellt!${NC}"
    fi
else
    echo "Erstelle Release manuell:"
    echo ""
    echo -e "${BLUE}1. Gehe zu: https://github.com/$GITHUB_USER/$REPO_NAME/releases/new${NC}"
    echo -e "${BLUE}2. Tag: ${GREEN}v1.0.0${NC}"
    echo -e "${BLUE}3. Title: ${GREEN}AutoUpdater v1.0.0${NC}"
    echo -e "${BLUE}4. Description: ${GREEN}Initial release${NC}"
    echo -e "${BLUE}5. Lade Assets hoch:${NC}"
    echo "   - lib/auto_update_engine.sh"
    echo "   - lib/auto_update_github_only.sh"
    echo "   - lib/auto_update_git_only.sh"
    echo "   - lib/auto_update_direct_only.sh"
    echo "   - bootstrap/bootstrap_minimal.sh"
    echo "   - bootstrap/bootstrap_with_fallback.sh"
    echo "   - standalone/auto_update_standalone.sh"
    echo -e "${BLUE}6. Klicke 'Publish release'${NC}"
    echo ""
fi

echo ""

# ==========================================
# SCHRITT 10: Verifizierung
# ==========================================

echo -e "${YELLOW}Schritt 10: Verifizierung${NC}"
echo ""

echo "Prüfe Repository..."

# Repository erreichbar
if curl -s -o /dev/null -w "%{http_code}" "https://github.com/$GITHUB_USER/$REPO_NAME" | grep -q "200"; then
    echo -e "${GREEN}✅ Repository erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️  Repository noch nicht öffentlich erreichbar (kann einige Sekunden dauern)${NC}"
fi

# Raw URL erreichbar
sleep 2
if curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/lib/auto_update_engine.sh" | grep -q "200"; then
    echo -e "${GREEN}✅ Engine-URL erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️  Engine-URL noch nicht erreichbar (kann einige Sekunden dauern)${NC}"
fi

echo ""

# ==========================================
# FERTIG!
# ==========================================

echo -e "${GREEN}=========================================="
echo "✅ Deployment erfolgreich abgeschlossen!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Repository:${NC} https://github.com/$GITHUB_USER/$REPO_NAME"
echo -e "${BLUE}Raw URLs:${NC}"
echo "  Engine:    https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/lib/auto_update_engine.sh"
echo "  Bootstrap: https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/bootstrap/bootstrap_minimal.sh"
echo ""
echo -e "${BLUE}Nächste Schritte:${NC}"
echo "1. Aktiviere GitHub Actions (sollte automatisch sein)"
echo "2. Füge Topics hinzu: shell, bash, auto-update, deployment"
echo "3. Teste mit einem eigenen Script (siehe docs/SETUP.md)"
echo ""
echo -e "${GREEN}Happy Auto-Updating! 🚀${NC}"
