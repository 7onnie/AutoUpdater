#!/bin/bash
# Test: Git-Modus Neustart mit relativem Skriptpfad (Issue #10).
# Szenario: Skript liegt in <repo>/sub/skript.sh, wird als "./skript.sh" bzw.
# "../sub/skript.sh" aus einem anderen Arbeitsverzeichnis gestartet. Die Engine
# macht im Git-Modus ein cd ins Repo-Root und startet nach dem Pull per exec neu.
# Erwartung: Neustart gelingt (2. START-Zeile) und $0 ist ein absoluter Pfad.
# Pro Variante wird die Engine aus VARIANTS getestet.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARIANTS="${RP_VARIANTS:-lib/auto_update_engine.sh lib/auto_update_git_only.sh}"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

FAILS=0
BASE="$(cd "${TMPDIR:-/tmp}" && pwd -P)/au_relpath_test_$$"

echo "bash: $BASH_VERSION"

run_case() {
    # run_case <engine-relpfad> <label> <start-cwd-relativ-zu-BASE> <aufrufpfad>
    local engine="$1" label="$2" startdir="$3" callpath="$4"
    local W="$BASE/$(echo "$engine$label" | tr '/.' '__')"
    local LOG="$W/log.txt"
    mkdir -p "$W"
    git init -q --bare "$W/origin.git"
    git -C "$W/origin.git" symbolic-ref HEAD refs/heads/main
    git init -q "$W/repo"
    git -C "$W/repo" symbolic-ref HEAD refs/heads/main
    git -C "$W/repo" config pull.rebase false
    mkdir -p "$W/repo/sub"
    local fn="_auto_update_main git_pull \"\$@\""
    [[ "$engine" == *git_only* ]] && fn="auto_update_git \"\$@\""
    {
        echo '#!/bin/bash'
        echo "source \"$REPO_ROOT/$engine\""
        echo "echo \"START:\$0:\$*\" >> \"$LOG\""
        echo "UPDATE_GIT_BRANCH=main"
        echo "$fn"
    } > "$W/repo/sub/skript.sh"
    chmod +x "$W/repo/sub/skript.sh"
    echo 1 > "$W/repo/data.txt"
    git -C "$W/repo" add -A
    git -C "$W/repo" commit -q -m v1
    git -C "$W/repo" remote add origin "$W/origin.git"
    git -C "$W/repo" push -q origin main
    # zweiter Klon schiebt ein Update
    git clone -q "$W/origin.git" "$W/other"
    echo 2 > "$W/other/data.txt"
    git -C "$W/other" commit -q -am v2
    git -C "$W/other" push -q origin main

    # tiefer Fremd-cwd, damit der relative Pfad nach dem cd ins Repo nicht
    # zufaellig wieder trifft
    mkdir -p "$W/elsewhere/deep"
    local cwd
    case "$startdir" in
        sub) cwd="$W/repo/sub" ;;
        *)   cwd="$W/elsewhere/deep" ;;
    esac
    # aufrufpfad relativ zu cwd
    local p="$callpath"
    [[ "$callpath" == "REL_FROM_ELSEWHERE" ]] && p="../../repo/sub/skript.sh"
    (cd "$cwd" && "$p" a1 "b 2" >"$W/out.txt" 2>&1)
    local rc=$?

    local starts second
    starts=$(grep -c '^START:' "$LOG" 2>/dev/null)
    second=$(grep '^START:' "$LOG" 2>/dev/null | sed -n '2p')
    local ok=1
    [[ $rc -eq 0 ]] || ok=0
    [[ "$starts" == "2" ]] || ok=0
    case "$second" in
        START:/*/../*|START:/*/./*) ok=0 ;;   # kein ../ oder ./ im Pfad
        START:/*"/skript.sh:a1 b 2") ;;
        *) ok=0 ;;
    esac
    if [[ $ok -eq 1 ]]; then
        echo "  PASS  [$engine] $label ('$callpath'): Neustart-Pfad absolut: $second"
    else
        echo "  FAIL  [$engine] $label ('$callpath'): rc=$rc starts=$starts zweiter Start='$second'"
        sed 's/^/        | /' "$W/out.txt"
        FAILS=$((FAILS + 1))
    fi
}

for engine in $VARIANTS; do
    run_case "$engine" "relativ ./skript.sh" sub "./skript.sh"
    run_case "$engine" "relativ ../repo/sub/skript.sh aus anderem cwd" else "REL_FROM_ELSEWHERE"
done

rm -rf "$BASE"
echo "=========================================="
if [[ $FAILS -eq 0 ]]; then
    echo "test_relpath_restart: ALLE GRUEN"
    exit 0
fi
echo "test_relpath_restart: $FAILS Fall/Faelle fehlgeschlagen"
exit 1
