"""Regression tests for trustworthy economy comparisons and isolated Git snapshots."""

import copy
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile


SPEC = importlib.util.spec_from_file_location("compare_economy", Path(__file__).with_name("compare-economy.py"))
COMPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPARE)


def fixture():
    return {"settings": {"farm": "1", "hours": 6, "orders": True, "equipment": []},
            "totals": {"incomePerSecond": 10, "orders": {"minutesMax": 12},
                       "goods": [{"id": "milk", "produced": 5, "ordered": 3}]},
            "sources": [{"name": "sipariş", "amount": 40}],
            "milestones": [{"name": "TÜM YÜKSELTMELER", "minutes": 200},
                           {"name": "ÇİFTLİK 2 alındı", "minutes": 210},
                           {"name": "Ç2 TÜM YÜKSELTMELER", "minutes": 550}]}


class ComparisonTests(unittest.TestCase):
    def test_all_scenario_fields_are_checked(self):
        for key, value in [("hours", 7), ("equipment", ["crown"]), ("newHiddenOption", True), ("orders", 1)]:
            other = fixture()
            other["settings"][key] = value
            with self.assertRaisesRegex(ValueError, "Scenario mismatch"):
                COMPARE.compare(fixture(), other)

    def test_runtime_identity_is_causal_but_revision_and_time_are_not(self):
        before = {"result": fixture(), "metadata": {"luau": {"sha256": "one"}, "simArgs": ["--hours", "6"], "python": {"version": "3"}, "platform": "test", "gitSha": "old", "timestamp": "old", "elapsedSeconds": 2}}
        after = copy.deepcopy(before)
        after["metadata"].update(gitSha="new", timestamp="new", elapsedSeconds=4)
        COMPARE.compare(before, after)
        after["metadata"]["luau"]["sha256"] = "two"
        with self.assertRaisesRegex(ValueError, "metadata mismatch"):
            COMPARE.compare(before, after)
        with self.assertRaisesRegex(ValueError, "metadata mismatch"):
            COMPARE.compare(before, fixture())
        with self.assertRaisesRegex(ValueError, "metadata mismatch"):
            COMPARE.compare({"result": fixture(), "metadata": {}}, {"result": fixture(), "metadata": {}})

    def test_missing_metrics_and_added_removed_goods_are_not_zero(self):
        after = fixture()
        after["totals"]["orders"]["referenceMinutesMax"] = 5
        after["totals"]["goods"] = [{"id": "egg", "produced": 0}]
        report = COMPARE.compare(fixture(), after)
        rows = {row["metric"]: row for row in report["metrics"]}
        cap = rows["totals.orders.referenceMinutesMax"]
        self.assertEqual((cap["status"], cap["before"], cap["delta"]), ("added", None, None))
        self.assertEqual(rows["goods.milk.produced"]["status"], "removed")
        self.assertEqual(rows["goods.egg.produced"]["after"], 0)
        self.assertIsNone(rows["goods.egg.produced"]["before"])
        self.assertTrue(any("different denominator" in warning for warning in report["warnings"]))

    def test_payout_and_duration_differences_preserve_their_semantics(self):
        after = fixture()
        after["sources"][0]["amount"] = 50
        after["milestones"][1]["minutes"] = 220
        after["milestones"][2]["minutes"] = 540
        rows = {row["metric"]: row for row in COMPARE.compare(fixture(), after)["metrics"]}
        self.assertEqual(rows["payouts.sipariş.amount"]["delta"], 10)
        self.assertEqual(rows["completion.farm2.minutesFromPurchase"]["before"], 340)
        self.assertEqual(rows["completion.farm2.minutesFromPurchase"]["delta"], -20)

    def test_zero_baseline_has_no_invented_percentage(self):
        before, after = fixture(), fixture()
        before["totals"]["incomePerSecond"] = 0
        row = next(row for row in COMPARE.compare(before, after)["metrics"] if row["metric"] == "totals.incomePerSecond")
        self.assertEqual(row["delta"], 10)
        self.assertIsNone(row["percent"])

    def test_archive_paths_cannot_escape_or_copy_symlinks(self):
        for name, mode in [("../escape", 0), ("src/link", 0o120777 << 16)]:
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w") as archive:
                info = zipfile.ZipInfo(name)
                info.external_attr = mode
                archive.writestr(info, b"payload")
            with tempfile.TemporaryDirectory() as directory:
                with patch.object(COMPARE.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, buffer.getvalue())):
                    with self.assertRaisesRegex(ValueError, "Unsafe archive"):
                        COMPARE.snapshot("abc", Path(directory))
                self.assertEqual(list(Path(directory).iterdir()), [])

    def test_duplicate_evidence_rows_fail(self):
        broken = fixture()
        broken["totals"]["goods"].append({"id": "milk", "produced": 9})
        with self.assertRaisesRegex(ValueError, "duplicate"):
            COMPARE.compare(broken, fixture())

    def test_external_input_and_interpreter_overrides_fail_before_snapshot(self):
        for option in ["--luau", "--lua=other", "--carry-account", "--carry", "--smoke", "--json"]:
            with patch.object(COMPARE, "pin_ref") as resolve:
                with self.assertRaisesRegex(ValueError, "controls JSON/interpreter"):
                    COMPARE.run(SimpleNamespace(sim_args=[option], luau=None))
                resolve.assert_not_called()


if __name__ == "__main__":
    unittest.main()
