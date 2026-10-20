#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# loop-state.sh - append-only-ish task state for the modeling orchestrator.
# Portable bash 3.2; writes only under the task output directory.
set -u

usage() {
    cat <<'EOF'
Usage: loop-state.sh <command> <task-dir> [args]

Commands:
  init <task-dir>                      create output/task-state.md from the template
  goal <task-dir> "<goal>" [goal|round] set the overall goal and the loop mode
  milestone add <task-dir> <id> "<description>"
  milestone status <task-dir> <id> <pending|active|done> ["<evidence>"]
                                     (done requires evidence)
  ac add <task-dir> <id> "<criterion>"
  ac status <task-dir> <id> <pending|pass|fail|inconclusive> ["<evidence>"]
  phase <task-dir> <phase>             set the current phase
  start-round <task-dir> "<objective>" increment the round and record the objective
  verdict <task-dir> <PASS|FAIL|INCONCLUSIVE> <gate> <evidence>
  finding <task-dir> <id> <severity> "<text>"
  finding resolve <task-dir> <id>       mark a finding resolved after a fix/re-review
  next <task-dir> "<action>"
  loop <task-dir>                      goal-aware continue/complete check
  show <task-dir>
  check <task-dir>                     goal/AC/milestone completion check
  --help

Exit: 0 pass/goal complete, 1 incomplete/check failure, 2 usage.
A round is a progress unit, not a goal. Continue until every AC has evidence-
backed PASS and every milestone is done, or until a real stop condition.
No source files, Git state, or files outside the task directory are written.
EOF
}

log() { printf '%s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; return 1; }
need_dir() {
    if [ -z "${1:-}" ]; then fail "missing task directory (run --help)"; return 2; fi
    if [ ! -d "$1" ]; then fail "task directory not found: $1"; return 1; fi
}
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
state_file() { printf '%s/output/task-state.md\n' "$1"; }
rounds_file() { printf '%s/output/rounds.tsv\n' "$1"; }
findings_file() { printf '%s/output/findings.tsv\n' "$1"; }

set_field() {
    _tmp="$(mktemp "${TMPDIR:-/tmp}/loop-state.XXXXXX")" || return 1
    awk -v k="$2" -v v="$3" '
        BEGIN { done = 0 }
        index($0, k ":") == 1 { print k ": " v; done = 1; next }
        { print }
        END { if (!done) print k ": " v }
    ' "$1" > "$_tmp" && mv "$_tmp" "$1"
    _rc=$?
    rm -f "$_tmp" 2>/dev/null || true
    return "$_rc"
}

update_state() {
    _st="$1"; shift
    while [ "$#" -gt 1 ]; do
        set_field "$_st" "$1" "$2" || { fail "cannot update $_st"; return 1; }
        shift 2
    done
}

init_state() {
    need_dir "$@" || return $?
    _dir="$1"; _out="$_dir/output"
    mkdir -p "$_out" || { fail "cannot create $_out"; return 1; }
    _state="$(state_file "$_dir")"
    if [ -f "$_state" ]; then log "state exists: $_state"; return 0; fi
    _template="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/task-state-template.md"
    if [ -f "$_template" ]; then cp "$_template" "$_state"; else
        printf '# Task state\n\nphase: intake\nround: 0\nupdated: %s\nnext action: <set>\n' "$(now)" > "$_state"
    fi
    if ! update_state "$_state" updated "$(now)"; then
        rm -f "$_state"
        return 1
    fi
    log "created $_state"
}

set_phase() {
    need_dir "$@" || return $?
    _dir="$1"; _phase="${2:-}"
    [ -n "$_phase" ] || { fail "missing phase"; return 2; }
    case "$_phase" in
        intake|evidence|ir|implement|build|debug|review|handoff|blocked) ;;
        *) fail "invalid phase: $_phase"; return 2 ;;
    esac
    _state="$(state_file "$_dir")"
    [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    update_state "$_state" phase "$_phase" updated "$(now)" || return 1
    log "phase=$_phase"
}

