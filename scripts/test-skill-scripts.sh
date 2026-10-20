#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT
#
# test-skill-scripts.sh - syntax and focused behavior tests for skill scripts.
# Portable bash 3.2; writes only under a temporary directory removed on exit.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-my-qemu-skill-tests.XXXXXX")" || exit 1
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

cleanup() {
    rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS %s\n' "$*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL %s\n' "$*"; }
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP %s\n' "$*"; }

expect_rc() { # expect_rc <expected> <label> <command...>
    expected="$1"; label="$2"; shift 2
    "$@" >/dev/null 2>&1
    actual=$?
    if [ "$actual" -eq "$expected" ]; then pass "$label (rc=$actual)"; else fail "$label (rc=$actual, expected $expected)"; fi
}

expect_contains() { # expect_contains <file> <text> <label>
    if grep -Fq -- "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3 (missing: $2)"; fi
}

make_repo() { # make_repo <dir>
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name "Test User"
    printf 'base\n' > "$1/README"
    git -C "$1" add README
    git -C "$1" commit -qm "base commit"
}

make_task() { # make_task <repo> <slug> -> prints task dir
    mkdir -p "$1/.oh-my-qemu/$2/logs"
    printf '# task\n' > "$1/.oh-my-qemu/$2/audit.md"
    printf '# commands\n' > "$1/.oh-my-qemu/$2/commands.md"
    printf '%s\n' "$1/.oh-my-qemu/$2"
}

test_syntax() {
    count=0
    for script in "$ROOT"/skills/*/scripts/*.sh; do
        [ -f "$script" ] || continue
        if bash -n "$script" 2>"$TMPROOT/bash-n.err"; then count=$((count + 1)); else fail "bash -n $script"; fi
    done
    pass "bash -n for $count skill script(s)"
    count=0
    for script in "$ROOT"/skills/*/scripts/*.py; do
        [ -f "$script" ] || continue
        if python3 -c "import sys; compile(open(sys.argv[1], encoding='utf-8').read(), sys.argv[1], 'exec')" "$script" 2>"$TMPROOT/python.err"; then
            count=$((count + 1))
        else
            fail "python compile $script"
        fi
    done
    pass "python compile for $count skill script(s)"
}

test_help() {
    for script in         "$ROOT/skills/qemu-workflow/scripts/gates.sh"         "$ROOT/skills/qemu-agent-feedback/scripts/check-redaction.sh"         "$ROOT/skills/qemu-build/scripts/preflight.sh"         "$ROOT/skills/qemu-debug/scripts/collect-context.sh"         "$ROOT/skills/qemu-qtest/scripts/check-registration.sh"         "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" \
        "$ROOT/skills/qemu-modeler/scripts/loop-state.sh" \
        "$ROOT/skills/qemu-model-review/scripts/review-checks.sh"; do
        expect_rc 0 "--help $(basename "$script")" bash "$script" --help
        expect_rc 2 "bad option $(basename "$script")" bash "$script" --definitely-not-an-option
    done
    expect_rc 0 "--help validate_register_ir.py" python3 "$ROOT/skills/qemu-register-extraction/scripts/validate_register_ir.py" --help
}

test_gates_exclude() {
    repo="$TMPROOT/gates-repo"
    make_repo "$repo"
    caller_exclude=$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null)
    caller_before=$(cksum "$caller_exclude" 2>/dev/null || true)
    expect_rc 0 "gates exclude first run" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' exclude"
    caller_after=$(cksum "$caller_exclude" 2>/dev/null || true)
    if [ "$caller_before" = "$caller_after" ]; then pass "exclude test leaves caller repository untouched"; else fail "exclude test changed the caller repository"; fi
    ( cd "$repo" && bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" exclude >/dev/null 2>&1 )
    rc1=$?
    ( cd "$repo" && bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" exclude >/dev/null 2>&1 )
    rc2=$?
    exclude_file="$repo/.git/info/exclude"
    if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ]; then pass "gates exclude is idempotent"; else fail "gates exclude rc=$rc1/$rc2"; fi
    for entry in .agents/ .oh-my-qemu/ builds/; do
        expect_contains "$exclude_file" "$entry" "gates exclude records $entry"
    done
    lines=$(grep -c '^\.oh-my-qemu/$' "$exclude_file" 2>/dev/null || true)
    if [ "$lines" = "1" ]; then pass "gates exclude has one .oh-my-qemu entry"; else fail "gates exclude entry count=$lines"; fi
}

test_gates_workspace_and_audit() {
    repo="$TMPROOT/gates-audit"
    make_repo "$repo"
    task=$(make_task "$repo" demo)
    cp "$ROOT/skills/qemu-workflow/assets/audit-template.md" "$task/audit.md"
    expect_rc 0 "gates workspace" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' workspace .oh-my-qemu/demo"
    expect_rc 0 "gates audit-sections" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' audit-sections .oh-my-qemu/demo/audit.md"
    printf '## Baseline\n' > "$task/audit.md"
    expect_rc 1 "gates audit-sections rejects incomplete audit" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' audit-sections .oh-my-qemu/demo/audit.md"
}

test_gates_round_result() {
    repo="$TMPROOT/gates-round"
    make_repo "$repo"
    task=$(make_task "$repo" demo)
    cp "$ROOT/skills/qemu-workflow/assets/round-result-template.md" "$task/round-result.md"
    sed -i.bak 's/<PASS | FAIL | INCONCLUSIVE>/PASS/; s/<gate>/marker BOOT READY/; s#<evidence path>#logs/serial.log#; s/<next blocker>/none/' "$task/round-result.md" 2>/dev/null || true
    # The template uses placeholders; build a minimal valid PASS document instead.
    cat > "$task/round-result.md" <<'EOF'
# Round 1
- VERDICT: PASS
- Gate: marker BOOT READY
- Evidence: logs/serial.log
- Changed paths: hw/arm/board.c
- Commands: make run
- Next blocker: none
EOF
    expect_rc 0 "gates round-result PASS with marker and evidence" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' round-result .oh-my-qemu/demo/round-result.md"
    cat > "$task/round-result.md" <<'EOF'
# Round 2
- VERDICT: PASS
- Gate: timeout after 120s, no marker
- Evidence: logs/serial.log
- Next blocker: none
EOF
    expect_rc 1 "gates round-result rejects timeout-based PASS" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' round-result .oh-my-qemu/demo/round-result.md"
    cat > "$task/round-result.md" <<'EOF'
# Round 3
- VERDICT: NOTPASS
- Gate: marker BOOT READY
- Evidence: logs/serial.log
EOF
    expect_rc 1 "gates round-result rejects a non-exact verdict" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' round-result .oh-my-qemu/demo/round-result.md"
}

test_gates_manifest_and_marker() {
    repo="$TMPROOT/gates-manifest"
    make_repo "$repo"
    task=$(make_task "$repo" demo)
    mkdir -p "$task/output"
    printf 'evidence one\n' > "$TMPROOT/ev1.txt"
    printf 'evidence two\n' > "$TMPROOT/ev2.txt"
    expect_rc 0 "gates evidence-manifest" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' evidence-manifest .oh-my-qemu/demo '$TMPROOT/ev1.txt' '$TMPROOT/ev2.txt'"
    expect_contains "$task/output/evidence-manifest.tsv" "sha256" "gates evidence-manifest writes header"
    lines=$(wc -l < "$task/output/evidence-manifest.tsv" | tr -d ' ')
    if [ "$lines" = "3" ]; then pass "gates evidence-manifest row count"; else fail "gates evidence-manifest row count=$lines"; fi
    printf 'BOOT READY\n' > "$TMPROOT/serial.log"
    expect_rc 0 "gates marker success" bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" marker "$TMPROOT/serial.log" "BOOT READY"
    : > "$TMPROOT/empty.log"
    expect_rc 2 "gates marker empty log is INCONCLUSIVE" bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" marker "$TMPROOT/empty.log" "BOOT READY"
    printf 'Kernel panic\n' > "$TMPROOT/serial.log"
    expect_rc 1 "gates marker failure marker" bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" marker "$TMPROOT/serial.log" "BOOT READY" "Kernel panic"
}

test_gates_build_dir() {
    repo="$TMPROOT/gates-build"
    make_repo "$repo"
    mkdir -p "$repo/builds/build-aarch64"
    printf '# Configured with: %s/configure --target-list=aarch64-softmmu\n' "$repo" > "$repo/builds/build-aarch64/config.log"
    expect_rc 0 "gates build-dir named build" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' build-dir builds/build-aarch64"
    mkdir -p "$repo/build"
    printf 'stale\n' > "$repo/build/config.log"
    expect_rc 1 "gates build-dir rejects unqualified build/" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' build-dir build"
}

test_gates_handoff_and_all() {
    repo="$TMPROOT/gates-handoff"
    make_repo "$repo"
    task=$(make_task "$repo" demo)
    cat > "$task/audit.md" <<'EOF'
# Task
## Baseline
## Goal and non-goals
## Scope and constraints
## Acceptance criteria
## Plan and verification gates
## Provenance
## Decisions and assumptions
## Round record
## Evidence and verification
- logs/serial.log
- Task dir: .oh-my-qemu/demo
- Build dir: builds/build-aarch64
## Unresolved gaps
- none
## Handoff
EOF
    expect_rc 0 "gates handoff" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' handoff .oh-my-qemu/demo/audit.md"
    expect_rc 0 "gates all with templates" bash -c "cd '$repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' all .oh-my-qemu/demo"
    status_repo="$TMPROOT/gates-status"
    make_repo "$status_repo"
    make_task "$status_repo" demo >/dev/null
    ( cd "$status_repo" && git status --short > "$TMPROOT/baseline-status.txt" )
    mkdir -p "$status_repo/.agents"
    printf 'leak\n' > "$status_repo/.agents/leak"
    expect_rc 1 "gates git-status rejects untracked excluded paths" bash -c "cd '$status_repo' && bash '$ROOT/skills/qemu-workflow/scripts/gates.sh' git-status '$TMPROOT/baseline-status.txt'"
}

test_gates_source_comments() {
    good="$TMPROOT/source-good.c"
    printf '/*\n * Demo hardware block.\n * Registers follow the vendor TRM section 4.\n */\n' > "$good"
    expect_rc 0 "gates source-comments accepts a clean source header" bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" source-comments "$good"
    bad="$TMPROOT/source-bad.c"
    printf '/*\n * Contract: output/register-contracts-r2.md section 2.\n * Decision recorded in audit.md.\n */\n' > "$bad"
    expect_rc 1 "gates source-comments rejects local output references" bash "$ROOT/skills/qemu-workflow/scripts/gates.sh" source-comments "$bad"
}

