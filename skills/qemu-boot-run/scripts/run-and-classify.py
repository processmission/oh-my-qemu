#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT

"""Run QEMU, scan a serial log, and classify process and guest outcomes."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from typing import Any


EXIT_FAILURE = 1
EXIT_TIMEOUT = 124


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run a command while watching a file-backed serial log, then "
            "rescan the finalized log before classifying the result."
        )
    )
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument(
        "--success-marker",
        action="append",
        required=True,
        help="Required success marker; repeat to require all markers.",
    )
    parser.add_argument(
        "--failure-marker",
        action="append",
        default=[],
        help="Decisive failure marker; repeat to reject any matching marker.",
    )
    parser.add_argument("--poll-interval", type=float, default=0.25)
    parser.add_argument("--terminate-grace", type=float, default=5.0)
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Command to run, preceded by --.",
    )
    args = parser.parse_args()

    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("a command is required after --")
    for name in ("timeout", "poll_interval", "terminate_grace"):
        if getattr(args, name) <= 0:
            parser.error(f"--{name.replace('_', '-')} must be greater than zero")
    if args.report and args.report.resolve() == args.log.resolve():
        parser.error("--report and --log must name different files")

    return args


def read_log(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return b""


def scan_log(
    path: Path, success_markers: list[str], failure_markers: list[str]
) -> dict[str, Any]:
    data = read_log(path)
    matched_success = [
        marker for marker in success_markers if marker.encode() in data
    ]
    missing_success = [
        marker for marker in success_markers if marker not in matched_success
    ]
    matched_failure = [
        marker for marker in failure_markers if marker.encode() in data
    ]

    if matched_failure:
        status = "failure"
    elif not missing_success:
        status = "success"
    else:
        status = "unmatched"

    return {
        "status": status,
        "matched_success_markers": matched_success,
        "missing_success_markers": missing_success,
        "matched_failure_markers": matched_failure,
        "log_bytes": len(data),
    }


def stop_process_group(process: subprocess.Popen[Any], grace: float) -> None:
    if process.poll() is not None:
        return

    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return

    try:
        process.wait(timeout=grace)
        return
    except subprocess.TimeoutExpired:
        pass

    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    process.wait()


def result_exit_code(
    semantic_status: str, timed_out: bool, process_exit_code: int | None
) -> int:
    if semantic_status == "success":
        return 0
    if semantic_status == "failure":
        return EXIT_FAILURE
    if timed_out:
        return EXIT_TIMEOUT
    if process_exit_code and 0 < process_exit_code < 126:
        return process_exit_code
    return EXIT_FAILURE


def write_report(report: dict[str, Any], path: Path | None) -> None:
    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(output, encoding="utf-8")
        print(path)
    else:
        print(output, end="")


def main() -> int:
    args = parse_args()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    args.log.write_bytes(b"")

    started = time.monotonic()
    process = subprocess.Popen(args.command, start_new_session=True)
    deadline = started + args.timeout
    timed_out = False
    stop_reason = "process-exit"

    try:
        while process.poll() is None:
            scan = scan_log(
                args.log, args.success_marker, args.failure_marker
            )
            if scan["status"] == "failure":
                stop_reason = "failure-marker"
                stop_process_group(process, args.terminate_grace)
                break
            if scan["status"] == "success":
                stop_reason = "success-marker"
                stop_process_group(process, args.terminate_grace)
                break
            if time.monotonic() >= deadline:
                timed_out = True
                stop_reason = "timeout"
                stop_process_group(process, args.terminate_grace)
                break
            time.sleep(args.poll_interval)
    except BaseException:
        stop_process_group(process, args.terminate_grace)
        raise

    process_exit_code = process.wait()

    # File-backed chardevs may flush only while the process is shutting down.
    final_scan = scan_log(args.log, args.success_marker, args.failure_marker)
    final_scan["evaluated_after_process_exit"] = True
    exit_code = result_exit_code(
        final_scan["status"], timed_out, process_exit_code
    )
    classification = {
        "success": "passed",
        "failure": "failed",
        "unmatched": "inconclusive",
    }[final_scan["status"]]

    if timed_out:
        process_status = "timed-out"
    elif stop_reason in ("success-marker", "failure-marker"):
        process_status = "terminated-after-marker"
    else:
        process_status = "exited"

    report = {
        "schema_version": 1,
        "command": args.command,
        "duration_seconds": round(time.monotonic() - started, 3),
        "log": str(args.log),
        "process": {
            "status": process_status,
            "exit_code": process_exit_code,
            "timed_out": timed_out,
            "stop_reason": stop_reason,
        },
        "semantic": final_scan,
        "classification": classification,
        "runner_exit_code": exit_code,
    }
    write_report(report, args.report)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
