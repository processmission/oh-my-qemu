#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
# gates.sh - optional hard gates for the qemu-workflow skill.
# Source it to call the gate_* functions, or run it as a CLI.
# Exit codes: 0 pass/skip, 1 fail, 2 usage; marker uses 2 for INCONCLUSIVE.
# Only writes: the repo info/exclude file and output/evidence-manifest.tsv.
set -u

usage() {
  printf '%s\n' \
    'Usage: gates.sh <subcommand> [args]' \
    'Subcommands: git-root, exclude, workspace, audit-sections, round-result,' \
    '  evidence-manifest, git-status, build-dir, marker, patch-series, source-comments,' \
    '  handoff, all' \
    '' \
    'Examples:' \
    '  gates.sh all .oh-my-qemu/<task-slug>' \
    '  gates.sh marker <serial.log> "<success-marker>"' \
    '  gates.sh evidence-manifest .oh-my-qemu/<task-slug> <files...>' \
    '' \
    'Run workspace/audit-sections after planning, round-result/marker after a round,' \
    'and handoff/git-status/evidence-manifest before handoff. A timeout or a missing' \
    'marker is INCONCLUSIVE, never PASS: let QEMU finalize the log first. Record any' \
    'skipped gate as a gap in audit.md.'
}

log() { printf '%s\n' "$*"; }
pass() { printf 'GATE PASS %s: %s\n' "$1" "$2"; }
fail() { printf 'GATE FAIL %s: %s\n' "$1" "$2"; }
skip() { printf 'GATE SKIP %s: %s\n' "$1" "$2"; }
warn() { printf 'GATE WARN %s: %s\n' "$1" "$2"; }
inconc() { printf 'GATE INCONCLUSIVE %s: %s\n' "$1" "$2"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_arg() {
  if [[ -z "${3:-}" ]]; then fail "$1" "usage: missing $2 (run --help)"; return 2; fi
  return 0
}
first_match() { grep -iE "$2" "$1" 2>/dev/null | sed -n '1p'; }
upper() { printf '%s\n' "$1" | awk '{ print toupper($0) }'; }
is_task_dir() {
  case "${1:-}" in .oh-my-qemu/*|*/.oh-my-qemu/*) return 0 ;; esac
  return 1
}
is_worktree() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
sha256_of() {
  local out
  if have_cmd sha256sum; then out=$(sha256sum "$1" 2>/dev/null) || return 1
  elif have_cmd shasum; then out=$(shasum -a 256 "$1" 2>/dev/null) || return 1
  else return 1; fi
  printf '%s\n' "${out%% *}"
}

gate_git_root() {
  local root
  if ! root=$(git rev-parse --show-toplevel 2>/dev/null) || [[ -z "$root" ]]; then
    fail 'git-root' 'not inside a Git worktree; record a non-Git provenance snapshot'; return 1
  fi
  pass 'git-root' "root=$root"
}

gate_exclude() {
  local root rel exclude entry added=0 unchanged=0
  is_worktree || { fail 'exclude' 'not inside a Git worktree'; return 1; }
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  rel=$(git -C "$root" rev-parse --git-path info/exclude 2>/dev/null)
  [[ -n "$rel" ]] || { fail 'exclude' 'cannot resolve info/exclude'; return 1; }
  case "$rel" in /*) exclude="$rel" ;; *) exclude="$root/$rel" ;; esac
  [[ -d "${exclude%/*}" ]] || { fail 'exclude' "exclude dir missing: ${exclude%/*}"; return 1; }
  [[ -f "$exclude" ]] || : > "$exclude"
  for entry in .agents/ .oh-my-qemu/ builds/; do
    if grep -qxF "$entry" "$exclude" 2>/dev/null || grep -qxF "${entry%/}" "$exclude" 2>/dev/null; then
      unchanged=$((unchanged + 1))
    else
      printf '%s\n' "$entry" >> "$exclude"; added=$((added + 1))
    fi
  done
  pass 'exclude' "added=$added unchanged=$unchanged file=$exclude (never .gitignore)"
}

gate_workspace() {
  local task_dir="${1:-}" file optional='' bad=0
  need_arg workspace task_dir "$task_dir" || return 2
  case "$task_dir" in *scratch*) fail workspace 'retired scratch directory; use scripts/ or output/'; return 1 ;; esac
  is_task_dir "$task_dir" || { fail workspace "task dir must be under .oh-my-qemu/: $task_dir"; return 1; }
  [[ -d "$task_dir" ]] || { fail workspace "task dir does not exist: $task_dir"; return 1; }
  for file in audit.md commands.md; do
    [[ -f "$task_dir/$file" ]] || { fail workspace "missing $file"; bad=1; }
    [[ ! -f "$task_dir/$file" || -s "$task_dir/$file" ]] || warn workspace "$file is empty"
  done
  for file in logs scripts output; do
    if [[ -d "$task_dir/$file" ]]; then optional="$optional $file=present"; else optional="$optional $file=absent"; fi
  done
  [[ "$bad" -eq 0 ]] || return 1
  pass workspace "task_dir=$task_dir$optional"
}

gate_audit_sections() {
  local file="${1:-}" heading missing=''
  need_arg audit-sections audit.md "$file" || return 2
  [[ -f "$file" ]] || { fail audit-sections "missing audit file: $file"; return 1; }
  while IFS= read -r heading; do
    grep -qxF "## $heading" "$file" || missing="$missing | $heading"
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
  [[ -z "$missing" ]] || { fail audit-sections "missing sections:$missing"; return 1; }
  pass audit-sections "file=$file sections=11"
}

gate_round_result() {
  local file="${1:-}" status_line status gate_line evidence_line text blocker
  need_arg round-result round-result.md "$file" || return 2
  [[ -f "$file" ]] || { fail round-result "missing file: $file"; return 1; }
  status_line=$(first_match "$file" '^[[:space:]]*(-[[:space:]]+)?(verdict|status):')
  [[ -n "$status_line" ]] || { fail round-result 'missing VERDICT or STATUS line'; return 1; }
  status=$(upper "$(printf '%s\n' "$status_line" | sed -E 's/^[[:space:]]*(-[[:space:]]+)?(verdict|status):[[:space:]]*//I' | awk '{ print $1 }')")
  case "$status" in
    PASS|FAIL|INCONCLUSIVE) ;;
    *) fail round-result 'VERDICT/STATUS must be exactly PASS, FAIL, or INCONCLUSIVE'; return 1 ;;
  esac
  if [[ "$status" == 'PASS' ]]; then
    gate_line=$(first_match "$file" '^[[:space:]]*(-[[:space:]]+)?(gate|gate check):')
    evidence_line=$(first_match "$file" '^[[:space:]]*(-[[:space:]]+)?evidence([[:space:]]+paths?)?:')
    [[ -n "$gate_line" ]] || { fail round-result 'PASS requires a gate line naming a marker or test'; return 1; }
    text=$(printf '%s %s\n' "$gate_line" "$evidence_line" | awk '{ print tolower($0) }')
    case "$text" in *timeout*|*'no marker'*|*'no-marker'*|*'empty serial'*)
      fail round-result 'PASS cannot rest on timeout, no-marker, or empty-serial evidence'; return 1 ;; esac
    case "$text" in *marker*|*test*) ;; *) fail round-result 'PASS gate line must name a configured marker or test'; return 1 ;; esac
    case "$text" in *logs/*|*output/*|*tests/*|*.log*) ;; *) fail round-result 'PASS requires an evidence path under logs/, output/, or tests/'; return 1 ;; esac
    pass round-result 'status=PASS gate and evidence recorded'; return 0
  fi
  blocker=$(first_match "$file" '^[[:space:]]*(-[[:space:]]+)?next[ -]blocker:')
  [[ -n "$blocker" ]] || { fail round-result "status=$status requires a next-blocker line"; return 1; }
  if printf '%s\n' "$blocker" | grep -qiE ':(.*[[:space:]])?none[[:space:]]*$'; then
    fail round-result "status=$status requires a concrete next blocker, not none"; return 1
  fi
  pass round-result "status=$status next blocker recorded"
}

gate_evidence_manifest() {
  local task_dir="${1:-}" out rows='' file hash count=0
  need_arg evidence-manifest task_dir "$task_dir" || return 2
  shift
  need_arg evidence-manifest 'one or more evidence files' "${1:-}" || return 2
  is_task_dir "$task_dir" || { fail evidence-manifest "task dir must be under .oh-my-qemu/: $task_dir"; return 1; }
  [[ -d "$task_dir/output" ]] || { fail evidence-manifest "missing task output dir: $task_dir/output"; return 1; }
  for file in "$@"; do
    [[ -f "$file" ]] || { fail evidence-manifest "missing file: $file"; return 1; }
    [[ -s "$file" ]] || { fail evidence-manifest "empty file: $file"; return 1; }
    hash=$(sha256_of "$file") || { fail evidence-manifest "sha256sum and shasum unavailable: $file"; return 1; }
    rows="${rows}${hash}	${file}"$'\n'; count=$((count + 1))
  done
  out="$task_dir/output/evidence-manifest.tsv"
  printf 'sha256\tpath\n' > "$out"
  printf '%s' "$rows" | awk '{ line[NR] = $0 } END { for (i = 1; i <= NR; i++) for (j = i + 1; j <= NR; j++) if (line[i] > line[j]) { t = line[i]; line[i] = line[j]; line[j] = t } for (i = 1; i <= NR; i++) print line[i] }' >> "$out"
  pass evidence-manifest "wrote $out entries=$count"
}

gate_git_status() {
  local baseline="${1:-}" current tracked bad pre_count=0 new_count=0 resolved_count=0 new_lines resolved_lines
  need_arg git-status baseline_status_file "$baseline" || return 2
  is_worktree || { fail git-status 'not inside a Git worktree'; return 1; }
  [[ -f "$baseline" ]] || { fail git-status "missing baseline status file: $baseline"; return 1; }
  current=$(git status --short 2>/dev/null)
  tracked=$(git ls-files --cached -- .agents/ .oh-my-qemu/ builds/ 2>/dev/null)
  bad=$(printf '%s\n' "$current" | grep -E '(^|[[:space:]])(\.agents|\.oh-my-qemu|builds)/' | sed -n '1,3p')
  if [[ -n "$tracked" || -n "$bad" ]]; then
    fail git-status "excluded paths are staged, tracked, or untracked: $(printf '%s\n' "$tracked" "$bad" | sed -n '1,3p')"; return 1
  fi
  pre_count=$(grep -c . "$baseline" 2>/dev/null) || pre_count=0
  new_lines=$(awk 'NR == FNR { base[$0] = 1; next } !($0 in base) && length($0) > 0 { print }' "$baseline" <(printf '%s\n' "$current"))
  resolved_lines=$(awk 'NR == FNR { cur[$0] = 1; next } !($0 in cur) && length($0) > 0 { print }' <(printf '%s\n' "$current") "$baseline")
  [[ -z "$new_lines" ]] || new_count=$(printf '%s\n' "$new_lines" | grep -c .)
  [[ -z "$resolved_lines" ]] || resolved_count=$(printf '%s\n' "$resolved_lines" | grep -c .)
  printf '%s\n' "$new_lines" | awk 'length($0) > 0 { print "  new: " $0 }'
  pass git-status "pre-existing=$pre_count new=$new_count resolved=$resolved_count"
}

gate_build_dir() {
  local dir="${1:-}" configured
  need_arg build-dir build_dir "$dir" || return 2
  case "$dir" in build|build/|*/build|*/build/) fail build-dir "unqualified build/ is not allowed: $dir"; return 1 ;; esac
  case "$dir" in builds/build-*|*/builds/build-*) ;; *) fail build-dir "build dir must match builds/build-<target>: $dir"; return 1 ;; esac
  [[ -d "$dir" ]] || { fail build-dir "build dir does not exist: $dir"; return 1; }
  [[ -f "$dir/config.log" ]] || { fail build-dir "missing config.log in $dir"; return 1; }
  configured=$(grep -m 1 -F 'Configured with:' "$dir/config.log" 2>/dev/null)
  if [[ -z "$configured" ]]; then pass build-dir "dir=$dir config.log present; configure command not recorded"; return 0; fi
  pass build-dir "dir=$dir $configured"
}

