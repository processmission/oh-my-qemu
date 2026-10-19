#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# check-registration.sh - read-only checks for a QEMU qtest registration and
# lifecycle. Portable bash 3.2; makes no writes.
# Exit codes: 0 pass, 1 check failed, 2 usage error.

set -u

usage() {
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done <<'EOF'
usage: check-registration.sh --meson <meson.build> --source <test.c> [--arch <arch>]

Read-only checks for a QEMU qtest:
  registration  test name present in tests/qtest/meson.build
  bucket        enclosing variable is qtests_<arch> or qtests_generic
  lifecycle     source calls qtest_init*/qtest_start and qtest_quit/qtest_end
  portability   warns on a hardcoded /tmp path (warning only)

options:
  --meson <file>   path to tests/qtest/meson.build
  --source <file>  path to the qtest source file
  --arch <arch>    expected qtests_<arch> bucket (for example aarch64)
  --help           show this help

exit codes: 0 pass, 1 check failed, 2 usage error
EOF
}

log() { printf '%s\n' "$*"; }
pass() { log "PASS $*"; }
fail() { log "FAIL $*"; return 1; }
skip() { log "SKIP $*"; }

need_arg() {
    if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        log "ERROR: missing value for $1"
        usage >&2
        return 2
    fi
}

test_name_of() {
    local base="${1##*/}"
    printf '%s\n' "${base%.c}"
}

registered_line() {
    local meson="$1" name="$2" line
    for line in $(awk -v pat="'$name'" 'index($0, pat) { print NR }' "$meson"); do
        if [ -n "$(enclosing_bucket "$meson" "'$name'")" ]; then
            printf '%s\n' "$line"
            return 0
        fi
    done
    return 1
}

enclosing_bucket() {
    # Return the qtests_* variable whose list actually contains the quoted test
    # name. Stop at the assignment's closing bracket so a later variable cannot
    # inherit the bucket.
    awk -v target="$2" '
        {
            line = $0
            if (inlist) {
                if (!found && index(line, target)) found = 1
                if (index(line, "]")) {
                    if (found) { print bucket; done = 1; exit }
                    inlist = 0; found = 0
                }
                next
            }
            pos = index(line, "qtests_")
            if (pos == 0) next
            if (pos > 1) {
                prev = substr(line, pos - 1, 1)
                if (prev ~ /[A-Za-z0-9_]/) next
            }
            rest = substr(line, pos)
            if (match(rest, /^[A-Za-z0-9_]+[ \t]*\+?=[ \t]*\[/)) {
                bucket = rest
                sub(/[ \t]*\+?=.*/, "", bucket)
                after = rest
                sub(/^[^[]*\[/, "", after)
                inlist = 1
                found = (index(after, target) > 0)
                if (index(after, "]")) {
                    if (found) { print bucket; done = 1; exit }
                    inlist = 0; found = 0
                }
            }
        }
        END { if (!done && inlist && found) print bucket }
    ' "$1"
}

check_registration() {
    local meson="$1" name="$2" arch="$3" line bucket expected
    if [ ! -f "$meson" ]; then fail "registration: meson.build not found: $meson"; return 1; fi
    line=$(registered_line "$meson" "$name")
    if [ -z "$line" ]; then fail "registration: '$name' not under a qtests_* variable in $meson"; return 1; fi
    bucket=$(enclosing_bucket "$meson" "'$name'")
    if [ -z "$bucket" ]; then
        fail "registration: '$name' at line $line is outside a qtests_* variable"; return 1
    fi
    if [ -n "$arch" ] && [ "$bucket" != "qtests_generic" ]; then
        expected="qtests_$arch"
        if [ "$bucket" != "$expected" ]; then
            if grep -Eq "^[[:space:]]*$expected[[:space:]]*=[[:space:]]*$bucket[[:space:]]*$" "$meson"; then
                log "INFO registration: '$name' is in $bucket, aliased by $expected"
            elif [ "${bucket#qtests_}" != "$bucket" ]; then
                fail "registration: '$name' is in $bucket, expected $expected or qtests_generic"
                return 1
            else
                log "WARN registration: '$name' is in $bucket; verify $expected includes $bucket"
            fi
        fi
    fi
    pass "registration: '$name' in $bucket (meson line $line)"
}

check_lifecycle() {
    local src="$1" status=0
    if [ ! -f "$src" ]; then fail "lifecycle: source not found: $src"; return 1; fi
    if grep -q 'qos_add_test' "$src"; then
        skip "lifecycle: qgraph test (qos_add_test) manages its own lifecycle"
        return 0
    fi
    if grep -Eq 'qtest_init[a-z_]*[[:space:]]*\(|qtest_start[[:space:]]*\(' "$src"; then
        pass "lifecycle: init call found"
    else
        fail "lifecycle: no qtest_init*/qtest_start call in $src"; status=1
    fi
    if grep -Eq 'qtest_quit[[:space:]]*\(|qtest_end[[:space:]]*\(' "$src"; then
        pass "lifecycle: quit call found"
    else
        fail "lifecycle: no qtest_quit/qtest_end call in $src"; status=1
    fi
    return "$status"
}

check_portability() {
    local src="$1" hits
    hits=$(grep -n '/tmp' "$src" 2>/dev/null | sed -n '1,5p')
    if [ -n "$hits" ]; then
        log "WARN portability: hardcoded /tmp path; use g_dir_make_tmp or g_file_open_tmp"
        printf '%s\n' "$hits" | sed 's/^/  /'
        return 0
    fi
    pass "portability: no hardcoded /tmp path"
}

report_result() {
    if [ "$1" -eq 0 ]; then log "RESULT: PASS"; return 0; fi
    log "RESULT: FAIL ($1 check(s) failed)"
    return 1
}

main() {
    local meson="" source="" arch="" errors=0 name
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h) usage; return 0 ;;
            --meson) need_arg "$1" "${2:-}" || return 2; meson="$2"; shift 2 ;;
            --source) need_arg "$1" "${2:-}" || return 2; source="$2"; shift 2 ;;
            --arch) need_arg "$1" "${2:-}" || return 2; arch="$2"; shift 2 ;;
            *) log "ERROR: unknown option: $1"; usage >&2; return 2 ;;
        esac
    done
    if [ -z "$meson" ] || [ -z "$source" ]; then
        log "ERROR: --meson and --source are required"
        usage >&2
        return 2
    fi
    name=$(test_name_of "$source")
    log "== qtest registration check: $name"
    check_registration "$meson" "$name" "$arch" || errors=$((errors + 1))
    check_lifecycle "$source" || errors=$((errors + 1))
    check_portability "$source"
    report_result "$errors"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