test_rst_gates() {
    repo="$TMPROOT/rst-repo"
    mkdir -p "$repo/docs/system/arm"
    cat > "$repo/docs/index.rst" <<'EOF'
QEMU documentation
==================

.. toctree::

   system/arm/test-board
EOF
    cat > "$repo/docs/system/arm/test-board.rst" <<'EOF'
Test Board
==========

Overview
--------

The test board is a local modeling fixture.

Boot options
------------

Direct Linux boot uses a kernel image and a DTB. A literal block follows::

    qemu-system-aarch64 -M test-board -nographic

Known limitations
-----------------

No firmware path is implemented in this fixture.
EOF
    expect_rc 0 "rst-gates accepts a clean page" bash "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" --repo-root "$repo" "$repo/docs/system/arm/test-board.rst"
    printf '.. toctree::\n   :maxdepth: 1\n\n   test-board\n' > "$repo/docs/system/arm/index.rst"
    : > "$repo/docs/index.rst"
    expect_rc 0 "rst-gates accepts a relative subdir toctree" bash "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" --repo-root "$repo" "$repo/docs/system/arm/test-board.rst"
    printf '.. toctree::\n\n   arm/test-board\n' > "$repo/docs/system/target-arm.rst"
    : > "$repo/docs/system/arm/index.rst"
    : > "$repo/docs/index.rst"
    expect_rc 0 "rst-gates accepts a non-index toctree" bash "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" --repo-root "$repo" "$repo/docs/system/arm/test-board.rst"
    mkdir -p "$repo/docs/system/riscv"
    printf '   test-board\n' > "$repo/docs/system/riscv/index.rst"
    : > "$repo/docs/system/target-arm.rst"
    : > "$repo/docs/system/arm/index.rst"
    : > "$repo/docs/index.rst"
    expect_rc 1 "rst-gates rejects prose-only toctree mention" bash "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" --repo-root "$repo" "$repo/docs/system/arm/test-board.rst"
    cat > "$repo/docs/system/arm/test-board.rst" <<'EOF'
Test Board
====

Overview
--------
See https://github.com/example/private-repo for the recipe and /Users/example/local/path.
EOF
    expect_rc 1 "rst-gates rejects underline, external link and local path" bash "$ROOT/skills/qemu-rst-documentation/scripts/rst-gates.sh" --repo-root "$repo" "$repo/docs/system/arm/test-board.rst"
}