gate_marker() {
  local log_file="${1:-}" success="${2:-}" failure="${3:-}"
  need_arg marker log "$log_file" || return 2
  need_arg marker success_marker "$success" || return 2
  [[ -f "$log_file" ]] || { fail marker "missing log: $log_file (let QEMU finalize the log first)"; return 1; }
  [[ -s "$log_file" ]] || { inconc marker 'empty log: no marker yet; timeout or no marker is INCONCLUSIVE'; return 2; }
  if [[ -n "$failure" ]] && grep -Fq -- "$failure" "$log_file"; then fail marker "failure marker found: $failure"; return 1; fi
  if grep -Fq -- "$success" "$log_file"; then pass marker "success marker found: $success log=$log_file"; return 0; fi
  inconc marker "success marker not found: $success (timeout or no marker is INCONCLUSIVE, not PASS)"
  return 2
}

gate_patch_series() {
  local base="${1:-}" root subjects bad_subjects bodies output rc bad=0
  need_arg patch-series base "$base" || return 2
  is_worktree || { skip patch-series 'not a Git worktree; series checks need Git'; return 0; }
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if ! git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
    skip patch-series "base not found: $base"; return 0
  fi
  subjects=$(git -C "$root" log --format=%s "$base..HEAD" 2>/dev/null)
  [[ -n "$subjects" ]] || { skip patch-series "no commits after $base"; return 0; }
  bad_subjects=$(printf '%s\n' "$subjects" | grep -E '^[^:]+:[[:space:]]+[A-Z]|\.$')
  if [[ -n "$bad_subjects" ]]; then
    fail patch-series-subject "subject must be lowercase imperative without a trailing period: $(printf '%s\n' "$bad_subjects" | sed -n '1p')"; bad=1
  else
    pass patch-series-subject 'commit subjects look conventional'
  fi
  if [[ -f "$root/.gitreview" ]]; then
    skip patch-series-change-id 'Gerrit tree (.gitreview present); Change-Id is expected'
  else
    bodies=$(git -C "$root" log --format=%B "$base..HEAD" 2>/dev/null)
    if printf '%s\n' "$bodies" | grep -qF 'Change-Id:'; then
      fail patch-series-change-id 'Change-Id found in an upstream-prep range'; bad=1
    else
      pass patch-series-change-id 'no Change-Id in an upstream-prep range'
    fi
  fi
  if [[ -f "$root/scripts/checkpatch.pl" ]] && have_cmd perl; then
    output=$(git -C "$root" format-patch --stdout "$base..HEAD" 2>/dev/null | perl "$root/scripts/checkpatch.pl" --no-signoff 2>&1)
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      pass patch-series-checkpatch 'scripts/checkpatch.pl --no-signoff passed'
    else
      fail patch-series-checkpatch 'scripts/checkpatch.pl --no-signoff reported findings'
      printf '%s\n' "$output" | awk 'NR <= 20 { print "  " $0 }'; bad=1
    fi
  else
    skip patch-series-checkpatch 'scripts/checkpatch.pl or perl unavailable; run it manually'
  fi
  [[ "$bad" -eq 0 ]] || return 1
  pass patch-series "range=$base..HEAD checked"
}

