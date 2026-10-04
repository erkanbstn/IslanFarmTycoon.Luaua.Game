#!/usr/bin/env python3
"""Compare matched economy evidence or run a pinned Git baseline without checking out files."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import platform
import re
import stat
import statistics
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
import zipfile


ROOT = Path(__file__).resolve().parents[1]
NON_CAUSAL = {"gitSha", "timestamp", "elapsedSeconds", "variant", "repeat"}
DEFAULT_ARGS = ["--persona", "hardcore", "--session", "0", "--hours", "6", "--farm", "1"]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=lambda value: fail(f"Non-finite JSON: {value}"))


def fail(message: str):
    raise ValueError(message)


def unpack(document: dict) -> tuple[dict, dict | None]:
    if not isinstance(document, dict):
        fail("Evidence must be a JSON object")
    result = document.get("result", document)
    if not isinstance(result, dict) or not isinstance(result.get("settings"), dict):
        fail("Evidence requires the full simulation settings object")
    metadata = document.get("metadata") if "result" in document else None
    if metadata is not None and not isinstance(metadata, dict):
        fail("metadata must be an object")
    return result, metadata


def causal_metadata(metadata: dict) -> dict:
    required = {"simArgs", "luau", "python", "platform"}
    if not required.issubset(metadata):
        fail("Causal metadata mismatch: incomplete runtime identity")
    return {key: value for key, value in metadata.items() if key not in NON_CAUSAL}


def matched(before: dict, after: dict) -> tuple[dict, dict, list[str]]:
    first, first_meta = unpack(before)
    second, second_meta = unpack(after)
    if json.dumps(first["settings"], sort_keys=True) != json.dumps(second["settings"], sort_keys=True):
        changed = sorted(key for key in set(first["settings"]) | set(second["settings"])
                         if key not in first["settings"] or key not in second["settings"]
                         or json.dumps(first["settings"][key], sort_keys=True) != json.dumps(second["settings"][key], sort_keys=True))
        fail("Scenario mismatch: " + ", ".join(changed))
    warnings = []
    if first_meta is None and second_meta is None:
        warnings.append("Legacy evidence has no runtime metadata; hidden CLI overrides and interpreter identity cannot be verified.")
    elif first_meta is None or second_meta is None or json.dumps(causal_metadata(first_meta), sort_keys=True) != json.dumps(causal_metadata(second_meta), sort_keys=True):
        fail("Causal metadata mismatch (simulation arguments, interpreter or environment)")
    return first, second, warnings


def index_rows(rows: list, key: str) -> dict:
    indexed = {}
    for row in rows:
        if not isinstance(row, dict) or key not in row or row[key] in indexed:
            fail(f"Invalid or duplicate {key} in metric rows")
        indexed[row[key]] = row
    return indexed


def flatten_numbers(value, prefix: str = "") -> dict:
    output = {}
    if isinstance(value, dict):
        for key, child in value.items():
            output.update(flatten_numbers(child, f"{prefix}.{key}" if prefix else key))
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        if not math.isfinite(value):
            fail("Non-finite metric")
        output[prefix] = value
    return output


def metrics(result: dict) -> dict:
    output = flatten_numbers(result.get("totals", {}), "totals")
    for name, key, rows in [
        ("goods", "id", result.get("totals", {}).get("goods", [])),
        ("payouts", "name", result.get("sources", [])),
        ("farms", "id", result.get("farms", [])),
    ]:
        for identifier, row in index_rows(rows, key).items():
            output.update(flatten_numbers(row, f"{name}.{identifier}"))
    for name, row in index_rows(result.get("milestones", []), "name").items():
        if "minutes" in row:
            if not isinstance(row["minutes"], (int, float)) or isinstance(row["minutes"], bool) or not math.isfinite(row["minutes"]):
                fail("Milestone minutes must be finite numbers")
            output[f"milestones.{name}.minutes"] = row["minutes"]
    milestones = index_rows(result.get("milestones", []), "name")
    bought = {str(result["settings"].get("farm", "1")): 0}
    for name, row in milestones.items():
        purchase = re.fullmatch(r"ÇİFTLİK (\d+) alındı", name)
        if purchase:
            bought[purchase[1]] = row.get("minutes")
    for name, row in milestones.items():
        finished = re.fullmatch(r"(?:Ç(\d+) )?TÜM YÜKSELTMELER", name)
        if finished:
            farm = finished[1] or str(result["settings"].get("farm", "1"))
            if bought.get(farm) is not None and row.get("minutes") is not None:
                output[f"completion.farm{farm}.minutesFromPurchase"] = row["minutes"] - bought[farm]
    return output


def compare(before: dict, after: dict) -> dict:
    first, second, warnings = matched(before, after)
    left, right = metrics(first), metrics(second)
    differences = []
    for key in sorted(set(left) | set(right)):
        old, new = left.get(key), right.get(key)
        status = "removed" if key not in right else "added" if key not in left else "measured"
        delta = new - old if status == "measured" else None
        differences.append({"metric": key, "before": old, "after": new, "status": status,
                            "delta": delta, "percent": delta / abs(old) * 100 if delta is not None and old != 0 else None})
    for side, result in [("before", first), ("after", second)]:
        if "referenceMinutesMax" not in result.get("totals", {}).get("orders", {}):
            warnings.append(f"{side}: reference-income order cap measurement is unavailable; active-farm minutes are a different denominator.")
    return {"schemaVersion": 1, "settings": first["settings"], "warnings": warnings, "metrics": differences,
            "metricSemantics": {"totals.orders.minutesMax": "minutes of the active farm's live income",
                                "totals.orders.referenceMinutesMax": "minutes of the shared contract-cap reference income",
                                "missing": "unavailable, never assumed to be zero",
                                "completion": "all-upgrade milestone time minus that farm's purchase milestone time"},
            "interpretation": "Differences describe measured scenarios, not causality or a live Roblox performance guarantee."}


def write_report(report: dict, output: Path):
    output.mkdir(parents=True, exist_ok=True)
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# Economy comparison", "", report["interpretation"], ""]
    lines += ["Order minutesMax uses active-farm live income; referenceMinutesMax uses the contract-cap reference.",
              "Missing measurements remain unavailable. Completion durations start at each farm's purchase milestone.", ""]
    for warning in report["warnings"]:
        lines.append(f"- {warning}")
    lines += ["", "| Metric | Before | After | Delta | % |", "|---|---:|---:|---:|---:|"]
    for row in report["metrics"]:
        def show(value):
            return "unavailable" if value is None else f"{value:.6g}"
        label = row["metric"].replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {label} | {show(row['before'])} | {show(row['after'])} | {show(row['delta'])} | {show(row['percent'])} |")
    if "performance" in report:
        lines += ["", "Whole-process simulation elapsed times (alternating baseline/current; includes changed work volume):", "",
                  "```json", json.dumps(report["performance"], indent=2), "```"]
    (output / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def snapshot(sha: str, destination: Path):
    archive = subprocess.run(["git", "archive", "--format=zip", sha, "src", "scripts", "tests"],
                             cwd=ROOT, capture_output=True, check=True).stdout
    root = destination.resolve()
    with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
        for member in zipped.infolist():
            target = (root / member.filename).resolve()
            if not target.is_relative_to(root) or "\\" in member.filename or stat.S_ISLNK(member.external_attr >> 16):
                fail("Unsafe archive member")
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(zipped.read(member))


def pin_ref(reference: str) -> str:
    result = subprocess.run(["git", "rev-parse", "--verify", "--end-of-options", f"{reference}^{{commit}}"],
                            cwd=ROOT, capture_output=True, check=True)
    return result.stdout.decode("ascii").strip()


def execute(folder: Path, arguments: list[str], executable: Path, metadata: dict) -> dict:
    command = [sys.executable, str(folder / "scripts" / "simulate-economy.py"), *arguments,
               "--json", "--luau", str(executable)]
    started = time.perf_counter()
    process = subprocess.run(command, cwd=folder, capture_output=True, check=False)
    elapsed = time.perf_counter() - started
    if process.returncode:
        fail(f"Simulation failed with exit {process.returncode}; inspect the selected scenario and baseline compatibility.")
    result = json.loads(process.stdout.decode("utf-8-sig"))
    unpack(result)
    return {"schemaVersion": 1, "metadata": {**metadata, "elapsedSeconds": elapsed}, "result": result}


def run(args) -> dict:
    arguments = args.sim_args or DEFAULT_ARGS
    if arguments and arguments[0] == "--":
        arguments = arguments[1:]
    if not arguments:
        arguments = DEFAULT_ARGS
    reserved = {"--json", "--luau", "--smoke", "--carry-account"}
    if any(argument.startswith("--") and any(option.startswith(argument.split("=", 1)[0]) for option in reserved) for argument in arguments):
        fail("Comparison controls JSON/interpreter modes; external account inputs are unsupported.")
    executable = Path(args.luau or ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")).resolve(strict=True)
    sha = pin_ref(args.baseline_ref)
    current = pin_ref("HEAD")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    common = {"simArgs": arguments, "luau": {"path": str(executable), "sha256": hashlib.sha256(executable.read_bytes()).hexdigest()},
              "python": {"executable": sys.executable, "version": platform.python_version()}, "platform": platform.platform()}
    evidence = {"before": [], "after": []}
    build = ROOT / ".test-build"
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="economy-baseline-", dir=build) as temporary:
        baseline = Path(temporary)
        snapshot(sha, baseline)
        for repeat in range(1, args.repeats + 1):
            for variant, folder, revision in [("before", baseline, sha), ("after", ROOT, current)]:
                document = execute(folder, arguments, executable, {**common, "gitSha": revision,
                                   "timestamp": datetime.now(timezone.utc).isoformat(), "variant": variant, "repeat": repeat})
                evidence[variant].append(document)
                path = args.output_dir / f"{variant}-{repeat}.json"
                path.write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"{variant} {repeat}: {document['metadata']['elapsedSeconds']:.3f}s", flush=True)
    report = compare(evidence["before"][0], evidence["after"][0])
    for variant, documents in evidence.items():
        if any(item["result"] != documents[0]["result"] for item in documents[1:]):
            fail(f"{variant} repeats produced different results; deterministic comparison is unavailable")
    means = {variant: statistics.mean(item["metadata"]["elapsedSeconds"] for item in documents) for variant, documents in evidence.items()}
    report["performance"] = {"repeats": args.repeats, "beforeSeconds": means["before"], "afterSeconds": means["after"],
                             "deltaSeconds": means["after"] - means["before"], "percent": (means["after"] / means["before"] - 1) * 100}
    report["evidence"] = {"baselineSha": sha, "currentHeadSha": current, "currentIncludesWorkingTree": True}
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    stored = modes.add_parser("compare", help="Compare existing simulation JSON evidence")
    stored.add_argument("--before", type=Path, required=True)
    stored.add_argument("--after", type=Path, required=True)
    live = modes.add_parser("run", help="Alternate pinned local Git baseline and current working-tree simulations")
    live.add_argument("--baseline-ref", required=True)
    live.add_argument("--luau")
    live.add_argument("--repeats", type=int, default=2)
    for mode in (stored, live):
        mode.add_argument("--output-dir", type=Path, default=ROOT / ".test-build" / "economy-comparison")
    live.add_argument("sim_args", nargs=argparse.REMAINDER, help="Simulation arguments after --")
    args = parser.parse_args()
    if args.mode == "run" and args.repeats < 2:
        parser.error("--repeats must be at least 2")
    try:
        report = run(args) if args.mode == "run" else compare(load(args.before), load(args.after))
        write_report(report, args.output_dir)
    except (ValueError, OSError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f"Comparison rejected: {error}", file=sys.stderr)
        return 1
    print(f"Evidence written: {args.output_dir / 'report.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
