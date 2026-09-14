#!/usr/bin/env python3
"""Run three token-path mutants only in temporary copies (no dependencies)."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
files = ["lib/auto_update_engine.sh", "lib/auto_update_github_only.sh",
         "lib/auto_update_direct_only.sh", "standalone/auto_update_standalone.sh"]
mutants = [
    ("skip_update_empty_guard", 'if [[ -z "$source_token" ]]; then',
     'if false; then', "empty_source_aborts_update"),
    ("skip_runtime_empty_guard", 'if [[ -z "$GITHUB_TOKEN" ]]; then',
     'if false; then', "empty_file_fails_closed"),
    ("ignore_migration_failure", 'new_content=$(_preserve_sensitive_vars "$script_path" "$new_content") || return 1',
     'new_content=$(_preserve_sensitive_vars "$script_path" "$new_content")',
     "empty_source_aborts_update"),
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
    restored = subprocess.run([str(root / "tests/test_credential_rotation.sh")], text=True, capture_output=True)
    print(f"RESTORED {name}: exit={restored.returncode}")
    for line in restored.stdout.splitlines():
        if f"::{catcher}" in line or line.startswith("TOTAL:"):
            print(line)
    assert restored.returncode == 0, restored.stdout + restored.stderr
print("MUTANTS: 3 caught, 0 survived")
print("RESTORED: testing unchanged working tree", flush=True)
subprocess.run([str(root / "tests/test_credential_rotation.sh")], check=True)
