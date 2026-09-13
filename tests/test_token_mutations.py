#!/usr/bin/env python3
"""Run three token-path mutants only in temporary copies (no dependencies)."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
files = ["lib/auto_update_engine.sh", "lib/auto_update_github_only.sh",
         "lib/auto_update_direct_only.sh", "standalone/auto_update_standalone.sh"]
mutants = [
    ("frozen_file_token", 'cat -- "$GITHUB_TOKEN_FILE"', 'printf OLD_TOKEN',
     "rotation_A_to_B"),
    ("inverted_file_selection", '[[ -n "${GITHUB_TOKEN_FILE:-}" ]]',
     '[[ -z "${GITHUB_TOKEN_FILE:-}" ]]', "rotation_A_to_B"),
    ("frozen_environment_token", 'else\n    GITHUB_TOKEN="${GITHUB_TOKEN:-}"',
     'else\n    GITHUB_TOKEN="OLD_TOKEN"', "environment_source"),
]
for name, before, after, catcher in mutants:
    with tempfile.TemporaryDirectory(prefix="autoupdater-mutant-") as directory:
        copy = Path(directory)
        for file in files:
            target = copy / file
            target.parent.mkdir(parents=True, exist_ok=True)
            content = (root / file).read_text()
            assert content.count(before) == 1, (file, before)
            target.write_text(content.replace(before, after))
        result = subprocess.run([str(root / "tests/test_credential_rotation.sh"), str(copy)],
                                text=True, capture_output=True)
        print(f"MUTANT {name}: exit={result.returncode}")
        for line in result.stdout.splitlines():
            if f"::{catcher}" in line or line.startswith("TOTAL:"):
                print(line)
        assert result.returncode == 1, result.stdout + result.stderr
        for file in files:
            assert f"FAIL {file}::{catcher}" in result.stdout, result.stdout
print("MUTANTS: 3 caught, 0 survived")
print("RESTORED: testing unchanged working tree", flush=True)
subprocess.run([str(root / "tests/test_credential_rotation.sh")], check=True)
