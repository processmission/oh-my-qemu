#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# Preflight checks for a QEMU build host. Prints a record block suitable for
# commands.md and never writes unless --record is given.

set -u

BUILD_DIR=""
SOURCE_ROOT=""
SYMBOL=""
RECORD=""
FAILED=0

usage() {
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done <<'EOF'
Usage: preflight.sh [options]

Check a QEMU build host and print a preflight record block for commands.md.

Options:
  --build-dir DIR    named build directory to inspect (config.log source check)
  --source-root DIR  QEMU source root to compare with config.log and search symbols
  --symbol NAME      pre-compile hint: search include/ and hw/ for NAME
  --record FILE      append the record block to FILE (default: print only)
  --help             show this help and exit 0

Exit: 0 required checks pass, 1 a required check failed, 2 usage error.
No writes happen unless --record is given.
EOF
}

log() {
    printf '%s\n' "$*"
}

record() {
    log "$*"
    if [ -n "$RECORD" ]; then
        printf '%s\n' "$*" >>"$RECORD"
    fi
}

note() {
    record "NOTE	$*"
}

check_host() {
    record "HOST	${OSTYPE:-unknown}	${HOSTTYPE:-unknown}	${MACHTYPE:-unknown}"
}

record_tool() {
    name="$1"
    path="$(command -v "$name" 2>/dev/null || true)"
    if [ -z "$path" ]; then
        record "TOOL-MISSING	$name"
        return 1
    fi
    version="$("$path" --version 2>/dev/null || true)"
    version="${version%%$'\n'*}"
    record "TOOL	$name	$path	$version"
}

check_core_tools() {
    status=0
    for name in git ninja python3 cc; do
        record_tool "$name" || status=1
    done
    if [ -n "$BUILD_DIR" ] && [ -x "$BUILD_DIR/pyvenv/bin/meson" ]; then
        version="$("$BUILD_DIR/pyvenv/bin/meson" --version 2>/dev/null | sed -n '1p')"
        record "TOOL	meson	$BUILD_DIR/pyvenv/bin/meson	$version"
    else
        record_tool meson || status=1
    fi
    if [ "$status" -ne 0 ]; then
        FAILED=1
    fi
    return "$status"
}

check_optional_tools() {
    for name in pkg-config sha256sum shasum timeout gtimeout objdump; do
        record_tool "$name" || true
    done
}

check_macos_notes() {
    case "${OSTYPE:-}" in
        darwin*)
            if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
                note "macOS: no timeout utility; bound runs with the qemu-boot-run runner or a foreground job."
            fi
            if [ -n "${TMPDIR:-}" ] && [ "${#TMPDIR}" -gt 80 ]; then
                note "macOS: TMPDIR is long; use a short temporary directory for qtest sockets."
            fi
            note "macOS: cross-architecture objdump may fail with an exec format error; use a native or LLVM tool."
            ;;
    esac
}

check_config_log() {
    if [ -z "$BUILD_DIR" ]; then
        note "no --build-dir given; config.log source check skipped."
        return 0
    fi
    if [ ! -f "$BUILD_DIR/config.log" ]; then
        record "CONFIG-LOG	$BUILD_DIR/config.log	MISSING"
        FAILED=1
        return 1
    fi
    line="$(grep -m 1 "Configured with:" "$BUILD_DIR/config.log" 2>/dev/null || true)"
    if [ -z "$line" ]; then
        record "CONFIG-LOG	$BUILD_DIR/config.log	NO CONFIGURE LINE"
        FAILED=1
        return 1
    fi
    configure="$(printf '%s\n' "$line" | awk -F"'" '{print $2}')"
    record "CONFIG-LOG	$BUILD_DIR/config.log	$configure"
    recorded="${configure%/*}"
    if [ -n "$SOURCE_ROOT" ]; then
        want="$(cd "$SOURCE_ROOT" 2>/dev/null && pwd || true)"
        have="$(cd "$recorded" 2>/dev/null && pwd || true)"
        if [ -n "$want" ] && [ -n "$have" ] && [ "$want" = "$have" ]; then
            record "CONFIG-SOURCE	$have	MATCH"
            return 0
        fi
        record "CONFIG-SOURCE	${have:-$recorded}	MISMATCH against $want"
        FAILED=1
        return 1
    fi
    note "config.log source is $recorded; compare it with the current source root before reuse."
}

check_symbol_hint() {
    if [ -z "$SYMBOL" ] || [ -z "$SOURCE_ROOT" ]; then
        return 0
    fi
    hits="$(grep -R -n "$SYMBOL" "$SOURCE_ROOT/include" 2>/dev/null | awk 'NR <= 5')"
    if [ -n "$hits" ]; then
        record "SYMBOL	$SYMBOL	FOUND IN include/"
        log "$hits"
    else
        record "SYMBOL	$SYMBOL	NOT FOUND IN include/"
        note "inspect the checked-out tree; a symbol may be new, renamed, or outside include/."
    fi
}

check_summary() {
    if [ "$FAILED" -eq 0 ]; then
        record "PREFLIGHT	PASS"
        return 0
    fi
    record "PREFLIGHT	FAIL"
    return 1
}

main() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --build-dir) [ "$#" -ge 2 ] || { usage >&2; return 2; }; BUILD_DIR="$2"; shift 2 ;;
            --source-root) [ "$#" -ge 2 ] || { usage >&2; return 2; }; SOURCE_ROOT="$2"; shift 2 ;;
            --symbol) [ "$#" -ge 2 ] || { usage >&2; return 2; }; SYMBOL="$2"; shift 2 ;;
            --record) [ "$#" -ge 2 ] || { usage >&2; return 2; }; RECORD="$2"; shift 2 ;;
            --help|-h) usage; return 0 ;;
            *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; return 2 ;;
        esac
    done
    check_host
    check_core_tools || true
    check_optional_tools || true
    check_macos_notes || true
    check_config_log || true
    check_symbol_hint || true
    check_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
