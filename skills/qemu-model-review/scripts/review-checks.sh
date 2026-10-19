#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# review-checks.sh - deterministic, read-only checks for a QEMU modeling review.
# Portable bash 3.2; makes no writes.
set -u

usage() {
    cat <<'EOF'
Usage: review-checks.sh --task-dir DIR [options]

Read-only checks for one modeling review round. It does not judge correctness;
it verifies that the required artifacts and deterministic gates are present.

Options:
  --task-dir DIR        .oh-my-qemu/<task-slug>/ directory (required)
  --repo DIR            QEMU checkout root (default: git root of the task dir)
  --ir FILE             RS-IR .ir file to check (optional)
  --validator FILE      validate_register_ir.py path (optional)
  --translation FILE    translation TSV produced by --translate (optional)
  --help                show this help

Checks: audit/commands, audit sections, excluded Git paths, RS-IR parse,
observe/placeholder presence, translation rows, round-result verdict.
Exit: 0 all required checks pass, 1 a required check failed, 2 usage.
EOF
}

log() { printf '%s\n' "$*"; }
pass() { PASS=$((PASS + 1)); log "PASS $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL $*"; }
skip() { SKIP=$((SKIP + 1)); log "SKIP $*"; }
need_value() {
    [ -n "${2:-}" ] || { log "ERROR: missing value for $1"; usage >&2; return 2; }
}
TASK_DIR=""; REPO_DIR=""; IR_FILE=""; VALIDATOR=""; TRANSLATION=""
PASS=0; FAIL=0; SKIP=0

check_task_dir() {
    [ -d "$TASK_DIR" ] || { fail "task dir not found: $TASK_DIR"; return 1; }
    if [ -f "$TASK_DIR/audit.md" ]; then pass "audit.md present"; else fail "missing audit.md"; fi
    if [ -f "$TASK_DIR/commands.md" ]; then pass "commands.md present"; else fail "missing commands.md"; fi
}

check_audit_sections() {
    [ -f "$TASK_DIR/audit.md" ] || return 0
    _missing=""
    while IFS= read -r _heading; do
        grep -qxF "## $_heading" "$TASK_DIR/audit.md" || _missing="$_missing | $_heading"
    done <<'HEADINGS'
Baseline
Goal and non-goals
Scope and constraints
Acceptance criteria
Plan and verification gates
Provenance
Decisions and assumptions
Round record
Evidence and verification
Unresolved gaps
Handoff
HEADINGS
    if [ -z "$_missing" ]; then pass "audit sections present"; else fail "audit missing sections:$_missing"; fi
}

check_git() {
    if [ -z "$REPO_DIR" ]; then
        REPO_DIR="$(git -C "$TASK_DIR" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    if [ -z "$REPO_DIR" ] || [ ! -e "$REPO_DIR/.git" ]; then
        skip "git checks (no worktree)"
        return 0
    fi
    _tracked="$(git -C "$REPO_DIR" ls-files --cached -- .agents/ .oh-my-qemu/ builds/ 2>/dev/null)"
    if [ -n "$_tracked" ]; then fail "excluded paths are tracked: $(printf '%s' "$_tracked" | sed -n '1,3p')"; else pass "no excluded path tracked"; fi
    _staged="$(git -C "$REPO_DIR" diff --cached --name-only -- .agents/ .oh-my-qemu/ builds/ 2>/dev/null)"
    if [ -n "$_staged" ]; then fail "excluded paths staged: $(printf '%s' "$_staged" | sed -n '1,3p')"; else pass "no excluded path staged"; fi
    _untracked="$(git -C "$REPO_DIR" status --short -- .agents/ .oh-my-qemu/ builds/ 2>/dev/null | grep -E '^(\?\?|[ MADRCU?!]{2})[[:space:]]' | sed -n '1,3p')"
    if [ -n "$_untracked" ]; then
        fail "managed paths remain visible to Git: $(printf '%s' "$_untracked")"
    else
        pass "no managed path visible to Git"
    fi
    _count="$(git -C "$REPO_DIR" status --short 2>/dev/null | wc -l | tr -d ' ')"
    log "INFO changed paths in worktree: $_count (compare with the recorded baseline)"
}

check_ir() {
    if [ -z "$IR_FILE" ]; then skip "RS-IR check (no --ir)"; return 0; fi
    if [ ! -f "$IR_FILE" ]; then fail "RS-IR not found: $IR_FILE"; return 1; fi
    if head -n 20 "$IR_FILE" | grep -qx 'ir 1.0'; then pass "RS-IR version header"; else fail "RS-IR missing ir 1.0"; fi
    if grep -q '^  observe ' "$IR_FILE"; then pass "RS-IR observe metadata present"; else skip "RS-IR has no observe line"; fi
    if grep -q 'status=unimplemented' "$IR_FILE"; then
        if grep 'status=unimplemented' "$IR_FILE" | grep -q 'placeholder='; then pass "unimplemented placeholders named"; else fail "unimplemented address missing placeholder"; fi
    fi
    if [ -n "$VALIDATOR" ]; then
        if [ ! -f "$VALIDATOR" ]; then fail "validator not found: $VALIDATOR"; return 1; fi
        if python3 "$VALIDATOR" "$IR_FILE" >/dev/null 2>&1; then pass "RS-IR validator"; else fail "RS-IR validator rejected the file"; fi
    else
        skip "RS-IR validator (no --validator)"
    fi
}

