#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
# rst-gates.sh - local gates for one QEMU reStructuredText page (bash 3.2).

set -u

DEFAULT_MAX_LINE=90
FAILURES=0

usage() {
    cat <<'EOF'
Usage: rst-gates.sh [options] <page.rst>

Local gates for a QEMU reStructuredText page.

Options:
  --repo-root DIR   QEMU checkout for the toctree check
                    (default: git root of the page directory, else cwd)
  --max-line N      prose line-length limit (default 90)
  -h, --help        show this help

Checks: heading underlines, toctree entry, out-of-tree repository links,
local absolute paths, line length, literal blocks, docutils parse.
Exit: 0 all pass, 1 a check failed, 2 usage error. docutils is skipped when
python3 or docutils is unavailable; record that as a validation limitation.
EOF
}

report() {
    printf '%s %s: %s\n' "$1" "$2" "$3"
    case "$1" in
        FAIL) FAILURES=$((FAILURES + 1)); return 1 ;;
        *) return 0 ;;
    esac
}

check_heading_underlines() {
    _out=$(awk '
function adorn(s,   c, i) {
    if (length(s) < 2) return 0
    c = substr(s, 1, 1)
    if (c != "=" && c != "-" && c != "~" && c != "^" && c != "\"" && c != "#" && c != "*" && c != "+" && c != "`" && c != ":") return 0
    for (i = 2; i <= length(s); i++) if (substr(s, i, 1) != c) return 0
    return 1
}
{ line[NR] = $0 }
END {
    bad = 0
    for (i = 2; i <= NR; i++)
        if (adorn(line[i]) && !adorn(line[i-1]) && line[i-1] !~ /^[[:space:]]*$/ && length(line[i]) < length(line[i-1])) {
            printf "%d: underline shorter than title\n", i
            bad = 1
        }
    exit bad
}' "$1")
    if [ $? -eq 0 ]; then report PASS "heading-underlines" "$1"
    else report FAIL "heading-underlines" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

check_toctree_entry() {
    _root=$(cd "$2" 2>/dev/null && pwd) || _root=$2
    if [ ! -d "$_root/docs" ]; then
        report FAIL "toctree" "no docs/ under repo root: $_root (pass --repo-root)"
        return
    fi
    _page=$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")
    _rel=${_page#"$_root"/}
    case "$_rel" in docs/*) _docname=${_rel#docs/} ;; *) _docname=$_rel ;; esac
    _docname=${_docname%.rst}
    _found=0
    for _index in $(find "$_root/docs" -name '*.rst' -type f 2>/dev/null); do
        grep -qE '^[[:space:]]*\.\.[[:space:]]+toctree::' "$_index" || continue
        _index_rel=${_index#"$_root"/docs/}
        _index_dir=${_index_rel%/*}
        [ "$_index_dir" = "$_index_rel" ] && _index_dir=""
        if [ -n "$_index_dir" ]; then
            case "$_docname" in
                "$_index_dir"/*) _candidate=${_docname#"$_index_dir"/} ;;
                *) continue ;;
            esac
        else
            _candidate=$_docname
        fi
        if awk -v entry="$_candidate" '
            BEGIN { found = 0; intoctree = 0 }
            {
                line = $0
                if (match(line, /^[[:space:]]*\.[[:space:]]*\.[[:space:]]+toctree::/)) { intoctree = 1; next }
                if (!intoctree) next
                if (line ~ /^[[:space:]]*$/) next
                if (line ~ /^[[:space:]]+:[A-Za-z0-9_-]+:/) next
                if (line ~ /^[[:space:]]+/) {
                    token = line
                    sub(/^[[:space:]]+/, "", token)
                    sub(/[[:space:]].*$/, "", token)
                    if (token == entry) { found = 1; exit }
                    next
                }
                intoctree = 0
            }
            END { exit !found }
        ' "$_index"; then
            report PASS "toctree" "$_docname (found in ${_index#"$_root"/} as $_candidate)"
            _found=1
            break
        fi
    done
    if [ "$_found" -eq 0 ]; then
        report FAIL "toctree" "$_docname is not listed relative to its own docs/**/index.rst"
    fi
}

check_no_external_repo_links() {
    _out=$(grep -nE '(github\.com|gitlab\.com|git\.savannah|sourceware|cgit\.|googlesource|kernel\.org|qemu-machine-images|/blob/|/tree/)' "$1" 2>/dev/null)
    if [ -z "$_out" ]; then report PASS "no-external-repo-links" "$1"
    else report FAIL "no-external-repo-links" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

check_absolute_local_paths() {
    _out=$(grep -nE '(/Users/|/home/[A-Za-z]|/root/|/private/|/var/folders/|[A-Za-z]:[\\])' "$1" 2>/dev/null)
    if [ -z "$_out" ]; then report PASS "no-local-absolute-paths" "$1"
    else report FAIL "no-local-absolute-paths" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

check_line_length() {
    _out=$(awk -v max="$2" 'length($0) > max { printf "%d: %d columns\n", NR, length($0); bad = 1 } END { exit bad }' "$1")
    if [ $? -eq 0 ]; then report PASS "line-length" "$1 (max $2)"
    else report FAIL "line-length" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

check_literal_blocks() {
    _out=$(awk '
{ line[NR] = $0 }
END {
    bad = 0
    for (i = 1; i <= NR; i++) {
        if (line[i] !~ /::[[:space:]]*$/) continue
        j = i + 1
        while (j <= NR && line[j] ~ /^[[:space:]]*$/) j++
        if (j > NR) { printf "%d: :: has no literal block\n", i; bad = 1 }
        else if (line[j] !~ /^[[:space:]]+/) { printf "%d: literal block not indented\n", i; bad = 1 }
    }
    exit bad
}' "$1")
    if [ $? -eq 0 ]; then report PASS "literal-blocks" "$1"
    else report FAIL "literal-blocks" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

check_docutils() {
    if ! command -v python3 >/dev/null 2>&1; then
        report SKIP "docutils" "python3 unavailable; record the validation gap"
        return
    fi
    _out=$(python3 - "$1" <<'PY' 2>&1
import sys
try:
    from docutils.core import publish_doctree
except Exception:
    print("docutils-not-installed")
    sys.exit(3)
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        publish_doctree(handle.read(), source_path=path,
                        settings_overrides={"report_level": 2, "halt_level": 2})
except SystemExit:
    sys.exit(1)
except Exception as exc:
    text = str(exc).strip()
    print(text.splitlines()[0] if text else exc.__class__.__name__)
    sys.exit(1)
print("docutils parse OK")
PY
)
    _rc=$?
    if [ "$_rc" -eq 3 ]; then report SKIP "docutils" "docutils unavailable; record the validation gap"
    elif [ "$_rc" -eq 0 ]; then report PASS "docutils" "$1"
    else report FAIL "docutils" "$1: $(printf '%s' "$_out" | awk 'NR<=3')"; fi
}

main() {
    _repo_root=""
    _max_line="$DEFAULT_MAX_LINE"
    _page=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) usage; return 0 ;;
            --repo-root) [ $# -ge 2 ] || { usage >&2; return 2; }; _repo_root=$2; shift 2 ;;
            --repo-root=*) _repo_root=${1#--repo-root=}; shift ;;
            --max-line) [ $# -ge 2 ] || { usage >&2; return 2; }; _max_line=$2; shift 2 ;;
            --max-line=*) _max_line=${1#--max-line=}; shift ;;
            --) shift; break ;;
            -*) printf 'unknown option: %s\n' "$1" >&2; usage >&2; return 2 ;;
            *) [ -z "$_page" ] || { usage >&2; return 2; }; _page=$1; shift ;;
        esac
    done
    if [ -z "$_page" ]; then usage >&2; return 2; fi
    if [ ! -f "$_page" ]; then printf 'FAIL input: file not found: %s\n' "$_page"; return 1; fi
    if [ -z "$_repo_root" ]; then
        _repo_root=$(git -C "$(dirname "$_page")" rev-parse --show-toplevel 2>/dev/null)
        [ -n "$_repo_root" ] || _repo_root=$(pwd)
    fi
    printf 'INFO page: %s\nINFO repo root: %s\n' "$_page" "$_repo_root"
    check_heading_underlines "$_page"
    check_toctree_entry "$_page" "$_repo_root"
    check_no_external_repo_links "$_page"
    check_absolute_local_paths "$_page"
    check_line_length "$_page" "$_max_line"
    check_literal_blocks "$_page"
    check_docutils "$_page"
    if [ "$FAILURES" -eq 0 ]; then printf 'RESULT PASS: %s\n' "$_page"; return 0; fi
    printf 'RESULT FAIL: %s check(s) failed for %s\n' "$FAILURES" "$_page"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
