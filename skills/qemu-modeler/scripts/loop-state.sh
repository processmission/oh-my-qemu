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
  phase <task-dir> <phase>             set the current phase
  start-round <task-dir> "<objective>" increment the round and record the objective
  verdict <task-dir> <PASS|FAIL|INCONCLUSIVE> <gate> <evidence>
  finding <task-dir> <id> <severity> "<text>"
  next <task-dir> "<action>"
  show <task-dir>
  check <task-dir>
  --help

Exit: 0 pass, 1 check failure, 2 usage.
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
    _round="$(awk -F': ' '/^round:/ { print $2; exit }' "$_state")"
    case "$_round" in ''|*[!0-9]*) _round=0 ;; esac
    _round=$((_round + 1))
    update_state "$_state" round "$_round" objective "$_objective" phase implement updated "$(now)" || return 1
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

record_verdict() {
    need_dir "$@" || return $?
    _dir="$1"; _verdict="${2:-}"; _gate="${3:-}"; _evidence="${4:-}"
    case "$_verdict" in PASS|FAIL|INCONCLUSIVE) ;; *) fail "invalid verdict: $_verdict"; return 2 ;; esac
    [ -n "$_gate" ] && [ -n "$_evidence" ] || { fail "verdict requires gate and evidence"; return 2; }
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
        printf 'id\tseverity\ttext\tupdated\n' > "$_findings" || { fail "cannot write $_findings"; return 1; }
    fi
    printf '%s\t%s\t%s\t%s\n' "$_id" "$_severity" "$_text" "$(now)" >> "$_findings" || { fail "cannot append $_findings"; return 1; }
    log "finding=$_id severity=$_severity"
}

set_next() {
    need_dir "$@" || return $?
    _dir="$1"; _action="${2:-}"; [ -n "$_action" ] || { fail "missing next action"; return 2; }
    _state="$(state_file "$_dir")"; [ -f "$_state" ] || { fail "state not initialized: $_state"; return 1; }
    update_state "$_state" "next action" "$_action" updated "$(now)" || return 1
    log "next=$_action"
}

show_state() {
    need_dir "$@" || return $?
    _dir="$1"
    log "== task-state: $_dir"
    if [ -f "$(state_file "$_dir")" ]; then sed -n '1,80p' "$(state_file "$_dir")"; else fail "state missing"; return 1; fi
    if [ -f "$(rounds_file "$_dir")" ]; then log "== rounds"; sed -n '1,20p' "$(rounds_file "$_dir")"; fi
}

check_state() {
    need_dir "$@" || return $?
    _dir="$1"; _fail=0
    [ -f "$_dir/audit.md" ] || { fail "missing audit.md"; _fail=1; }
    [ -f "$_dir/commands.md" ] || { fail "missing commands.md"; _fail=1; }
    [ -f "$(state_file "$_dir")" ] || { fail "missing output/task-state.md"; _fail=1; }
    [ "$_fail" -eq 0 ] && log "PASS state/audit files present: $_dir"
    return "$_fail"
}

main() {
    _cmd="${1:-}"
    case "$_cmd" in
        ''|-h|--help|help) usage; return 0 ;;
        init) shift; init_state "$@" ;;
        phase) shift; set_phase "$@" ;;
        start-round) shift; start_round "$@" ;;
        verdict) shift; record_verdict "$@" ;;
        finding) shift; add_finding "$@" ;;
        next) shift; set_next "$@" ;;
        show) shift; show_state "$@" ;;
        check) shift; check_state "$@" ;;
        *) fail "unknown command: $_cmd (run --help)"; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
