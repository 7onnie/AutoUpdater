#!/bin/bash
# ==========================================
# REPRODUKTIONS-TEST: Issue #1
# ==========================================
# Beweist: ein rotiertes GitHub-Credential, das ueber ein Release ausgeliefert
# wird, muss ein Update ueberleben. Vorher ueberschrieb _preserve_sensitive_vars()
# den neuen Wert bedingungslos mit dem ALTEN, installierten Wert.
#
# Szenario A (Rotation): altes Credential installiert -> Release liefert NEUES
# Credential aus -> nach dem Update-Merge muss das NEUE Credential im Ergebnis stehen.
#
# Szenario B (Zero-Touch-Regression): Release liefert KEIN Credential (leeres
# Feld, Normalfall bei jedem gewoehnlichen Feature-Update) -> das bisher
# installierte Credential darf nicht verloren gehen.
# ==========================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="/tmp/auto_update_credential_rotation_test"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

FILES=(
    "lib/auto_update_engine.sh"
    "lib/auto_update_github_only.sh"
    "lib/auto_update_direct_only.sh"
    "standalone/auto_update_standalone.sh"
)

setup_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
}

cleanup_test_env() {
    rm -rf "$TEST_DIR"
}

assert_contains() {
    local haystack="$1" needle="$2" desc="$3"
    ((TESTS_TOTAL++))
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        echo -e "  ${GREEN}✅ PASS${NC}: $desc"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ FAIL${NC}: $desc"
        echo "     erwartet enthalten: $needle"
        echo "     tatsaechlich: $(printf '%s' "$haystack" | grep '^GITHUB_TOKEN=')"
        ((TESTS_FAILED++))
    fi
}

test_rotation_survives_update() {
    local relfile="$1"
    local file="$REPO_ROOT/$relfile"

    echo ""
    echo "=========================================="
    echo "TEST: Credential-Rotation ueberlebt Update ($relfile)"
    echo "=========================================="

    if [[ ! -f "$file" ]]; then
        ((TESTS_TOTAL++))
        echo -e "  ${RED}❌ FAIL${NC}: Datei nicht gefunden: $file"
        ((TESTS_FAILED++))
        return
    fi

    (
        source "$file" 2>/dev/null

        # Zaehler in der Subshell zuruecksetzen: sonst erbt jede weitere
        # Subshell die bereits inkrementierten Werte des Elternprozesses.
        TESTS_TOTAL=0
        TESTS_PASSED=0
        TESTS_FAILED=0

        local old_script="$TEST_DIR/old_script.sh"
        printf '#!/bin/bash\nGITHUB_TOKEN="ghp_OLD_BEFORE_ROTATION"\necho "old"\n' > "$old_script"

        # Szenario A: Release liefert rotiertes (neues) Credential aus
        local new_content_rotated
        new_content_rotated=$(printf '#!/bin/bash\nGITHUB_TOKEN="ghp_NEW_AFTER_ROTATION"\necho "new"\n')

        local result_rotated
        result_rotated=$(_preserve_sensitive_vars "$old_script" "$new_content_rotated")

        assert_contains "$result_rotated" 'GITHUB_TOKEN="ghp_NEW_AFTER_ROTATION"' \
            "Rotiertes Credential aus dem Release erreicht die neue Version"

        ((TESTS_TOTAL++))
        if printf '%s' "$result_rotated" | grep -qF 'ghp_OLD_BEFORE_ROTATION'; then
            echo -e "  ${RED}❌ FAIL${NC}: Altes Credential ist noch im Ergebnis vorhanden (Rotation blockiert)"
            ((TESTS_FAILED++))
        else
            echo -e "  ${GREEN}✅ PASS${NC}: Altes Credential wurde nicht mehr eingesetzt"
            ((TESTS_PASSED++))
        fi

        # Szenario B: Release liefert leeres Credential (Normalfall) -> altes bleibt (Zero-Touch)
        local new_content_empty
        new_content_empty=$(printf '#!/bin/bash\nGITHUB_TOKEN=""\necho "new"\n')

        local result_empty
        result_empty=$(_preserve_sensitive_vars "$old_script" "$new_content_empty")

        assert_contains "$result_empty" 'GITHUB_TOKEN="ghp_OLD_BEFORE_ROTATION"' \
            "Zero-Touch: Credential bleibt erhalten, wenn Release keins liefert"

        rm -f "$old_script"

        echo "$TESTS_TOTAL $TESTS_PASSED $TESTS_FAILED" > "$TEST_DIR/counts_$(basename "$relfile").txt"
    )
}

run_all_tests() {
    echo "=========================================="
    echo "Credential-Rotation Reproduktions-Test (Issue #1)"
    echo "=========================================="
    echo "Repository: $REPO_ROOT"

    setup_test_env

    for f in "${FILES[@]}"; do
        test_rotation_survives_update "$f"
        if [[ -f "$TEST_DIR/counts_$(basename "$f").txt" ]]; then
            read -r sub_total sub_passed sub_failed < "$TEST_DIR/counts_$(basename "$f").txt"
            TESTS_TOTAL=$((TESTS_TOTAL + sub_total))
            TESTS_PASSED=$((TESTS_PASSED + sub_passed))
            TESTS_FAILED=$((TESTS_FAILED + sub_failed))
        else
            # test_rotation_survives_update lief in einer Subshell; wenn die
            # Zaehl-Datei fehlt, ist die Datei selbst nicht ladbar gewesen.
            TESTS_TOTAL=$((TESTS_TOTAL + 1))
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done

    cleanup_test_env

    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:  $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
        exit 1
    fi
}

run_all_tests
