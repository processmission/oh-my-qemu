#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026 Process Mission
# SPDX-License-Identifier: MIT

"""Tests for the qemu-boot-run marker classifier."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
RUNNER = (
    REPO_ROOT
    / "skills"
    / "qemu-boot-run"
    / "scripts"
    / "run-and-classify.py"
)


class BootRunClassifierTest(unittest.TestCase):
    def run_case(
        self,
        program: str,
        *,
        timeout: float = 0.3,
        success: str = "READY",
        failure: str | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            log = root / "serial.log"
            report = root / "report.json"
            command = [
                sys.executable,
                str(RUNNER),
                "--timeout",
                str(timeout),
                "--poll-interval",
                "0.02",
                "--terminate-grace",
                "0.5",
                "--log",
                str(log),
                "--report",
                str(report),
                "--success-marker",
                success,
            ]
            if failure:
                command.extend(["--failure-marker", failure])
            command.extend(
                ["--", sys.executable, "-c", textwrap.dedent(program), str(log)]
            )
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=5,
            )
            return result, json.loads(report.read_text(encoding="utf-8"))

    def test_success_flushed_only_after_timeout_termination(self) -> None:
        result, report = self.run_case(
            """
            import signal
            import sys
            import time

            output = open(sys.argv[1], "w", buffering=8192)

            def stop(_signum, _frame):
                output.write("READY\\n")
                output.close()
                raise SystemExit(0)

            signal.signal(signal.SIGTERM, stop)
            while True:
                time.sleep(0.05)
            """,
            timeout=1,
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(report["classification"], "passed")
        self.assertTrue(report["process"]["timed_out"])
        self.assertEqual(report["semantic"]["status"], "success")
        self.assertTrue(report["semantic"]["evaluated_after_process_exit"])

    def test_live_success_stops_process_without_timeout(self) -> None:
        result, report = self.run_case(
            """
            import sys
            import time

            with open(sys.argv[1], "w") as output:
                output.write("READY\\n")
            time.sleep(30)
            """,
            timeout=1,
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(report["process"]["stop_reason"], "success-marker")
        self.assertFalse(report["process"]["timed_out"])
        self.assertEqual(report["semantic"]["status"], "success")

    def test_unmatched_timeout_remains_timeout(self) -> None:
        result, report = self.run_case(
            """
            import time
            time.sleep(30)
            """
        )

        self.assertEqual(result.returncode, 124)
        self.assertEqual(report["classification"], "inconclusive")
        self.assertTrue(report["process"]["timed_out"])
        self.assertEqual(report["semantic"]["status"], "unmatched")

    def test_failure_marker_wins_over_success_marker(self) -> None:
        result, report = self.run_case(
            """
            import sys

            with open(sys.argv[1], "w") as output:
                output.write("READY\\nKernel panic\\n")
            """,
            failure="Kernel panic",
        )

        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["classification"], "failed")
        self.assertEqual(report["semantic"]["status"], "failure")


if __name__ == "__main__":
    unittest.main()