start_round() {
    need_dir "$@" || return $?
    _dir="$1"; _objective="${2:-}"
    [ -n "$_objective" ] || { fail "missing round objective"; return 2; }
    _state="$(state_file "$_dir")"
    [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _goal="$(goal_value "$_state")"
    case "$_goal" in
        ''|'<'*) fail "set the goal before starting a round: loop-state.sh goal <task-dir> \"<goal>\""; return 1 ;;
    esac
    _round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
    case "$_round" in ''|*[!0-9]*) _round=0 ;; esac
    _round=$((_round + 1))
    update_state "$_state" round "$_round" objective "$_objective" phase implement "review status" not-requested updated "$(now)" || return 1
    log "round=$_round objective=$_objective"
}

acquire_lock() {
    _lock="$1"; _tries=0
    while ! mkdir "$_lock" 2>/dev/null; do
        _tries=$((_tries + 1))
        [ "$_tries" -ge 100 ] && return 1
        sleep 0.05
    done
}

release_lock() {
    rmdir "$1" 2>/dev/null || true
}

valid_pass() {
    _vp_gate="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    _vp_evidence="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
    case "$_vp_gate" in ''|none|n/a|-) return 1 ;; esac
    case "$_vp_gate" in *timeout*|*'timed out'*|*'no crash'*|*'no marker'*|*'empty log'*|*'empty serial'*) return 1 ;; esac
    case "$_vp_gate" in *marker*|*qtest*|*test*|*expected*) ;; *) return 1 ;; esac
    case "$_vp_evidence" in ''|none|n/a|-) return 1 ;; esac
    return 0
}

record_verdict() {
    need_dir "$@" || return $?
    _dir="$1"; _verdict="${2:-}"; _gate="${3:-}"; _evidence="${4:-}"
    case "$_verdict" in PASS|FAIL|INCONCLUSIVE) ;; *) fail "invalid verdict: $_verdict"; return 2 ;; esac
    [ -n "$_gate" ] && [ -n "$_evidence" ] || { fail "verdict requires gate and evidence"; return 2; }
    if [ "$_verdict" = PASS ] && ! valid_pass "$_gate" "$_evidence"; then
        fail "PASS verdict needs a marker/qtest/test gate and non-empty evidence, not timeout/none"; return 1
    fi
    _state="$(state_file "$_dir")"
    _lock="$_dir/output/.rounds.lock"
    if ! acquire_lock "$_lock"; then fail "cannot acquire verdict lock: $_lock"; return 1; fi
    if [ ! -f "$_state" ]; then release_lock "$_lock"; fail "state not initialized: $_state"; return 1; fi
    _round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
    case "$_round" in ''|*[!0-9]*) _round=0 ;; esac
    _rounds="$(rounds_file "$_dir")"
    if [ -d "$_rounds" ]; then release_lock "$_lock"; fail "round history is a directory: $_rounds"; return 1; fi
    _state_backup="$(mktemp "${TMPDIR:-/tmp}/loop-state.XXXXXX")" || { release_lock "$_lock"; fail "cannot stage $_state"; return 1; }
    if ! cp "$_state" "$_state_backup"; then rm -f "$_state_backup"; release_lock "$_lock"; fail "cannot stage $_state"; return 1; fi
    if ! update_state "$_state" "review status" "$_verdict" updated "$(now)"; then
        cp "$_state_backup" "$_state" 2>/dev/null || true
        rm -f "$_state_backup"; release_lock "$_lock"; return 1
    fi
    if [ ! -f "$_rounds" ]; then
        if ! printf 'round\tverdict\tgate\tevidence\tupdated\n' > "$_rounds"; then
            cp "$_state_backup" "$_state" 2>/dev/null || true
            rm -f "$_state_backup"; release_lock "$_lock"; fail "cannot create $_rounds"; return 1
        fi
    fi
    if ! printf '%s\t%s\t%s\t%s\t%s\n' "$_round" "$_verdict" "$_gate" "$_evidence" "$(now)" >> "$_rounds"; then
        cp "$_state_backup" "$_state" 2>/dev/null || true
        rm -f "$_state_backup"; release_lock "$_lock"; fail "cannot append $_rounds"; return 1
    fi
    rm -f "$_state_backup"
    release_lock "$_lock"
    log "verdict=$_verdict round=$_round evidence=$_evidence"
}

