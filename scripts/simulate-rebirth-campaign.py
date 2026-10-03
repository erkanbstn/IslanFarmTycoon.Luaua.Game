#!/usr/bin/env python3
"""Gerçek Rebirth.apply ile 30 tur boyunca ücretsiz ve hızlandırılmış ilerleme.

Her tur önceki turdan altın, sahiplik, ekipman, perkler, günlük çevirme kotası ve
ömür boyu kazancı taşır. Yürüyüş, oyuncu karar kalitesi ve canlı kullanıcı davranışı
modellenmez. Hızlandırılmış koşu ekipmana başlangıçtan sahiptir; edinme süresi hariçtir.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

from importlib.util import module_from_spec, spec_from_file_location

ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("rebirth_comparison", ROOT / "scripts/simulate-rebirth.py")
comparison = module_from_spec(spec)
spec.loader.exec_module(comparison)


def campaign(persona: str, accelerated: bool, levels: int, output_dir: Path) -> dict:
    name = "accelerated" if accelerated else "free"
    carry_path = output_dir / f"{persona}-{name}-carry.json"
    rows = []
    calendar_hours = active_hours = 0.0
    for count in range(levels):
        extra = ["--rebirth", str(count), "--apply-rebirth", "--gold-policy", "equipment"]
        if count:
            extra.extend(["--carry-account", str(carry_path)])
        if accelerated:
            extra.extend(["--run-double", "--equipment",
                          "diamond_hammer,golden_crown,income_charm_3,golden_wings",
                          "--conveniences", "auto_collect,pet_cash,pet_goods"])
        row = comparison.run(persona, f"{name}-r{count + 1}", extra)
        next_account = row.pop("nextAccount", None)
        if not next_account or next_account["progression"]["count"] != count + 1:
            raise RuntimeError(f"{persona}/{name}: gerçek rebirth {count + 1} dönüşümü tamamlanmadı")
        if next_account["gold"] < 0:
            raise RuntimeError("Negative carried wallet")
        if count:
            previous = json.loads(carry_path.read_text(encoding="utf-8"))
            for kind in ("items", "conveniences"):
                if not set(previous["owned"][kind]).issubset(next_account["owned"][kind]):
                    raise RuntimeError(f"Permanent {kind} disappeared across rebirth")
        carry_path.write_text(json.dumps(next_account, ensure_ascii=False), encoding="utf-8")
        calendar_hours += row["calendarHours"]
        active_hours += row["activeHours"]
        rows.append(row)
        print(f"{persona}/{name} R{count + 1:02}: {row['calendarHours'] / 24:.2f} gün, "
              f"{row['activeHours']:.2f} aktif saat", flush=True)
    return {"persona": persona, "scenario": name, "calendarHours": calendar_hours,
            "activeHours": active_hours, "rows": rows, "finalAccount": next_account}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--personas", default="casual,idle")
    parser.add_argument("--levels", type=int, default=30)
    parser.add_argument("--output", default=".test-build/rebirth30-campaign.json")
    args = parser.parse_args()
    personas = [part.strip() for part in args.personas.split(",") if part.strip()]
    if not personas or any(part not in {"ideal", "casual", "idle", "hardcore"} for part in personas):
        parser.error("Geçersiz persona")
    if not 1 <= args.levels <= 30:
        parser.error("Seviye sayısı 1..30 olmalı")
    sys.stdout.reconfigure(encoding="utf-8")
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(campaign, persona, paid, args.levels, output.parent)
                   for persona in personas for paid in (False, True)]
        results = [future.result() for future in futures]
    output.write_text(json.dumps({"limitations": __doc__, "campaigns": results},
                                ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
