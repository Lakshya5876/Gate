load test_helper

# Pins a real bug reported from a live user run: uninstall.sh's _confirm used
# ${answer,,} (bash 4+ lowercase parameter expansion). macOS ships bash 3.2 as
# /bin/bash by default (Apple never ships GPLv3 bash, and does not upgrade
# it) — most Mac users never install a newer bash via Homebrew, so this hit
# on the very first real macOS run: "uninstall.sh: line 49: ${answer,,}: bad
# substitution", right after the user typed "y" at the removal-confirmation
# prompt, aborting before anything was actually removed.
#
# Both tests here explicitly invoke /bin/bash (not `bash`, which on some
# machines/PATHs could resolve to a Homebrew-installed bash 4/5) to
# reproduce the exact macOS-default-bash conditions the bug report was
# filed against.

@test "_confirm (uninstall.sh) accepts y/Y/yes/YES and declines everything else, under real bash 3.2 syntax rules" {
    BASH_VERSION_MAJOR=$(/bin/bash -c 'echo ${BASH_VERSINFO[0]}')
    # This test's whole point is exercising bash 3.2's stricter parameter-
    # expansion rules — if the box running this suite has upgraded /bin/bash,
    # the original bug wouldn't reproduce here anyway, so skip rather than
    # give a false sense of coverage.
    if [ "$BASH_VERSION_MAJOR" -ge 4 ]; then
        skip "/bin/bash on this machine is already bash 4+ — cannot reproduce the bash-3.2-only failure mode here"
    fi

    start_line=$(grep -n '^_confirm() {' "${FRAMEWORK_ROOT}/uninstall.sh" | head -1 | cut -d: -f1)
    end_line=$(awk -v s="$start_line" 'NR>s && /^}/{print NR; exit}' "${FRAMEWORK_ROOT}/uninstall.sh")
    sed -n "${start_line},${end_line}p" "${FRAMEWORK_ROOT}/uninstall.sh" > "${BATS_TEST_TMPDIR}/confirm_func.sh"

    for input in y Y yes YES; do
        run /bin/bash -c "source '${BATS_TEST_TMPDIR}/confirm_func.sh'; echo '$input' | _confirm 'Proceed?' && echo CONFIRMED || echo DECLINED"
        [ "$status" -eq 0 ]
        [[ "$output" != *"bad substitution"* ]]
        [[ "$output" == *"CONFIRMED"* ]]
    done

    for input in n N no "" garbage; do
        run /bin/bash -c "source '${BATS_TEST_TMPDIR}/confirm_func.sh'; echo '$input' | _confirm 'Proceed?' && echo CONFIRMED || echo DECLINED"
        [ "$status" -eq 0 ]
        [[ "$output" != *"bad substitution"* ]]
        [[ "$output" == *"DECLINED"* ]]
    done
}

setup_staleness_pair() {
    # Real local+remote git repos (not mocked), so _check_framework_staleness
    # exercises its actual fetch/rev-list logic end to end.
    STALE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/staleness-XXXXXX")"
    git init -q -b main --bare "${STALE_ROOT}/remote.git"
    git clone -q "${STALE_ROOT}/remote.git" "${STALE_ROOT}/origin_clone"
    (
        cd "${STALE_ROOT}/origin_clone"
        git config user.email t@t.com
        git config user.name t
        echo v1 > f.txt && git add f.txt && git commit -q -m v1
        git push -q origin main
    )
    git clone -q "${STALE_ROOT}/remote.git" "${STALE_ROOT}/local_stale"

    start_line=$(grep -n '^_check_framework_staleness() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    end_line=$(grep -n '^_upgrade() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    sed -n "${start_line},$((end_line - 1))p" "${FRAMEWORK_ROOT}/install.sh" > "${BATS_TEST_TMPDIR}/staleness_func.sh"
    source "${BATS_TEST_TMPDIR}/staleness_func.sh"
}

teardown_staleness_pair() {
    [ -n "${STALE_ROOT:-}" ] && [ -d "$STALE_ROOT" ] && rm -rf "$STALE_ROOT"
}

@test "_check_framework_staleness warns when the local clone is behind its upstream" {
    setup_staleness_pair
    (
        cd "${STALE_ROOT}/origin_clone"
        echo v2 > f.txt && git add f.txt && git commit -q -m v2
        git push -q origin main
    )
    run _check_framework_staleness "${STALE_ROOT}/local_stale"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 commit(s)"* ]]
    [[ "$output" == *"behind origin/main"* ]]
    teardown_staleness_pair
}

@test "_check_framework_staleness is silent when the clone is already up to date" {
    setup_staleness_pair
    run _check_framework_staleness "${STALE_ROOT}/origin_clone"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_staleness_pair
}

@test "_check_framework_staleness degrades silently (no crash) when not a git repo" {
    NOTAREPO="$(mktemp -d "${TMPDIR:-/tmp}/not-a-repo-XXXXXX")"
    start_line=$(grep -n '^_check_framework_staleness() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    end_line=$(grep -n '^_upgrade() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    sed -n "${start_line},$((end_line - 1))p" "${FRAMEWORK_ROOT}/install.sh" > "${BATS_TEST_TMPDIR}/staleness_func2.sh"
    source "${BATS_TEST_TMPDIR}/staleness_func2.sh"
    run _check_framework_staleness "$NOTAREPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "$NOTAREPO"
}

@test "_check_framework_staleness degrades silently (no crash) when the remote is unreachable" {
    setup_staleness_pair
    git -C "${STALE_ROOT}/local_stale" remote set-url origin "/nonexistent/path/${STALE_ROOT##*/}.git"
    run _check_framework_staleness "${STALE_ROOT}/local_stale"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_staleness_pair
}

@test "no shipped shell script uses bash-4-only syntax (macOS's default /bin/bash is 3.2)" {
    # Grep, not a bash-version check, so this catches the class of bug
    # regardless of what bash the CI/dev machine happens to have installed —
    # the constraint is about what macOS ships by default, not what any one
    # box running this test suite has. Excludes comment-only lines (`#...`)
    # since this file's own explanatory comments legitimately reference the
    # banned syntax by name when documenting why it's banned.
    run bash -c "grep -rnE '\\\$\\{[A-Za-z_][A-Za-z0-9_]*(\\[[^]]*\\])?,,|\\\$\\{[A-Za-z_][A-Za-z0-9_]*(\\[[^]]*\\])?\\^\\^|declare -A|readarray|mapfile' '${FRAMEWORK_ROOT}/install.sh' '${FRAMEWORK_ROOT}/uninstall.sh' '${FRAMEWORK_ROOT}'/templates/*.sh | grep -vE '^[^:]+:[0-9]+: *#'"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}