add_finding() {
    need_dir "$@" || return $?
    _dir="$1"; _id="${2:-}"; _severity="${3:-}"; _text="${4:-}"
    [ -n "$_id" ] && [ -n "$_severity" ] && [ -n "$_text" ] || { fail "finding needs id, severity, text"; return 2; }
    case "$_severity" in BLOCKER|MAJOR|MINOR|NOTE) ;; *) fail "invalid severity: $_severity"; return 2 ;; esac
    _state="$(state_file "$_dir")"
    [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _findings="$(findings_file "$_dir")"
    if [ ! -d "$(dirname "$_findings")" ]; then fail "output directory missing: $(dirname "$_findings")"; return 1; fi
    if [ ! -f "$_findings" ]; then
        printf 'id\tseverity\ttext\tupdated\tstatus\n' > "$_findings" || { fail "cannot write $_findings"; return 1; }
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$_id" "$_severity" "$_text" "$(now)" open >> "$_findings" || { fail "cannot append $_findings"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "finding=$_id severity=$_severity status=open"
}

resolve_finding() {
    need_dir "$@" || return $?
    _dir="$1"; _id="$2"
    [ -n "$_id" ] || { fail "finding resolve needs an id"; return 2; }
    _findings="$(findings_file "$_dir")"
    [ -f "$_findings" ] || { fail "no findings file: $_findings"; return 1; }
    _tmp="$(mktemp "${TMPDIR:-/tmp}/loop-finding.XXXXXX")" || { fail "cannot stage findings"; return 1; }
    if ! awk -F'\t' -v OFS='\t' -v id="$_id" -v ts="$(now)" '
        $1==id { $5="resolved"; $4=ts; found=1 }
        { print }
        END { exit !found }
    ' "$_findings" > "$_tmp"; then
        rm -f "$_tmp"; fail "finding not found: $_id"; return 1
    fi
    mv "$_tmp" "$_findings" || { rm -f "$_tmp"; fail "cannot update $_findings"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "finding=$_id status=resolved"
}

set_next() {
    need_dir "$@" || return $?
    _dir="$1"; _action="${2:-}"; [ -n "$_action" ] || { fail "missing next action"; return 2; }
    _state="$(state_file "$_dir")"; [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    update_state "$_state" "next action" "$_action" updated "$(now)" || return 1
    log "next=$_action"
}

milestones_file() { printf '%s/output/milestones.tsv\n' "$1"; }
acceptance_file() { printf '%s/output/acceptance.tsv\n' "$1"; }
goal_value() { awk '/^goal:/ { line=$0; sub(/^goal:[[:space:]]*/, "", line); print line; exit }' "$1"; }
goal_mode_value() { awk -F': ' '/^goal mode:/ { print $2; exit }' "$1"; }

ensure_tsv() {
    _f="$1"; _header="$2"
    if [ ! -f "$_f" ]; then
        printf '%s\n' "$_header" > "$_f" || return 1
    fi
}

invalidate_review() {
    _inv_state="$(state_file "$1")"
    if [ -f "$_inv_state" ]; then
        update_state "$_inv_state" "review status" not-requested updated "$(now)" || return 1
    fi
}

set_goal() {
    need_dir "$@" || return $?
    _dir="$1"; _goal="$2"; _mode="${3:-goal}"
    [ -n "$_goal" ] || { fail "goal text required"; return 2; }
    case "$_mode" in goal|round) ;; *) fail "goal mode must be goal or round"; return 2 ;; esac
    _state="$(state_file "$_dir")"
    [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _existing_goal="$(goal_value "$_state")"
    case "$_existing_goal" in
        ''|'<'*) ;;
        *) [ "$_existing_goal" = "$_goal" ] || { fail "goal is already set; keep it stable or start a new task"; return 1; } ;;
    esac
    _round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
    case "$_round" in ''|*[!0-9]*) _round=0 ;; esac
    _baseline="none"
    [ "$_mode" = round ] && _baseline="$_round"
    update_state "$_state" goal "$_goal" "goal mode" "$_mode" "round mode baseline" "$_baseline" updated "$(now)" || return 1
    log "goal=$_goal mode=$_mode baseline=$_baseline"
}

