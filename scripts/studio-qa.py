#!/usr/bin/env python3
"""Build an isolated nonpersistent QA place; print explicit Studio commands.

No Studio connection, publishing, DataStore writes, or changes to default.project.json.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ("fresh", "merchant", "production", "rebirth-ready")


def project(root: Path = ROOT) -> dict:
    data = copy.deepcopy(json.loads((root / "default.project.json").read_text(encoding="utf-8")))

    def absolute(node: dict) -> None:
        for key, value in node.items():
            if key == "$path":
                path = (root / value).resolve()
                if not path.is_relative_to(root.resolve()) or not path.exists():
                    raise ValueError(f"Invalid project input: {value}")
                node[key] = path.as_posix()
            elif isinstance(value, dict):
                absolute(value)

    absolute(data)
    data["name"] = "roblox-oyun-studio-qa-NOT-FOR-PUBLISH"
    data["tree"]["Workspace"].setdefault("$attributes", {}).update(
        StudioNonPersistentData=True, StudioQaEnabled=True
    )
    fixture_dir = root / "tests" / "studio"
    if not (fixture_dir / "ScenarioRunner.server.luau").is_file():
        raise ValueError("Studio QA runner is missing")
    data["tree"]["ServerScriptService"]["StudioQa"] = {"$path": fixture_dir.resolve().as_posix()}
    return data


def command(scenario: str, user_id: int, request_id: int, rebirth_level: int) -> str:
    if scenario not in SCENARIOS or not 0 <= rebirth_level <= 30 or request_id <= 0:
        raise ValueError("Invalid QA request")
    payload = json.dumps(dict(scenario=scenario, userId=user_id, requestId=request_id,
                              rebirthLevel=rebirth_level), separators=(",", ":"))
    return '\n'.join([
        '-- Run in Studio SERVER during Play, only in the isolated QA place.',
        'assert(game:GetService("RunService"):IsStudio(), "Studio required")',
        'local world = game:GetService("Workspace")',
        'assert(world:GetAttribute("StudioQaEnabled") == true and world:GetAttribute("StudioNonPersistentData") == true, "Isolated QA place required")',
        'assert(game:GetService("ReplicatedStorage"):FindFirstChild("StudioQaState"), "QA runner not ready")',
        f'game:GetService("ServerStorage"):SetAttribute("StudioQaRequest", {json.dumps(payload)})',
    ])


SERVER_INSPECT = '''-- Read-only Studio SERVER diagnostics. No saved player data is printed.
local Players = game:GetService("Players")
local world = game:GetService("Workspace")
local qa = game:GetService("ReplicatedStorage"):FindFirstChild("StudioQaState")
local report = {studio = game:GetService("RunService"):IsStudio(),
    enabled = world:GetAttribute("StudioQaEnabled"), nonpersistent = world:GetAttribute("StudioNonPersistentData"),
    lastResult = if qa then qa:GetAttribute("LastResult") else nil, players = {}}
for _, player in Players:GetPlayers() do
    table.insert(report.players, {userId = player.UserId, ready = player:GetAttribute("WorldReady"),
        persistent = player:GetAttribute("DataPersistent")})
end
local map = world:FindFirstChild("World")
local hub = if map then map:FindFirstChild("Hub") else nil
report.merchantPresent = hub ~= nil and hub:FindFirstChild("TravelingMerchant") ~= nil
print(game:GetService("HttpService"):JSONEncode(report))'''

CLIENT_INSPECT = '''-- Read-only Studio CLIENT diagnostics for currently visible GUI objects.
local player = game:GetService("Players").LocalPlayer
local gui = player:FindFirstChildOfClass("PlayerGui")
local report = {textOverflows = {}, visibleButtons = {}, truncated = false}
local function visible(object)
    local cursor = object
    while cursor and cursor ~= gui do
        if cursor:IsA("GuiObject") and not cursor.Visible then return false end
        if cursor:IsA("ScreenGui") and not cursor.Enabled then return false end
        cursor = cursor.Parent
    end
    return cursor == gui
end
if gui then
    for _, object in gui:GetDescendants() do
        if object:IsA("GuiObject") and object.AbsoluteSize.X > 0 and object.AbsoluteSize.Y > 0 and visible(object) then
            if (object:IsA("TextLabel") or object:IsA("TextButton")) and not object.TextFits then
                if #report.textOverflows < 50 then
                    table.insert(report.textOverflows, {path = object:GetFullName(), width = object.AbsoluteSize.X, height = object.AbsoluteSize.Y})
                else report.truncated = true end
            end
            if object:IsA("GuiButton") and #report.visibleButtons < 100 then
                table.insert(report.visibleButtons, object:GetFullName())
            end
        end
    end
end
print(game:GetService("HttpService"):JSONEncode(report))'''


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="action", required=True)
    build = sub.add_parser("build", help="Build a separate QA rbxlx; never publish it")
    build.add_argument("--output", type=Path, default=ROOT / ".test-build" / "studio-qa.rbxlx")
    build.add_argument("--rojo", type=Path)
    cmd = sub.add_parser("command", help="Print a fixture request for Studio Server Play")
    cmd.add_argument("--scenario", choices=SCENARIOS, required=True)
    cmd.add_argument("--user-id", type=int, required=True)
    cmd.add_argument("--request-id", type=int, default=int(time.time() * 1000))
    cmd.add_argument("--rebirth-level", type=int, choices=range(31), default=0)
    inspect = sub.add_parser("inspect", help="Print read-only server/client diagnostics")
    inspect.add_argument("--side", choices=("server", "client"), default="server")
    return result


def main() -> int:
    args = parser().parse_args()
    if args.action == "command":
        print(command(args.scenario, args.user_id, args.request_id, args.rebirth_level))
    elif args.action == "inspect":
        print(SERVER_INSPECT if args.side == "server" else CLIENT_INSPECT)
    else:
        output = args.output.resolve()
        build_dir = ROOT / ".test-build"
        if not output.is_relative_to(build_dir.resolve()) or output.suffix != ".rbxlx":
            raise ValueError("QA output must be a .rbxlx inside this repository's .test-build directory")
        output.parent.mkdir(parents=True, exist_ok=True)
        manifest = output.with_suffix(".project.json")
        manifest.write_text(json.dumps(project(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        pinned = Path.home() / ".rokit/tool-storage/rojo-rbx/rojo/7.4.4/rojo.exe"
        executable = str(args.rojo) if args.rojo else str(pinned) if pinned.exists() else shutil.which("rojo")
        if not executable:
            raise ValueError("Rojo unavailable; use doctor.py or --rojo")
        subprocess.run([executable, "build", str(manifest), "--output", str(output)], cwd=ROOT, check=True)
        print(f"QA place: {output}\nOpen separately in Studio. DO NOT PUBLISH.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as problem:
        print(f"Studio QA failed: {problem}", file=sys.stderr)
        raise SystemExit(1)
