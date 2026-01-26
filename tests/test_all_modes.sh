#!/bin/bash
# ==========================================
# AUTO-UPDATE ENGINE - TEST SUITE
# ==========================================
# Testet alle Update-Modi und Funktionen
# ==========================================

set -e

# Test-Konfiguration
TEST_DIR="/tmp/auto_update_tests"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_PATH="$REPO_ROOT/lib/auto_update_engine.sh"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zähler
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==========================================
# HELPER FUNKTIONEN
# ==========================================

log_test() {
    echo ""
    echo "=========================================="
    echo "TEST: $1"
    echo "=========================================="
}

log_success() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}ℹ️ ${NC} $1"
}

setup_test_env() {
    log_info "Setup: Erstelle Test-Umgebung"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
}

cleanup_test_env() {
    log_info "Cleanup: Entferne Test-Umgebung"
    rm -rf "$TEST_DIR"
}

# ==========================================
# UNIT TESTS
# ==========================================

test_engine_exists() {
    ((TESTS_TOTAL++))
    log_test "Engine existiert"

    if [[ -f "$ENGINE_PATH" ]]; then
        log_success "Engine gefunden: $ENGINE_PATH"
    else
        log_failure "Engine nicht gefunden: $ENGINE_PATH"
    fi
}

test_engine_syntax() {
    ((TESTS_TOTAL++))
    log_test "Engine Syntax-Check"

    if bash -n "$ENGINE_PATH"; then
        log_success "Engine Syntax ist korrekt"
    else
        log_failure "Engine Syntax-Fehler"
    fi
}

test_engine_sourcing() {
    ((TESTS_TOTAL++))
    log_test "Engine kann gesourced werden"

    if source "$ENGINE_PATH" 2>/dev/null; then
        log_success "Engine erfolgreich gesourced"
    else
        log_failure "Engine konnte nicht gesourced werden"
    fi
}

test_utility_functions() {
    ((TESTS_TOTAL++))
    log_test "Utility-Funktionen vorhanden"

    source "$ENGINE_PATH"

    local functions=("_log" "_compare_versions" "_backup_script" "_self_replace" "_check_dependencies")
    local missing=0

    for func in "${functions[@]}"; do
        if declare -f "$func" > /dev/null; then
            echo "  ✅ $func existiert"
        else
            echo "  ❌ $func fehlt"
            ((missing++))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_success "Alle Utility-Funktionen vorhanden"
    else
        log_failure "$missing Utility-Funktionen fehlen"
    fi
}

test_version_comparison() {
    ((TESTS_TOTAL++))
    log_test "Versions-Vergleich"

    source "$ENGINE_PATH"

    # Test 1: Gleiche Version
    _compare_versions "1.0.0" "1.0.0"
    if [[ $? -eq 0 ]]; then
        echo "  ✅ 1.0.0 == 1.0.0"
    else
        echo "  ❌ 1.0.0 == 1.0.0 failed"
        log_failure "Versions-Vergleich fehlgeschlagen"
        return
    fi

    # Test 2: Update verfügbar
    _compare_versions "1.0.0" "1.1.0"
    if [[ $? -eq 1 ]]; then
        echo "  ✅ 1.0.0 < 1.1.0"
    else
        echo "  ❌ 1.0.0 < 1.1.0 failed"
        log_failure "Versions-Vergleich fehlgeschlagen"
        return
    fi

    # Test 3: Lokale Version neuer
    _compare_versions "2.0.0" "1.0.0"
    if [[ $? -eq 2 ]]; then
        echo "  ✅ 2.0.0 > 1.0.0"
    else
        echo "  ❌ 2.0.0 > 1.0.0 failed"
        log_failure "Versions-Vergleich fehlgeschlagen"
        return
    fi

    log_success "Versions-Vergleich funktioniert"
}

test_cache_handling() {
    ((TESTS_TOTAL++))
    log_test "Cache-Handling"

    source "$ENGINE_PATH"

    local cache_file="$TEST_DIR/test.cache"
    echo "test content" > "$cache_file"

    # Cache sollte gültig sein (gerade erstellt)
    if _is_cache_valid "$cache_file"; then
        log_success "Cache-Validierung funktioniert"
    else
        log_failure "Cache sollte gültig sein"
    fi

    # Nicht-existente Datei sollte invalid sein
    if ! _is_cache_valid "$TEST_DIR/nonexistent.cache"; then
        echo "  ✅ Nicht-existente Datei ist invalid"
    else
        echo "  ❌ Nicht-existente Datei sollte invalid sein"
        log_failure "Cache-Handling fehlerhaft"
        return
    fi

    log_success "Cache-Handling funktioniert"
}

test_backup_script() {
    ((TESTS_TOTAL++))
    log_test "Script-Backup"

    source "$ENGINE_PATH"

    # Test-Script erstellen
    local test_script="$TEST_DIR/test_backup.sh"
    echo "#!/bin/bash" > "$test_script"
    echo "echo 'test'" >> "$test_script"

    UPDATE_BACKUP=1
    local backup_path
    backup_path=$(_backup_script "$test_script")

    if [[ -f "$backup_path" ]]; then
        log_success "Backup erstellt: $backup_path"
    else
        log_failure "Backup nicht erstellt"
    fi

    # Cleanup
    rm -f "$test_script" "$backup_path"
}