add_milestone() {
    need_dir "$@" || return $?
    _dir="$1"; _id="$2"; _desc="$3"
    [ -n "$_id" ] && [ -n "$_desc" ] || { fail "milestone needs id and description"; return 2; }
    _desc="$(printf '%s' "$_desc" | tr '\t' ' ')"
    _state="$(state_file "$_dir")"; [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _f="$(milestones_file "$_dir")"
    [ -d "$(dirname "$_f")" ] || { fail "output directory missing"; return 1; }
    ensure_tsv "$_f" $'id\tstatus\tdescription\tevidence\tupdated' || { fail "cannot create $_f"; return 1; }
    if awk -F'\t' -v id="$_id" '$1==id{found=1} END{exit !found}' "$_f"; then
        fail "duplicate milestone: $_id"; return 1
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$_id" pending "$_desc" - "$(now)" >> "$_f" || { fail "cannot append $_f"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "milestone=$_id status=pending"
}

set_milestone_status() {
    need_dir "$@" || return $?
    _dir="$1"; _id="$2"; _status="$3"; _evidence="${4:-}"
    [ -n "$_id" ] && [ -n "$_status" ] || { fail "milestone status needs id and status"; return 2; }
    case "$_status" in pending|active|done) ;; *) fail "milestone status must be pending, active, or done"; return 2 ;; esac
    _f="$(milestones_file "$_dir")"
    [ -f "$_f" ] || { fail "no milestones file: $_f"; return 1; }
    _old="$(awk -F'\t' -v id="$_id" '$1==id{print $4; exit}' "$_f")"
    [ -n "$_evidence" ] || _evidence="$_old"
    [ -n "$_evidence" ] || _evidence="-"
    if [ "$_status" = done ] && { [ "$_evidence" = "-" ] || [ -z "$_evidence" ]; }; then
        fail "done milestone needs evidence (exit gate/artifact)"; return 1
    fi
    _tmp="$(mktemp "${TMPDIR:-/tmp}/loop-ms.XXXXXX")" || { fail "cannot stage milestones"; return 1; }
    if ! awk -F'\t' -v OFS='\t' -v id="$_id" -v status="$_status" -v evidence="$_evidence" -v ts="$(now)" '
        $1==id { $2=status; $4=evidence; $5=ts; found=1 }
        { print }
        END { exit !found }
    ' "$_f" > "$_tmp"; then
        rm -f "$_tmp"; fail "milestone not found: $_id"; return 1
    fi
    mv "$_tmp" "$_f" || { rm -f "$_tmp"; fail "cannot update $_f"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "milestone=$_id status=$_status evidence=$_evidence"
}

add_ac() {
    need_dir "$@" || return $?
    _dir="$1"; _id="$2"; _criterion="$3"
    [ -n "$_id" ] && [ -n "$_criterion" ] || { fail "AC needs id and criterion"; return 2; }
    _criterion="$(printf '%s' "$_criterion" | tr '\t' ' ')"
    _state="$(state_file "$_dir")"; [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _f="$(acceptance_file "$_dir")"
    [ -d "$(dirname "$_f")" ] || { fail "output directory missing"; return 1; }
    ensure_tsv "$_f" $'id\tstatus\tcriterion\tevidence\tupdated' || { fail "cannot create $_f"; return 1; }
    if awk -F'\t' -v id="$_id" '$1==id{found=1} END{exit !found}' "$_f"; then
        fail "duplicate AC: $_id"; return 1
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$_id" pending "$_criterion" - "$(now)" >> "$_f" || { fail "cannot append $_f"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "ac=$_id status=pending"
}

set_ac_status() {
    need_dir "$@" || return $?
    _dir="$1"; _id="$2"; _status="$3"; _evidence="${4:-}"
    [ -n "$_id" ] && [ -n "$_status" ] || { fail "AC status needs id and status"; return 2; }
    case "$_status" in pending|pass|fail|inconclusive) ;; *) fail "AC status must be pending, pass, fail, or inconclusive"; return 2 ;; esac
    _f="$(acceptance_file "$_dir")"
    [ -f "$_f" ] || { fail "no acceptance file: $_f"; return 1; }
    _old="$(awk -F'\t' -v id="$_id" '$1==id{print $4; exit}' "$_f")"
    if [ "$_status" = pass ] && { [ "$_evidence" = "-" ] || [ -z "$_evidence" ]; }; then
        fail "PASS AC needs fresh explicit evidence, not inherited from another status"; return 1
    fi
    [ -n "$_evidence" ] || _evidence="$_old"
    [ -n "$_evidence" ] || _evidence="-"
    _tmp="$(mktemp "${TMPDIR:-/tmp}/loop-ac.XXXXXX")" || { fail "cannot stage acceptance"; return 1; }
    if ! awk -F'\t' -v OFS='\t' -v id="$_id" -v status="$_status" -v evidence="$_evidence" -v ts="$(now)" '
        $1==id { $2=status; $4=evidence; $5=ts; found=1 }
        { print }
        END { exit !found }
    ' "$_f" > "$_tmp"; then
        rm -f "$_tmp"; fail "AC not found: $_id"; return 1
    fi
    mv "$_tmp" "$_f" || { rm -f "$_tmp"; fail "cannot update $_f"; return 1; }
    invalidate_review "$_dir" || { fail "cannot invalidate review state"; return 1; }
    log "ac=$_id status=$_status evidence=$_evidence"
}

