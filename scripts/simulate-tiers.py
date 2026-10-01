#!/usr/bin/env python3
"""Çiftlik kademeleri tablosu: çok çiftlikli oyuncu her çiftliği bitirip sıradakini alır (simulate-economy.py --finish-first).

Her oyuncu tipi (ideal/casual/idle) için çiftlik başına: satın alma zamanı, ada açılışları, "tüm yükseltmeler" ve satın almadan
tamamlamaya geçen süre. Doğrular: her çiftlik bitiyor (deadlock yok: ürün gereksinimleri dahil), ideal oyuncuda süre kademe arttıkça artıyor (casual/idle: Çiftlik 3'ten itibaren).
Hedef: Config/Difficulty.luau tiers[n].targetMinutes (ideal oyuncu). Kullanım:

    python scripts/simulate-tiers.py                        # ideal
    python scripts/simulate-tiers.py --personas ideal,casual,idle
    python scripts/simulate-tiers.py --mults 1,6.6,12,...   # çarpanları Config'e dokunmadan dene
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SIMULATE = ROOT / "scripts" / "simulate-economy.py"
FARMS = 6


def run(persona: str, hours: float, mults: str, extra: list[str]) -> dict:
    command = [
        sys.executable, str(SIMULATE), "--persona", persona, "--hours", str(hours), "--farms", str(FARMS),
        "--finish-first", "--json", *extra,
    ]
    if mults:
        command += ["--mults", mults]
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    result = subprocess.run(command, cwd=ROOT, capture_output=True, env=env)
    if result.returncode != 0:
        sys.stderr.write(result.stderr.decode("utf-8", errors="replace"))
        raise SystemExit(result.returncode)
    return json.loads(result.stdout.decode("utf-8"))


def farm_rows(data: dict) -> list[dict]:
    """Çiftlik başına kilometre taşları: satın alma, ada açılışları (sırayla), tüm yükseltmeler."""
    rows = [{"tier": n, "bought": 0.0 if n == 1 else None, "islands": [], "done": None} for n in range(1, FARMS + 1)]
    for item in data["milestones"]:
        name, minutes = item["name"], item["minutes"]
        bought = re.match(r"ÇİFTLİK (\d+) alındı", name)
        if bought:
            rows[int(bought.group(1)) - 1]["bought"] = minutes
            continue
        match = re.match(r"(?:Ç(\d+) )?(.*)", name)
        tier = int(match.group(1) or 1)
        what = match.group(2)
        if what == "TÜM YÜKSELTMELER":
            rows[tier - 1]["done"] = minutes
        elif what.startswith("island_"):
            rows[tier - 1]["islands"].append((what[len("island_"):], minutes))
    return rows


def format_duration(minutes: float | None) -> str:
    if minutes is None:
        return "—"
    if minutes < 180:
        return f"{minutes:.0f} dk"
    if minutes < 2880:
        return f"{minutes / 60:.1f} sa"
    return f"{minutes / 1440:.1f} gün"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--personas", default="ideal", help="Virgülle: ideal,casual,idle,hardcore")
    parser.add_argument("--days", type=float, default=0, help="Simüle edilecek süre (gün); 0 = oyuncu tipine göre")
    parser.add_argument("--mults", default="", help="Deneme: kademe çiftlik çarpanları (virgülle)")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    personas = [name.strip() for name in args.personas.split(",") if name.strip()]
    # Süre tavanı (saat): ideal birkaç gün, casual/idle haftalar
    horizon = {"ideal": 160.0, "hardcore": 240.0, "casual": 24 * 150.0, "idle": 24 * 365.0}
    with ThreadPoolExecutor(max_workers=len(personas)) as pool:
        futures = {
            name: pool.submit(run, name, args.days * 24 if args.days else horizon.get(name, 240.0), args.mults, [])
            for name in personas
        }
        results = {name: future.result() for name, future in futures.items()}

    failed = False
    for name in personas:
        data = results[name]
        rows = farm_rows(data)
        print(f"\nOYUNCU: {name} — çiftlik tamamlama (satın almadan tüm yükseltmelere)")
        print("  Çiftlik  alım            1. ada   2. ada   3. ada   tamam           süre        önceki x")
        previous: float | None = None
        for row in rows:
            islands = [format_duration(minutes) for _, minutes in row["islands"][:3]]
            islands += ["—"] * (3 - len(islands))
            duration = None if row["bought"] is None or row["done"] is None else row["done"] - row["bought"]
            ratio = "" if duration is None or previous is None else f"{duration / previous:.2f}"
            print(
                f"  {row['tier']:>5}   {format_duration(row['bought']):<14}  "
                + "  ".join(f"{text:<7}" for text in islands)
                + f"  {format_duration(row['done']):<14}  {format_duration(duration):<10}  {ratio}"
            )
            if duration is None and row["bought"] is not None:
                failed = True
                print(f"    ! Çiftlik {row['tier']} süre tavanında bitmedi (deadlock ya da çok uzun)")
            elif duration is not None:
                shorter = previous is not None and (duration <= previous if name == "ideal" else duration < previous * 0.999)
                if shorter and (name == "ideal" or row["tier"] > 2):
                    failed = True
                    print(f"    ! Çiftlik {row['tier']} süresi bir öncekinden kısa: kademe monoton artmıyor")
                elif shorter:
                    # Casual/idle: Çiftlik 1 oturum zincirine (üretim, geri dönüş) bağlı uzun sürer, Çiftlik 2 ise o sırada biriken kasayla hızlı biter
                    print("    ~ Çiftlik 2, 1'den kısa: oturum sınırlı oyuncuda kasa birikir (bilinen davranış, hata sayılmaz)")
                previous = duration
        goods = data.get("totals", {}).get("unlockGoods", {})
        if goods:
            print("  açılışlara harcanan ürün: " + ", ".join(f"{key} {value}" for key, value in sorted(goods.items())))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
