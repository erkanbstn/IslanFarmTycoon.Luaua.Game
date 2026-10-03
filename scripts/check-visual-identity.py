#!/usr/bin/env python3
"""Exercise real visual service sources with a small Instance identity fixture."""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "AnimalVisualService": "src/server/Presentation/AnimalVisualService.luau",
    "ZoneVisualService": "src/server/Presentation/ZoneVisualService.luau",
    "ExtensionVisualService": "src/server/Presentation/ExtensionVisualService.luau",
    "BarnVisualService": "src/server/World/BarnVisualService.luau",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default=str(ROOT / ".tools/luau/luau.exe"))
    args = parser.parse_args()
    fixture = (ROOT / "tests/visual-identity.spec.luau").read_text(encoding="utf-8-sig")
    factories = []
    for name, path in SOURCES.items():
        source = (ROOT / path).read_text(encoding="utf-8-sig")
        # Substitute only module imports; production function bodies stay verbatim.
        source = re.sub(r"^local (\w+) =\s+require\([^\n]+\)(?: :: [^\n]+)?$",
                        lambda m: f"local {m[1]} = deps.{m[1]}", source, flags=re.M)
        source = re.sub(r'return require\(script\.Parent\.Parent:WaitForChild\("Services"\):WaitForChild\("\w+"\)\)',
                        'error("Identity fixture does not trigger service callbacks")', source)
        if re.search(r"\brequire\s*\(", source):
            raise ValueError(f"Unresolved module import in {path}")
        factories.append(f"factories.{name} = function(deps)\n{source}\nend\n")
    combined = fixture.replace("-- SOURCE_FACTORIES", "\n".join(factories))
    with tempfile.TemporaryDirectory(prefix="roblox-visual-identity-") as directory:
        spec = Path(directory) / "visual-identity.luau"
        spec.write_text(combined, encoding="utf-8")
        return subprocess.run([args.luau, str(spec)], cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