show_goal_status() {
    _dir="$1"
    _state="$(state_file "$_dir")"
    log "== goal"
    sed -n '/^goal:/p;/^goal mode:/p' "$_state" 2>/dev/null || true
    _ms="$(milestones_file "$_dir")"
    _ac="$(acceptance_file "$_dir")"
    if [ -f "$_ms" ]; then
        _total=$(awk 'END { print NR-1 }' "$_ms"); [ "$_total" -lt 0 ] && _total=0
        _done=$(awk -F'\t' '$2=="done" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ms")
        log "milestones: $_done/$_total evidence-backed done"
        awk -F'\t' 'NR > 1 && ($2 != "done" || $4 == "-" || $4 == "") { print "  PENDING milestone " $1 ": " $3 }' "$_ms"
    else
        log "milestones: 0/0 done (not initialized)"
    fi
    if [ -f "$_ac" ]; then
        _atotal=$(awk 'END { print NR-1 }' "$_ac"); [ "$_atotal" -lt 0 ] && _atotal=0
        _apass=$(awk -F'\t' '$2=="pass" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ac")
        log "acceptance: $_apass/$_atotal evidence-backed PASS"
        awk -F'\t' 'NR > 1 && ($2 != "pass" || $4 == "-" || $4 == "") { print "  OPEN AC " $1 ": status=" $2 " -> " $3 }' "$_ac"
    else
        log "acceptance: 0/0 evidence-backed PASS (not initialized)"
    fi
}

round_result_block() {
    _rblk_file="$1"; _rblk_round="$2"
    if _rblk="$(awk -v want="$_rblk_round" '
        /^##[[:space:]]+Round[[:space:]]+[0-9]+/ {
            line=$0
            sub(/^##[[:space:]]+Round[[:space:]]+/, "", line)
            sub(/[^0-9].*$/, "", line)
            if (line == want) { capture=1; found=1; block=$0 "\n"; next }
            if (capture) capture=0
            next
        }
        capture { block=block $0 "\n" }
        END { if (!found) exit 1; printf "%s", block }
    ' "$_rblk_file")"; then
        printf '%s\n' "$_rblk"; return 0
    fi
    awk -v want="$_rblk_round" '
        $0 ~ ("^[[:space:]]*Round:[[:space:]]*" want "[[:space:]]*$") { inblk=1; found=1 }
        inblk { print }
        END { exit !found }
    ' "$_rblk_file"
}

loop_goal() {
    need_dir "$@" || return $?
    _dir="$1"
    _state="$(state_file "$_dir")"
    [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    _mode="$(goal_mode_value "$_state")"
    case "$_mode" in
        round)
            _round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
            case "$_round" in ''|*[!0-9]*) _round=0 ;; esac
            _baseline="$(awk -F': ' '/^round mode baseline:/ { print $2; exit }' "$_state")"
            case "$_baseline" in ''|none|*[!0-9]*) _baseline=0 ;; esac
            if [ "$_round" -le "$_baseline" ]; then
                log "ROUND MODE: run the requested round (baseline=$_baseline, current=$_round); goal-mode continuation is disabled."
                return 1
            fi
            _rr="$_dir/output/round-result.md"
            if [ ! -f "$_rr" ]; then
                log "ROUND MODE: round $_round has no round-result yet; finish and record that round before handoff."
                return 1
            fi
            if ! _rr_block="$(round_result_block "$_rr" "$_round")"; then
                log "ROUND MODE: round $_round has no matching round-result section; finish and record that round before handoff."
                return 1
            fi
            _rr_verdict="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?(verdict|status):' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?(verdict|status):[[:space:]]*//I' | awk '{ print toupper($1) }')"
            case "$_rr_verdict" in
                PASS|FAIL|INCONCLUSIVE) ;;
                *) log "ROUND MODE: round $_round has no valid verdict; complete review and record the round result first."; return 1 ;;
            esac
            _rr_gate="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?gate:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?gate:[[:space:]]*//I; s/[[:space:]]*$//')"
            _rr_evidence="$(printf '%s\n' "$_rr_block" | grep -iE '^[[:space:]]*(-[[:space:]]+)?evidence:' | sed -n '1p' | sed -E 's/^[[:space:]]*(-[[:space:]]+)?evidence:[[:space:]]*//I; s/[[:space:]]*$//')"
            if [ -z "$_rr_gate" ] || [ -z "$_rr_evidence" ]; then
                log "ROUND MODE: round $_round result needs gate and evidence before handoff."
                return 1
            fi
            _review="$(awk -F': ' '/^review status:/ { print $2; exit }' "$_state")"
            case "$_review" in
                PASS|FAIL|INCONCLUSIVE) ;;
                *) log "ROUND MODE: review status is $_review; complete independent review before handoff."; return 1 ;;
            esac
            _last_round="$(awk -F'\t' 'NR > 1 { r=$1 } END { print r }' "$(rounds_file "$_dir")" 2>/dev/null)"
            _last_verdict="$(awk -F'\t' 'NR > 1 { v=$2 } END { print v }' "$(rounds_file "$_dir")" 2>/dev/null)"
            if [ "$_last_round" != "$_round" ] || [ "$_last_verdict" != "$_rr_verdict" ]; then
                log "ROUND MODE: round $_round is not validated by the recorded round history; record the verdict before handoff."
                return 1
            fi
            log "ROUND COMPLETE: validated round $_round ($_rr_verdict); handoff after the requested single round; goal-mode continuation is disabled."
            return 0
            ;;
        goal|'')
            check_state "$_dir"
            ;;
        *)
            fail "invalid goal mode in $_state: $_mode"; return 2
            ;;
    esac
}

