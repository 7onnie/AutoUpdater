#!/bin/bash
# Test: standalone startet nach einem Update MIT den Skript-Argumenten neu (Issue #13).
# Vorher rief `auto_update` die Modus-Funktionen ohne Argumente auf; deren
# `exec ... "$@"` sah die leeren Funktionsargumente, der Neustart lief ohne Argumente.
# Dynamisch geprueft im git_pull-Modus (echtes Update gegen ein lokales origin):
#   mitargs  — Start mit `a1 "b 2"` => zweiter Start bekommt genau `a1|b 2`
#   ohneargs — Start ohne Argumente unter `set -u` => Neustart laeuft fehlerfrei
# Statisch fuer github_release/direct_download: kein `exec` mit nacktem "$@" mehr.

_RepoRoot="$(cd "$(dirname "$0")/.." && pwd)"
_Standalone="$_RepoRoot/standalone/auto_update_standalone.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

_Fails=0
_Base="$(cd "${TMPDIR:-/tmp}" && pwd -P)/au_sa_args_$$"

_RunCase() {
    # _RunCase <label> <set-u 0|1> <args...>
    local _Label="$1"
    local _SetU="$2"
    shift 2
    local _W="$_Base/$_Label"
    local _Log="$_W/log.txt"
    mkdir -p "$_W"
    git init -q --bare "$_W/origin.git"
    git -C "$_W/origin.git" symbolic-ref HEAD refs/heads/main
    git init -q "$_W/repo"
    git -C "$_W/repo" symbolic-ref HEAD refs/heads/main
    git -C "$_W/repo" config pull.rebase false
    {
        echo '#!/bin/bash'
        if [[ "$_SetU" == "1" ]]; then
            echo 'set -u'
        fi
        echo "source \"$_Standalone\""
        echo "_Joined=\$(IFS='|'; echo \"\$*\")"
        echo "echo \"START:\$#:\$_Joined\" >> \"$_Log\""
        echo "UPDATE_MODE=git_pull"
        echo "UPDATE_GIT_BRANCH=main"
        echo 'auto_update "$@"'
        echo "echo \"RC:\$?\" >> \"$_Log\""
    } > "$_W/repo/skript.sh"
    chmod +x "$_W/repo/skript.sh"
    echo 1 > "$_W/repo/data.txt"
    git -C "$_W/repo" add -A
    git -C "$_W/repo" commit -q -m v1
    git -C "$_W/repo" remote add origin "$_W/origin.git"
    git -C "$_W/repo" push -q origin main
    git clone -q "$_W/origin.git" "$_W/other"
    echo 2 > "$_W/other/data.txt"
    git -C "$_W/other" commit -q -am v2
    git -C "$_W/other" push -q origin main

    "$_W/repo/skript.sh" "$@" >"$_W/out.txt" 2>&1
    local _Rc=$?

    local _Joined
    _Joined=$(IFS='|'; echo "$*")
    local _Want="START:$#:$_Joined"
    local _Second
    _Second=$(grep '^START:' "$_Log" 2>/dev/null | sed -n '2p')
    if [[ $_Rc -eq 0 && "$_Second" == "$_Want" ]]; then
        echo "  PASS  $_Label: zweiter Start '$_Second'"
    else
        echo "  FAIL  $_Label: rc=$_Rc erwartet '$_Want', zweiter Start '$_Second'"
        sed 's/^/        | /' "$_Log" "$_W/out.txt"
        _Fails=$((_Fails + 1))
    fi
}

_RunCase mitargs 0 a1 "b 2"
_RunCase ohneargs 1

# Statisch: kein Neustart mehr mit den Funktionsargumenten.
_Nackt=$(grep -nE 'exec "\$(0|script_path)" "\$@"' "$_Standalone")
if [[ -z "$_Nackt" ]]; then
    echo "  PASS  statisch: kein exec mit nacktem \"\$@\""
else
    echo "  FAIL  statisch: exec mit Funktionsargumenten:"
    echo "$_Nackt" | sed 's/^/        | /'
    _Fails=$((_Fails + 1))
fi

rm -rf "$_Base"
echo "=========================================="
if [[ $_Fails -eq 0 ]]; then
    echo "test_standalone_args: ALLE GRUEN"
    exit 0
fi
echo "test_standalone_args: $_Fails Fall/Faelle fehlgeschlagen"
exit 1
