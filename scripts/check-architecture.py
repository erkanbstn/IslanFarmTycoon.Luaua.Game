#!/usr/bin/env python3
"""Mimari bağımlılık kuralları (docs/MIMARI.md): katmanlar yalnızca izinli katmanlara `require` ile bağlanır.

Sunucu:  Modules (saf mantık)  ←  World (statik harita)  ←  Presentation (durumdan dünyaya çizim)  ←  Services (oyun mantığı)
İstemci: Core  ←  Effects  ←  Ui  ←  Interaction
Ortak:   Shared yalnızca Shared'a bağlanır (sunucu/istemci klasörlerini bilmez).

Bir katman, kendi ve "altındaki" katmanları kullanabilir; yukarıya bağımlılık hatadır. İstisnalar ALLOW listesindedir
(gerekçesiyle). Kullanım: python scripts/check-architecture.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Katman -> kullanabileceği katmanlar (kendisi dahil)
SERVER_RULES = {
    "Modules": {"Modules"},
    "World": {"World"},
    "Presentation": {"Presentation", "World", "Modules"},
    "Services": {"Services", "Presentation", "World", "Modules"},
}
CLIENT_RULES = {
    "Core": {"Core"},
    "Effects": {"Core", "Effects"},
    "Ui": {"Core", "Effects", "Ui"},
    "Interaction": {"Core", "Effects", "Ui", "Interaction"},
}
# (dosya, hedef katman): bilinçli istisna. Gerekçe yanında.
ALLOW = {
    # Görsel servisler oyuncu durumunu okumak için servislere bağlanır; döngüyü kırmak için tembel require ile.
    ("src/server/Presentation/ExtensionVisualService.luau", "Services"),
    ("src/server/Presentation/CollectorVisualService.luau", "Services"),
}

WAIT = re.compile(r'WaitForChild\("(\w+)"\)')


def layer_of(path: str) -> tuple[str, str] | None:
    parts = path.replace("\\", "/").split("/")
    if len(parts) >= 4 and parts[0] == "src" and parts[1] == "server" and parts[2] in SERVER_RULES:
        return "server", parts[2]
    if len(parts) >= 4 and parts[0] == "src" and parts[1] == "client" and parts[2] in CLIENT_RULES:
        return "client", parts[2]
    if len(parts) >= 3 and parts[0] == "src" and parts[1] == "shared":
        return "shared", "Shared"
    return None


def main() -> int:
    problems: list[str] = []
    for directory, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if not name.endswith(".luau"):
                continue
            full = os.path.join(directory, name)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            info = layer_of(rel)
            if not info:
                continue
            side, layer = info
            text = open(full, encoding="utf-8").read()
            # require(...) ifadelerinin zincirleri (çok satırlı olabilir)
            for match in re.finditer(r"require\(([^()]*(?:\([^()]*\)[^()]*)*)\)", text):
                chain = WAIT.findall(match.group(1))
                if side == "shared":
                    if "ServerScriptService" in match.group(1) or "StarterPlayer" in match.group(1):
                        problems.append(f"{rel}: shared katmanı sunucu/istemci yoluna bağlanamaz: {match.group(1)[:80]}")
                    continue
                rules = SERVER_RULES if side == "server" else CLIENT_RULES
                for target in chain:
                    if target in rules and target != layer and target not in rules[layer]:
                        if (rel, target) in ALLOW:
                            continue
                        problems.append(f"{rel}: {side}/{layer} katmanı {target} katmanına bağlanamaz (yukarı bağımlılık)")
            if side == "client" and re.search(r"ServerScriptService|ServerStorage", text):
                problems.append(f"{rel}: istemci kodu sunucu servislerine erişemez")
            if side == "shared" and re.search(r'GetService\("(ServerScriptService|ServerStorage|StarterPlayer)"\)', text):
                problems.append(f"{rel}: shared katmanı sunucu/istemci servislerine bağlanamaz")
    if problems:
        print("Mimari kural ihlalleri:")
        for problem in sorted(set(problems)):
            print("  -", problem)
        print("Kurallar: docs/MIMARI.md. Bilinçli istisna için scripts/check-architecture.py ALLOW listesine gerekçeyle ekle.")
        return 1
    print("Mimari kurallar tamam.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