show_state() {
    need_dir "$@" || return $?
    _dir="$1"
    log "== task-state: $_dir"
    if [ -f "$(state_file "$_dir")" ]; then sed -n '1,80p' "$(state_file "$_dir")"; else fail "state missing"; return 1; fi
    if [ -f "$(rounds_file "$_dir")" ]; then log "== rounds"; sed -n '1,20p' "$(rounds_file "$_dir")"; fi
    show_goal_status "$_dir"
}

check_state() {
    need_dir "$@" || return $?
    _dir="$1"; _fail=0
    [ -f "$_dir/audit.md" ] || { fail "missing audit.md"; _fail=1; }
    [ -f "$_dir/commands.md" ] || { fail "missing commands.md"; _fail=1; }
    _state="$(state_file "$_dir")"
    if [ ! -f "$_state" ]; then fail "missing output/task-state.md"; _fail=1; fi
    _goal="$(goal_value "$_state" 2>/dev/null || true)"
    case "$_goal" in
        ''|'<'*) fail "goal not set: run loop-state.sh goal <task-dir> \"<goal>\""; _fail=1 ;;
    esac
    _ms="$(milestones_file "$_dir")"
    _ac="$(acceptance_file "$_dir")"
    _m_total=0; _m_done=0; _a_total=0; _a_pass=0
    if [ ! -f "$_ms" ]; then
        fail "no milestones: add at least one with loop-state.sh milestone add"; _fail=1
    else
        _m_total=$(awk 'END { print NR-1 }' "$_ms"); [ "$_m_total" -lt 0 ] && _m_total=0
        _m_done=$(awk -F'\t' '$2=="done" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ms")
    fi
    if [ ! -f "$_ac" ]; then
        fail "no acceptance criteria: add at least one with loop-state.sh ac add"; _fail=1
    else
        _a_total=$(awk 'END { print NR-1 }' "$_ac"); [ "$_a_total" -lt 0 ] && _a_total=0
        _a_pass=$(awk -F'\t' '$2=="pass" && $4!="-" && $4!=""{n++} END{print n+0}' "$_ac")
    fi
    [ "$_m_total" -lt 2 ] && { fail "goal contract needs 2-5 milestones (found $_m_total)"; _fail=1; }
    [ "$_m_total" -gt 5 ] && { fail "goal contract needs 2-5 milestones (found $_m_total)"; _fail=1; }
    [ "$_a_total" -lt 1 ] && { fail "acceptance list is empty"; _fail=1; }
    [ "$_m_done" -ne "$_m_total" ] && { fail "milestones pending or lacking evidence: $_m_done/$_m_total evidence-backed done"; _fail=1; }
    [ "$_a_pass" -ne "$_a_total" ] && { fail "acceptance pending: $_a_pass/$_a_total evidence-backed PASS"; _fail=1; }
    if [ -f "$(findings_file "$_dir")" ]; then
        _blockers=$(awk -F'\t' 'NR > 1 && $2=="BLOCKER" && ($5=="" || $5=="open"){n++} END{print n+0}' "$(findings_file "$_dir")")
        [ "$_blockers" -gt 0 ] && { fail "unresolved BLOCKER findings: $_blockers"; _fail=1; }
    fi
    if [ "$_fail" -eq 0 ]; then
        _review="$(awk -F': ' '/^review status:/ { print $2; exit }' "$_state")"
        [ "$_review" = PASS ] || { fail "current review status is not PASS: $_review"; _fail=1; }
        _current_round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
        _last_round="$(awk -F'\t' 'NR > 1 { r=$1 } END { print r }' "$(rounds_file "$_dir")" 2>/dev/null)"
        _last_verdict="$(awk -F'\t' 'NR > 1 { v=$2 } END { print v }' "$(rounds_file "$_dir")" 2>/dev/null)"
        [ "$_last_round" = "$_current_round" ] || { fail "latest verdict is for round ${_last_round:-missing}, current round is ${_current_round:-missing}"; _fail=1; }
        [ "$_last_verdict" = PASS ] || { fail "latest round verdict is not PASS: ${_last_verdict:-missing}"; _fail=1; }
        _last_gate="$(awk -F'\t' 'NR > 1 { g=$3 } END { print g }' "$(rounds_file "$_dir")" 2>/dev/null)"
        _last_evidence="$(awk -F'\t' 'NR > 1 { e=$4 } END { print e }' "$(rounds_file "$_dir")" 2>/dev/null)"
        if [ "$_last_verdict" = PASS ] && ! valid_pass "$_last_gate" "$_last_evidence"; then
            fail "latest PASS verdict lacks a validated gate/evidence"; _fail=1
        fi
    fi
    show_goal_status "$_dir"
    if [ "$_fail" -eq 0 ]; then
        log "PASS goal complete: $_goal"
        return 0
    fi
    log "CONTINUE goal active: $_goal"
    return 1
}