test_check_registration() {
    dir="$TMPROOT/qtest"
    mkdir -p "$dir"
    cat > "$dir/meson.build" <<'EOF'
qtests_aarch64 = [
  'test-board-test',
]
EOF
    cat > "$dir/test-board-test.c" <<'EOF'
#include "qemu/osdep.h"
#include "libqtest.h"
static void test_board(void) { QTestState *s = qtest_init("-M test-board"); qtest_quit(s); }
int main(int argc, char **argv) { g_test_init(&argc, &argv, NULL); qtest_add_func("/test-board/run", test_board); return g_test_run(); }
EOF
    expect_rc 0 "check-registration accepts a registered test" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/test-board-test.c" --arch aarch64
    cat > "$dir/meson.build" <<'EOF'
qtests_generic = [
]
EOF
    expect_rc 1 "check-registration rejects an unregistered test" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/test-board-test.c" --arch aarch64
    cat > "$dir/meson.build" <<'EOF'
qtests_aarch64 = [
]
not_qtests = ['ghost-test']
EOF
    cp "$dir/test-board-test.c" "$dir/ghost-test.c"
    expect_rc 1 "check-registration rejects bucket leakage" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/ghost-test.c" --arch aarch64
    cat > "$dir/meson.build" <<'EOF'
qtests_aarch64 = (config_all_devices.has_key('x') ? ['guarded-test'] : [])
EOF
    cp "$dir/test-board-test.c" "$dir/guarded-test.c"
    expect_rc 0 "check-registration accepts a guarded bucket expression" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/guarded-test.c" --arch aarch64
    cat > "$dir/meson.build" <<'EOF'
qtests_aarch64 = [] # conditional group (
qtests_x86_64 = ['x86-test']
EOF
    cp "$dir/test-board-test.c" "$dir/x86-test.c"
    expect_rc 1 "check-registration ignores delimiters in comments" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/x86-test.c" --arch aarch64
    cat > "$dir/meson.build" <<'EOF'
qtests_aarch64 = [] # 'ghost-test'
EOF
    expect_rc 1 "check-registration ignores test names in comments" bash "$ROOT/skills/qemu-qtest/scripts/check-registration.sh" --meson "$dir/meson.build" --source "$dir/ghost-test.c" --arch aarch64
}

test_validate_register_ir() {
    ir="$ROOT/skills/qemu-register-extraction/scripts/validate_register_ir.py"
    template="$ROOT/skills/qemu-register-extraction/assets/register-semantics-template.ir"
    example="$ROOT/skills/qemu-register-extraction/assets/register-semantics-example.ir"
    expect_rc 0 "register IR template validates" python3 "$ir" "$template"
    expect_rc 0 "register IR example validates" python3 "$ir" "$example"
    expect_rc 0 "register IR --list-ops" python3 "$ir" --list-ops
    python3 "$ir" --list-ops > "$TMPROOT/vocab.tsv" 2>/dev/null
    if grep -q "trigger.*register_write" "$TMPROOT/vocab.tsv"; then pass "register IR vocabulary lists register_write"; else fail "register IR vocabulary missing register_write"; fi
    if python3 "$ir" --dump "$example" > "$TMPROOT/dump.ir" 2>/dev/null; then
        pass "register IR --dump writes canonical text"
        expect_rc 0 "register IR dump re-validates" python3 "$ir" "$TMPROOT/dump.ir"
    else
        fail "register IR --dump failed"
    fi
    cat > "$TMPROOT/base.ir" <<'EOF'
ir 1.0
target ip fixture
target variants demo
target workload boot
source S1 fixture:1
symbol register CTRL offset=0x00 width=32 access=rw reset=0x0 source=S1
symbol field CTRL.EN bits=0 access=rw source=S1
symbol constant MODE_PERIODIC value=1 source=S1
symbol state counter type=uint32
symbol timer period_timer
symbol irq irq0 kind=level source=S1
symbol address UNMODELED_WINDOW base=0x1000 size=0x100 status=unimplemented placeholder=board_unimpl source=S1
rule R1 "enable starts timer" tier=driver confidence=HIGH sources=S1
  trigger register_write CTRL width=32
  condition bit_set(CTRL.EN)
  transition schedule_timer(period_timer, MODE_PERIODIC)
  transition assert_irq(irq0)
  framework registerinfo hook=post_write rationale="fixture"
  observe trace="fixture.r1" log="none" error="guest_error"
  qtest "timer scheduled and irq raised"
flow init R1
EOF
    expect_rc 0 "register IR minimal rule validates" python3 "$ir" "$TMPROOT/base.ir"
    cat > "$TMPROOT/logging-only.ir" <<'EOF'
ir 1.0
target ip fixture
target variants demo
target workload boot
source S1 fixture:1
symbol register CTRL offset=0x00 width=32 access=rw reset=0x0 source=S1
rule R1 "logging-only access" tier=driver confidence=HIGH sources=S1
  trigger register_read CTRL width=32
  transition log_unimp(CTRL)
  framework registerinfo hook=post_read rationale="visibility-only fixture"
  observe trace="none" log="unimp" error="none"
  qtest "read logs that the register is unimplemented"
  gap "hardware behavior is unknown"
EOF
    expect_rc 0 "register IR logging-only rule with gap validates" python3 "$ir" "$TMPROOT/logging-only.ir"
    sed '/^  gap /d' "$TMPROOT/logging-only.ir" > "$TMPROOT/logging-only-gap.ir"
    expect_rc 1 "register IR logging-only rule without gap fails" python3 "$ir" "$TMPROOT/logging-only-gap.ir"
    sed 's/^ir 1.0/ir 2.0/' "$TMPROOT/base.ir" > "$TMPROOT/bad-version.ir"
    expect_rc 1 "register IR rejects bad version" python3 "$ir" "$TMPROOT/bad-version.ir"
    sed 's/schedule_timer/unknown_op/' "$TMPROOT/base.ir" > "$TMPROOT/bad-op.ir"
    expect_rc 1 "register IR rejects unknown operation" python3 "$ir" "$TMPROOT/bad-op.ir"
    sed 's/bit_set(CTRL.EN)/bit_set(CTRL.EN, CTRL.EN)/' "$TMPROOT/base.ir" > "$TMPROOT/bad-arity.ir"
    expect_rc 1 "register IR rejects wrong arity" python3 "$ir" "$TMPROOT/bad-arity.ir"
    sed 's/bit_set(CTRL.EN)/bit_set(MISSING.FIELD)/' "$TMPROOT/base.ir" > "$TMPROOT/bad-symbol.ir"
    expect_rc 1 "register IR rejects unknown symbol" python3 "$ir" "$TMPROOT/bad-symbol.ir"
    sed 's/condition bit_set(CTRL.EN)/condition assign_field(CTRL, 1)/' "$TMPROOT/base.ir" > "$TMPROOT/bad-condition-op.ir"
    expect_rc 1 "register IR rejects operation in condition" python3 "$ir" "$TMPROOT/bad-condition-op.ir"
    sed 's/transition schedule_timer(period_timer, MODE_PERIODIC)/transition bit_set(CTRL.EN)/' "$TMPROOT/base.ir" > "$TMPROOT/bad-transition-op.ir"
    expect_rc 1 "register IR rejects condition in transition" python3 "$ir" "$TMPROOT/bad-transition-op.ir"
    sed '/framework/d' "$TMPROOT/base.ir" > "$TMPROOT/bad-framework.ir"
    expect_rc 1 "register IR rejects missing framework" python3 "$ir" "$TMPROOT/bad-framework.ir"
    sed '/qtest/d' "$TMPROOT/base.ir" > "$TMPROOT/bad-qtest.ir"
    expect_rc 1 "register IR rejects missing qtest" python3 "$ir" "$TMPROOT/bad-qtest.ir"
    sed 's/transition schedule_timer(period_timer, MODE_PERIODIC)/transition EXPANDS dma_read(CTRL, MODE_PERIODIC, MODE_PERIODIC)/' "$TMPROOT/base.ir" > "$TMPROOT/bad-expansion.ir"
    expect_rc 1 "register IR requires expansion note for EXPANDS" python3 "$ir" "$TMPROOT/bad-expansion.ir"
    sed '/observe/d' "$TMPROOT/base.ir" > "$TMPROOT/bad-observe.ir"
    expect_rc 1 "register IR requires observe for guest-visible transition" python3 "$ir" "$TMPROOT/bad-observe.ir"
    sed 's/ placeholder=board_unimpl//' "$TMPROOT/base.ir" > "$TMPROOT/bad-placeholder.ir"
    expect_rc 1 "register IR requires placeholder for unimplemented address" python3 "$ir" "$TMPROOT/bad-placeholder.ir"
    sed 's/transition schedule_timer/transition UNSUPPORTED schedule_timer/' "$TMPROOT/base.ir" > "$TMPROOT/bad-unimp-log.ir"
    expect_rc 1 "register IR requires log=unimp for unimplemented transition" python3 "$ir" "$TMPROOT/bad-unimp-log.ir"
    sed 's/sources=S1/sources=S1 invented=value/' "$TMPROOT/base.ir" > "$TMPROOT/bad-rule-attr.ir"
    expect_rc 1 "register IR rejects unknown rule attributes" python3 "$ir" "$TMPROOT/bad-rule-attr.ir"
    if python3 "$ir" --translate "$TMPROOT/base.ir" > "$TMPROOT/translate.tsv" 2>/dev/null; then
        pass "register IR --translate writes a worklist"
        if grep -q "rule.*R1.*registerinfo.*post_write" "$TMPROOT/translate.tsv"; then pass "register IR translation maps R1 to RegisterInfo"; else fail "register IR translation row missing"; fi
        if grep -q "address.*UNMODELED_WINDOW.*unimplemented-device.*board_unimpl" "$TMPROOT/translate.tsv"; then pass "register IR translation maps placeholder"; else fail "register IR translation placeholder row missing"; fi
    else
        fail "register IR --translate failed"
    fi
}

