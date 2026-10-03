#!/usr/bin/env python3
"""Mimari bağımlılık kuralları (docs/MIMARI.md): katmanlar yalnızca izinli katmanlara `require` ile bağlanır.

Sunucu:  Modules (saf mantık)  ←  World (statik harita)  ←  Presentation (durumdan dünyaya çizim)  ←  Services (oyun mantığı)
İstemci: Core  ←  Effects  ←  Ui  ←  Interaction
Ortak:   Shared yalnızca Shared'a bağlanır (sunucu/istemci klasörlerini bilmez).

Bir katman, kendi ve "altındaki" katmanları kullanabilir; yukarıya bağımlılık hatadır. İstisnalar ALLOW listesindedir
(gerekçesiyle) ve yalnızca TEMBEL (işlev içinde) require ile kullanılabilir: izinli dosyada bile dosya başındaki yukarı
yönlü require hatadır.

World katmanı yalnızca World kardeşlerini ve Shared'ı require eder (Studio eklentisi klasörü kopyalayıp çalıştırır;
başka katmana giden require kopyada sessizce canlı koda düşer ya da WaitForChild'da asılır). Shared'a ulaşan arama
yalnızca `World/SharedRef.luau`'da durur; diğer World dosyaları `require(script.Parent:WaitForChild("SharedRef"))` kullanır.

DataStoreService yalnızca `Services/SaveStore.luau`'da kullanılır (oturum/facade `PlayerDataService` onu çağırır).

Kullanım: python scripts/check-architecture.py
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
    # Görsel servisler oyuncu durumunu okumak için servislere bağlanır; döngüyü kırmak için YALNIZCA tembel (işlev içi) require.
    ("src/server/Presentation/CollectorVisualService.luau", "Services"),
}

WAIT = re.compile(r'WaitForChild\("(\w+)"\)')
REQUIRE = re.compile(r"require\(([^()]*(?:\([^()]*\)[^()]*)*)\)")
# stylua uzun `local x = require(...)` satırını `local x =` + girintili `require(...)` olarak böler
CONTINUED_LOCAL = re.compile(r"^local [\w, ]+(?::[^=]+)? =\s*$")
SHARED_REF = "src/server/World/SharedRef.luau"
SAVE_STORE = "src/server/Services/SaveStore.luau"
SHARED_SEARCH = re.compile(r'FindFirstChild\("Shared"\)|WaitForChild\("Shared"\)')
WORLD_SIBLING = re.compile(r'^script\.Parent:WaitForChild\("(\w+)"\)$')


def layer_of(path: str) -> tuple[str, str] | None:
    parts = path.replace("\\", "/").split("/")
    if len(parts) >= 4 and parts[0] == "src" and parts[1] == "server" and parts[2] in SERVER_RULES:
        return "server", parts[2]
    if len(parts) >= 4 and parts[0] == "src" and parts[1] == "client" and parts[2] in CLIENT_RULES:
        return "client", parts[2]
    if len(parts) >= 3 and parts[0] == "src" and parts[1] == "shared":
        return "shared", "Shared"
    return None


def is_top_level(text: str, start: int) -> bool:
    """`require(` dosya başında mı (girintisiz `local x = require(...)`; stylua bölünce bir alt satırda), işlev içinde mi?"""
    line_start = text.rfind("\n", 0, start) + 1
    if text[line_start : line_start + 1] not in (" ", "\t"):
        return True
    if text[line_start:start].strip() != "":
        return False  # girintili satırda başka bir ifadenin içinde (işlev gövdesi)
    previous_start = text.rfind("\n", 0, max(line_start - 1, 0)) + 1
    previous = text[previous_start : max(line_start - 1, 0)].rstrip("\r")
    return CONTINUED_LOCAL.match(previous) is not None


def world_siblings() -> set[str]:
    folder = os.path.join(ROOT, "src", "server", "World")
    return {name[: -len(".luau")] for name in os.listdir(folder) if name.endswith(".luau")}


def world_problem(argument: str, siblings: set[str]) -> str | None:
    """World'deki bir require yalnızca `Shared...` (SharedRef'ten gelen) ya da `script.Parent:WaitForChild("<World dosyası>")` olabilir."""
    argument = argument.strip()
    if re.match(r"^Shared\b", argument):
        return None
    sibling = WORLD_SIBLING.match(argument)
    if sibling:
        return None if sibling.group(1) in siblings else f"{sibling.group(1)} World klasöründe yok"
    return "kök Shared ya da script.Parent kardeşi değil"


def check_text(rel: str, text: str, siblings: set[str]) -> list[str]:
    """Tek dosyanın ihlalleri (test edilebilsin diye dosya okumadan ayrılmış)."""
    problems: list[str] = []
    info = layer_of(rel)
    if not info:
        return problems
    side, layer = info
    # Yorumlar taranmaz (konumları korumak için aynı uzunlukta boşlukla değiştirilir)
    text = re.sub(r"--[^\n]*", lambda comment: " " * len(comment.group()), text)
    for match in REQUIRE.finditer(text):
        argument = match.group(1)
        chain = WAIT.findall(argument)
        if side == "shared":
            if "ServerScriptService" in argument or "StarterPlayer" in argument:
                problems.append(f"{rel}: shared katmanı sunucu/istemci yoluna bağlanamaz: {argument[:80]}")
            continue
        if (side, layer) == ("server", "World"):
            problem = world_problem(argument, siblings)
            if problem:
                problems.append(
                    f"{rel}: World katmanı yalnızca World ve Shared'ı require edebilir ({problem}): {argument[:80]}"
                )
        rules = SERVER_RULES if side == "server" else CLIENT_RULES
        for target in chain:
            if target in rules and target != layer and target not in rules[layer]:
                if (rel, target) in ALLOW:
                    if is_top_level(text, match.start()):
                        problems.append(
                            f"{rel}: {target} katmanına bağlanan istisna require'ı dosya başında; işlev içinde (tembel) olmalı"
                        )
                    continue
                problems.append(f"{rel}: {side}/{layer} katmanı {target} katmanına bağlanamaz (yukarı bağımlılık)")
    if (side, layer) == ("server", "World") and rel != SHARED_REF and SHARED_SEARCH.search(text):
        problems.append(
            f'{rel}: Shared araması yalnızca World/SharedRef.luau\'da olmalı; `require(script.Parent:WaitForChild("SharedRef"))` kullan'
        )
    if side == "server" and rel != SAVE_STORE and re.search(r'GetService\("DataStoreService"\)', text):
        problems.append(f"{rel}: DataStore çağrıları yalnızca {SAVE_STORE}'da yapılır")
    if side == "client" and re.search(r"ServerScriptService|ServerStorage", text):
        problems.append(f"{rel}: istemci kodu sunucu servislerine erişemez")
    if side == "shared" and re.search(r'GetService\("(ServerScriptService|ServerStorage|StarterPlayer)"\)', text):
        problems.append(f"{rel}: shared katmanı sunucu/istemci servislerine bağlanamaz")
    return problems


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    problems: list[str] = []
    siblings = world_siblings()
    for directory, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if not name.endswith(".luau"):
                continue
            full = os.path.join(directory, name)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            with open(full, encoding="utf-8") as handle:
                problems.extend(check_text(rel, handle.read(), siblings))
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
