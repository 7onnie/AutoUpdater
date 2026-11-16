#!/bin/bash
# Test: Git-Modus laesst das Arbeitsverzeichnis des Aufrufers unveraendert (Issue #10, Teil 2).
# Vorher wechselte die Pull-Funktion per `cd "$repo_path"` ins Repo-Root und kehrte nie
# zurueck: nach `auto_update` lief das aufrufende Skript in einem fremden Verzeichnis
# weiter — auch wenn gar kein Update noetig war. Relative Pfade danach zeigten ins Leere.
# Geprueft je Variante (Engine, git_only, standalone) und je Ausgang:
#   aktuell      — kein Update verfuegbar (return 0)
#   lokal        — Update verfuegbar, lokale Aenderungen => Abbruch (return 1)
#   fetchfehler  — origin nicht erreichbar (return 1)
#   dryrun       — Update verfuegbar, UPDATE_DRY_RUN=1 (return 0)
#   neustart     — echtes Update; der neu gestartete Prozess startet im Aufrufer-cwd
# Erwartung: die CWD-Zeile nach dem Aufruf (bzw. im Neustart) ist das Start-Verzeichnis.

_RepoRoot="$(cd "$(dirname "$0")/.." && pwd)"
_Variants="${CWD_VARIANTS:-lib/auto_update_engine.sh lib/auto_update_git_only.sh standalone/auto_update_standalone.sh}"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

_Fails=0
_Base="$(cd "${TMPDIR:-/tmp}" && pwd -P)/au_cwd_test_$$"

_RunCase() {
    # _RunCase <engine-relpfad> <ausgang>
    local _Engine="$1"
    local _Case="$2"
    local _W="$_Base/$(echo "$_Engine$_Case" | tr '/.' '__')"
    local _Log="$_W/log.txt"
    mkdir -p "$_W"
    git init -q --bare "$_W/origin.git"
    git -C "$_W/origin.git" symbolic-ref HEAD refs/heads/main
    git init -q "$_W/repo"
    git -C "$_W/repo" symbolic-ref HEAD refs/heads/main
    git -C "$_W/repo" config pull.rebase false
    mkdir -p "$_W/repo/sub"

    local _Fn="_auto_update_main git_pull \"\$@\""
    if [[ "$_Engine" == *git_only* ]]; then
        _Fn="auto_update_git \"\$@\""
    elif [[ "$_Engine" == standalone/* ]]; then
        _Fn="_update_git_pull \"\$@\""
    fi
    {
        echo '#!/bin/bash'
        echo "source \"$_RepoRoot/$_Engine\""
        echo "echo \"START:\$PWD\" >> \"$_Log\""
        echo "UPDATE_GIT_BRANCH=main"
        echo "$_Fn"
        echo "echo \"RC:\$?\" >> \"$_Log\""
        echo "echo \"CWD:\$PWD\" >> \"$_Log\""
    } > "$_W/repo/sub/skript.sh"
    chmod +x "$_W/repo/sub/skript.sh"
    echo 1 > "$_W/repo/data.txt"
    git -C "$_W/repo" add -A
    git -C "$_W/repo" commit -q -m v1
    git -C "$_W/repo" remote add origin "$_W/origin.git"
    git -C "$_W/repo" push -q origin main

    if [[ "$_Case" != "aktuell" && "$_Case" != "fetchfehler" ]]; then
        git clone -q "$_W/origin.git" "$_W/other"
        echo 2 > "$_W/other/data.txt"
        git -C "$_W/other" commit -q -am v2
        git -C "$_W/other" push -q origin main
    fi
    if [[ "$_Case" == "lokal" ]]; then
        echo lokal > "$_W/repo/data.txt"
    fi
    if [[ "$_Case" == "fetchfehler" ]]; then
        git -C "$_W/repo" remote set-url origin "$_W/gibt-es-nicht.git"
    fi

    local _Start="$_W/elsewhere/deep"
    mkdir -p "$_Start"
    local _DryRun=""
    if [[ "$_Case" == "dryrun" ]]; then
        _DryRun=1
    fi
    (cd "$_Start" && UPDATE_DRY_RUN="$_DryRun" "$_W/repo/sub/skript.sh" >"$_W/out.txt" 2>&1)

    local _Want="CWD:$_Start"
    local _Got
    _Got=$(grep '^CWD:' "$_Log" 2>/dev/null | tail -1)
    local _Ok=1
    if [[ "$_Got" != "$_Want" ]]; then
        _Ok=0
    fi
    if [[ "$_Case" == "neustart" ]]; then
        # Der Neustart muss ebenfalls im Aufrufer-cwd beginnen (2. START-Zeile).
        local _Second
        _Second=$(grep '^START:' "$_Log" 2>/dev/null | sed -n '2p')
        if [[ "$_Second" != "START:$_Start" ]]; then
            _Ok=0
            _Got="$_Got / zweiter Start='$_Second'"
        fi
    fi
    if [[ $_Ok -eq 1 ]]; then
        echo "  PASS  [$_Engine] $_Case: $_Got"
    else
        echo "  FAIL  [$_Engine] $_Case: erwartet '$_Want', erhalten '$_Got'"
        sed 's/^/        | /' "$_Log" "$_W/out.txt"
        _Fails=$((_Fails + 1))
    fi
}

for _Engine in $_Variants; do
    for _Case in aktuell lokal fetchfehler dryrun neustart; do
        _RunCase "$_Engine" "$_Case"
    done
done

rm -rf "$_Base"
echo "=========================================="
if [[ $_Fails -eq 0 ]]; then
    echo "test_cwd_preserved: ALLE GRUEN"
    exit 0
fi
echo "test_cwd_preserved: $_Fails Fall/Faelle fehlgeschlagen"
exit 1
