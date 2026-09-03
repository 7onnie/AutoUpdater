#!/bin/sh
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$DIR/tests/test_all_modes.sh"
"$DIR/tests/test_credential_rotation.sh"