main() {
    _cmd="${1:-}"
    case "$_cmd" in
        ''|-h|--help|help) usage; return 0 ;;
        init) shift; init_state "$@" ;;
        goal) shift; set_goal "$@" ;;
        milestone)
            shift
            _sub="${1:-}"; shift 2>/dev/null || true
            case "$_sub" in
                add) add_milestone "$@" ;;
                status) set_milestone_status "$@" ;;
                *) fail "milestone requires add or status"; return 2 ;;
            esac
            ;;
        ac)
            shift
            _sub="${1:-}"; shift 2>/dev/null || true
            case "$_sub" in
                add) add_ac "$@" ;;
                status) set_ac_status "$@" ;;
                *) fail "ac requires add or status"; return 2 ;;
            esac
            ;;
        phase) shift; set_phase "$@" ;;
        start-round) shift; start_round "$@" ;;
        verdict) shift; record_verdict "$@" ;;
        finding)
            shift
            if [ "${1:-}" = resolve ]; then
                shift; resolve_finding "$@"
            else
                add_finding "$@"
            fi
            ;;
        next) shift; set_next "$@" ;;
        loop) shift; loop_goal "$@" ;;
        show) shift; show_state "$@" ;;
        check) shift; check_state "$@" ;;
        *) fail "unknown command: $_cmd (run --help)"; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
