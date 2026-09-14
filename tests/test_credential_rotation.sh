#!/bin/bash
# Copy-only regression: optional argument is a checkout/copy of the engine.
set -u
REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
files=(lib/auto_update_engine.sh lib/auto_update_github_only.sh lib/auto_update_direct_only.sh standalone/auto_update_standalone.sh)
for file in "${files[@]}"; do
    (
        source "$REPO_ROOT/$file"
        UPDATE_VERBOSE=0 UPDATE_BACKUP=0 UPDATE_DRY_RUN=0
        GITHUB_TOKEN=ENV_SOURCE
        passed=0 failed=0
        check() {
            if "$@"; then echo "PASS $file::$name"; passed=$((passed + 1)); else
                echo "FAIL $file::$name"
                failed=$((failed + 1))
            fi
        }
        old="$TEST_DIR/version-A.sh"
        printf '#!/bin/bash\nGITHUB_TOKEN="OLD_TOKEN"\n' > "$old"
        printf '%s\n' OLD_TOKEN > "$TEST_DIR/source"
        content=$(printf '#!/bin/bash\nGITHUB_TOKEN="" # release placeholder\nprintf "%%s" "$GITHUB_TOKEN"\n')
        # Rotate first, then actually replace the disposable A with B.
        printf '%s\n' NEW_TOKEN > "$TEST_DIR/source"
        name=rotation_A_to_B
        if _self_replace "$old" "$content" > "$TEST_DIR/replace.log" 2>&1; then
            value=$(GITHUB_TOKEN=STALE_ENV GITHUB_TOKEN_FILE="$TEST_DIR/source" bash "$old")
            check test "$value" = NEW_TOKEN
        else
            check false
        fi
        name=no_embedded_old_token
        check test "$(grep -c OLD_TOKEN "$old")" = 0
        printf '%s\n' NEXT_TOKEN > "$TEST_DIR/source"
        name=rotation_without_another_update
        value=$(GITHUB_TOKEN=STALE_ENV GITHUB_TOKEN_FILE="$TEST_DIR/source" bash "$old")
        check test "$value" = NEXT_TOKEN
        name=environment_source
        value=$(GITHUB_TOKEN=ENV_NEW GITHUB_TOKEN_FILE= bash "$old")
        check test "$value" = ENV_NEW
        name=missing_file_fails_closed
        GITHUB_TOKEN=STALE_ENV GITHUB_TOKEN_FILE="$TEST_DIR/missing" bash "$old" > "$TEST_DIR/missing.log" 2>&1
        check test "$?" -ne 0
        name=empty_file_fails_closed
        : > "$TEST_DIR/source"
        value=$(GITHUB_TOKEN=STALE_ENV GITHUB_TOKEN_FILE="$TEST_DIR/source" bash "$old" 2> "$TEST_DIR/empty.log")
        status=$?
        check test "$status" -ne 0
        name=empty_source_message
        check grep -q 'configured token source is empty' "$TEST_DIR/empty.log"
        name=empty_environment_fails_closed
        GITHUB_TOKEN= GITHUB_TOKEN_FILE= bash "$old" > /dev/null 2>&1
        check test "$?" -ne 0
        name=empty_source_aborts_update
        before=$(cat "$old")
        GITHUB_TOKEN_FILE="$TEST_DIR/source" _self_replace "$old" "$content" > /dev/null 2>&1
        check test "$?" -ne 0
        name=failed_update_preserves_installed_file
        check test "$(cat "$old")" = "$before"
        name=release_literal_uses_runtime_source
        content=$(printf '#!/bin/bash\nGITHUB_TOKEN="RELEASE_LITERAL"\nprintf "%%s" "$GITHUB_TOKEN"\n')
        _preserve_sensitive_vars "$old" "$content" > "$TEST_DIR/literal.sh"
        value=$(GITHUB_TOKEN=ENV_NEW GITHUB_TOKEN_FILE= bash "$TEST_DIR/literal.sh")
        check test "$value" = ENV_NEW
        name=dynamic_source_preserved
        content=$(printf '#!/bin/bash\nGITHUB_TOKEN=$(printf DYNAMIC_NEW)\nprintf "%%s" "$GITHUB_TOKEN"\n')
        _preserve_sensitive_vars "$old" "$content" > "$TEST_DIR/dynamic.sh"
        value=$(bash "$TEST_DIR/dynamic.sh")
        check test "$value" = DYNAMIC_NEW
        name=export_single_quote_assignment
        content=$(printf "#!/bin/bash\n  export GITHUB_TOKEN='RELEASE_LITERAL' # comment\nbash -c 'printf %%s \"\$GITHUB_TOKEN\"'\n")
        _preserve_sensitive_vars "$old" "$content" > "$TEST_DIR/export.sh"
        value=$(GITHUB_TOKEN=ENV_NEW GITHUB_TOKEN_FILE= bash "$TEST_DIR/export.sh")
        check test "$value" = ENV_NEW
        name=runtime_secret_is_data
        printf '%s\n' 'token-$(touch SHOULD_NOT_EXIST)-back\slash' > "$TEST_DIR/source"
        value=$(GITHUB_TOKEN_FILE="$TEST_DIR/source" bash "$old")
        check test "$value" = 'token-$(touch SHOULD_NOT_EXIST)-back\slash'
        echo "$file: passed=$passed failed=$failed"
        echo "$passed $failed" > "$TEST_DIR/$(basename "$file").counts"
    ) || exit 1
done
passed=0 failed=0
for counts in "$TEST_DIR"/*.counts; do
    read -r p f < "$counts"
    passed=$((passed+p)) failed=$((failed+f))
done
echo "TOTAL: $((passed+failed)), PASSED: $passed, FAILED: $failed, SKIPPED: 0"
[[ "$failed" = 0 ]]
