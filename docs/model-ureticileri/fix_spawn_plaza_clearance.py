"""Lift the visible spawn paving above paths while keeping its base grounded."""
from pathlib import Path
import xml.etree.ElementTree as ET

path = Path(__file__).resolve().parents[2] / 'assets/HubProps/SpawnPlaza.rbxmx'
tree = ET.parse(path)
for item in tree.getroot().iter('Item'):
    if item.get('class') != 'Part':
        continue
    props = item.find('Properties')
    name = props.find("string[@name='Name']").text
    frame = props.find("CoordinateFrame[@name='CFrame']")
    if name in ('BronzeRim', 'StoneDisc'):
        height = .52 if name == 'BronzeRim' else .54
        props.find("Vector3[@name='Size']/X").text = str(height)
        frame.find('Y').text = str(height / 2)
        if name == 'StoneDisc':
            props.find("token[@name='Material']").text = '800'
    else:
        # Idempotent: restore the authored height from the decoration's name.
        authored = {'RadialPaver': .23, 'CompassRay': .2825,
                    'CompassTip': .285, 'CompassCenter': .285}[name]
        frame.find('Y').text = str(authored + .28)
ET.indent(tree.getroot(), space='  ')
tree.write(path, encoding='utf-8', xml_declaration=True)
print(path.name, 'grounded base .54 studs; raised compass paving')
