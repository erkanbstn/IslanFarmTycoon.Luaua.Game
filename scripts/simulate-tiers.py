#!/usr/bin/env python3
"""Çiftlik kademeleri tablosu: çok çiftlikli oyuncu her çiftliği bitirip sıradakini alır (simulate-economy.py --finish-first).

Her oyuncu tipi (ideal/casual/idle) için tema (= kademe) başına: satın alma zamanı, satın almadan sonra ada açılışları (ritim), "tüm yükseltmeler" ve satın almadan
tamamlamaya geçen süre. Doğrular: her çiftlik bitiyor (deadlock yok: ürün gereksinimleri dahil); `--assert-monotonic` ile süre tema 1 -> 6 her oyuncu tipinde KESİN artar.
Hedef: Config/Difficulty.luau tiers[n].targetMinutes (ideal oyuncu). Kullanım:

    python scripts/simulate-tiers.py                        # ideal
    python scripts/simulate-tiers.py --personas ideal,casual,idle
    python scripts/simulate-tiers.py --mults 1,6.6,12,...   # çarpanları Config'e dokunmadan dene
    python scripts/simulate-tiers.py --order 1,6,5,4,3,2     # en kötü alım sırası (önce en zor tema)
    python scripts/simulate-tiers.py --personas ideal,casual,idle --assert-monotonic
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


def run(persona: str, hours: float, mults: str, extra: list[str], order: str = "") -> dict:
    command = [
        sys.executable, str(SIMULATE), "--persona", persona, "--hours", str(hours), "--farms", str(FARMS),
        "--finish-first", "--json", *extra,
    ]
    if mults:
        command += ["--mults", mults]
    if order:
        command += ["--order", order]
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
    parser.add_argument("--order", default="", help="Çiftlik alım sırası (tema numaraları; ör. 1,6,5,4,3,2 = en kötü sıra)")
    parser.add_argument(
        "--assert-monotonic",
        action="store_true",
        help="Her oyuncu tipinde tema 1 -> 6 çiftlik tamamlama süresi KESİN artmıyorsa hata (varsayılan alım sırasında)",
    )
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    personas = [name.strip() for name in args.personas.split(",") if name.strip()]
    # Süre tavanı (saat): ideal birkaç gün, casual/idle haftalar
    horizon = {"ideal": 160.0, "hardcore": 240.0, "casual": 24 * 150.0, "idle": 24 * 365.0}
    with ThreadPoolExecutor(max_workers=len(personas)) as pool:
        futures = {
            name: pool.submit(
                run, name, args.days * 24 if args.days else horizon.get(name, 240.0), args.mults, [], args.order
            )
            for name in personas
        }
        results = {name: future.result() for name, future in futures.items()}

    failed = False
    for name in personas:
        data = results[name]
        rows = farm_rows(data)
        print(f"
OYUNCU: {name} — çiftlik tamamlama (satın almadan tüm yükseltmelere){' · sıra ' + args.order if args.order else ''}")
        print("  Tema  alım            1. ada      2. ada      3. ada      tamam       süre        önceki x")
        print("        (adalar ve süre: satın almadan sonra)")
        previous: float | None = None
        durations: list[float | None] = []
        for row in sorted(rows, key=lambda item: (item["bought"] is None, item["bought"] or 0)):
            bought = row["bought"]
            islands = [format_duration(None if bought is None else minutes - bought) for _, minutes in row["islands"][:3]]
            islands += ["—"] * (3 - len(islands))
            duration = None if bought is None or row["done"] is None else row["done"] - bought
            ratio = "" if duration is None or previous is None else f"{duration / previous:.2f}"
            print(
                f"  {row['tier']:>4}  {format_duration(bought):<14}  "
                + "  ".join(f"{text:<10}" for text in islands)
                + f"  {format_duration(duration):<10}  {ratio}"
            )
            if duration is None and bought is not None:
                failed = True
                print(f"    ! Tema {row['tier']} süre tavanında bitmedi (deadlock ya da çok uzun)")
            if duration is not None:
                previous = duration
        by_theme = {row["tier"]: (None if row["bought"] is None or row["done"] is None else row["done"] - row["bought"]) for row in rows}
        durations = [by_theme.get(tier) for tier in range(1, FARMS + 1)]
        if args.assert_monotonic and not args.order:
            for tier in range(2, FARMS + 1):
                before, after = durations[tier - 2], durations[tier - 1]
                if before is not None and after is not None and after <= before:
                    failed = True
                    print(f"    ! Tema {tier} süresi ({format_duration(after)}) tema {tier - 1}'den ({format_duration(before)}) kısa/eşit: monoton artmıyor ({name})")
        goods = data.get("totals", {}).get("unlockGoods", {})
        if goods:
            print("  açılışlara harcanan ürün: " + ", ".join(f"{key} {value}" for key, value in sorted(goods.items())))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
