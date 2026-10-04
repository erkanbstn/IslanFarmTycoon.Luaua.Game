"""QA artifacts stay isolated; commands are parsed by the real Luau compiler."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("studio_qa", ROOT / "scripts/studio-qa.py")
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class StudioQaTests(unittest.TestCase):
    def test_production_mapping_unchanged_and_qa_nonpersistent(self):
        path = ROOT / "default.project.json"
        before = path.read_bytes()
        test = qa.project()
        self.assertEqual(before, path.read_bytes())
        original = json.loads(before)
        self.assertNotIn("StudioQa", original["tree"]["ServerScriptService"])
        self.assertNotIn("StudioQaEnabled", original["tree"]["Workspace"].get("$attributes", {}))
        self.assertEqual(test["tree"]["Workspace"]["$attributes"]["StudioNonPersistentData"], True)
        self.assertEqual(test["tree"]["Workspace"]["$attributes"]["StudioQaEnabled"], True)
        self.assertTrue(Path(test["tree"]["ServerScriptService"]["StudioQa"]["$path"]).is_absolute())

    def test_all_paths_survive_manifest_relocation(self):
        def visit(node):
            for key, value in node.items():
                if key == "$path":
                    self.assertTrue(Path(value).is_absolute())
                    self.assertTrue(Path(value).exists())
                elif isinstance(value, dict):
                    visit(value)
        visit(qa.project())

    def test_reject_external_project_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "default.project.json").write_text(json.dumps({"tree": {"Bad": {"$path": "../outside"}}}))
            with self.assertRaises(ValueError):
                qa.project(root)

    def test_invalid_requests(self):
        for scenario, level, request_id in [("other", 0, 1), ("fresh", 31, 1), ("fresh", 0, 0)]:
            with self.assertRaises(ValueError):
                qa.command(scenario, 1, request_id, level)

    def test_commands_compile(self):
        compiler = ROOT / ".tools/luau/luau-compile.exe"
        if not compiler.exists():
            self.skipTest("Luau compiler unavailable; full verification checks tool availability")
        with tempfile.TemporaryDirectory() as tmp:
            for index, text in enumerate([qa.command("rebirth-ready", -1, 1, 30), qa.SERVER_INSPECT, qa.CLIENT_INSPECT]):
                source = Path(tmp) / f"command-{index}.luau"
                source.write_text(text, encoding="utf-8")
                result = subprocess.run([str(compiler), str(source)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
