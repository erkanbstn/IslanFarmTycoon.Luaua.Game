"""Generate the ten theme fish as primitive Roblox XML; no game code changes."""
from pathlib import Path
import importlib.util
import json
import math
import xml.etree.ElementTree as ET
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/Animals'
IDENTITY = np.eye(3)


def rz(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def ry(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def corners(size, pos, rot):
    return np.array([[x, y, z] for x in (-size[0]/2, size[0]/2)
                     for y in (-size[1]/2, size[1]/2)
                     for z in (-size[2]/2, size[2]/2)]) @ rot.T + pos


def reference_bounds(name):
    vertices = []
    for item in ET.parse(OUT / f'{name}.rbxmx').getroot().iter('Item'):
        if item.get('class') not in ('Part', 'WedgePart'):
            continue
        p = item.find('Properties')
        cf, sz = p.find("CoordinateFrame[@name='CFrame']"), p.find("Vector3[@name='Size']")
        pos = np.array([float(cf.find(k).text) for k in ('X', 'Y', 'Z')])
        size = np.array([float(sz.find(k).text) for k in ('X', 'Y', 'Z')])
        rot = np.array([[float(cf.find(f'R{a}{b}').text) for b in range(3)] for a in range(3)])
        vertices.extend(corners(size, pos, rot))
    vertices = np.array(vertices)
    return np.ptp(vertices, axis=0)


def scalar(p, tag, name, value):
    ET.SubElement(p, tag, {'name': name}).text = str(value)


def frame(p, name, pos, rot, optional=False):
    if optional:
        p = ET.SubElement(p, 'OptionalCoordinateFrame', {'name': name})
        node = ET.SubElement(p, 'CFrame')
    else:
        node = ET.SubElement(p, 'CoordinateFrame', {'name': name})
    for key, value in zip(('X', 'Y', 'Z'), pos):
        ET.SubElement(node, key).text = f'{value:.8f}'
    for a in range(3):
        for b in range(3):
            ET.SubElement(node, f'R{a}{b}').text = f'{rot[a,b]:.8f}'


SPECS = [
    ('red_mullet', 'anchovy', .34, .34, (190, 91, 74), (120, 59, 52), (231, 201, 157)),
    ('sea_bream', 'seabass', .34, .56, (180, 193, 176), (84, 110, 99), (221, 222, 197)),
    ('sardine', 'anchovy', .26, .30, (153, 188, 196), (43, 91, 123), (222, 230, 219)),
    ('bluefish', 'seabass', .31, .36, (126, 160, 173), (40, 70, 94), (205, 216, 208)),
    ('whiting', 'anchovy', .28, .31, (166, 178, 153), (97, 115, 91), (225, 217, 184)),
    ('turbot', 'seabass', .72, .12, (138, 134, 91), (94, 95, 62), (199, 190, 137)),
    ('trout', 'anchovy', .32, .37, (154, 179, 158), (63, 97, 77), (223, 218, 185)),
    ('salmon', 'seabass', .34, .40, (191, 167, 163), (95, 112, 109), (227, 208, 184)),
    ('koi', 'anchovy', .34, .38, (238, 229, 202), (236, 227, 201), (249, 239, 212)),
    ('tuna', 'seabass', .40, .40, (99, 136, 157), (37, 63, 90), (201, 210, 196)),
]


def make(spec, checker):
    species, reference, width, height, skin, back, belly = spec
    flat = species == 'turbot'
    pieces = []

    def add(name, size, pos, color, kind='Part', rot=IDENTITY, shape=1):
        pieces.append([name, np.array(size, dtype=float), np.array(pos, dtype=float),
                       np.array(color), kind, rot.copy(), shape])

    add('Body', (width, height, .72), (0, 0, 0), skin)
    # Paired wedges taper the head and haunch in the horizontal plane.
    for side in (-1, 1):
        rot = rz(-side * math.pi / 2)
        add('HeadSlope', (height * .95, width / 2, .30),
            (side * width / 4, -.01 * height, -.51), skin, 'WedgePart', rot)
        add('HaunchSlope', (height * .85, width / 2, .30),
            (side * width / 4, -.025 * height, .51), skin, 'WedgePart', ry(math.pi) @ rz(side * math.pi / 2))
    add('TailPeduncle', (width*.42, height*.52, .28), (0, 0, .69), skin)
    add('Belly', (width*.82, .025, .66), (0, -height/2-.002, -.015), belly)
    eye = .055 if flat else .058
    for side in (-1, 1):
        eye_pos = (side*width*.16-width*.16, height/2+.019, -.45) if flat else (side*width*.35, height*.13, -.48)
        add('Eye', (eye, eye, eye), eye_pos, (21, 29, 28), shape=0)
    add('Mouth', (width*.22, .016, .018), (0, -height*.15, -.665), (55, 57, 49))
    for side in (-1, 1):
        rot = rz(side*math.pi/2) if flat else rz(math.pi if side == -1 else 0)
        pos = (side*.12, 0, .93) if flat else (0, side*.12, .93)
        add('Tail', (.035, .30, .30), pos, back, 'WedgePart', rot)
    if flat:
        add('DorsalFin', (.025, .16, .70), (-width*.55, 0, -.04), back, 'WedgePart', rz(math.pi/2))
        add('Fin', (.025, .16, .70), (width*.55, 0, -.04), back, 'WedgePart', rz(-math.pi/2))
        add('Back', (width*.84, .015, .52), (0, height/2+.004, 0), skin)
    else:
        dorsal = .12 if species in ('red_mullet', 'whiting', 'koi') else .20
        add('DorsalFin', (.028, dorsal, .34), (0, height/2+dorsal/2-.018, .03), back, 'WedgePart')
        for side in (-1, 1):
            add('Fin', (.022, .13, .24), (side*width*.56, -height*.1, .04), back, 'WedgePart', rz(-side*.70))
    # Signature details, limited to twenty geometry parts.
    if species in ('red_mullet', 'koi', 'whiting'):
        for side in (-1, 1) if species != 'whiting' else (0,):
            barbel_z = -.70 if species == 'whiting' else -.65
            add('Barbel', (.018, .018, .17), (side*width*.13, -height*.34, barbel_z), belly)
    if species in ('sardine', 'bluefish', 'trout'):
        for side in (-1, 1):
            add('LateralStripe', (.012, .045, .62), (side*(width/2+.004), height*.12, 0),
                (167, 83, 89) if species == 'trout' else back)
    if species == 'sea_bream':
        for side in (-1, 1):
            cheek_angle = side * math.atan(width / .60)
            add('GoldCheek', (.012, height*.32, .06), (side*(width/3+.0007), .015, -.46),
                (184, 148, 62), rot=ry(cheek_angle))
    if species == 'trout':
        for side, z in [(-1, -.22), (1, -.06), (-1, .20)]:
            add('Spot', (.038, .038, .038), (side*(width/2+.012), height*.30, z), (48, 61, 46), shape=0)
    if species == 'koi':
        for side, color, z in [(-1, (229, 99, 35), -.12), (1, (177, 58, 42), .12)]:
            add('ColorPatch', (.014, height*.65, .24), (side*(width/2+.005), .01, z), color)
        add('CrownPatch', (width*.7, .018, .22), (0, height/2+.006, -.19), (217, 78, 32))
    if species == 'turbot':
        for x, z in [(-.18, .09), (.15, -.10), (.10, .21)]:
            add('SkinSpot', (.075, .018, .075), (x, height/2+.018, z), (82, 80, 49))
    if species == 'salmon':
        add('AdiposeFin', (.025, .075, .10), (0, height*.38, .45), back, 'WedgePart')
        add('Jaw', (width*.25, .05, .09), (0, -height*.22, -.64), belly)
    if species == 'tuna':
        for j in range(3):
            fin_height = .07-j*.012
            add('Finlet', (.023, fin_height, .075), (0, height*.4+fin_height/2-.004, .43+j*.1), (191, 157, 61), 'WedgePart')
        add('SecondDorsalFin', (.023, .105, .13), (0, height*.48, .30), back, 'WedgePart')
    assert len(pieces) <= 20, (species, len(pieces))
    cloud = np.concatenate([corners(s, pos, rot) for _, s, pos, _, _, rot, _ in pieces])
    extent = np.ptp(cloud, axis=0)
    target = reference_bounds(reference)
    # Keep each species in its existing small/large slot; uniform scaling preserves equal Ball dimensions.
    scale = min(target[2]/extent[2], target[0]/extent[0], target[1]/extent[1])
    r = ET.Element('roblox', {'version': '4'})
    ET.SubElement(r, 'Meta', {'name': 'ExplicitAutoJoints'}).text = 'true'
    m = ET.SubElement(r, 'Item', {'class': 'Model', 'referent': f'RBX_{species}'})
    p = ET.SubElement(m, 'Properties')
    scalar(p, 'string', 'Name', species)
    scalar(p, 'Ref', 'PrimaryPart', f'RBX_{species}_0')
    frame(p, 'WorldPivotData', (0, 0, 0), IDENTITY, True)
    for index, (name, size, pos, color, kind, rot, shape) in enumerate(pieces):
        item = ET.SubElement(m, 'Item', {'class': kind, 'referent': f'RBX_{species}_{index}'})
        p = ET.SubElement(item, 'Properties')
        scalar(p, 'string', 'Name', name)
        sz = ET.SubElement(p, 'Vector3', {'name': 'Size'})
        for key, value in zip(('X', 'Y', 'Z'), size*scale):
            ET.SubElement(sz, key).text = f'{value:.8f}'
        frame(p, 'CFrame', pos*scale, rot)
        co = ET.SubElement(p, 'Color3', {'name': 'Color'})
        for key, value in zip(('R', 'G', 'B'), color/255):
            ET.SubElement(co, key).text = f'{value:.8f}'
        scalar(p, 'token', 'Material', 272)
        if kind == 'Part':
            scalar(p, 'token', 'Shape', shape)
        for key, value in [('Anchored', True), ('CanCollide', False), ('CanTouch', False),
                           ('CanQuery', False), ('CastShadow', False)]:
            scalar(p, 'bool', key, str(value).lower())
        scalar(p, 'float', 'Transparency', 0)
        scalar(p, 'float', 'Reflectance', 0)
    ET.indent(r, space='  ')
    path = OUT / f'{species}.rbxmx'
    ET.ElementTree(r).write(path, encoding='utf-8', xml_declaration=True)
    problems = checker.inspect(path, 'Animals')
    assert not problems, (species, problems)
    return {'model': species, 'parts': len(pieces), 'reference': reference,
            'boundsXYZ': [round(float(v), 4) for v in extent*scale]}


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('checker', ROOT/'scripts/check-assets.py')
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    report = [make(spec, checker) for spec in SPECS]
    print(json.dumps(report, ensure_ascii=False, indent=2))
