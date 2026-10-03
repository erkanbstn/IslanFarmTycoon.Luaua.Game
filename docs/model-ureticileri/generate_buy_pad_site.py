"""İstek 8: satın alma pedi ve yapım alanı tabelası, özgün ölçülerle."""
from pathlib import Path
import importlib.util
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'FacilityProps'
IDENTITY = (1, 0, 0, 0, 1, 0, 0, 0, 1)
UP_DISC = (0, -1, 0, 1, 0, 0, 0, 0, 1)


def frame(parent, name, position, rotation=IDENTITY, optional=False):
    node = ET.SubElement(parent, 'OptionalCoordinateFrame' if optional else 'CoordinateFrame', name=name)
    if optional:
        node = ET.SubElement(node, 'CFrame')
    for axis, value in zip('XYZ', position):
        ET.SubElement(node, axis).text = str(value)
    for index, value in enumerate(rotation):
        ET.SubElement(node, f'R{index // 3}{index % 3}').text = str(value)


def part(model, name, size, position, color, material, shape=1, rotation=IDENTITY, collide=False):
    item = ET.SubElement(model, 'Item', {'class': 'Part', 'referent': f'GPT_{name}'})
    props = ET.SubElement(item, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = name
    vector = ET.SubElement(props, 'Vector3', name='Size')
    for axis, value in zip('XYZ', size):
        ET.SubElement(vector, axis).text = str(value)
    frame(props, 'CFrame', position, rotation)
    rgb = ET.SubElement(props, 'Color3', name='Color')
    for axis, value in zip('RGB', color):
        ET.SubElement(rgb, axis).text = str(value / 255)
    ET.SubElement(props, 'token', name='Material').text = str(material)
    ET.SubElement(props, 'token', name='Shape').text = str(shape)
    for key, value in {'Anchored': True, 'CanCollide': collide, 'CanQuery': False,
                       'CanTouch': False, 'CastShadow': False}.items():
        ET.SubElement(props, 'bool', name=key).text = str(value).lower()


def save(root, name):
    path = OUT / f'{name}.rbxmx'
    ET.indent(root, space='  ')
    ET.ElementTree(root).write(path, encoding='utf-8')
    spec = importlib.util.spec_from_file_location('checker', ROOT / 'scripts' / 'check-assets.py')
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    errors = checker.inspect(path, 'FacilityProps')
    assert not errors, errors
    count = sum(item.attrib.get('class') == 'Part' for item in root.iter('Item'))
    print(f'{name}: {count} parts; inspect OK')


def buy_pad():
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'Meta', name='ExplicitAutoJoints').text = 'true'
    model = ET.SubElement(root, 'Item', {'class': 'Model', 'referent': 'RBXMODEL'})
    props = ET.SubElement(model, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = 'BuyPad'
    frame(props, 'WorldPivotData', (0, 0, 0), optional=True)
    part(model, 'Pad', (.5, 5, 5), (0, .25, 0), (122, 118, 108), 880, 2, UP_DISC)
    part(model, 'Ring', (.12, 4.4, 4.4), (0, .56, 0), (230, 230, 230), 288, 2, UP_DISC)
    part(model, 'Inner', (.16, 3.7, 3.7), (0, .6, 0), (58, 54, 48), 272, 2, UP_DISC)
    part(model, 'Coin', (.22, 1.7, 1.7), (0, 2.3, 0), (255, 205, 60), 1088, 2)
    save(root, 'BuyPad')


def site():
    root = ET.parse(OUT / 'BuildSite_Unbuilt.rbxmx').getroot()
    model = root.find('Item')
    pivot = model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
    origin = tuple(float(pivot.find(axis).text) for axis in 'XYZ')
    # Eski tezgâh koordinatlarını kaldır; yerel görünüm ve PivotTo sonucu aynı kalır.
    for cf in model.findall(".//CoordinateFrame[@name='CFrame']"):
        for axis, offset in zip('XYZ', origin):
            cf.find(axis).text = str(float(cf.find(axis).text) - offset)
    for axis in 'XYZ':
        pivot.find(axis).text = '0'
    for child in list(model.findall('Item')):
        if child.findtext("Properties/string[@name='Name']") in ('SignPole', 'SiteSign'):
            model.remove(child)
    part(model, 'SignPole', (.4, 6, .4), (0, 3, -5.8), (110, 80, 50), 512, collide=True)
    part(model, 'SiteSign', (5.6, 1.9, .3), (0, 6.6, -5.8), (85, 60, 40), 528)
    save(root, 'BuildSite_Unbuilt')


if __name__ == '__main__':
    buy_pad()
    site()
