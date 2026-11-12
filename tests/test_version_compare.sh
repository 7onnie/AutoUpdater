#!/bin/bash
# Test: _compare_versions (Issue #11) — feldweise numerischer Versionsvergleich.
# Rueckgabe: 0 = gleich, 1 = Update (Remote neuer), 2 = lokal neuer, 3 = unlesbar (kein Update).
# Prueft die Engine und alle Kopien. Exit 0 = alles gruen.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILES="${VC_FILES:-lib/auto_update_engine.sh standalone/auto_update_standalone.sh lib/auto_update_direct_only.sh lib/auto_update_github_only.sh}"

FAILS=0
TOTAL=0

check() {
    # check <erwarteter Code> <current> <remote>
    local want="$1" cur="$2" rem="$3" got
    TOTAL=$((TOTAL + 1))
    _compare_versions "$cur" "$rem" 2>/dev/null
    got=$?
    if [[ $got -eq $want ]]; then
        echo "  PASS  '$cur' vs '$rem' -> $got"
    else
        echo "  FAIL  '$cur' vs '$rem' -> $got (erwartet $want)"
        FAILS=$((FAILS + 1))
    fi
}

check_loud() {
    # Unlesbare Version: Code 3 UND Meldung auf stderr
    local cur="$1" rem="$2" err got
    TOTAL=$((TOTAL + 1))
    err=$(_compare_versions "$cur" "$rem" 2>&1 >/dev/null)
    got=$?
    _compare_versions "$cur" "$rem" >/dev/null 2>&1
    got=$?
    if [[ $got -eq 3 && -n "$err" ]]; then
        echo "  PASS  unlesbar '$cur' vs '$rem' -> 3 + stderr"
    else
        echo "  FAIL  unlesbar '$cur' vs '$rem' -> $got, stderr='${err}'"
        FAILS=$((FAILS + 1))
    fi
}

for f in $FILES; do
    echo "== $f (bash $BASH_VERSION)"
    # frischer Subshell-Scope pro Datei
    (
        # shellcheck disable=SC1090
        source "$REPO_ROOT/$f" || exit 99
        FAILS=0
        TOTAL=0
        check 1 "1.9.0" "1.10.0"
        check 2 "1.10.0" "1.9.0"
        check 0 "2.0" "2.0.0"
        check 0 "2.0.0" "2.0"
        check 1 "v1.2.3" "1.2.4"
        check 1 "v1.2.3" "v1.2.4"
        check 2 "001.004.000" "001.003.009"
        check 0 "1.0.0" "1.0.0"
        check 1 "1.0.0" "1.0.1"
        check 1 "2.0" "2.0.1"
        check 2 "2.1" "2.0.9"
        check 1 "9.9.9" "10.0.0"
        # unlesbar -> Code 3 (kein Update) und laut
        check_loud "" "1.0.0"
        check_loud "1.0.0" ""
        check_loud "unknown" "1.0.0"
        check_loud "1.0.0" "abc"
        check_loud "1..2" "1.0.0"
        check_loud "1.0.0" "1.2.x"
        check_loud "1.0.0" "1.0.0-beta"
        echo "  -> $((TOTAL - FAILS))/$TOTAL gruen"
        exit "$FAILS"
    )
    rc=$?
    if [[ $rc -ne 0 ]]; then
        FAILS=$((FAILS + 1))
        echo "  Datei $f: rc=$rc"
    fi
done

echo "=========================================="
if [[ $FAILS -eq 0 ]]; then
    echo "test_version_compare: ALLE GRUEN"
    exit 0
fi
echo "test_version_compare: $FAILS Datei(en) mit Fehlern"
exit 1
