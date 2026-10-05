#!/usr/bin/env python3
"""Gerçek Config/FarmMath ile ücretsiz ve hızlandırıcılı rebirth koşularını karşılaştırır.

Her senaryo yeni tur başlangıcını ölçer. Önceden sahip olunan ekipman senaryosu,
o ekipmanın geçmişte kazanılması için gereken süreyi içermez. Canlı oyuncu ölçümü değildir.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(persona: str, scenario: str, extra: list[str]) -> dict:
    days = {"ideal": 12, "casual": 180, "idle": 365, "hardcore": 30}[persona]
    command = [sys.executable, str(ROOT / "scripts/simulate-economy.py"), "--persona", persona,
               "--days", str(days), "--farms", "6", "--finish-first", "--completion", "basic",
               "--stop-at-rebirth", "--json", *extra]
    result = subprocess.run(command, cwd=ROOT, capture_output=True,
                            env=dict(os.environ, PYTHONIOENCODING="utf-8"), check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    data = json.loads(result.stdout.decode("utf-8-sig"))
    totals = data["totals"]
    if not totals.get("rebirthMinutes") or totals["farmsOwned"] != 6:
        raise RuntimeError(f"{persona}/{scenario}: rebirth koşulu süre sınırında tamamlanmadı")
    return {"persona": persona, "scenario": scenario, "settings": data["settings"],
            "calendarHours": totals["rebirthMinutes"] / 60,
            "activeHours": totals["onlineMinutes"] / 60,
            "goldEarned": totals["goldEarned"], "goldSpent": totals["goldSpent"],
            "goldRemaining": totals["gold"], "milestones": data["milestones"],
            "account": data["account"], "nextAccount": data.get("nextAccount")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--personas", default="ideal,casual,idle")
    parser.add_argument("--scenarios", default="free_save,free_equipment,r1_income,r1_reward_equipment,permanent_fast")
    parser.add_argument("--output", default=".test-build/rebirth-comparison.json")
    args = parser.parse_args()
    personas = [part.strip() for part in args.personas.split(",") if part.strip()]
    scenarios = {
        "free_save": [],
        "free_equipment": ["--gold-policy", "equipment"],
        "free_convert": ["--gold-policy", "convert"],
        "r1_income": ["--rebirth", "1", "--perks", "income:1"],
        "r1_reward_equipment": ["--rebirth", "1", "--perks", "income:1", "--starting-gold", "750", "--gold-policy", "equipment"],
        "r3_ready3": ["--rebirth", "3", "--perks", "ready_start:3"],
        "r5_ready5": ["--rebirth", "5", "--perks", "ready_start:5"],
        "r5_income5": ["--rebirth", "5", "--perks", "income:5"],
        "permanent_fast": ["--rebirth", "10", "--perks", "income:5,growth:5", "--run-double",
                           "--equipment", "diamond_hammer,golden_crown,income_charm_3,golden_wings",
                           "--conveniences", "auto_collect,pet_cash,pet_goods"],
    }
    names = [part.strip() for part in args.scenarios.split(",") if part.strip()]
    if not personas or any(part not in {"ideal", "casual", "idle", "hardcore"} for part in personas):
        parser.error("Geçersiz oyuncu politikası")
    if not names or any(part not in scenarios for part in names):
        parser.error("Geçersiz senaryo")
    sys.stdout.reconfigure(encoding="utf-8")
    with ThreadPoolExecutor(max_workers=min(3, len(personas) * len(names))) as pool:
        futures = [pool.submit(run, persona, name, scenarios[name]) for persona in personas for name in names]
        rows = [future.result() for future in futures]
    for row in rows:
        print(f"{row['persona']:8} {row['scenario']:16} takvim {row['calendarHours'] / 24:.2f} gün "
              f"aktif {row['activeHours']:.2f} saat altın {row['goldRemaining']}")
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"limitations": __doc__, "rows": rows}, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
