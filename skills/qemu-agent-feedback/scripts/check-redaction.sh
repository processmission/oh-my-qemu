#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# check-redaction.sh - scan a feedback draft for private data before presenting it.
# Every check is a function that reads the text from standard input and returns
# 0 when clean or 1 when a finding exists. Findings never echo the matched text.
set -u

usage() {
  printf '%s\n' \
    'Usage: check-redaction.sh [--text <string>] <file>...' \
    'Scan a draft feedback title and body for private data before presenting it.' \
    'Checks: local_paths, home_paths, hostnames, git_identity, emails, tokens,' \
    '  private_repos.' \
    '' \
    'Examples:' \
    '  check-redaction.sh <title-file> <body-file>' \
    '  check-redaction.sh --text "<draft title>"' \
    '' \
    'Allowlist: only https://github.com/processmission/oh-my-qemu is public.' \
    'Exit codes: 0 pass, 1 findings, 2 usage.'
}

check_local_paths() {
  ! grep -qE "(^|[^[:alnum:]_.~/-])/(Users|home|root|data|workspace|mnt|srv|opt)/"
}

check_home_paths() {
  ! grep -qE '~/|\$HOME|%USERPROFILE%|[A-Za-z]:\\\\Users'
}

check_hostnames() {
  ! grep -qE '(^|[^[:alnum:]_-])[[:alnum:]-]+\.(local|lan|home|corp|internal)([^[:alnum:]_-]|$)|'\
'(^|[^0-9])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}([^0-9]|$)'
}

check_git_identity() {
  ! grep -qiE '(Signed-off-by|Author|Committer):[[:space:]]*[^<]*<[^>]+@[^>]+>|git config user\.(name|email)'
}

check_emails() {
  ! grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
}

check_tokens() {
  ! grep -qE 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|'\
'sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----|'\
'(token|password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]{6,}'
}

check_private_repos() {
  local urls hit
  urls=$(grep -oE '(https?|ssh|git)://[^[:space:]"<>]+|git@[^[:space:]"<>]+' || true)
  [[ -n "$urls" ]] || return 0
  hit=$(printf '%s\n' "$urls" | grep -vE '^https://github\.com/processmission/oh-my-qemu(/|$)' | sed -n '1p')
  [[ -z "$hit" ]] && return 0
  return 1
}

run_checks() { # run_checks <label> <text>
  local label="$1" text="$2" name found=0
  for name in local_paths home_paths hostnames git_identity emails tokens private_repos; do
    if printf '%s\n' "$text" | "check_$name"; then
      printf 'CHECK PASS %s: %s\n' "$name" "$label"
    else
      printf 'CHECK FAIL %s: %s\n' "$name" "$label"
      found=1
    fi
  done
  return "$found"
}

main() {
  local arg text findings=0 checked=0
  if [[ "$#" -eq 0 ]]; then usage; return 2; fi
  while [[ "$#" -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
      -h|--help) usage; return 0 ;;
      --text)
        if [[ "$#" -eq 0 ]]; then
          printf 'CHECK FAIL input: --text requires a value\n'
          usage; return 2
        fi
        text="$1"; shift
        run_checks 'inline-text' "$text" || findings=$((findings + 1))
        checked=$((checked + 1))
        ;;
      *)
        case "$arg" in
          -*)
            printf 'CHECK FAIL input: unknown option: %s\n' "$arg"
            usage >&2
            return 2
            ;;
        esac
        if [[ ! -f "$arg" ]]; then
          printf 'CHECK FAIL input: file not found: %s\n' "$arg"
          findings=$((findings + 1))
          continue
        fi
        text=$(<"$arg")
        run_checks "$arg" "$text" || findings=$((findings + 1))
        checked=$((checked + 1))
        ;;
    esac
  done
  if [[ "$findings" -ne 0 ]]; then
    printf 'REDACTION FAIL: inputs=%s findings=%s\n' "$checked" "$findings"
    return 1
  fi
  printf 'REDACTION PASS: inputs=%s\n' "$checked"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
