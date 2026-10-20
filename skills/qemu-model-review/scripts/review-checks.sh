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
  --final-goal          enforce all milestones evidence-backed done, all ACs
                        evidence-backed PASS, and current round PASS (use only
                        for a goal-completion claim)
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
FINAL_GOAL=0
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

check_goal_contract() {
    _state="$TASK_DIR/output/task-state.md"
    if [ ! -f "$_state" ]; then
        if [ "$FINAL_GOAL" -eq 1 ]; then fail "final goal requires output/task-state.md"; return 1; fi
        skip "goal contract (no task-state.md)"; return 0
    fi
    if ! grep -q '^goal: ' "$_state"; then
        if [ "$FINAL_GOAL" -eq 1 ]; then fail "final goal requires a goal field"; return 1; fi
        skip "goal contract (state has no goal)"; return 0
    fi
    if grep -Eq '^goal: (<|$)' "$_state"; then fail "goal is a placeholder"; return 1; fi
    _ms="$TASK_DIR/output/milestones.tsv"
    _ac="$TASK_DIR/output/acceptance.tsv"
    if [ ! -f "$_ms" ]; then fail "goal contract missing milestones.tsv"; return 1; fi
    if [ ! -f "$_ac" ]; then fail "goal contract missing acceptance.tsv"; return 1; fi
    _m_total=$(awk 'END { print NR-1 }' "$_ms"); [ "$_m_total" -lt 0 ] && _m_total=0
    _m_done=$(awk -F'\t' 'NR > 1 && $2=="done" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ms")
    _a_total=$(awk 'END { print NR-1 }' "$_ac"); [ "$_a_total" -lt 0 ] && _a_total=0
    _a_pass=$(awk -F'\t' 'NR > 1 && $2=="pass" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ac")
    _m_bad=$(awk -F'\t' 'NR > 1 && ($2!="pending" && $2!="active" && $2!="done"){n++} NR > 1 && $2=="done" && ($4=="" || $4=="-"){n++} END{print n+0}' "$_ms")
    _a_bad=$(awk -F'\t' 'NR > 1 && ($2!="pending" && $2!="pass" && $2!="fail" && $2!="inconclusive"){n++} NR > 1 && $2=="pass" && ($4=="" || $4=="-"){n++} END{print n+0}' "$_ac")
    if [ "$_m_total" -lt 1 ] || [ "$_a_total" -lt 1 ]; then fail "goal contract has no milestones or ACs"; return 1; fi
    if [ "$_m_total" -lt 2 ] || [ "$_m_total" -gt 5 ]; then fail "goal contract needs 2-5 milestones (found $_m_total)"; return 1; fi
    if [ "$_m_bad" -gt 0 ]; then fail "invalid milestone rows or done milestones without evidence: $_m_bad"; return 1; fi
    if [ "$_a_bad" -gt 0 ]; then fail "invalid AC rows or PASS ACs without evidence: $_a_bad"; return 1; fi
    if [ "$FINAL_GOAL" -eq 1 ]; then
        if [ "$_m_done" -ne "$_m_total" ]; then fail "final goal: milestones not evidence-backed done: $_m_done/$_m_total"; return 1; fi
        if [ "$_a_pass" -ne "$_a_total" ]; then fail "final goal: ACs not evidence-backed PASS: $_a_pass/$_a_total"; return 1; fi
        _blockers=0
        if [ -f "$TASK_DIR/output/findings.tsv" ]; then
            _blockers=$(awk -F'\t' 'NR > 1 && $2=="BLOCKER" && ($5=="" || $5=="open"){n++} END{print n+0}' "$TASK_DIR/output/findings.tsv")
        fi
        if [ "$_blockers" -gt 0 ]; then fail "final goal: unresolved BLOCKER findings: $_blockers"; return 1; fi
        _rr="$TASK_DIR/output/round-result.md"
        if [ ! -f "$_rr" ]; then fail "final goal: missing round-result.md"; return 1; fi
        _state_round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
        if ! _rr_block="$(round_result_block "$_rr" "$_state_round")"; then
            fail "final goal: no round-result section for current round ${_state_round:-missing}"; return 1
        fi
        _rr_verdict="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?(verdict|status):' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?(verdict|status):[[:space:]]*//I' | awk '{ print toupper($1) }')"
        if [ "$_rr_verdict" != PASS ]; then fail "final goal: round-result verdict is not PASS: ${_rr_verdict:-missing}"; return 1; fi
        _rr_gate="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?gate:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?gate:[[:space:]]*//I; s/[[:space:]]*$//')"
        _rr_evidence="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?evidence:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?evidence:[[:space:]]*//I; s/[[:space:]]*$//')"
        if [ -z "$_rr_gate" ] || [ -z "$_rr_evidence" ]; then fail "final goal: round-result needs non-empty gate and evidence"; return 1; fi
        pass "goal contract final: $_m_done/$_m_total evidence-backed milestones, $_a_pass/$_a_total ACs, round PASS"
    else
        pass "goal contract valid: intermediate ($_m_done/$_m_total milestones, $_a_pass/$_a_total ACs); final completion not claimed"
    fi
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

round_result_block() {
    _rblk_file="$1"; _rblk_round="$2"
    if _rblk="$(awk -v want="$_rblk_round" '
        /^##[[:space:]]+Round[[:space:]]+[0-9]+/ {
            if (inblk) exit
            line=$0
            sub(/^##[[:space:]]+Round[[:space:]]+/, "", line)
            sub(/[^0-9].*$/, "", line)
            if (line == want) { inblk=1; found=1; print; next }
            next
        }
        inblk { print }
        END { exit !found }
    ' "$_rblk_file")"; then
        printf '%s\n' "$_rblk"; return 0
    fi
    awk -v want="$_rblk_round" '
        $0 ~ ("^[[:space:]]*Round:[[:space:]]*" want "[[:space:]]*$") { inblk=1; found=1 }
        inblk { print }
        END { exit !found }
    ' "$_rblk_file"
}

check_round_result() {
    _rr="$TASK_DIR/output/round-result.md"
    if [ ! -f "$_rr" ]; then fail "round-result missing: $_rr"; return 1; fi
    _rr_block=""
    if [ -f "$TASK_DIR/output/task-state.md" ]; then
        _rr_round="$(awk -F': ' '/^round:/ { print $2; exit }' "$TASK_DIR/output/task-state.md")"
        if [ -n "$_rr_round" ]; then
            if ! _rr_block="$(round_result_block "$_rr" "$_rr_round")"; then
                fail "round-result missing matching section for round $_rr_round"; return 1
            fi
        fi
    fi
    [ -n "$_rr_block" ] || _rr_block="$(cat "$_rr")"
    _line="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?(verdict|status):' | sed -n '1p')"
    if [ -z "$_line" ]; then fail "round-result missing verdict/status"; return 1; fi
    _verdict="$(printf '%s' "$_line" | sed -E 's/^[[:space:]]*(-[[:space:]]+)?(verdict|status):[[:space:]]*//I' | awk '{ print toupper($1) }')"
    case "$_verdict" in
        PASS|FAIL|INCONCLUSIVE) pass "round-result verdict present" ;;
        *) fail "round-result verdict must be exactly PASS, FAIL, or INCONCLUSIVE"; return 1 ;;
    esac
    _gate="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?gate:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?gate:[[:space:]]*//I; s/[[:space:]]*$//')"
    _evidence="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?evidence:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?evidence:[[:space:]]*//I; s/[[:space:]]*$//')"
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
            --final-goal) FINAL_GOAL=1; shift ;;
            -h|--help) usage; return 0 ;;
            *) log "ERROR: unknown option: $1"; usage >&2; return 2 ;;
        esac
    done
    if [ -z "$TASK_DIR" ]; then log "ERROR: --task-dir is required"; usage >&2; return 2; fi
    check_task_dir
    check_goal_contract
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
