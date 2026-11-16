#!/bin/sh
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$DIR/tests/test_all_modes.sh"
"$DIR/tests/test_credential_rotation.sh"
bash "$DIR/tests/test_version_compare.sh"
bash "$DIR/tests/test_relpath_restart.sh"
bash "$DIR/tests/test_cwd_preserved.sh"
bash "$DIR/tests/test_standalone_args.sh"