test_orchestrator_state() {
    task="$TMPROOT/orch-task/.oh-my-qemu/demo"
    mkdir -p "$task"
    printf '# audit\n' > "$task/audit.md"
    printf '# commands\n' > "$task/commands.md"
    loop="$ROOT/skills/qemu-modeler/scripts/loop-state.sh"
    fresh="$TMPROOT/orch-init/.oh-my-qemu/demo"
    mkdir -p "$fresh"
    printf '# audit\n' > "$fresh/audit.md"
    printf '# commands\n' > "$fresh/commands.md"
    expect_rc 1 "loop-state init fails when state temp is unavailable" env TMPDIR=/nonexistent bash "$loop" init "$fresh"
    if [ -f "$fresh/output/task-state.md" ]; then fail "loop-state init left a failed state file"; else pass "loop-state init removes a failed state file"; fi
    expect_rc 0 "loop-state init retries after failure" bash "$loop" init "$fresh"
    if grep -q '<ISO-8601>' "$fresh/output/task-state.md"; then fail "loop-state init retry left template placeholder"; else pass "loop-state init retry repairs the state"; fi
    expect_rc 1 "loop-state verdict fails when state temp is unavailable" env TMPDIR=/nonexistent bash "$loop" verdict "$fresh" PASS "marker X" "logs/x.log"
    if [ -f "$fresh/output/rounds.tsv" ] && grep -q 'PASS' "$fresh/output/rounds.tsv"; then fail "loop-state appended a verdict before state update"; else pass "loop-state does not append a verdict on failed state update"; fi
    expect_rc 0 "loop-state init" bash "$loop" init "$task"
    expect_rc 0 "loop-state goal" bash "$loop" goal "$task" "model demo timer" goal
    expect_rc 0 "loop-state milestone" bash "$loop" milestone add "$task" M1 "timer model implemented"
    expect_rc 0 "loop-state AC" bash "$loop" ac add "$task" AC1 "periodic interrupt fires"
    expect_rc 0 "loop-state phase" bash "$loop" phase "$task" evidence
    expect_rc 0 "loop-state start-round" bash "$loop" start-round "$task" "probe reset value"
    expect_rc 1 "loop-state fails when state temp is unavailable" env TMPDIR=/nonexistent bash "$loop" phase "$task" build
    rm -f "$task/output/rounds.tsv"
    mkdir "$task/output/rounds.tsv"
    expect_rc 1 "loop-state rejects unappendable round history" bash "$loop" verdict "$task" PASS "marker BOOT READY" "logs/serial.log"
    if grep -q '^review status: not-requested' "$task/output/task-state.md"; then pass "loop-state rolls back state when round history fails"; else fail "loop-state changed state before round history"; fi
    rmdir "$task/output/rounds.tsv"
    expect_rc 0 "loop-state verdict" bash "$loop" verdict "$task" PASS "marker BOOT READY" "logs/serial.log"
    expect_rc 0 "loop-state finding" bash "$loop" finding "$task" F-01 BLOCKER "missing trace event"
    expect_rc 0 "loop-state next" bash "$loop" next "$task" "add trace and rerun"
    if grep -q '^round: 1' "$task/output/task-state.md"; then pass "loop-state increments round"; else fail "loop-state round not updated"; fi
    if grep -q 'probe reset value' "$task/output/task-state.md"; then pass "loop-state records objective"; else fail "loop-state objective missing"; fi
    expect_contains "$task/output/rounds.tsv" "PASS" "loop-state records verdict"
    expect_contains "$task/output/findings.tsv" "F-01" "loop-state records finding"
    if grep -q '^review status: PASS' "$task/output/task-state.md"; then pass "loop-state writes review status field"; else fail "loop-state review status field missing"; fi
    if grep -q '^next action: add trace and rerun' "$task/output/task-state.md"; then pass "loop-state writes next action field"; else fail "loop-state next action field missing"; fi
    expect_rc 1 "loop-state check blocks an incomplete goal" bash "$loop" check "$task"
    goal_task="$TMPROOT/orch-goal/.oh-my-qemu/demo"
    mkdir -p "$goal_task"
    printf '# audit\n' > "$goal_task/audit.md"
    printf '# commands\n' > "$goal_task/commands.md"
    expect_rc 0 "goal task init" bash "$loop" init "$goal_task"
    expect_rc 0 "goal task contract" bash "$loop" goal "$goal_task" "demo timer goal" goal
    expect_rc 0 "goal task milestone" bash "$loop" milestone add "$goal_task" M1 "timer model implemented"
    expect_rc 0 "goal task second milestone" bash "$loop" milestone add "$goal_task" M2 "timer interrupt wired"
    expect_rc 0 "goal task AC" bash "$loop" ac add "$goal_task" AC1 "periodic interrupt fires"
    bash "$loop" start-round "$goal_task" "implement timer" >/dev/null
    expect_rc 0 "goal task records a round verdict" bash "$loop" verdict "$goal_task" PASS "marker demo-timer" "logs/demo-timer.log"
    expect_rc 1 "loop-state loop continues while AC is open" bash "$loop" loop "$goal_task"
    expect_rc 1 "loop-state rejects PASS AC without evidence" bash "$loop" ac status "$goal_task" AC1 pass
    expect_rc 0 "loop-state records evidence-backed AC pass" bash "$loop" ac status "$goal_task" AC1 pass "qtest demo-timer"
    expect_rc 0 "loop-state records a failed AC" bash "$loop" ac status "$goal_task" AC1 fail "logs/failure.log"
    expect_rc 1 "loop-state rejects PASS AC inheriting failure evidence" bash "$loop" ac status "$goal_task" AC1 pass
    expect_rc 0 "loop-state records fresh AC pass evidence" bash "$loop" ac status "$goal_task" AC1 pass "qtest demo-timer fixed"
    expect_rc 1 "loop-state loop waits for milestone completion" bash "$loop" loop "$goal_task"
    expect_rc 1 "loop-state rejects milestone done without evidence" bash "$loop" milestone status "$goal_task" M1 done
    expect_rc 0 "loop-state records milestone done" bash "$loop" milestone status "$goal_task" M1 done "qtest demo-timer exit gate"
    expect_rc 0 "loop-state records the second milestone done" bash "$loop" milestone status "$goal_task" M2 done "qtest demo-timer irq exit gate"
    expect_rc 0 "loop-state records a verdict after contract changes" bash "$loop" verdict "$goal_task" PASS "marker demo-timer final" "logs/demo-timer-final.log"
    expect_rc 0 "loop-state completes the goal" bash "$loop" loop "$goal_task"
    expect_rc 0 "loop-state check passes a complete goal" bash "$loop" check "$goal_task"
    expect_rc 1 "loop-state rejects changing a completed goal" bash "$loop" goal "$goal_task" "different goal" goal
    expect_rc 0 "loop-state accepts the unchanged goal" bash "$loop" goal "$goal_task" "demo timer goal" goal
    expect_rc 0 "loop-state records a review blocker" bash "$loop" finding "$goal_task" F-01 BLOCKER "missing trace event"
    expect_rc 1 "loop-state blocks on an open BLOCKER" bash "$loop" loop "$goal_task"
    expect_rc 1 "loop-state resolve rejects an unknown finding" bash "$loop" finding resolve "$goal_task" F-99
    expect_rc 0 "loop-state resolves a fixed blocker" bash "$loop" finding resolve "$goal_task" F-01
    expect_rc 0 "loop-state completes after blocker resolution" bash "$loop" loop "$goal_task"
    bash "$loop" start-round "$goal_task" "next regression round" >/dev/null
    expect_rc 1 "loop-state invalidates the previous verdict on a new round" bash "$loop" loop "$goal_task"
    expect_rc 0 "loop-state records the new round verdict" bash "$loop" verdict "$goal_task" PASS "marker demo-timer round2" "logs/demo-timer-round2.log"
    expect_rc 0 "loop-state completes after the new round PASS" bash "$loop" loop "$goal_task"
    round_task="$TMPROOT/orch-round/.oh-my-qemu/demo"
    mkdir -p "$round_task"
    printf '# audit\n' > "$round_task/audit.md"
    printf '# commands\n' > "$round_task/commands.md"
    bash "$loop" init "$round_task" >/dev/null
    bash "$loop" goal "$round_task" "one-round demo" round >/dev/null
    bash "$loop" milestone add "$round_task" M1 "round model" >/dev/null
    bash "$loop" ac add "$round_task" AC1 "one behavior" >/dev/null
    expect_rc 1 "loop-state round mode waits for the requested round" bash "$loop" loop "$round_task"
    bash "$loop" start-round "$round_task" "single round" >/dev/null
    printf 'Round: 1\n' > "$round_task/output/round-result.md"
    expect_rc 1 "loop-state round mode rejects a header-only round result" bash "$loop" loop "$round_task"
    cat > "$round_task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate:
Evidence:
EOF
    bash "$loop" verdict "$round_task" PASS "marker ROUND READY" "logs/round.log" >/dev/null
    expect_rc 1 "loop-state round mode rejects empty gate/evidence" bash "$loop" loop "$round_task"
    cat > "$round_task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate: marker ROUND READY
Evidence: logs/round.log
EOF
    bash "$loop" verdict "$round_task" PASS "marker ROUND READY" "logs/round.log" >/dev/null
    if bash "$loop" loop "$round_task" > "$TMPROOT/round-mode.out" 2>&1; then
        if grep -q 'ROUND COMPLETE' "$TMPROOT/round-mode.out"; then pass "loop-state round mode hands off after a validated round"; else fail "loop-state round-mode handoff message missing"; fi
    else
        fail "loop-state round mode did not hand off"
    fi
    resumed="$TMPROOT/orch-round-resumed/.oh-my-qemu/demo"
    mkdir -p "$resumed"
    printf '# audit\n' > "$resumed/audit.md"
    printf '# commands\n' > "$resumed/commands.md"
    bash "$loop" init "$resumed" >/dev/null
    bash "$loop" goal "$resumed" "resumed round demo" goal >/dev/null
    bash "$loop" start-round "$resumed" "historical round" >/dev/null
    printf 'Round: 1\n' > "$resumed/output/round-result.md"
    bash "$loop" goal "$resumed" "resumed round demo" round >/dev/null
    expect_rc 1 "loop-state round mode ignores a historical round result" bash "$loop" loop "$resumed"
    bash "$loop" start-round "$resumed" "requested round" >/dev/null
    expect_rc 1 "loop-state round mode rejects a stale round result" bash "$loop" loop "$resumed"
    cat > "$resumed/output/round-result.md" <<'EOF'
Round: 2
Verdict: PASS
Gate: marker RESUMED READY
Evidence: logs/resumed.log
EOF
    bash "$loop" verdict "$resumed" PASS "marker RESUMED READY" "logs/resumed.log" >/dev/null
    expect_rc 0 "loop-state round mode accepts the validated requested round result" bash "$loop" loop "$resumed"
    nostate="$TMPROOT/no-state/.oh-my-qemu/demo"
    mkdir -p "$nostate"
    printf '# audit\n' > "$nostate/audit.md"
    printf '# commands\n' > "$nostate/commands.md"
    expect_rc 1 "loop-state rejects verdict before init" bash "$loop" verdict "$nostate" PASS "marker X" "logs/x.log"
    parallel="$TMPROOT/orch-parallel/.oh-my-qemu/demo"
    mkdir -p "$parallel"
    printf '# audit\n' > "$parallel/audit.md"
    printf '# commands\n' > "$parallel/commands.md"
    bash "$loop" init "$parallel" >/dev/null
    n=1
    while [ "$n" -le 8 ]; do
        bash "$loop" verdict "$parallel" PASS "marker M$n" "logs/$n.log" >/dev/null &
        n=$((n + 1))
    done
    wait
    rows=$(grep -c '^0[[:space:]]PASS' "$parallel/output/rounds.tsv" 2>/dev/null || true)
    if [ "${rows:-0}" = "8" ]; then pass "loop-state serializes concurrent verdicts"; else fail "loop-state lost concurrent verdicts: rows=$rows"; fi
    if [ ! -d "$parallel/output/.rounds.lock" ]; then pass "loop-state releases the verdict lock"; else fail "loop-state left the verdict lock"; fi
    expect_rc 1 "loop-state rejects finding before init" bash "$loop" finding "$nostate" F-02 BLOCKER "must not be lost"
    rm -rf "$task/output"
    expect_rc 1 "loop-state rejects finding after output removal" bash "$loop" finding "$task" F-03 BLOCKER "must not be lost"
}

