#!/usr/bin/env python3
"""Check the actual Luau harness imports and lexical module order without running tests.

The runner emits metadata while constructing its existing bundle, so this check
does not infer declarations from Python syntax or execute Luau. TD001: import
mismatch; TD002: unavailable captured dependency; TD003: malformed metadata.
Factory parameters count as explicit injections. Nested bundle locals never
escape their scope.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MODULE = "-- Harness module: "
END_MODULE = "-- Harness endmodule: "
SCOPE = "-- Harness scope: "
END_SCOPE = "-- Harness endscope: "


def check_bundle(bundle: str) -> list[dict]:
    scopes: list[tuple[str, set[str]]] = [("root", set())]
    issues: list[dict] = []
    current = None
    for line in bundle.splitlines():
        if line.startswith(MODULE):
            try:
                current = json.loads(line[len(MODULE):])
                name, path = current["name"], current["path"]
                deps = set(current["dependencies"])
                injected = {arg.strip() for arg in current["factory_args"].split(",") if arg.strip()}
                type_only = set(current.get("type_only_dependencies", []))
            except (ValueError, KeyError, TypeError, AttributeError):
                issues.append({"code": "TD003", "severity": "error", "message": "Invalid harness module metadata"})
                current = None
                continue
            available = set().union(*(values for _, values in scopes)) | injected
            for dep in sorted(deps - available):
                if dep in type_only:
                    issues.append({"code": "TD004", "severity": "warning", "path": path, "module": name,
                                   "message": f"{dep} is used only in type annotations; no runtime mock is required"})
                    continue
                issues.append({"code": "TD002", "severity": "error", "path": path, "module": name,
                               "message": f"{name} captures unavailable {dep}; declare it earlier or explicitly inject it as a factory argument"})
        elif line.startswith(END_MODULE):
            name = line[len(END_MODULE):]
            if not current or current["name"] != name:
                issues.append({"code": "TD003", "severity": "error", "message": f"Unmatched module end: {name}"})
            else:
                scopes[-1][1].add(name)
            current = None
        elif current is not None:
            continue  # Production locals are inside their module, not harness globals.
        elif line.startswith(SCOPE):
            scopes.append((line[len(SCOPE):], set()))
        elif line.startswith(END_SCOPE):
            name = line[len(END_SCOPE):]
            if len(scopes) < 2 or scopes[-1][0] != name:
                issues.append({"code": "TD003", "severity": "error", "message": f"Unmatched scope end: {name}"})
            else:
                scopes.pop()
                scopes[-1][1].add(name)
        else:
            match = re.match(r"local (\w+)\s*=", line)
            if match:
                scopes[-1][1].add(match[1])
    if current or len(scopes) != 1:
        issues.append({"code": "TD003", "severity": "error", "message": "Unclosed harness module or bundle scope"})
    return issues


def report(issues: list[dict], json_output: bool = False) -> int:
    errors = sum(issue["severity"] == "error" for issue in issues)
    if json_output:
        print(json.dumps({"ok": errors == 0, "issues": issues}, ensure_ascii=False))
    else:
        for issue in issues:
            print(f"{issue['code']} {issue.get('path', '')}: {issue['message']}")
        if not issues:
            print("Test dependencies and lexical module order passed (read-only).")
    return int(errors > 0)


def load_runner():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("dependency_runner", ROOT / "scripts/run-tests.py")
    assert spec and spec.loader
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    return runner


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit machine-readable findings")
    args = parser.parse_args(argv)
    try:
        return load_runner().main(["--check-dependencies"], lambda issues: report(issues, args.json))
    except (ValueError, OSError) as error:
        return report([{"code": "TD001", "severity": "error", "message": str(error)}], args.json)


if __name__ == "__main__":
    raise SystemExit(main())
