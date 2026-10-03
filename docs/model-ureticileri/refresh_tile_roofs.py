"""Align remaining roof surfaces with the existing brick/tile roof style."""
from pathlib import Path
import xml.etree.ElementTree as E

ROOT = Path(__file__).resolve().parents[2]
SURFACES = {'Roof', 'RoofLeft', 'RoofRight', 'UpperRoof', 'TowerRoof',
            'RoofTile', 'HiveRoof', 'HiveRoofSlope', 'CanopyLeft', 'CanopyRight', 'RoofRidge'}
OLD_MATERIALS = {'1040', '528', '272'}


def main():
    total_files = total_parts = 0
    for folder in ('HomeModels', 'Buildings', 'BuildingLevels', 'HubProps',
                   'ZoneDecor', 'Barns', 'ShoreModels'):
        for path in (ROOT / 'assets' / folder).glob('*.rbxmx'):
            tree = E.parse(path)
            changed = 0
            for item in tree.findall('.//Item'):
                props = item.find('Properties')
                if props is None:
                    continue
                name = props.findtext("string[@name='Name']", '')
                material = props.find("token[@name='Material']")
                if name in SURFACES and material is not None and material.text in OLD_MATERIALS:
                    material.text = '848'
                    changed += 1
            if changed:
                E.indent(tree, space='  ')
                tree.write(path, encoding='utf-8')
                total_files += 1
                total_parts += changed
    print(f'{total_files} models; {total_parts} roof surfaces updated; geometry/pivots unchanged')


if __name__ == '__main__':
    main()