check_translation() {
    if [ -z "$TRANSLATION" ]; then skip "translation check (no --translation)"; return 0; fi
    if [ ! -f "$TRANSLATION" ]; then fail "translation not found: $TRANSLATION"; return 1; fi
    if grep -q '^kind' "$TRANSLATION"; then pass "translation header"; else fail "translation missing header"; fi
    _rules="$(grep -c '^rule' "$TRANSLATION" 2>/dev/null || true)"
    if [ "${_rules:-0}" -gt 0 ] 2>/dev/null; then pass "translation rule rows: $_rules"; else fail "translation has no rule rows"; fi
    _placeholders="$(grep -c '^address' "$TRANSLATION" 2>/dev/null || true)"
    log "INFO translation placeholder rows: ${_placeholders:-0}"
    if [ -n "$IR_FILE" ] && [ -f "$IR_FILE" ]; then
        _ir_ids="$(awk '$1 == "rule" { print $2 }' "$IR_FILE" | sort -u)"
        _tr_ids="$(awk -F'\t' '$1 == "rule" && NF >= 3 && $2 != "" { print $2 }' "$TRANSLATION" | sort -u)"
        _missing="$(comm -23 <(printf '%s\n' "$_ir_ids") <(printf '%s\n' "$_tr_ids"))"
        _extra="$(comm -13 <(printf '%s\n' "$_ir_ids") <(printf '%s\n' "$_tr_ids"))"
        if [ -n "$_missing" ]; then
            fail "translation missing rule rows: $(printf '%s' "$_missing" | tr '\n' ' ')"
        elif [ -n "$_extra" ]; then
            fail "translation has unknown rule rows: $(printf '%s' "$_extra" | tr '\n' ' ')"
        else
            pass "translation rule IDs match RS-IR"
        fi
    fi
}

check_round_result() {
    _rr="$TASK_DIR/output/round-result.md"
    if [ ! -f "$_rr" ]; then fail "round-result missing: $_rr"; return 1; fi
    _line="$(grep -iE '^[[:space:]]*(-[[:space:]]+)?(verdict|status):' "$_rr" | sed -n '1p')"
    if [ -z "$_line" ]; then fail "round-result missing verdict/status"; return 1; fi
    _verdict="$(printf '%s' "$_line" | sed -E 's/^[[:space:]]*(-[[:space:]]+)?(verdict|status):[[:space:]]*//I' | awk '{ print toupper($1) }')"
    case "$_verdict" in
        PASS|FAIL|INCONCLUSIVE) pass "round-result verdict present" ;;
        *) fail "round-result verdict must be exactly PASS, FAIL, or INCONCLUSIVE"; return 1 ;;
    esac
    _gate="$(grep -iE '^[[:space:]]*(-[[:space:]]+)?gate:' "$_rr" | sed -n '1p')"
    _evidence="$(grep -iE '^[[:space:]]*(-[[:space:]]+)?evidence:' "$_rr" | sed -n '1p')"
    case "$_verdict" in
        PASS)
            if [ -z "$_gate" ] || [ -z "$_evidence" ]; then
                fail "PASS round-result needs gate and evidence"
                return 1
            fi
            _gate_l="$(printf '%s' "$_gate" | tr '[:upper:]' '[:lower:]')"
            case "$_gate_l" in
                *timeout*|*'timed out'*|*'no crash'*|*'no marker'*|*'empty log'*|*'empty serial'*)
                    fail "PASS cannot rest on timeout, no-crash, no-marker, or empty-log evidence"
                    return 1
                    ;;
            esac
            case "$_gate_l" in
                *marker*|*qtest*|*test*|*expected*) ;;
                *)
                    fail "PASS gate must name a configured marker or a test"
                    return 1
                    ;;
            esac
            pass "PASS gate/evidence recorded"
            ;;
        FAIL|INCONCLUSIVE)
            _blocker="$(grep -iE '^[[:space:]]*(-[[:space:]]+)?next[ -]blocker:' "$_rr" | sed -n '1p')"
            if [ -z "$_blocker" ]; then
                fail "non-PASS round-result needs a next-blocker line"
                return 1
            fi
            if printf '%s\n' "$_blocker" | grep -qiE ':[[:space:]]*(none|n/a)[[:space:]]*$'; then
                fail "non-PASS round-result needs a concrete next blocker, not none"
                return 1
            fi
            pass "non-PASS next blocker recorded"
            ;;
    esac
}

main() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task-dir) need_value "$1" "${2:-}" || return 2; TASK_DIR="$2"; shift 2 ;;
            --repo) need_value "$1" "${2:-}" || return 2; REPO_DIR="$2"; shift 2 ;;
            --ir) need_value "$1" "${2:-}" || return 2; IR_FILE="$2"; shift 2 ;;
            --validator) need_value "$1" "${2:-}" || return 2; VALIDATOR="$2"; shift 2 ;;
            --translation) need_value "$1" "${2:-}" || return 2; TRANSLATION="$2"; shift 2 ;;
            -h|--help) usage; return 0 ;;
            *) log "ERROR: unknown option: $1"; usage >&2; return 2 ;;
        esac
    done
    if [ -z "$TASK_DIR" ]; then log "ERROR: --task-dir is required"; usage >&2; return 2; fi
    check_task_dir
    check_audit_sections
    check_git
    check_ir
    check_translation
    check_round_result
    log "RESULT: pass=$PASS fail=$FAIL skip=$SKIP"
    [ "$FAIL" -eq 0 ]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