test_review_checks() {
    root="$TMPROOT/review-task"
    task="$root/.oh-my-qemu/demo"
    mkdir -p "$task/output"
    printf '# commands\n' > "$task/commands.md"
    cat > "$task/audit.md" <<'EOF'
# Task
## Baseline
## Goal and non-goals
## Scope and constraints
## Acceptance criteria
## Plan and verification gates
## Provenance
## Decisions and assumptions
## Round record
## Evidence and verification
- logs/serial.log
## Unresolved gaps
## Handoff
EOF
    cp "$ROOT/skills/qemu-register-extraction/assets/register-semantics-example.ir" "$task/output/register-semantics.ir"
    python3 "$ROOT/skills/qemu-register-extraction/scripts/validate_register_ir.py" --translate "$task/output/register-semantics.ir" > "$task/output/translation.tsv" 2>/dev/null
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    expect_rc 0 "review-checks accepts a complete packet" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" \
        --task-dir "$task" \
        --ir "$task/output/register-semantics.ir" \
        --validator "$ROOT/skills/qemu-register-extraction/scripts/validate_register_ir.py" \
        --translation "$task/output/translation.tsv"
    expect_rc 1 "review-checks --final-goal requires task-state" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    cat > "$task/output/task-state.md" <<'EOF'
goal: demo timer goal
goal mode: goal
round: 1
phase: review
EOF
    printf 'id\tstatus\tdescription\tevidence\tupdated\n' > "$task/output/milestones.tsv"
    printf 'M1\tpending\ttimer model\t-\tnow\n' >> "$task/output/milestones.tsv"
    printf 'id\tstatus\tcriterion\tevidence\tupdated\n' > "$task/output/acceptance.tsv"
    printf 'AC1\tpending\tinterrupt fires\t-\tnow\n' >> "$task/output/acceptance.tsv"
    expect_rc 1 "review-checks enforces the 2-5 milestone contract" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    printf 'M2\tpending\tinterrupt wired\t-\tnow\n' >> "$task/output/milestones.tsv"
    expect_rc 0 "review-checks accepts an intermediate goal contract" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    expect_rc 1 "review-checks --final-goal rejects an incomplete goal" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    printf 'id\tstatus\tdescription\tevidence\tupdated\n' > "$task/output/milestones.tsv"
    printf 'M1\tdone\ttimer model\tqtest demo-timer exit gate\tnow\n' >> "$task/output/milestones.tsv"
    printf 'M2\tdone\tinterrupt wired\tqtest demo-timer irq exit gate\tnow\n' >> "$task/output/milestones.tsv"
    printf 'id\tstatus\tcriterion\tevidence\tupdated\n' > "$task/output/acceptance.tsv"
    printf 'AC1\tpass\tinterrupt fires\tqtest demo-timer\tnow\n' >> "$task/output/acceptance.tsv"
    expect_rc 0 "review-checks --final-goal accepts a complete goal" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    sed 's/^round: 1$/round: 2/' "$task/output/task-state.md" > "$TMPROOT/state-round2.md"
    mv "$TMPROOT/state-round2.md" "$task/output/task-state.md"
    expect_rc 1 "review-checks --final-goal rejects a stale round-result" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    cat > "$task/output/round-result.md" <<'EOF'
Round: 2
Verdict: PASS
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    expect_rc 0 "review-checks --final-goal accepts the current round-result" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    cat > "$task/output/round-result.md" <<'EOF'
Round: 2
Verdict: PASS
Gate: marker BOOT READY
Evidence:
EOF
    expect_rc 1 "review-checks --final-goal rejects empty round evidence" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: FAIL
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    expect_rc 1 "review-checks --final-goal rejects a FAIL round" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task" --final-goal
    expect_rc 1 "review-checks rejects non-PASS without blocker" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    printf 'Next blocker: add the missing trace event\n' >> "$task/output/round-result.md"
    expect_rc 0 "review-checks accepts non-PASS with blocker" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    grep -v '^rule' "$task/output/translation.tsv" > "$task/output/stale-translation.tsv"
    expect_rc 1 "review-checks rejects a translation missing IR rules" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" \
        --task-dir "$task" --ir "$task/output/register-semantics.ir" --translation "$task/output/stale-translation.tsv"
    rm -f "$task/output/round-result.md"
    expect_rc 1 "review-checks rejects a missing round-result" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: PASS
Gate: timeout after 60 seconds
Evidence: logs/serial.log
EOF
    expect_rc 1 "review-checks rejects timeout-based PASS" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    cat > "$task/output/round-result.md" <<'EOF'
Round: 1
Verdict: NOTPASS
Gate: marker BOOT READY
Evidence: logs/serial.log
EOF
    expect_rc 1 "review-checks rejects a non-exact verdict" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$task"
    gitrepo="$TMPROOT/review-git"
    mkdir -p "$gitrepo"
    ( cd "$gitrepo" && git init -q && git config user.name test && git config user.email test@example.com && printf 'base\n' > base.txt && git add base.txt && git commit -qm base )
    gtask="$gitrepo/.oh-my-qemu/demo"
    mkdir -p "$gtask"
    printf '# audit\n' > "$gtask/audit.md"
    printf '# commands\n' > "$gtask/commands.md"
    mkdir -p "$gitrepo/.agents" && printf 'leak\n' > "$gitrepo/.agents/leak"
    if bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" --task-dir "$gtask" --repo "$gitrepo" > "$TMPROOT/review-git.out" 2>&1; then
        fail "review-checks rejects untracked managed paths"
    elif grep -q 'managed paths remain visible to Git' "$TMPROOT/review-git.out"; then
        pass "review-checks rejects untracked managed paths"
    else
        fail "review-checks untracked path message missing"
    fi
    sed -i.bak '/^## Unresolved gaps$/d' "$task/audit.md" 2>/dev/null || true
    rm -f "$task/audit.md.bak"
    expect_rc 1 "review-checks rejects an incomplete audit" bash "$ROOT/skills/qemu-model-review/scripts/review-checks.sh" \
        --task-dir "$task" --ir "$task/output/register-semantics.ir"
}

