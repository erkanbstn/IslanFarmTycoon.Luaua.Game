#!/usr/bin/env python3
"""Read-only project diagnostics: tool pins, Git state, Luau, baseline and guides.

No installation, network, generated files, Git mutation or environment dump.
Exit 0 means required local tools and guides are present; exit 1 lists missing pieces.
Tool version probes are informational and never silently assert a version match.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def probe(command: list[str], root: Path, *, environment: dict | None = None) -> tuple[int, str]:
    try:
        result = subprocess.run(command, cwd=root, env=environment, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=10, check=False)
        return result.returncode, result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def tool_path(root: Path, name: str, pin: str) -> tuple[str | None, str]:
    package, _, version = pin.partition("@")
    extension = ".exe" if os.name == "nt" else ""
    direct = Path.home() / ".rokit/tool-storage" / package.lower() / version / (name + extension)
    if direct.is_file():
        return str(direct), "pinned Rokit storage"
    executable = shutil.which(name)
    return executable, "PATH (version must match the pin)"


def diagnose(root: Path, luau_directory: Path | None = None, *, require_types: bool = False) -> dict:
    issues = []
    manifest = root / "rokit.toml"
    text = manifest.read_text(encoding="utf-8-sig") if manifest.is_file() else ""
    pins = dict(re.findall(r'^\s*(\w+)\s*=\s*"([^"\n]+@[^"\n]+)"', text, re.MULTILINE))
    tools = {}
    for name in ("rojo", "stylua", "selene"):
        pin = pins.get(name)
        path, origin = tool_path(root, name, pin) if pin else (None, "missing pin")
        code, version = probe([path, "--version"], root) if path else (1, "")
        tools[name] = {"pin": pin, "path": path, "origin": origin,
                       "version_output": version.splitlines()[0] if code == 0 and version else None}
        if not path or not pin:
            issues.append({"code": "DR001", "severity": "error", "message": f"{name} missing; run rokit install"})
        elif code != 0:
            issues.append({"code": "DR002", "severity": "warning", "message": f"{name} version probe unavailable"})
        elif pin.partition("@")[2] not in re.findall(r"\d+(?:\.\d+){1,3}", version):
            issues.append({"code": "DR003", "severity": "error", "message": f"{name} version does not match {pin}"})
    extension = ".exe" if os.name == "nt" else ""
    directory = luau_directory or root / ".tools/luau"
    luau = {name: str(directory / (name + extension)) if (directory / (name + extension)).is_file() else None
            for name in ("luau", "luau-compile", "luau-analyze")}
    if not all(luau.values()):
        issues.append({"code": "DR004", "severity": "error", "message": "Luau interpreter/compiler/analyzer missing; provide --luau-directory"})
    verification = root / "scripts/verify.ps1"
    expected = re.search(r"Luau ([\d.]+) interpreter/compiler", verification.read_text(encoding="utf-8-sig")) if verification.is_file() else None
    type_tools = all((root / ".tools/luau-lsp" / path).is_file() for path in ("luau-lsp" + extension, "globalTypes.d.luau"))
    if not type_tools:
        issues.append({"code": "DR005", "severity": "error" if require_types else "warning", "message": "Type tools missing; powershell scripts/setup-types.ps1"})
    baseline_path = root / "scripts/types-baseline.json"
    try:
        baseline = json.loads(baseline_path.read_text(encoding="utf-8-sig"))
        if not isinstance(baseline, dict) or any(not isinstance(value, int) or isinstance(value, bool) or value < 0 for value in baseline.values()):
            raise ValueError("invalid counts")
        known_findings = sum(baseline.values())
    except (OSError, ValueError):
        known_findings = None
        issues.append({"code": "DR006", "severity": "error", "message": "Type baseline missing or invalid"})
    guides = {path: (root / path).is_file() for path in ("AGENTS.md", "docs/MIMARI.md", ".cursor/rules/tests-tooling.mdc", ".cursor/skills/roblox-verify/SKILL.md")}
    for path, exists in guides.items():
        if not exists:
            issues.append({"code": "DR007", "severity": "error", "message": f"Guide missing: {path}"})
    environment = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    code, status = probe(["git", "-c", "core.fsmonitor=false", "status", "--porcelain=v1"], root, environment=environment)
    branch_code, branch = probe(["git", "symbolic-ref", "--short", "HEAD"], root, environment=environment)
    git = {"available": code == 0, "branch": branch if branch_code == 0 else "detached or unavailable",
           "changed_files": len(status.splitlines()) if code == 0 else None}
    if code != 0:
        issues.append({"code": "DR008", "severity": "warning", "message": "Git status unavailable"})
    return {"ok": not any(issue["severity"] == "error" for issue in issues), "read_only": True,
            "root": str(root), "python": sys.version.split()[0], "git": git, "tools": tools,
            "luau": {"expected_version": expected[1] if expected else None, "executables": luau,
                     "version_verified": False}, "types": {"tools_present": type_tools, "known_findings": known_findings},
            "guides": guides, "issues": issues,
            "commands": {"fast": "powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1 -RequireTypes",
                         "full": "powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Mode Full -RequireTypes",
                         "dependencies": "python scripts/check-test-dependencies.py"}}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--luau-directory", type=Path)
    parser.add_argument("--require-types", action="store_true")
    args = parser.parse_args(argv)
    if not args.root.is_dir():
        parser.error("--root must be an existing directory")
    result = diagnose(args.root.resolve(), args.luau_directory, require_types=args.require_types)
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"Doctor (read-only): {'ready' if result['ok'] else 'missing requirements'}")
        print(f"Git: {result['git']['branch']}; changed files: {result['git']['changed_files']}")
        for name, tool in result["tools"].items():
            print(f"{name}: {tool['pin']} - {tool['version_output'] or 'version unavailable'}")
        print(f"Luau expected: {result['luau']['expected_version']}; executables: {all(result['luau']['executables'].values())}; binary version unverified")
        print(f"Type tools: {result['types']['tools_present']}; baseline: {result['types']['known_findings']}")
        for issue in result["issues"]:
            print(f"{issue['code']} {issue['severity']}: {issue['message']}")
        for label, command in result["commands"].items():
            print(f"{label}: {command}")
    return int(not result["ok"])


if __name__ == "__main__":
    raise SystemExit(main())
