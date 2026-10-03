#!/usr/bin/env python3
"""Season glow loop microbenchmark with fixed models/parts (not Studio FPS)."""
from pathlib import Path
import argparse
import sys
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--baseline", default="a8c15a17ece6c90aef8baf850c29d0c8b84f38d9", help="Commit containing the original pre-optimization loop")
parser.add_argument("--luau", default=str(ROOT / ".tools/luau" / ("luau.exe" if sys.platform == "win32" else "luau")))
args = parser.parse_args()
runner = runpy.run_path(str(ROOT / "scripts/run-tests.py"))
legacy = subprocess.run(
    ["git", "show", f"{args.baseline}:src/client/Effects/SeasonSignal.client.luau"],
    cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
).stdout
start = legacy.index('\tlocal low = EffectSettings.quality() == "low"')
end = legacy.index("\nend)", start)
old_loop = legacy[start:end].replace("local now = os.clock()", "local now = benchmarkNow")
source = runner["module"]("SeasonGlow", "src/client/Effects/SeasonGlow.luau") + r'''
local quality = "high"
local benchmarkNow = 0
local EffectSettings = { quality = function() return quality end, reducedMotion = function() return false end }
local models, cached = {}, {}
local glows = {}
local scans = 0
for _ = 1, 120 do
    local parts = {}
    for _, name in { "Glow", "Mark_1", "Mark_2", "Mark_3", "Mark_4", "Ring_1", "Ring_2", "Ring_3" } do
        table.insert(parts, { Name = name, Transparency = 0.3,
            IsA = function() return true end, GetAttribute = function() return 0.3 end })
    end
    local model = { Parent = true, GetAttribute = function() return "good" end,
        GetDescendants = function() scans += 1 return table.clone(parts) end }
    table.insert(models, model)
    glows[model] = model
    table.insert(cached, SeasonGlow.capture(model))
end
local function oldUpdate()
''' + old_loop + r'''
end
local function newUpdate()
    for _, glow in cached do SeasonGlow.update(glow, benchmarkNow, quality == "low", false) end
end
local function measure(update)
    scans = 0
    local start = os.clock()
    for tick = 1, 1500 do benchmarkNow = tick / 15 update() end
    return os.clock() - start, scans
end
for _, tier in { "high", "low" } do
    quality = tier
    local before, after = {}, {}
    local oldScans, newScans = 0, 0
    for run = 1, 7 do
        if run % 2 == 0 then
            after[run], newScans = measure(newUpdate)
            before[run], oldScans = measure(oldUpdate)
        else
            before[run], oldScans = measure(oldUpdate)
            after[run], newScans = measure(newUpdate)
        end
    end
    table.sort(before) table.sort(after)
    print(string.format("%s: old=%.6fs new=%.6fs reduction=%.1f%% scans=%d -> %d (120 glows, 8 parts, 1500 ticks, 7 runs)",
        tier, before[4], after[4], (1-after[4]/before[4])*100, oldScans, newScans))
end
'''
output = ROOT / ".test-build/benchmark-season-glow.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source, encoding="utf-8")
subprocess.run([args.luau, str(output)], cwd=ROOT, check=True)
