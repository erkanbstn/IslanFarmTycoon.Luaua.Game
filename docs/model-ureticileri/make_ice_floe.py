"""A thick, angular ice slab; geometry lives in the model, not the controller."""
from pathlib import Path
import xml.etree.ElementTree as E

root = E.Element('roblox', version='4')
E.SubElement(root, 'Meta', name='ExplicitAutoJoints').text = 'true'
model = E.SubElement(root, 'Item', {'class': 'Model', 'referent': 'RBX_ICEFLOE'})
props = E.SubElement(model, 'Properties')
E.SubElement(props, 'string', name='Name').text = 'IceFloe'

def frame(parent, tag, name, pos, matrix):
    node = E.SubElement(parent, tag, name=name)
    for key, value in zip(['X', 'Y', 'Z'] + [f'R{r}{c}' for r in range(3) for c in range(3)], pos + matrix):
        E.SubElement(node, key).text = str(value)
    return node

identity = [1,0,0,0,1,0,0,0,1]
pivot = E.SubElement(props, 'OptionalCoordinateFrame', name='WorldPivotData')
frame(pivot, 'CFrame', 'unused', [0,0,0], identity).attrib.clear()

for index, (name, cls, size, pos, rotation) in enumerate([
    ('IceSurface', 'Part', [6,.8,4], [0,0,0], identity),
    ('IceEdgeLeft', 'WedgePart', [.8,1.6,4], [-3.8,0,0], [0,-1,0,1,0,0,0,0,1]),
    ('IceEdgeRight', 'WedgePart', [.8,1.6,4], [3.8,0,0], [0,1,0,1,0,0,0,0,-1]),
]):
    item = E.SubElement(model, 'Item', {'class': cls, 'referent': f'RBX_ICE_{index}'})
    p = E.SubElement(item, 'Properties')
    E.SubElement(p, 'string', name='Name').text = name
    vector = E.SubElement(p, 'Vector3', name='Size')
    for axis, value in zip('XYZ', size): E.SubElement(vector, axis).text = str(value)
    frame(p, 'CoordinateFrame', 'CFrame', pos, rotation)
    color = E.SubElement(p, 'Color3', name='Color')
    for axis, value in zip('RGB', [204/255,229/255,237/255]): E.SubElement(color, axis).text = str(value)
    E.SubElement(p, 'token', name='Material').text = '1536'
    if cls == 'Part': E.SubElement(p, 'token', name='Shape').text = '1'
    for key, value in {'Anchored':True,'CanCollide':True,'CanQuery':True,'CanTouch':False,'CastShadow':True}.items():
        E.SubElement(p, 'bool', name=key).text = str(value).lower()
    E.SubElement(p, 'float', name='Transparency').text = '.12'
    E.SubElement(p, 'float', name='Reflectance').text = '.025'

E.indent(root, space='  ')
path = Path(__file__).resolve().parents[2] / 'assets/SeasonModels/IceFloe.rbxmx'
E.ElementTree(root).write(path, encoding='utf-8', xml_declaration=True)
print(path, '3 solid parts, angular slab, pivot at slab centre')
