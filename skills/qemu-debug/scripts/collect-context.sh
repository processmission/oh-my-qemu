#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# collect-context.sh - collect QEMU failure context into a report skeleton.
# Portable bash 3.2; writes only the --output file.
set -u

usage() {
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done <<'EOF'
usage: collect-context.sh --output <report.md> --qemu <binary> [options]
Capture stable context of a QEMU failure into a Markdown report skeleton:
command line, binary hash, build config line, host tools and versions, git
provenance (or a recorded provenance gap), and evidence log paths.
options:
  --output <file>    report file to write (required; no other writes)
  --qemu <path>      QEMU system binary from the failing run (required)
  --command <text>   exact command line; quote it in the shell
  --build-dir <dir>  QEMU build directory (for config.log)
  --cwd <dir>        working directory of the failing run (default: current)
  --log <path>       evidence log path; repeat the option for each log
  --help             show this help
exit codes: 0 report written, 1 a collection check failed, 2 usage error
EOF
}
log() { printf '%s\n' "$*"; }
pass() { log "PASS $*"; }
fail() { log "FAIL $*"; return 1; }
need_arg() {
    if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        log "ERROR: missing value for $1"
        usage >&2
        return 2
    fi
}
absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$PWD/$1" ;;
    esac
}
hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
    else
        printf '%s\n' "unavailable"
    fi
}
build_config_line() {
    local build_dir="$1" config_log="$build_dir/config.log"
    if [ ! -f "$config_log" ]; then
        config_log=$(find "$build_dir" -maxdepth 2 -name config.log -type f 2>/dev/null | sed -n '1p')
    fi
    if [ -z "$config_log" ]; then
        printf '%s\n' "unavailable (no config.log under $build_dir)"; return 1
    fi
    sed -n '/^# Configured with:/{s/^# //;p;q;}' "$config_log"
}
tool_line() {
    local tool="$1" version=""
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '%s: unavailable\n' "$tool"; return 1
    fi
    version=$("$tool" --version 2>/dev/null | sed -n '1p')
    printf '%s: %s\n' "$tool" "${version:-(installed, version unavailable)}"
}
git_state() {
    local cwd="${1:-$PWD}"
    if ! command -v git >/dev/null 2>&1; then
        printf '%s\n' "provenance gap: git unavailable"; return 1
    fi
    if ! git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf '%s\n' "provenance gap: not a git worktree at $cwd"; return 1
    fi
    printf 'HEAD: %s\nstatus:\n' "$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)"
    git -C "$cwd" status --short 2>/dev/null | sed -n '1,40p'
}
log_line() {
    local abs
    abs=$(absolute_path "$1")
    if [ -f "$abs" ]; then
        printf '%s (exists, sha256: %s)\n' "$abs" "$(hash_file "$abs")"
    else
        printf '%s (missing)\n' "$abs"
    fi
}

write_report() {
    local output="$1" qemu_abs="$2" hash="$3" command_line="$4"
    local cwd="$5" build_dir="$6" config_line="$7" logs="$8" host_os="$9"
    local tool path
    {
        printf '# QEMU crash report\n\n'
        printf '## Command and working directory\n\n'
        printf -- '- Command: %s\n- Working directory: %s\n\n' "$command_line" "$cwd"
        printf '## Binary and build\n\n'
        printf -- '- QEMU binary: %s\n- sha256: %s\n' "$qemu_abs" "$hash"
        printf -- '- Build directory: %s\n- Build config: %s\n- Host OS: %s\n\n' \
            "${build_dir:-(not provided)}" "$config_line" "$host_os"
        printf '## Failure\n\n'
        printf -- '- Signal or exit status: <fill from the rerun>\n- Assertion or abort message (file:line): <paste the QEMU message>\n- Backtrace: <paste thread apply all bt full output>\n'
        printf -- '- Core dump path: <path or none>\n- Reproducer: <minimized failing command>\n'
        printf -- '- Image or firmware hashes: <sha256 per input>\n\n'
        printf '## Host tools\n\n'
        for tool in git python3 meson ninja gdb lldb objdump; do
            printf -- '- %s\n' "$(tool_line "$tool")"
        done
        printf '\n## Provenance\n\n%s\n' "$(git_state "$cwd")"
        printf '\n## Logs\n\n'
        printf '%s' "$logs" | while IFS= read -r path; do
            if [ -n "$path" ]; then printf -- '- %s\n' "$(log_line "$path")"; fi
        done
        if [ -z "$logs" ]; then printf -- '- (no --log paths recorded)\n'; fi
        printf '\n## Classification and next check\n\n'
        printf -- '- Classification: <environment | image | boot ABI | board | device | TCG | guest>\n'
        printf -- '- Next narrow check: <one command>\n'
        printf -- '- Cleanup: <processes stopped, temporary files removed>\n'
    } > "$output"
}

main() {
    local output="" qemu="" command_line="" build_dir="" cwd="" logs=""
    local qemu_abs hash config_line host_os out_dir errors=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h) usage; return 0 ;;
            --output) need_arg "$1" "${2:-}" || return 2; output="$2"; shift 2 ;;
            --qemu) need_arg "$1" "${2:-}" || return 2; qemu="$2"; shift 2 ;;
            --command) need_arg "$1" "${2:-}" || return 2; command_line="$2"; shift 2 ;;
            --build-dir) need_arg "$1" "${2:-}" || return 2; build_dir="$2"; shift 2 ;;
            --cwd) need_arg "$1" "${2:-}" || return 2; cwd="$2"; shift 2 ;;
            --log) need_arg "$1" "${2:-}" || return 2; printf -v logs '%s%s\n' "$logs" "$2"; shift 2 ;;
            *) log "ERROR: unknown option: $1"; usage >&2; return 2 ;;
        esac
    done
    if [ -z "$output" ] || [ -z "$qemu" ]; then
        log "ERROR: --output and --qemu are required; refusing to write without them"
        usage >&2; return 2
    fi
    out_dir="${output%/*}"; if [ "$out_dir" = "$output" ]; then out_dir="."; fi
    if [ ! -d "$out_dir" ]; then fail "output: directory does not exist: $out_dir"; return 1; fi
    qemu_abs=$(absolute_path "$qemu"); hash="unavailable"
    if [ -f "$qemu_abs" ]; then
        hash=$(hash_file "$qemu_abs"); pass "binary: $qemu_abs (sha256 $hash)"
    else
        fail "binary: not found: $qemu_abs"; errors=1
    fi
    if [ -z "$cwd" ]; then cwd="$PWD"; fi
    cwd=$(absolute_path "$cwd")
    if [ -z "$command_line" ]; then command_line="(not provided)"; fi
    config_line="(no --build-dir given)"
    if [ -n "$build_dir" ]; then
        if ! config_line=$(build_config_line "$build_dir"); then
            fail "build config: no config.log under $build_dir"
            errors=$((errors + 1))
            config_line="unavailable"
        fi
    fi
    if [ -z "$config_line" ]; then config_line="unavailable"; fi
    host_os="${OSTYPE:-unknown}"
    if ! write_report "$output" "$qemu_abs" "$hash" "$command_line" "$cwd" \
        "$build_dir" "$config_line" "$logs" "$host_os"; then
        fail "report: cannot write $output"; return 1
    fi
    pass "report: $output"
    if [ "$errors" -ne 0 ]; then log "RESULT: FAIL ($errors collection check(s) failed)"; return 1; fi
    log "RESULT: PASS"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
