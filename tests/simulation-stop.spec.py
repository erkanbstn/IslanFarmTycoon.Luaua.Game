"""Opt-in tier simulation stopping preserves real completion milestones."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
SIMULATION = ROOT / "scripts" / "simulate-economy.py"
LUAU: str | None = None


def simulation_command(*arguments: str) -> list[str]:
    return [sys.executable, str(SIMULATION), *(["--luau", LUAU] if LUAU else []), *arguments]


class SimulationStopTests(unittest.TestCase):
    def simulate(self, *arguments: str) -> dict:
        result = subprocess.run(
            simulation_command("--json", *arguments),
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        return json.loads(result.stdout.decode("utf-8-sig"))

    def test_requires_full_sequential_completion(self):
        for arguments in [[], ["--finish-first", "--completion", "basic"]]:
            result = subprocess.run(
                simulation_command("--stop-after-farms", *arguments),
                cwd=ROOT,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 2)

    def test_incomplete_farms_run_entire_horizon(self):
        result = self.simulate("--hours", "0.1", "--farms", "6", "--finish-first", "--stop-after-farms")
        self.assertAlmostEqual(result["totals"]["onlineMinutes"], 6)
        self.assertEqual(result["totals"]["farmsOwned"], 1)

    def test_completion_time_and_prior_milestones_are_unchanged(self):
        arguments = ("--persona", "ideal", "--hours", "6", "--farms", "1", "--finish-first")
        full = self.simulate(*arguments)
        stopped = self.simulate(*arguments, "--stop-after-farms")
        completion = next(row["minutes"] for row in full["milestones"] if row["name"] == "TÜM YÜKSELTMELER")
        prefix = [row for row in full["milestones"] if row["minutes"] <= completion]
        self.assertEqual(stopped["milestones"], prefix)
        self.assertAlmostEqual(stopped["totals"]["onlineMinutes"], completion, places=2)
        self.assertEqual(full["totals"]["onlineMinutes"], 360)
        self.assertLess(stopped["totals"]["onlineMinutes"], full["totals"]["onlineMinutes"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--luau")
    options, remaining = parser.parse_known_args()
    LUAU = options.luau
    unittest.main(argv=[sys.argv[0], *remaining])