test_dependencies_check() {
    ((TESTS_TOTAL++))
    log_test "Dependency-Check"

    source "$ENGINE_PATH"

    # Test mit vorhandener Dependency
    if _check_dependencies bash; then
        echo "  ✅ bash gefunden"
    else
        echo "  ❌ bash sollte vorhanden sein"
        log_failure "Dependency-Check fehlgeschlagen"
        return
    fi

    # Test mit nicht-vorhandener Dependency
    if ! _check_dependencies nonexistent_tool_xyz; then
        echo "  ✅ Nicht-vorhandenes Tool erkannt"
        log_success "Dependency-Check funktioniert"
    else
        echo "  ❌ Nicht-vorhandenes Tool sollte fehlen"
        log_failure "Dependency-Check fehlgeschlagen"
    fi
}

# ==========================================
# INTEGRATION TESTS
# ==========================================

test_dry_run_mode() {
    ((TESTS_TOTAL++))
    log_test "Dry-Run Modus"

    source "$ENGINE_PATH"

    UPDATE_DRY_RUN=1
    UPDATE_MODE="disabled"

    if _auto_update_main "disabled"; then
        log_success "Dry-Run Modus funktioniert"
    else
        log_failure "Dry-Run Modus fehlgeschlagen"
    fi

    UPDATE_DRY_RUN=0
}

test_disabled_mode() {
    ((TESTS_TOTAL++))
    log_test "Disabled Modus"

    source "$ENGINE_PATH"

    if _auto_update_main "disabled"; then
        log_success "Disabled Modus funktioniert"
    else
        log_failure "Disabled Modus fehlgeschlagen"
    fi
}

test_invalid_mode() {
    ((TESTS_TOTAL++))
    log_test "Ungültiger Modus"

    source "$ENGINE_PATH"

    if ! _auto_update_main "invalid_mode_xyz" 2>/dev/null; then
        log_success "Ungültiger Modus wird korrekt abgelehnt"
    else
        log_failure "Ungültiger Modus sollte fehlschlagen"
    fi
}

# ==========================================
# BEISPIEL-TESTS
# ==========================================

test_examples_syntax() {
    ((TESTS_TOTAL++))
    log_test "Beispiel-Scripts Syntax"

    local examples_dir="$REPO_ROOT/examples"
    local errors=0

    for example in "$examples_dir"/*.sh; do
        if bash -n "$example" 2>/dev/null; then
            echo "  ✅ $(basename "$example")"
        else
            echo "  ❌ $(basename "$example") hat Syntax-Fehler"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Alle Beispiele haben korrekte Syntax"
    else
        log_failure "$errors Beispiele haben Syntax-Fehler"
    fi
}

test_bootstrap_syntax() {
    ((TESTS_TOTAL++))
    log_test "Bootstrap-Scripts Syntax"

    local bootstrap_dir="$REPO_ROOT/bootstrap"
    local errors=0

    for bootstrap in "$bootstrap_dir"/*.sh; do
        if bash -n "$bootstrap" 2>/dev/null; then
            echo "  ✅ $(basename "$bootstrap")"
        else
            echo "  ❌ $(basename "$bootstrap") hat Syntax-Fehler"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Alle Bootstrap-Scripts haben korrekte Syntax"
    else
        log_failure "$errors Bootstrap-Scripts haben Syntax-Fehler"
    fi
}

test_standalone_syntax() {
    ((TESTS_TOTAL++))
    log_test "Standalone-Script Syntax"

    local standalone="$REPO_ROOT/standalone/auto_update_standalone.sh"

    if bash -n "$standalone" 2>/dev/null; then
        log_success "Standalone-Script hat korrekte Syntax"
    else
        log_failure "Standalone-Script hat Syntax-Fehler"
    fi
}

test_lib_syntax() {
    ((TESTS_TOTAL++))
    log_test "Lib-Module Syntax"

    local lib_dir="$REPO_ROOT/lib"
    local errors=0

    for lib in "$lib_dir"/*.sh; do
        if bash -n "$lib" 2>/dev/null; then
            echo "  ✅ $(basename "$lib")"
        else
            echo "  ❌ $(basename "$lib") hat Syntax-Fehler"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Alle Lib-Module haben korrekte Syntax"
    else
        log_failure "$errors Lib-Module haben Syntax-Fehler"
    fi
}

# ==========================================
# MAIN TEST RUNNER
# ==========================================

run_all_tests() {
    echo "=========================================="
    echo "AutoUpdater Test Suite"
    echo "=========================================="
    echo "Repository: $REPO_ROOT"
    echo ""

    setup_test_env

    # Unit Tests
    echo ""
    echo "--- Unit Tests ---"
    test_engine_exists
    test_engine_syntax
    test_engine_sourcing
    test_utility_functions
    test_version_comparison
    test_cache_handling
    test_backup_script
    test_dependencies_check

    # Integration Tests
    echo ""
    echo "--- Integration Tests ---"
    test_dry_run_mode
    test_disabled_mode
    test_invalid_mode

    # Syntax Tests
    echo ""
    echo "--- Syntax Tests ---"
    test_examples_syntax
    test_bootstrap_syntax
    test_standalone_syntax
    test_lib_syntax

    cleanup_test_env

    # Summary
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

# Run tests
run_all_tests
