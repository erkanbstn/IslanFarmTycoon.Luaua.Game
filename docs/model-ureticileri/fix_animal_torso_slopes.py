"""Remove generic flaring torso wedges without extending the animal bounds."""
from pathlib import Path
import xml.etree.ElementTree as E

ROOT = Path(__file__).resolve().parents[2]
SPECIES = ('cow', 'buffalo', 'yak', 'pig', 'sheep', 'goat', 'horse',
           'deer', 'camel', 'llama', 'rabbit', 'squirrel')


def vector(props, node):
    return [float(props.findtext(node + '/' + a)) for a in 'XYZ']


def fix(path):
    tree = E.parse(path)
    model = tree.getroot().find('Item')
    parts = [(i, i.find('Properties')) for i in model.findall('Item')
             if i.get('class') in ('Part', 'WedgePart')]
    body = next(p for _, p in parts if p.findtext("string[@name='Name']") == 'Body')
    slopes = [(i, p) for i, p in parts
              if p.findtext("string[@name='Name']") in ('ChestSlope', 'HaunchSlope')]
    if not slopes:
        print(path.stem, 'already fixed')
        return
    cf = "CoordinateFrame[@name='CFrame']"
    center = vector(body, cf)
    size = vector(body, "Vector3[@name='Size']")
    extent = size[2] / 2
    # These source models have identity Body rotation and 0/180-degree slope yaw.
    for row in range(3):
        for col in range(3):
            assert abs(float(body.findtext(cf + f'/R{row}{col}')) - (row == col)) < 1e-6
    for item, p in slopes:
        pos = vector(p, cf)
        dims = vector(p, "Vector3[@name='Size']")
        half_z = sum(abs(float(p.findtext(cf + f'/R2{j}'))) * dims[j] / 2 for j in range(3))
        extent = max(extent, abs(pos[2] - center[2]) + half_z)
        model.remove(item)
    body.find("Vector3[@name='Size']/Z").text = f'{extent * 2:.9f}'
    E.indent(tree, space='  ')
    tree.write(path, encoding='utf-8')
    print(path.stem, f'Body.Z {size[2]:.3f} -> {extent * 2:.3f}; removed {len(slopes)} wedges')


if __name__ == '__main__':
    for species in SPECIES:
        fix(ROOT / 'assets' / 'Animals' / f'{species}.rbxmx')
