#!/usr/bin/env python3
"""Saniyeler içinde saf Luau spec alt kümesi: tek giriş, verify.ps1 değil.

  python scripts/smoke-quick.py --list                 # --only adlarını göster
  python scripts/smoke-quick.py --only hud-layout,admin  # adı verilen spec'ler
  python scripts/smoke-quick.py                        # değişen dosyalardan türetilen spec'ler (yoksa hepsi)
  python scripts/smoke-quick.py --all                  # tüm saf Luau paketi
Süre bütçesi (varsayılan 20 sn) aşılırsa uyarır, başarısız saymaz. Alt küme tam paketin yerine geçmez;
Roblox çalışma zamanı/dünya testleri Studio ister. Çıkış kodu run-tests.py ile aynıdır (2: bilinmeyen ad).
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import time

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]


def load_triage():
    spec = importlib.util.spec_from_file_location("smoke_triage", ROOT / "scripts" / "triage.py")
    assert spec and spec.loader
    sys.dont_write_bytecode = True
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def select(args: argparse.Namespace) -> tuple[list[str], bool]:
    """(--only adları, hepsi mi)."""
    if args.all:
        return [], True
    if args.only:
        return [name.strip() for entry in args.only for name in entry.split(",") if name.strip()], False
    triage = load_triage()
    state = triage.git_state(ROOT)
    specs, run_all, _ = triage.affected_specs(ROOT, [item["path"] for item in state["changed"] if not item["deleted"]])
    return (specs, False) if specs and not run_all else ([], True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", action="append", default=[], metavar="SPEC")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--luau", help="Luau yorumlayıcı yolu (varsayılan .tools/luau veya PATH)")
    parser.add_argument("--budget", type=float, default=20.0, help="uyarı eşiği, saniye")
    args = parser.parse_args(argv)
    command = [sys.executable, str(ROOT / "scripts" / "run-tests.py")]
    if args.luau:
        command += ["--luau", args.luau]
    if args.list:
        return subprocess.run(command + ["--list"], cwd=ROOT, check=False).returncode
    only, everything = select(args)
    if only:
        command += ["--only", ",".join(only)]
    print(f"smoke-quick: {'tüm saf Luau paketi' if everything else 'alt küme: ' + ','.join(only)}", flush=True)
    started = time.monotonic()
    code = subprocess.run(command, cwd=ROOT, check=False).returncode
    elapsed = time.monotonic() - started
    note = "" if elapsed <= args.budget else f"  UYARI: bütçe {args.budget:g} sn aşıldı"
    print(f"smoke-quick: {'geçti' if code == 0 else 'BAŞARISIZ (' + str(code) + ')'} {elapsed:.1f} sn{note}")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