gate_source_comments() {
  local file comments hits bad=0
  [[ "$#" -gt 0 ]] || { fail source-comments 'usage: gates.sh source-comments <source-file...>'; return 2; }
  for file in "$@"; do
    if [[ ! -f "$file" ]]; then
      fail source-comments "file not found: $file"; bad=1; continue
    fi
    comments=$(awk '
      BEGIN { inblock=0; instr=0; insq=0; esc=0; squote=sprintf("%c",39) }
      {
        line=$0; out=""; i=1; n=length(line)
        while (i <= n) {
          c=substr(line,i,1)
          if (inblock) {
            if (c=="*" && substr(line,i+1,1)=="/") { inblock=0; i+=2 }
            else { out=out c; i++ }
            continue
          }
          if (instr) {
            if (esc) { esc=0; i++ }
            else if (c=="\\") { esc=1; i++ }
            else if (c=="\"") { instr=0; i++ }
            else { i++ }
            continue
          }
          if (insq) {
            if (esc) { esc=0; i++ }
            else if (c=="\\") { esc=1; i++ }
            else if (c==squote) { insq=0; i++ }
            else { i++ }
            continue
          }
          if (c=="\"") { instr=1; i++; continue }
          if (c==squote) { insq=1; i++; continue }
          if (c=="/" && substr(line,i+1,1)=="*") { inblock=1; i+=2; continue }
          if (c=="/" && substr(line,i+1,1)=="/") { out=out " " substr(line,i+2); i=n+1; continue }
          i++
        }
        if (out != "") print out
      }
    ' "$file")
    hits=$(printf '%s\n' "$comments" | grep -niE '[.]oh-my-qemu/|audit[.]md|round-result|(^|[^[:alnum:]_])(logs|output|evidence)/[A-Za-z0-9._/-]+|register-contracts?-[A-Za-z0-9._-]+[.]md|/(Users|home|workspace|tmp|root|private|mnt|opt)/[^ ]*|task artifact directory|modeled contract|neighboring[^ ]* (PCI|devices)|no policy in this tree|same manual style|register framework|framework decision|accepted (framework )?deviation|implementation decision|design rationale|(^|[^[:alnum:]_])(round[[:space:]]+[0-9]+|milestone|AC[0-9]+|audit|review (status|finding|passed|requested)|finding|evidence|next blocker|task[- ](slug|state|artifact)|session|in this round|process note|work log|progress)([^[:alnum:]_]|$)' | sed -n '1,5p')
    if [[ -n "$hits" ]]; then
      fail source-comments "local audit/output references in source comments: $file"
      printf '%s\n' "$hits" | sed 's/^/  /'
      bad=1
    fi
  done
  [[ "$bad" -eq 0 ]] || return 1
  pass source-comments "no local audit/output references in $# source file(s)"
}

gate_handoff() {
  local file="${1:-}" evidence detail
  need_arg handoff audit.md "$file" || return 2
  [[ -f "$file" ]] || { fail handoff "missing audit file: $file"; return 1; }
  evidence=$(grep -E '(^|[[:space:]])(logs|output|tests)/[[:alnum:]_.-]' "$file" 2>/dev/null | sed -n '1p')
  [[ -n "$evidence" ]] || { fail handoff 'missing an evidence path under logs/, output/, or tests/'; return 1; }
  grep -qxF '## Unresolved gaps' "$file" || { fail handoff "missing an '## Unresolved gaps' section"; return 1; }
  detail="audit=$file"
  evidence=$(first_match "$file" 'task[ -]dir:')
  [[ -z "$evidence" ]] || detail="$detail; $evidence"
  evidence=$(first_match "$file" 'build[ -]dir:')
  [[ -z "$evidence" ]] || detail="$detail; $evidence"
  pass handoff "$detail"
}

gate_all() {
  local task_dir="${1:-}" failures=0 round_result
  need_arg all task_dir "$task_dir" || return 2
  gate_workspace "$task_dir" || failures=$((failures + 1))
  gate_audit_sections "$task_dir/audit.md" || failures=$((failures + 1))
  gate_handoff "$task_dir/audit.md" || failures=$((failures + 1))
  round_result="$task_dir/output/round-result.md"
  [[ ! -f "$round_result" ]] || gate_round_result "$round_result" || failures=$((failures + 1))
  if [[ "$failures" -ne 0 ]]; then fail all "failures=$failures task_dir=$task_dir"; return 1; fi
  pass all "task_dir=$task_dir gates ok"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    ''|-h|--help|help) usage; return 0 ;;
    git-root) shift; gate_git_root "$@" ;;
    exclude) shift; gate_exclude "$@" ;;
    workspace) shift; gate_workspace "$@" ;;
    audit-sections) shift; gate_audit_sections "$@" ;;
    round-result) shift; gate_round_result "$@" ;;
    evidence-manifest) shift; gate_evidence_manifest "$@" ;;
    git-status) shift; gate_git_status "$@" ;;
    build-dir) shift; gate_build_dir "$@" ;;
    marker) shift; gate_marker "$@" ;;
    patch-series) shift; gate_patch_series "$@" ;;
    source-comments) shift; gate_source_comments "$@" ;;
    handoff) shift; gate_handoff "$@" ;;
    all) shift; gate_all "$@" ;;
    *) fail cli "unknown subcommand: $cmd (run --help)"; return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