test_preflight() {
    repo="$TMPROOT/preflight"
    mkdir -p "$repo/src/builds/build-test"
    printf "# Configured with: '%s/src/configure' '--target-list=aarch64-softmmu'\n" "$repo" > "$repo/src/builds/build-test/config.log"
    # Keep this test independent of the host toolchain (CI may lack meson/ninja).
    fakebin="$TMPROOT/fakebin-preflight"
    mkdir -p "$fakebin"
    for tool in git ninja meson python3 cc; do
        printf '#!/usr/bin/env bash\nif [ "${1:-}" = "--version" ]; then echo "%s fake 1.0"; fi\nexit 0\n' "$tool" > "$fakebin/$tool"
        chmod +x "$fakebin/$tool"
    done
    old_path="$PATH"
    PATH="$fakebin:$PATH"
    expect_rc 0 "preflight records a matching build dir" bash "$ROOT/skills/qemu-build/scripts/preflight.sh" --build-dir "$repo/src/builds/build-test" --source-root "$repo/src"
    PATH="$old_path"
    # A build-local meson must satisfy the tool check when the host has none.
    fakebin2="$TMPROOT/fakebin-preflight2"
    mkdir -p "$fakebin2" "$repo/src/builds/build-test/pyvenv/bin"
    for tool in git ninja python3 cc; do
        printf '#!/usr/bin/env bash\nif [ "${1:-}" = "--version" ]; then echo "%s fake 1.0"; fi\nexit 0\n' "$tool" > "$fakebin2/$tool"
        chmod +x "$fakebin2/$tool"
    done
    printf '#!/usr/bin/env bash\necho "9.9.0"\n' > "$repo/src/builds/build-test/pyvenv/bin/meson"
    chmod +x "$repo/src/builds/build-test/pyvenv/bin/meson"
    old_path="$PATH"
    PATH="$fakebin2:/usr/bin:/bin"
    expect_rc 0 "preflight accepts build-local meson" bash "$ROOT/skills/qemu-build/scripts/preflight.sh" --build-dir "$repo/src/builds/build-test" --source-root "$repo/src"
    PATH="$old_path"
}

