#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# check-framework-decision.sh - read-only check of a register framework decision.
# Portable bash 3.2; no writes.
# Exit: 0 pass, 1 check failure, 2 usage.

set -u

usage() {
    cat <<'EOF'
usage: check-framework-decision.sh <decision.md>

Checks a qemu-peripheral-modeling framework decision record:
  bank kind, implementation, decisive input, rationale, structural reason,
  hybrid split, accepted limits, and review gate.
  Manual/hybrid control/status banks must name a structural command/FIFO/DMA/
  timing/reentrancy reason; placeholders and "nearby devices are manual" are
  rejected.

exit codes: 0 pass, 1 check failed, 2 usage
EOF
}

log() { printf '%s\n' "$*"; }
pass() { log "PASS $*"; }
fail() { log "FAIL $*"; return 1; }

field() {
    awk -v key="- $2:" 'index($0, key) == 1 { line = $0; sub(/^- [^:]+:[[:space:]]*/, "", line); print line; exit }' "$1"
}

placeholder() {
    _ph_value="$(printf '%s' "$1" | tr -d '\140' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    case "$_ph_value" in
        ''|'<'*|*'<placeholder>'*) return 0 ;;
        *) return 1 ;;
    esac
}

main() {
    if [ "$#" -ne 1 ]; then usage >&2; return 2; fi
    _file="$1"
    if [ ! -f "$_file" ]; then fail "decision file not found: $_file"; return 1; fi
    _status=0

    _kind="$(field "$_file" 'Bank kind')"
    _impl="$(field "$_file" 'Implementation')"
    _decisive="$(field "$_file" 'Decisive input')"
    _rationale="$(field "$_file" 'Rationale')"
    _structural="$(field "$_file" 'Structural reason (required for manual/hybrid)')"
    _hybrid="$(field "$_file" 'Hybrid split')"
    _limits="$(field "$_file" 'Accepted limits')"
    _review="$(field "$_file" 'Review gate')"

    case "$_kind" in
        control-status|data-command|hybrid) pass "bank kind: $_kind" ;;
        *) fail "bank kind must be control-status, data-command, or hybrid"; _status=1 ;;
    esac
    case "$_impl" in
        RegisterInfo|'manual MMIO'|hybrid) pass "implementation: $_impl" ;;
        *) fail "implementation must be RegisterInfo, manual MMIO, or hybrid"; _status=1 ;;
    esac
    if placeholder "$_decisive"; then fail "decisive input is missing or a placeholder"; _status=1
    else pass "decisive input recorded"; fi
    if placeholder "$_rationale"; then fail "rationale is missing or a placeholder"; _status=1
    else pass "rationale recorded"; fi
    if placeholder "$_limits"; then fail "accepted limits are missing or a placeholder"; _status=1
    else pass "accepted limits recorded"; fi
    if placeholder "$_review"; then fail "review gate is missing or a placeholder"; _status=1
    else pass "review gate recorded"; fi

    case "$_impl" in
        RegisterInfo)
            pass "RegisterInfo selected; structural reason not required"
            ;;
        'manual MMIO'|hybrid)
            if placeholder "$_structural"; then
                fail "manual/hybrid choice needs a structural reason"; _status=1
            elif ! printf '%s' "$_structural" | grep -Eiq 'fifo|command|dma|tim(e|er|ing)|reentr|stream|aperture|queue|doorbell|view'; then
                fail "structural reason must name a command/FIFO/DMA/timing/reentrancy structure, not nearby convention or schedule"; _status=1
            else
                pass "structural reason names a framework limit"
            fi
            if [ "$_impl" = hybrid ] && placeholder "$_hybrid"; then
                fail "hybrid choice needs a RegisterInfo/manual split"; _status=1
            elif [ "$_impl" = hybrid ]; then
                pass "hybrid split recorded"
            fi
            ;;
    esac
    if [ "$_status" -eq 0 ]; then
        log "RESULT PASS: $_file"
        return 0
    fi
    log "RESULT FAIL: $_file"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
