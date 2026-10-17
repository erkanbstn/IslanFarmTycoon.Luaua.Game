"""Real harness dependency/scope regressions and read-only doctor diagnostics."""
from pathlib import Path
import contextlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = load("dependency_check_fixture", "scripts/check-test-dependencies.py")
RUNNER = load("dependency_runner_fixture", "scripts/run-tests.py")
DOCTOR = load("doctor_fixture", "scripts/doctor.py")
HYGIENE = load("hygiene_fixture", "scripts/check-repo-hygiene.py")
TRIAGE = load("triage_fixture", "scripts/triage.py")
SMOKE = load("smoke_quick_fixture", "scripts/smoke-quick.py")


class DependencyTests(unittest.TestCase):
    def module(self, name: str, source: str, deps=(), args: str = "") -> str:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            (fixture / "module.luau").write_text(source, encoding="utf-8")
            with patch.object(RUNNER, "ROOT", fixture):
                return RUNNER.module(name, "module.luau", set(deps), args)

    def test_valid_actual_require_substitution_and_order(self):
        inventory = self.module("Inventory", "return {}")
        merchant = self.module("Merchant", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory', {"Inventory"})
        self.assertEqual(CHECKER.check_bundle(inventory + merchant), [])

    def test_unknown_or_unresolved_require_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unexpected dependency"):
            self.module("Merchant", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory')
        with self.assertRaisesRegex(ValueError, "Dependency mismatch"):
            self.module("Merchant", "return {}", {"Inventory"})
        with self.assertRaisesRegex(ValueError, "Unresolved require"):
            self.module("Merchant", 'return require(script.Parent.Inventory)')

    def test_later_local_inventory_cannot_be_captured_by_merchant(self):
        merchant = self.module("Merchant", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory', {"Inventory"})
        inventory = self.module("Inventory", "return {}")
        findings = CHECKER.check_bundle(merchant + inventory)
        self.assertEqual([row["code"] for row in findings], ["TD002"])
        self.assertIn("Inventory", findings[0]["message"])

    def test_nested_inventory_does_not_escape_save_codec_scope(self):
        nested = "-- Harness scope: SaveCodec\n" + self.module("Inventory", "return {}") + "-- Harness endscope: SaveCodec\n"
        merchant = self.module("Merchant", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory', {"Inventory"})
        self.assertEqual(CHECKER.check_bundle(nested + merchant)[0]["code"], "TD002")

    def test_factory_argument_is_an_explicit_runtime_mock(self):
        factory = self.module("MerchantFactory", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory', {"Inventory"}, "game, Inventory")
        self.assertEqual(CHECKER.check_bundle(factory), [])
        captured = self.module("MerchantFactory", 'local Inventory = require(script.Parent.Inventory)\nreturn Inventory', {"Inventory"}, "game")
        self.assertEqual(CHECKER.check_bundle(captured)[0]["code"], "TD002")

    def test_type_annotation_requires_no_runtime_mock_but_runtime_usage_does(self):
        annotation = self.module("BannerFactory", 'local Banner = require(script.Parent.Banner)\nfunction create(value: Banner.Frame)\nreturn value\nend\nreturn create', {"Banner"}, "game")
        findings = CHECKER.check_bundle(annotation)
        self.assertEqual((findings[0]["code"], findings[0]["severity"]), ("TD004", "warning"))
        runtime = self.module("BannerFactory", 'local Banner = require(script.Parent.Banner)\nreturn Banner.create()', {"Banner"}, "game")
        self.assertEqual(CHECKER.check_bundle(runtime)[0]["code"], "TD002")

    def test_return_annotation_and_unrelated_cast_do_not_confuse_runtime_usage(self):
        annotation = self.module("BannerFactory", 'local Banner = require(script.Parent.Banner)\nfunction create(): Banner.Frame\nreturn {}\nend\nreturn create', {"Banner"}, "game")
        self.assertEqual(CHECKER.check_bundle(annotation)[0]["code"], "TD004")
        runtime = self.module("BannerFactory", 'local Banner = require(script.Parent.Banner)\nreturn (input :: any) + Banner.value', {"Banner"}, "game")
        self.assertEqual(CHECKER.check_bundle(runtime)[0]["code"], "TD002")

    def test_malformed_metadata_fails_closed(self):
        self.assertEqual(CHECKER.check_bundle("-- Harness module: {bad}")[0]["code"], "TD003")
        self.assertEqual(CHECKER.check_bundle("-- Harness endscope: Unknown")[0]["code"], "TD003")

    def test_real_project_check_does_not_write_generated_test_file(self):
        generated = ROOT / ".test-build/run.luau"
        before = generated.stat().st_mtime_ns if generated.exists() else None
        result = subprocess.run([sys.executable, "scripts/check-test-dependencies.py", "--json"], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["ok"])
        self.assertEqual(before, generated.stat().st_mtime_ns if generated.exists() else None)


class DoctorTests(unittest.TestCase):
    def fixture(self, root: Path):
        for path in ("CLAUDE.md", "docs/MIMARI.md", ".claude/rules/tests-tooling.md", ".claude/skills/roblox-verify/SKILL.md", "scripts/verify.ps1", "scripts/types-baseline.json", "rokit.toml"):
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("{}" if path.endswith("json") else "fixture", encoding="utf-8")

    def test_missing_requirements_are_specific_and_never_install(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
            with patch.object(DOCTOR, "probe", return_value=(1, "")) as probe:
                result = DOCTOR.diagnose(root, require_types=True)
            after = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
            self.assertEqual(before, after)
            self.assertFalse(result["ok"])
            self.assertTrue({"DR001", "DR004", "DR005"}.issubset({row["code"] for row in result["issues"]}))
            self.assertTrue(all(call.args[0][0] == "git" for call in probe.call_args_list))
            self.assertNotIn("environment", result)

    def test_wrong_tool_version_is_reported_instead_of_assumed_matching(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            (root / "rokit.toml").write_text('[tools]\nrojo="r/rojo@7.4.4"\nstylua="r/stylua@2.0.2"\nselene="r/selene@0.28.0"', encoding="utf-8")
            with patch.object(DOCTOR, "tool_path", return_value=("fake", "PATH")), patch.object(DOCTOR, "probe", return_value=(0, "tool 99.99")):
                result = DOCTOR.diagnose(root)
            self.assertEqual(sum(row["code"] == "DR003" for row in result["issues"]), 3)
            self.assertFalse(result["luau"]["version_verified"])


@unittest.skipUnless(shutil.which("powershell") or shutil.which("pwsh"), "PowerShell unavailable")
class FastWrapperTests(unittest.TestCase):
    def run_wrapper(self, verify: str, arguments=()):
        with tempfile.TemporaryDirectory() as directory:
            scripts = Path(directory) / "scripts"
            scripts.mkdir()
            (scripts / "verify-fast.ps1").write_bytes((ROOT / "scripts/verify-fast.ps1").read_bytes())
            (scripts / "verify.ps1").write_text(verify, encoding="utf-8")
            return subprocess.run([shutil.which("powershell") or shutil.which("pwsh"), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / "verify-fast.ps1"), *arguments], capture_output=True, text=True)

    def test_fast_wrapper_forwards_type_requirement_and_custom_paths(self):
        result = self.run_wrapper('param($Mode,$LuauDirectory,$Python,[switch]$RequireTypes)\nWrite-Output "$Mode|$LuauDirectory|$Python|$RequireTypes"\nexit 0', ["-RequireTypes", "-LuauDirectory", "custom luau folder", "-Python", "custom python"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Fast|custom luau folder|custom python|True", result.stdout)

    def test_fast_wrapper_never_hides_a_verification_failure(self):
        result = self.run_wrapper('param($Mode,$LuauDirectory,$Python,[switch]$RequireTypes)\nthrow "fixture failed"')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture failed", result.stderr)


class HygieneTests(unittest.TestCase):
    def repo(self, files: dict[str, str], git: bool = False) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        for name, content in files.items():
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        if git:
            if not shutil.which("git"):
                self.skipTest("git yok")
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "add", "-f", "."], cwd=root, check=True)
        return root

    def findings(self, files: dict[str, str], git: bool = False) -> str:
        return "\n".join(HYGIENE.check(self.repo(files, git)))

    def test_real_repository_is_clean(self):
        self.assertEqual(HYGIENE.check(ROOT), [])

    def test_dead_path_and_broken_link_are_reported_but_prefix_and_history_are_not(self):
        out = self.findings({
            "CLAUDE.md": "`docs/GONE.md` ve [x](docs/MISSING.md) ve `assets/Pets/Pet_`\n`docs/OLD.md` (git geçmişinde).\n",
            "assets/Pets/Pet_cow.rbxmx": "<roblox/>",
            "docs/LIVE.md": "CLAUDE.md anar\n",
        })
        self.assertIn("var olmayan yol: docs/GONE.md", out)
        self.assertIn("kırık bağlantı: docs/MISSING.md", out)
        self.assertNotIn("Pet_", out)
        self.assertNotIn("OLD.md", out)

    def test_orphan_doc_script_and_module_are_reported(self):
        out = self.findings({
            "CLAUDE.md": "`docs/USED.md` `scripts/used.py` `UsedModule`\n",
            "docs/USED.md": "x", "docs/ORPHAN.md": "x",
            "scripts/used.py": "", "scripts/orphan.py": "",
            "src/server/Services/UsedModule.luau": "return {}", "src/server/Services/DeadModule.luau": "return {}",
            "src/server/Services/Main.server.luau": "return nil",
        })
        self.assertIn("docs/ORPHAN.md", out)
        self.assertIn("scripts/orphan.py", out)
        self.assertIn("DeadModule.luau", out)
        for fine in ("docs/USED.md:", "scripts/used.py:", "UsedModule.luau:", "Main.server.luau:"):
            self.assertNotIn(fine, out)

    def test_luau_dead_function_commented_code_and_remote_gaps_are_reported(self):
        out = self.findings({
            "CLAUDE.md": "x",
            "src/server/Services/Svc.luau": "local Svc = {}\nfunction Svc.used() end\nfunction Svc.dead() end\n-- local old = 1\n-- Svc.old()\n-- normal açıklama metni\nreturn Svc\n",
            "src/client/Ui/Caller.luau": "local Svc = require(x)\nSvc.used()\nremote.get('Both')\nremote.get('OnlyClient')\n",
            "src/server/Services/Handler.luau": "remote.get('Both')\nlocal map = { Mapped = f }\n",
            "src/shared/Remotes.luau": 'export type EventName =\n\t"Both"\n\t| "OnlyClient"\n\t| "Mapped"\n\nreturn {}\n',
        })
        self.assertIn("`dead` yalnızca tanımlı", out)
        self.assertNotIn("`used`", out)
        self.assertIn("yorum satırına alınmış kod: -- local old = 1", out)
        self.assertIn("yorum satırına alınmış kod: -- Svc.old()", out)
        self.assertNotIn("normal açıklama", out)
        self.assertIn("`OnlyClient` olayı sunucu tarafında", out)
        self.assertIn("`Mapped` olayı istemci tarafında", out)
        self.assertNotIn("`Both`", out)

    def test_dead_locale_key_is_reported_but_atoms_and_escapes_are_not(self):
        files = {"CLAUDE.md": "x", "src/server/Cfg.luau": 'return { name = "Et Tütsühanesi", t = "Aktif ürün", u = "Tekrar" }'}
        locale = 'return {\n\t["Tütsühane"] = "a",\n\t["Aktif ürün\\nTekrar"] = "b",\n\t["Ölü kaldırılmış"] = "c",\n}\n'
        for code in ("en", "de", "ru", "es", "pt"):
            files[f"src/shared/Locales/{code}.luau"] = locale
        out = self.findings(files)
        self.assertIn("Ölü kaldırılmış", out)
        self.assertNotIn("Tütsühane", out)
        self.assertNotIn("Aktif", out)

    def test_oversized_doc_is_reported(self):
        out = self.findings({"CLAUDE.md": "docs/BIG.md docs/SMALL.md", "docs/BIG.md": "satır\n" * 401, "docs/SMALL.md": "satır\n" * 400})
        self.assertIn("docs/BIG.md: 401 satır", out)
        self.assertNotIn("docs/SMALL.md:", out)

    def test_unknown_handover_commit_is_reported(self):
        out = self.findings({"CLAUDE.md": "docs/DEVIR_DURUMU.md", "docs/DEVIR_DURUMU.md": "Main `abc1234` ve 12345678 sayısı\n"}, git=True)
        self.assertIn("depoda olmayan commit kimliği: abc1234", out)
        self.assertNotIn("12345678", out)

    def test_tracked_junk_is_reported_only_when_git_tracks_it(self):
        out = self.findings({"CLAUDE.md": "x", "render.log": "x", "scripts/__pycache__/a.pyc": "x"}, git=True)
        self.assertIn("render.log: git'te izlenen", out)
        self.assertIn("scripts/__pycache__/a.pyc: git'te izlenen", out)
        self.assertNotIn("CLAUDE.md:", out)


def changed(path: str, deleted: bool = False) -> dict:
    return {"path": path, "status": "silindi" if deleted else "değişti", "deleted": deleted}


class TriageTests(unittest.TestCase):
    def claude_rules(self) -> set[str]:
        text = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        section = text.split("## Kurallar ve skill'ler", 1)[1].split("\n## ", 1)[0]
        return set(re.findall(r"\.claude/rules/[\w-]+\.md", section))

    def test_mapping_matches_claude_table_rule_paths_and_skills(self):
        on_disk = {path.relative_to(ROOT).as_posix() for path in (ROOT / ".claude/rules").glob("*.md")}
        self.assertEqual({rule for rule, _ in TRIAGE.RULES}, self.claude_rules())
        self.assertEqual({rule for rule, _ in TRIAGE.RULES}, on_disk)
        for rule, patterns in TRIAGE.RULES:
            text = (ROOT / rule).read_text(encoding="utf-8").replace("\r\n", "\n")
            block = re.match(r"^---\n(.*?)\n---\n", text, re.S)
            self.assertIsNotNone(block, rule)
            listed = re.findall(r'^\s+-\s+"([^"]+)"\s*$', block.group(1), re.MULTILINE)
            self.assertTrue(listed, rule)
            self.assertEqual(sorted(patterns), sorted(listed), rule)
        skills = {path.name for path in (ROOT / ".claude/skills").iterdir() if path.is_dir()}
        self.assertLessEqual({skill for skill, _ in TRIAGE.SKILLS}, skills)
        self.assertIn("roblox-verify", skills)

    def test_glob_semantics(self):
        self.assertTrue(TRIAGE.matches("Main.luau", ("**/*.luau",)))
        self.assertTrue(TRIAGE.matches("src/a/b/C.luau", ("**/*.luau",)))
        self.assertTrue(TRIAGE.matches("default.project.json", ("*.project.json",)))
        self.assertFalse(TRIAGE.matches("src/server/default.project.json", ("*.project.json",)))
        self.assertFalse(TRIAGE.matches("src/client/A.luau", ("src/server/**/*.luau",)))

    def test_ui_change_maps_rules_skill_spec_and_commands(self):
        plan = TRIAGE.build_plan(ROOT, [changed("src/client/Ui/Hud/GoalCard.luau")])
        self.assertIn(".claude/rules/client-ui.md", plan["rules"])
        self.assertIn(".claude/rules/luau-style.md", plan["rules"])
        self.assertNotIn(".claude/rules/server-security.md", plan["rules"])
        self.assertEqual(plan["skills"][0], "roblox-add-ui")
        self.assertEqual(plan["skills"][-1], "roblox-verify")
        ids = [item["id"] for item in plan["commands"]]
        self.assertEqual(ids[0], "stylua")
        self.assertIn("architecture", ids)
        self.assertEqual(ids[-1], "hygiene")
        self.assertTrue(plan["specs"]["run_all"] or "hud-layout" in plan["specs"]["only"], plan["specs"])
        self.assertTrue(any("Arayüz" in message for message in plan["manual"]))

    def test_changed_spec_file_runs_only_that_spec(self):
        plan = TRIAGE.build_plan(ROOT, [changed("tests/admin.spec.luau")])
        self.assertEqual(plan["specs"], {"only": ["admin"], "run_all": False, "no_pure_spec": []})
        command = next(item for item in plan["commands"] if item["id"] == "run-tests-only")
        self.assertEqual(command["argv"][-2:], ["--only", "admin"])

    def test_config_change_prefers_whole_pure_suite_and_flags_slow_audit(self):
        plan = TRIAGE.build_plan(ROOT, [changed("src/shared/Config/Animals.luau")])
        self.assertTrue(plan["specs"]["run_all"])
        costs = {item["id"]: item["cost"] for item in plan["commands"]}
        self.assertEqual(costs["run-tests"], "cheap")
        self.assertEqual(costs["audit-economy"], "medium")

    def test_no_changes_has_no_commands_and_a_hint(self):
        plan = TRIAGE.build_plan(ROOT, [], branch="main")
        self.assertTrue(plan["nothing_changed"])
        self.assertEqual((plan["commands"], plan["rules"], plan["skills"], plan["changed"]), ([], [], [], []))
        self.assertIn("verify-fast", plan["hint"])
        self.assertIn("değişen: 0", TRIAGE.render(plan))
        unavailable = TRIAGE.build_plan(ROOT, [], git_available=False)
        self.assertIn("okunamadı", unavailable["hint"])

    def test_unknown_file_is_reported_without_crashing(self):
        plan = TRIAGE.build_plan(ROOT, [changed("mystery.xyz"), changed("src/server/World/NoSuchFile.luau")])
        self.assertEqual(plan["unmapped"], ["mystery.xyz"])
        self.assertEqual(plan["specs"]["no_pure_spec"], ["src/server/World/NoSuchFile.luau"])
        self.assertEqual(plan["commands"][-1]["id"], "hygiene")
        self.assertTrue(TRIAGE.render(plan))

    def test_deleted_files_get_hygiene_but_no_file_arguments(self):
        plan = TRIAGE.build_plan(ROOT, [changed("docs/OLD.md", deleted=True), changed("src/client/Ui/Gone.luau", deleted=True)])
        self.assertEqual([item["id"] for item in plan["commands"]], ["ai-docs", "hygiene"])

    def test_json_schema_and_stable_keys(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = TRIAGE.main(["--json", "--skip-health", "--files", "CLAUDE.md", "scripts/triage.py"])
        self.assertEqual(code, 0)
        plan = json.loads(output.getvalue())
        self.assertEqual(plan["schema"], 1)
        self.assertEqual(set(plan), {"schema", "git", "nothing_changed", "hint", "counts", "changed", "rules", "skills", "specs", "commands", "manual", "unmapped", "health", "results"})
        self.assertEqual(set(plan["commands"][0]), {"id", "argv", "display", "cost", "why"})
        self.assertEqual(set(plan["changed"][0]), {"path", "status", "deleted", "area", "rules", "skills"})
        self.assertIn("tooling", [item["id"] for item in plan["commands"]])
        self.assertIsNone(plan["health"])

    def test_empty_git_state_via_main(self):
        output = io.StringIO()
        with patch.object(TRIAGE, "git_state", return_value={"available": True, "branch": "x", "changed": []}), contextlib.redirect_stdout(output):
            self.assertEqual(TRIAGE.main(["--json", "--skip-health", "--run"]), 0)
        plan = json.loads(output.getvalue())
        self.assertTrue(plan["nothing_changed"])
        self.assertEqual(plan["results"], [])

    def test_run_skips_slow_and_missing_tools_and_fails_on_nonzero(self):
        commands = [
            TRIAGE.command("slow", ["python", "-c", "pass"], "x", "medium"),
            TRIAGE.command("tool", ["{rojo}", "--version"], "x"),
            TRIAGE.command("bad", ["python", "-c", "raise SystemExit(3)"], "x"),
            TRIAGE.command("ok", ["python", "-c", "pass"], "x"),
        ]
        with patch.object(TRIAGE, "resolve_tool", return_value=None):
            results = {item["id"]: item["status"] for item in TRIAGE.run_commands(ROOT, commands, include_slow=False)}
        self.assertEqual(results, {"slow": "atlandı", "tool": "atlandı", "bad": "BAŞARISIZ", "ok": "geçti"})

    def test_runner_only_filter_selects_specs_and_reports_unknown(self):
        def spec(name: str, path: str) -> str:
            return "-- Harness module: " + json.dumps({"name": name, "path": path}) + "\nlocal x = 1\n"

        pieces = [spec("hudLayoutSpec", "tests/hud-layout.spec.luau"), spec("playerDataSpec", "tests/player-data-service.spec.luau"),
                  spec("Helper", "src/x.luau"), "hudLayoutSpec(A)\n", "playerDataSpec(B)\n", "other()\n"]
        kept, unknown = RUNNER.select_specs(pieces, ["hud-layout"])
        self.assertEqual(unknown, [])
        self.assertEqual([piece for piece in kept if piece.endswith(")\n")], ["hudLayoutSpec(A)\n", "other()\n"])
        self.assertEqual(len(kept), len(pieces) - 1)
        kept, unknown = RUNNER.select_specs(pieces, ["player-data-service, playerData", "tests/hud-layout.spec.luau"])
        self.assertEqual((unknown, len(kept)), ([], len(pieces)))
        _, unknown = RUNNER.select_specs(pieces, ["nope,hudLayoutSpec"])
        self.assertEqual(unknown, ["nope"])
        self.assertEqual(RUNNER.normalize_spec("hudLayoutSpec"), RUNNER.normalize_spec("tests/hud-layout.spec.luau"))

    def test_runner_catalog_knows_every_spec_file_in_the_real_runner_source(self):
        graph = TRIAGE.runner_graph(ROOT)
        self.assertGreater(len(graph["specs"]), 40)
        for data in graph["specs"].values():
            self.assertTrue((ROOT / data["path"]).is_file(), data["path"])
            self.assertEqual(RUNNER.normalize_spec(data["only"]), RUNNER.normalize_spec(data["path"]))

    def test_smoke_quick_selection(self):
        args = type("Args", (), {})()
        args.all, args.only = False, ["admin, hud-layout", "data"]
        self.assertEqual(SMOKE.select(args), (["admin", "hud-layout", "data"], False))
        args.all = True
        self.assertEqual(SMOKE.select(args), ([], True))


class AiDocsSingleSourceTests(unittest.TestCase):
    """check-ai-docs.py kopya bir depo üzerinde: tek kaynak kuralları bozulunca kırmızı olmalı."""

    SKIP = shutil.ignore_patterns(".git", ".tools", ".test-build", ".cleanup-archive", "assets", "client-assets", "artwork", "node_modules", "__pycache__")

    @classmethod
    def setUpClass(cls):
        cls._directory = tempfile.TemporaryDirectory()
        cls.base = Path(cls._directory.name) / "base"
        shutil.copytree(ROOT, cls.base, ignore=cls.SKIP)

    @classmethod
    def tearDownClass(cls):
        cls._directory.cleanup()

    def run_checker(self, mutate=None):
        copy = Path(self._directory.name) / f"copy-{self._testMethodName}"
        shutil.copytree(self.base, copy)
        if mutate:
            mutate(copy)
        env = {**os.environ, "AI_DOCS_ROOT": str(copy), "PYTHONDONTWRITEBYTECODE": "1"}
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "check-ai-docs.py")], capture_output=True, text=True, encoding="utf-8", env=env)
        return result.returncode, result.stdout

    def test_pristine_copy_passes_when_assets_present(self):
        # assets/ kopyalanmadığı için glob eşleşmesi kural dosyalarında bildirilebilir; yalnız tek kaynak hatası olmamalı.
        _, out = self.run_checker()
        for phrase in ("ikinci kural/skill kaynağı", "Cursor", "dışında", "çıpasını anmıyor", "hızlı kontrol tablosu", "yönlendirme taslağı", "paths listesi"):
            self.assertNotIn(phrase, out)

    def test_leftover_cursor_agents_and_copilot_sources_are_rejected(self):
        def mutate(copy: Path):
            (copy / ".cursor" / "rules").mkdir(parents=True)
            (copy / ".cursor" / "rules" / "x.mdc").write_text("---\n---\n", encoding="utf-8")
            (copy / ".cursorrules").write_text("x", encoding="utf-8")
            (copy / "AGENTS.md").write_text("x", encoding="utf-8")
            (copy / ".github" / "instructions").mkdir(parents=True)
            (copy / ".github" / "copilot-instructions.md").write_text("x", encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        for stray in (".cursor", ".cursorrules", "AGENTS.md", ".github/copilot-instructions.md"):
            self.assertIn(f"{stray}: ikinci kural/skill kaynağı", out)
        self.assertIn(".cursor/rules/x.mdc: .mdc (Cursor) kural biçimi yasak", out)

    def test_rule_or_skill_outside_claude_and_stray_files_are_rejected(self):
        def mutate(copy: Path):
            (copy / "docs" / "stray.mdc").write_text("---\n---\n", encoding="utf-8")
            (copy / "docs" / "SKILL.md").write_text("x", encoding="utf-8")
            (copy / "docs" / "stray-rule.md").write_text('---\ndescription: x\npaths:\n  - "src/**"\n---\n', encoding="utf-8")
            (copy / ".claude" / "skills" / "roblox-verify" / "extra.md").write_text("x", encoding="utf-8")
            (copy / ".claude" / "rules" / "nested").mkdir()
            (copy / ".claude" / "rules" / "nested" / "y.md").write_text("x", encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        self.assertIn("docs/stray.mdc: .mdc (Cursor) kural biçimi yasak", out)
        self.assertIn("docs/SKILL.md: skill dosyası .claude/skills dışında", out)
        self.assertIn("docs/stray-rule.md: kural dosyası .claude/rules dışında", out)
        self.assertIn("roblox-verify/extra.md: .claude/skills altında yalnız SKILL.md", out)
        self.assertIn(".claude/rules/nested/y.md: .claude/rules altında yalnız düz *.md", out)

    def test_rule_frontmatter_and_globs_are_validated(self):
        def mutate(copy: Path):
            rules = copy / ".claude" / "rules"
            (rules / "luau-style.md").write_text("---\ndescription: x\n---\nbody\n", encoding="utf-8")
            (rules / "server-security.md").write_text('---\ndescription: x\npaths:\n  - "yok/hicbir/**"\n---\nbody\n', encoding="utf-8")
            (rules / "client-ui.md").write_text('---\npaths:\n  - "src/**"\n---\nbody\n', encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        self.assertIn(".claude/rules/luau-style.md: paths listesi eksik veya boş", out)
        self.assertIn(".claude/rules/server-security.md: glob hiçbir dosyayla eşleşmiyor: yok/hicbir/**", out)
        self.assertIn(".claude/rules/client-ui.md: description eksik", out)

    def test_skill_stub_name_mismatch_and_missing_listing_are_rejected(self):
        def mutate(copy: Path):
            skills = copy / ".claude" / "skills"
            (skills / "roblox-verify" / "SKILL.md").write_text(
                "---\nname: roblox-verify\ndescription: x\n---\n\nTam metin: `.cursor/skills/roblox-verify/SKILL.md` içindedir.\n", encoding="utf-8")
            localize = skills / "roblox-localize" / "SKILL.md"
            localize.write_text(localize.read_text(encoding="utf-8").replace("name: roblox-localize", "name: baska-ad", 1), encoding="utf-8")
            claude = copy / "CLAUDE.md"
            claude.write_text(claude.read_text(encoding="utf-8").replace("`roblox-add-ui`", "roblox-add-ui"), encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        self.assertIn("roblox-verify/SKILL.md: gövde", out)
        self.assertIn("roblox-verify/SKILL.md: başka bir kaynak skill dosyasına yönlendiriyor", out)
        self.assertIn("roblox-localize/SKILL.md: name alanı klasör adıyla eşleşmiyor", out)
        self.assertIn("CLAUDE.md skill'i listelemiyor: roblox-add-ui", out)

    def test_missing_anchor_and_quick_commands_section_are_rejected(self):
        def mutate(copy: Path):
            claude = copy / "CLAUDE.md"
            text = claude.read_text(encoding="utf-8").replace("docs/HIZLI_AKSIYON.md", "docs/baska.md").replace("Hızlı kontrol komutları", "Komutlar")
            claude.write_text(text, encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        self.assertIn("CLAUDE.md: 'docs/HIZLI_AKSIYON.md' çıpasını anmıyor", out)
        self.assertIn("CLAUDE.md 'Hızlı kontrol komutları' bölümü eksik", out)

    def test_claude_quick_command_table_must_list_every_entry_command(self):
        def mutate(copy: Path):
            claude = copy / "CLAUDE.md"
            claude.write_text(claude.read_text(encoding="utf-8").replace("scripts/smoke-quick.py", "scripts/yok.py"), encoding="utf-8")

        code, out = self.run_checker(mutate)
        self.assertEqual(code, 1)
        self.assertIn("scripts/smoke-quick.py komutunu listelemiyor", out)


ITEMS = load("simulate_items_fixture", "scripts/simulate-items.py")
LUAU_EXECUTABLE = ITEMS.find_luau(None)


class SimulateItemsTests(unittest.TestCase):
    """Ekipman gücü ölçüm betiği: saf yardımcılar, argüman ayrıştırma, sonuç şeması ve ekipman akışı (koşusuz, saniyeler)."""

    def test_gold_formula_matches_documented_rule(self):
        self.assertEqual(ITEMS.formula_gold(3_500_000), 740)
        self.assertEqual(ITEMS.formula_gold(30_000_000), 1500)
        self.assertEqual(ITEMS.formula_gold(40_000), 210)
        self.assertGreaterEqual(ITEMS.formula_gold(2_000_000), ITEMS.formula_gold(1_000_000))

    def test_round_robin_perks_sum_to_count_and_respect_level_cap(self):
        order = ["income", "growth", "starting_cash", "upgrade_discount", "facility_speed", "offline", "contract", "ready_start"]
        self.assertEqual(ITEMS.perks_for(0, order), "")
        self.assertEqual(ITEMS.perks_for(5, order), "income:1,growth:1,starting_cash:1,upgrade_discount:1,facility_speed:1")
        for count in (8, 17, 30):
            levels = [int(part.split(":")[1]) for part in ITEMS.perks_for(count, order).split(",")]
            self.assertEqual(sum(levels), count)
            self.assertLessEqual(max(levels), 5)

    def test_state_and_argument_parsing(self):
        self.assertEqual(ITEMS.parse_states("ideal:5, casual:5,ideal:0,ideal:5"), [("ideal", 5), ("casual", 5), ("ideal", 0)])
        for bad in ("", "robot:1", "ideal", "ideal:31", "ideal:x"):
            with self.assertRaises(ValueError):
                ITEMS.parse_states(bad)
        args = ITEMS.build_parser().parse_args([])
        self.assertEqual((args.states, args.workers, args.probe, args.idle, args.skip_singles), (ITEMS.DEFAULT_STATES, 12, False, False, False))
        args = ITEMS.build_parser().parse_args(["--probe", "--items", "iron_hammer", "--no-cache"])
        self.assertTrue(args.probe and args.no_cache)
        self.assertEqual(args.items, "iron_hammer")

    def test_classification_thresholds(self):
        self.assertEqual([ITEMS.classify(value) for value in (None, 0.0, 0.49, 0.5, 10.0, 10.01)], ["unmeasured", "dead", "dead", "ok", "ok", "strong"])

    def test_rank_correlation(self):
        self.assertAlmostEqual(ITEMS.spearman([1, 2, 3, 4], [10, 20, 30, 40]), 1.0)
        self.assertAlmostEqual(ITEMS.spearman([1, 2, 3, 4], [4, 3, 2, 1]), -1.0)
        self.assertIsNone(ITEMS.spearman([1, 2, 3], [5, 5, 5]))
        self.assertIsNone(ITEMS.spearman([1, 2], [1, 2]))

    def test_ordering_inversions_are_per_slot_and_tolerant(self):
        rows = [{"id": "a", "slot": "tool", "cost": 300, "pct": 4.0}, {"id": "b", "slot": "tool", "cost": 600, "pct": 1.0},
                {"id": "c", "slot": "charm", "cost": 900, "pct": 0.1}, {"id": "d", "slot": "tool", "cost": 700, "pct": 3.9}]
        found = ITEMS.ordering_inversions(rows)
        self.assertEqual([(row["cheap"], row["dear"]) for row in found], [("a", "b")])
        self.assertEqual(ITEMS.ordering_inversions(rows, tolerance=5), [])

    def test_gold_accumulation_and_greedy_purchases(self):
        rewards = [750, 760, 770]
        cumulative = ITEMS.cumulative_gold(rewards, 4)
        self.assertEqual(cumulative, [750, 1510, 2280, 3050])
        self.assertEqual((ITEMS.rebirth_to_afford(cumulative, 1500), ITEMS.rebirth_to_afford(cumulative, 9999)), (2, None))
        options = [{"id": "x", "gold": 700, "savedDays": 1.4, "slot": "tool"}, {"id": "y", "gold": 500, "savedDays": 0.5, "slot": "head"},
                   {"id": "w", "gold": 100, "savedDays": 0.2, "slot": "tool"}, {"id": "z", "gold": 100, "savedDays": 0, "slot": "back"}]
        timeline = ITEMS.greedy_purchases(options, rewards, 2)
        self.assertEqual(timeline[0]["bought"], ["x"])  # aynı yuvadaki daha zayıf w, x varken alınmaz
        self.assertEqual(timeline[1]["bought"], ["y"])
        self.assertAlmostEqual(timeline[1]["savedDays"], 1.9)
        self.assertEqual(ITEMS.scale_for_target(0.1, 2.0, 5.0), 0.25)
        self.assertIsNone(ITEMS.scale_for_target(0.1, 0.0, 5.0))

    def test_loadout_selection_uses_channel_tier_and_measured_score(self):
        items = [{"id": "cheap", "slot": "tool", "channel": "cash", "price": 1000, "goldCost": None, "noCash": False},
                 {"id": "mid", "slot": "tool", "channel": "cashGold", "price": 600000, "goldCost": 390, "noCash": False},
                 {"id": "top", "slot": "tool", "channel": "gold", "price": 2000000, "goldCost": 600, "noCash": True},
                 {"id": "dud", "slot": "head", "channel": "cash", "price": 5000, "goldCost": None, "noCash": False}]
        score = {"cheap": 1.0, "mid": 3.0, "top": 5.0, "dud": 0.0}
        self.assertEqual(ITEMS.best_per_slot(items, "starter", score, ["tool", "head"]), ["cheap"])
        self.assertEqual(ITEMS.best_per_slot(items, "mid", score, ["tool", "head"]), ["mid"])
        self.assertEqual(ITEMS.best_per_slot(items, "premium", score, ["tool", "head"]), ["top"])

    def test_report_schema_with_synthetic_catalog(self):
        catalog = {"rewards": [750, 760, 770] * 11, "maxRebirth": 30, "slotOrder": ["tool", "head"],
                   "items": [{"id": "iron", "name": "Demir", "slot": "tool", "level": 2, "channel": "cashGold", "price": 600000, "noCash": False,
                              "effects": {"upgradeDiscount": 0.1}, "tradeoffs": {}, "power": None, "goldCost": 390, "robux": False},
                             {"id": "cap", "name": "Kep", "slot": "head", "level": 1, "channel": "cash", "price": 15000, "noCash": False,
                              "effects": {"movementSpeed": 0.05}, "tradeoffs": {}, "power": None, "goldCost": None, "robux": False}],
                   "conveniences": [{"id": "auto_collect", "goldCost": 300, "robux": False}]}
        states = [("ideal", 5)]
        key = ITEMS.state_key("ideal", 5)
        singles = {"iron": {key: ITEMS.measure(5.0, 4.4, "ideal")}, "cap": {key: ITEMS.measure(5.0, 5.0, "ideal")},
                   "auto_collect": {key: ITEMS.measure(5.0, 4.0, "ideal")}}
        rows = ITEMS.build_item_rows(catalog, singles, states)
        self.assertEqual([row["id"] for row in rows], ["iron", "cap", "auto_collect"])
        self.assertEqual(rows[1]["unmodeled"], ["movementSpeed"])
        self.assertTrue(rows[1]["goldDerived"] and not rows[0]["goldDerived"])
        loadouts = ITEMS.loadouts_for(rows, catalog, states)
        self.assertEqual(sorted(loadouts), ["endgame", "mid", "premium", "starter"])
        self.assertEqual(loadouts["mid"]["items"], ["iron"])
        analysis = ITEMS.analyze(rows, loadouts, catalog, states, {key: 5.0})
        for field in ("primary", "dead", "deadAll", "unmeasurable", "strong", "byLevel", "goldFormulaMismatches", "inversionsByGold", "rebirthGold", "greedy",
                      "tierInversions", "fit", "suggestions", "perItem"):
            self.assertIn(field, analysis)
        self.assertEqual(analysis["strong"], ["iron"])
        self.assertEqual(analysis["unmeasurable"], ["cap"])
        report = {"states": states, "baseline": {key: 5.0}, "items": rows, "loadouts": {}, "analysis": analysis, "freeLoadout": {}}
        json.dumps(report)
        self.assertIn("iron", ITEMS.render(report))
        self.assertEqual(ITEMS.measure(4.0, 3.0, "casual")["pct"], 25.0)
        self.assertTrue(ITEMS.measure(16.0, 15.9, "casual")["belowResolution"])

    @unittest.skipUnless(LUAU_EXECUTABLE, "Luau yorumlayıcısı yok")
    def test_every_equipped_effect_reaches_the_real_farmmath_consumer(self):
        catalog = ITEMS.run_bridge(LUAU_EXECUTABLE, {})
        items = [item for item in catalog["items"] if item["channel"] != "none"]
        flow = ITEMS.flow_audit(catalog["probe"], items)
        self.assertGreater(len(flow), 60)
        self.assertEqual([row for row in flow if not row["ok"]], [])
        self.assertTrue({"incomeBonus", "upgradeDiscount", "facilitySpeed", "offlineBonus", "storageBonus", "growthSpeed", "contractBonus", "goodsYield"}
                        <= {row["key"] for row in flow})

    @unittest.skipUnless(LUAU_EXECUTABLE, "Luau yorumlayıcısı yok")
    def test_caps_hold_for_the_most_stacked_loadout(self):
        base = ITEMS.run_bridge(LUAU_EXECUTABLE, {})
        items = [item for item in base["items"] if item["channel"] != "none"]
        stacked = [max((item for item in items if item["slot"] == slot), key=lambda item: sum(max(value, 0) for key, value in item["effects"].items() if key != "growthSpeed"))
                   for slot in base["slotOrder"]]
        loadouts = {"stacked": [item["id"] for item in stacked]}
        probe = ITEMS.run_bridge(LUAU_EXECUTABLE, loadouts)
        rows = ITEMS.cap_audit(probe["probe"], items, loadouts, probe["limits"])
        self.assertTrue(rows and all(row["ok"] for row in rows), rows)

    @unittest.skipUnless(LUAU_EXECUTABLE, "Luau yorumlayıcısı yok")
    def test_simulation_rejects_two_items_in_one_slot_and_clears_free_equipment(self):
        simulation = ROOT / "scripts" / "simulate-economy.py"
        conflict = subprocess.run([sys.executable, str(simulation), "--luau", LUAU_EXECUTABLE, "--hours", "0.02", "--json", "--equipment", "diamond_hammer,gold_hammer"],
                                  cwd=ROOT, capture_output=True, check=False)
        self.assertNotEqual(conflict.returncode, 0)
        self.assertIn("Equipment slot conflict", conflict.stdout.decode(errors="replace") + conflict.stderr.decode(errors="replace"))
        common = [sys.executable, str(simulation), "--luau", LUAU_EXECUTABLE, "--hours", "0.02", "--json", "--rebirth", "5",
                  "--perks", "income:1,growth:1,starting_cash:1,upgrade_discount:1,facility_speed:1"]
        free = subprocess.run(common, cwd=ROOT, capture_output=True, check=True)
        cleared = subprocess.run(common + ["--clear-equipment", "--equipment", "diamond_hammer"], cwd=ROOT, capture_output=True, check=True)
        self.assertEqual(sorted(json.loads(free.stdout.decode("utf-8-sig"))["loadout"]["equipped"]), ["charm", "head"])
        loadout = json.loads(cleared.stdout.decode("utf-8-sig"))["loadout"]
        self.assertEqual(loadout["equipped"], {"tool": "diamond_hammer"})
        # Beklenen indirim Config'ten okunur (denge değişince test kırılmasın)
        items_source = (ROOT / "src/shared/Config/Items.luau").read_text(encoding="utf-8")
        match = re.search(r'id = "diamond_hammer",.*?upgradeDiscount = ([0-9.]+)', items_source, re.S)
        self.assertIsNotNone(match)
        discount = float(match.group(1))
        self.assertAlmostEqual(loadout["effects"]["upgradeDiscount"], discount)
        self.assertAlmostEqual(loadout["movementMultiplier"], 1.02)

    def test_what_if_parsing_and_effective_noise_floor(self):
        self.assertEqual(ITEMS.parse_what_if("a:incomeBonus=0.3,offlineBonus=0.1; b:upgradeDiscount=0.12"),
                         {"a": [("incomeBonus", 0.3), ("offlineBonus", 0.1)], "b": [("upgradeDiscount", 0.12)]})
        for bad in ("", "a", "a:x", "a:x=y", ":x=1"):
            with self.assertRaises(ValueError):
                ITEMS.parse_what_if(bad)
        args = ITEMS.build_parser().parse_args(["--what-if", "a:incomeBonus=0.3", "--reanalyze", "x.json"])
        self.assertEqual((args.what_if, args.reanalyze), ("a:incomeBonus=0.3", "x.json"))
        one_session = {"pct": 1.9, "savedDays": 0.33}
        self.assertEqual(ITEMS.effective_pct(one_session, "casual:R5"), 0.0)
        self.assertEqual(ITEMS.effective_pct({"pct": 5.0, "savedDays": 0.9}, "casual:R5"), 5.0)
        self.assertEqual(ITEMS.effective_pct({"pct": 0.2, "savedDays": 0.01}, "ideal:R5"), 0.0)
        self.assertIsNone(ITEMS.effective_pct(None, "ideal:R5"))
        self.assertEqual(ITEMS.ols([1, 2, 3], [2, 4, 6]), (0.0, 2.0))

    @unittest.skipUnless(LUAU_EXECUTABLE, "Luau yorumlayıcısı yok")
    def test_item_effect_override_reaches_farmmath_without_touching_config(self):
        simulation = ROOT / "scripts" / "simulate-economy.py"
        command = [sys.executable, str(simulation), "--luau", LUAU_EXECUTABLE, "--hours", "0.02", "--json", "--equipment", "golden_crown"]
        plain = json.loads(subprocess.run(command, cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8-sig"))
        tuned = json.loads(subprocess.run(command + ["--item-effect", "golden_crown:incomeBonus=0.25"], cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8-sig"))
        self.assertNotAlmostEqual(plain["loadout"]["effects"]["incomeBonus"], 0.25)
        self.assertAlmostEqual(tuned["loadout"]["effects"]["incomeBonus"], 0.25)
        bad = subprocess.run(command + ["--item-effect", "oops"], cwd=ROOT, capture_output=True, check=False)
        self.assertEqual(bad.returncode, 2)


if __name__ == "__main__":
    unittest.main()