test_redaction() {
    clean="$TMPROOT/clean-draft.md"
    printf 'The workflow should check evidence before claiming PASS.\n' > "$clean"
    expect_rc 0 "check-redaction accepts a clean draft" bash "$ROOT/skills/qemu-agent-feedback/scripts/check-redaction.sh" "$clean"
    dirty="$TMPROOT/dirty-draft.md"
    printf 'Observed at /Users/example/private/qemu and token: abcdef123456.\n' > "$dirty"
    expect_rc 1 "check-redaction flags private path and secret" bash "$ROOT/skills/qemu-agent-feedback/scripts/check-redaction.sh" "$dirty"
    token="$TMPROOT/token-draft.md"
    printf 'ghp_abcdefghijklmnopqrstuvwxyz0123456789\n' > "$token"
    expect_rc 1 "check-redaction flags a GitHub token" bash "$ROOT/skills/qemu-agent-feedback/scripts/check-redaction.sh" "$token"
    punct="$TMPROOT/punct-draft.md"
    printf 'path=/workspace/private\n' > "$punct"
    expect_rc 1 "check-redaction flags punctuation-delimited paths" bash "$ROOT/skills/qemu-agent-feedback/scripts/check-redaction.sh" "$punct"
}

test_collect_context() {
    repo="$TMPROOT/context"
    mkdir -p "$repo/builds/build-test"
    printf '# Configured with: %s/builds/build-test/../../configure --target-list=aarch64-softmmu\n' "$repo" > "$repo/builds/build-test/config.log"
    out="$TMPROOT/crash-report.md"
    expect_rc 0 "collect-context writes a report" bash "$ROOT/skills/qemu-debug/scripts/collect-context.sh" --output "$out" --qemu "$(command -v sh)" --command "qemu-system-aarch64 -M test" --build-dir "$repo/builds/build-test" --cwd "$repo"
    expect_contains "$out" "## Command and working directory" "collect-context report has command section"
    expect_contains "$out" "## Provenance" "collect-context report has provenance section"
    expect_rc 2 "collect-context requires --output" bash "$ROOT/skills/qemu-debug/scripts/collect-context.sh" --qemu "$(command -v sh)"
    expect_rc 1 "collect-context fails on missing config.log" bash "$ROOT/skills/qemu-debug/scripts/collect-context.sh" --output "$TMPROOT/crash-missing.md" --qemu "$(command -v sh)" --build-dir "$TMPROOT/no-such-build" --cwd "$repo"
    runroot="$TMPROOT/runroot"
    mkdir -p "$runroot/bin" "$runroot/builds/build-test"
    cp "$(command -v sh)" "$runroot/bin/qemu"
    printf '# Configured with: %s/builds/build-test/../../configure --target-list=aarch64-softmmu\n' "$runroot" > "$runroot/builds/build-test/config.log"
    printf 'serial output\n' > "$runroot/serial.log"
    out2="$TMPROOT/crash-relative.md"
    expect_rc 0 "collect-context resolves relative artifacts from --cwd" bash "$ROOT/skills/qemu-debug/scripts/collect-context.sh" --output "$out2" --qemu bin/qemu --build-dir builds/build-test --log serial.log --cwd "$runroot"
    expect_contains "$out2" "$runroot/bin/qemu" "collect-context resolves relative binary"
    expect_contains "$out2" "$runroot/serial.log" "collect-context resolves relative log"
}

test_framework_decision() {
    good="$TMPROOT/framework-good.md"
    cat > "$good" <<'EOF'
# Register bank framework decision record
- Device: demo
- Window: 0x1000+0x100
- Bank kind: control-status
- RegisterInfo default applies: yes
- Implementation: RegisterInfo
- Decisive input: none: RegisterInfo default
- Rationale: control/status storage with W1C and IRQ hooks
- Structural reason (required for manual/hybrid): <not applicable>
- Hybrid split: none
- Accepted limits: 4-byte accesses only
- Review gate: reviewer F-01 PASS
EOF
    expect_rc 0 "framework decision accepts RegisterInfo default" bash "$ROOT/skills/qemu-peripheral-modeling/scripts/check-framework-decision.sh" "$good"
    manual="$TMPROOT/framework-manual.md"
    cat > "$manual" <<'EOF'
# Register bank framework decision record
- Device: demo
- Window: 0x1000+0x100
- Bank kind: control-status
- Implementation: manual MMIO
- Decisive input: none: no policy, user direction, or comparable sibling
- Rationale: command doorbell and FIFO aperture need explicit sequencing
- Structural reason (required for manual/hybrid): command doorbell and FIFO aperture cannot be expressed by RegisterAccessInfo hooks
- Hybrid split: none
- Accepted limits: 4-byte accesses only
- Review gate: reviewer F-02 PASS
EOF
    expect_rc 0 "framework decision accepts a structural manual exception" bash "$ROOT/skills/qemu-peripheral-modeling/scripts/check-framework-decision.sh" "$manual"
    bad="$TMPROOT/framework-bad.md"
    cat > "$bad" <<'EOF'
# Register bank framework decision record
- Device: demo
- Window: 0x1000+0x100
- Bank kind: control-status
- Implementation: manual MMIO
- Decisive input: nearby devices are manual
- Rationale: we are behind schedule
- Structural reason (required for manual/hybrid): nearby devices are manual
- Hybrid split: none
- Accepted limits: <access sizes, side effects, reentrancy>
- Review gate: <reviewer/date/verdict>
EOF
    expect_rc 1 "framework decision rejects a weak manual rationale" bash "$ROOT/skills/qemu-peripheral-modeling/scripts/check-framework-decision.sh" "$bad"
}

test_assets_exist() {
    for asset in         "$ROOT/skills/qemu-workflow/assets/audit-template.md"         "$ROOT/skills/qemu-workflow/assets/round-result-template.md"         "$ROOT/skills/qemu-workflow/assets/evidence-manifest-template.md"         "$ROOT/skills/qemu-workflow/assets/handoff-template.md"         "$ROOT/skills/qemu-board-modeling/assets/board-contract-template.md"         "$ROOT/skills/qemu-board-modeling/assets/unimplemented-map-template.csv"         "$ROOT/skills/qemu-rst-documentation/assets/board-machine-page-template.rst"         "$ROOT/skills/qemu-register-extraction/assets/ir-ops.def" "$ROOT/skills/qemu-register-extraction/assets/register-semantics-template.ir" "$ROOT/skills/qemu-register-extraction/assets/register-semantics-example.ir"         "$ROOT/skills/qemu-qtest/assets/qtest-plan-template.md"         "$ROOT/skills/qemu-model-verification/assets/claim-record-template.md"         "$ROOT/skills/qemu-debug/assets/crash-report-template.md"         "$ROOT/skills/qemu-build/assets/build-record-template.md"         "$ROOT/skills/qemu-kernel-build/assets/build-record-template.md"         "$ROOT/skills/qemu-uboot-build/assets/artifact-manifest-template.md"         "$ROOT/skills/qemu-image/assets/packaging-plan-template.md"         "$ROOT/skills/qemu-boot-run/assets/run-record-template.md"         "$ROOT/skills/qemu-linux-boot/assets/boot-evidence-template.md"         "$ROOT/skills/qemu-tcg-frontend/assets/isa-coverage-template.md"         "$ROOT/skills/qemu-tcg-backend/assets/backend-change-template.md" \
        "$ROOT/skills/qemu-modeler/assets/task-state-template.md" \
        "$ROOT/skills/qemu-modeler/assets/review-request-template.md" \
        "$ROOT/skills/qemu-model-review/assets/review-report-template.md"; do
        if [ -s "$asset" ]; then pass "asset exists: ${asset#$ROOT/}"; else fail "asset missing or empty: ${asset#$ROOT/}"; fi
    done
}

main() {
    printf 'skill script tests: %s\n' "$ROOT"
    test_syntax
    test_help
    test_assets_exist
    test_gates_exclude
    test_gates_workspace_and_audit
    test_gates_round_result
    test_gates_manifest_and_marker
    test_gates_build_dir
    test_gates_handoff_and_all
    test_gates_source_comments
    test_rst_gates
    test_check_registration
    test_validate_register_ir
    test_orchestrator_state
    test_review_checks
    test_preflight
    test_framework_decision
    test_redaction
    test_collect_context
    printf '\nsummary: %s passed, %s failed, %s skipped\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
    [ "$FAIL_COUNT" -eq 0 ]
}

main "$@"
