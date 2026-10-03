"""Fix walking barriers and the well fall trap, without changing visible art.

Bridge Rails retain exact authored sizes/frames/materials and become solid.
The well receives one invisible collision-only disc just below the stone rim.
This intentionally takes the well from 35 to 36 parts to preserve every
visible piece, including the user's Brick roof materials.
"""
from pathlib import Path
import copy
import importlib.util
import math
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
PART_CLASSES=('Part','WedgePart')

def prop(item,tag,name):return item.find(f"Properties/{tag}[@name='{name}']")
def name(item):return prop(item,'string','Name').text
def set_bool(item,key,value):
    node=prop(item,'bool',key)
    if node is None:node=ET.SubElement(item.find('Properties'),'bool',{'name':key})
    node.text='true' if value else 'false'
def xyz(item,tag,key):return [float(prop(item,tag,key).find(a).text)for a in 'XYZ']
def scalar(p,tag,key,value):ET.SubElement(p,tag,{'name':key}).text=str(value)
def parts(model):return [i for i in model.iter('Item')if i.get('class')in PART_CLASSES]

def save(path,tree,checker):
    ET.indent(tree.getroot(),space='  ');tree.write(path,encoding='utf-8',xml_declaration=False)
    assert not checker.inspect(path,path.parent.name),checker.inspect(path,path.parent.name)

def bridge(path,checker):
    tree=ET.parse(path);model=tree.getroot().find('Item')
    before=copy.deepcopy(model)
    rails=[]
    for p in parts(model):
        if name(p)=='Rail':
            set_bool(p,'CanCollide',True);set_bool(p,'CanQuery',True);set_bool(p,'CanTouch',False)
            rails.append(p)
        elif name(p)in('RailCap','RailIronBrace'):
            set_bool(p,'CanCollide',False);set_bool(p,'CanQuery',False);set_bool(p,'CanTouch',False)
    assert len(rails)==2
    deck=next(p for p in parts(model)if name(p)=='Deck')
    deck_size=xyz(deck,'Vector3','Size');deck_pos=xyz(deck,'CoordinateFrame','CFrame')
    intervals=[]
    for rail in rails:
        size=xyz(rail,'Vector3','Size');pos=xyz(rail,'CoordinateFrame','CFrame')
        assert size[2]==deck_size[2]
        assert pos[1]-size[1]/2<=deck_pos[1]+deck_size[1]/2+1e-6
        assert abs(pos[0])-size[0]/2<deck_size[0]/2
        assert pos[1]+size[1]/2-(deck_pos[1]+deck_size[1]/2)>=2-1e-6
        intervals.append((pos[2]-size[2]/2,pos[2]+size[2]/2))
    # Repeated modules meet at Z seam exactly; no omitted rail endpoints.
    assert intervals[0]==intervals[1]==(-deck_size[2]/2,deck_size[2]/2)
    for old,new in zip(parts(before),parts(model)):
        for tag,key in [('Vector3','Size'),('CoordinateFrame','CFrame'),('Color3','Color'),('token','Material')]:
            assert ET.tostring(prop(old,tag,key))==ET.tostring(prop(new,tag,key))
    save(path,tree,checker)
    print(path.name,len(parts(model)),'parts; side barrier width .5, height 2, length',deck_size[2],'continuous seams')

def well(checker):
    path=ROOT/'assets/HomeModels/Well.rbxmx';tree=ET.parse(path);model=tree.getroot().find('Item')
    existing=[p for p in parts(model)if name(p)!='WellSafetyPlatform']
    signatures=[ET.tostring(p)for p in existing]
    safety=next((p for p in parts(model)if name(p)=='WellSafetyPlatform'),None)
    if safety is not None:model.remove(safety)
    safety=ET.SubElement(model,'Item',{'class':'Part','referent':'RBXWELL_SAFETY_PLATFORM'})
    p=ET.SubElement(safety,'Properties');scalar(p,'string','Name','WellSafetyPlatform')
    size=ET.SubElement(p,'Vector3',{'name':'Size'})
    for k,v in zip('XYZ',(.18,3.9,3.9)):ET.SubElement(size,k).text=str(v)
    cf=ET.SubElement(p,'CoordinateFrame',{'name':'CFrame'})
    for k,v in zip('XYZ',(0,2.22,0)):ET.SubElement(cf,k).text=str(v)
    # Roblox Cylinder's X axis is its long axis: Z90 aligns it with Y.
    for j,v in enumerate((0,-1,0,1,0,0,0,0,1)):ET.SubElement(cf,f'R{j//3}{j%3}').text=str(v)
    color=ET.SubElement(p,'Color3',{'name':'Color'})
    for k in 'RGB':ET.SubElement(color,k).text='0.5'
    scalar(p,'token','Material',272);scalar(p,'token','Shape',2);scalar(p,'float','Transparency',1)
    for key,val in [('Anchored','true'),('CanCollide','true'),('CanQuery','true'),('CanTouch','false'),('CastShadow','false')]:scalar(p,'bool',key,val)
    # Source geometry, colors and every existing material remain untouched.
    assert signatures==[ET.tostring(q)for q in parts(model)if name(q)!='WellSafetyPlatform']
    rings=[q for q in existing if name(q)=='Ring'];caps=[q for q in existing if name(q)=='StoneCap']
    assert len(rings)==len(caps)==8
    inner_radius=min(math.hypot(*[xyz(q,'CoordinateFrame','CFrame')[a]for a in (0,2)])-xyz(q,'Vector3','Size')[2]/2 for q in rings)
    hole_circumradius=inner_radius/math.cos(math.pi/8)
    assert hole_circumradius<1.95
    rim_top=max(xyz(q,'CoordinateFrame','CFrame')[1]+xyz(q,'Vector3','Size')[1]/2 for q in caps)
    platform_top=2.22+.18/2
    assert 0<=rim_top-platform_top<.25
    # Dense horizontal-hole check against the octagonal inner wall planes.
    checked=0
    for ix in range(-200,201):
        for iz in range(-200,201):
            x,z=ix*.01,iz*.01
            if all(x*math.sin(j*math.pi/4)+z*math.cos(j*math.pi/4)<=inner_radius+1e-8 for j in range(8)):
                assert math.hypot(x,z)<1.95+1e-6
                checked+=1
    assert len(parts(model))==36
    assert all(prop(q,'token','Material').text=='848' for q in existing if name(q)in('RoofTile','RoofRidge'))
    save(path,tree,checker)
    print('Well:',len(parts(model)),'parts; covered',checked,'hole grid points; inner vertex radius',round(hole_circumradius,4),
        'plug radius1.95; topY',platform_top,'rimY',rim_top,'exit step',round(rim_top-platform_top,3))

def main():
    spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts/check-assets.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
    for path in sorted((ROOT/'assets/BridgeModels').glob('*.rbxmx')):bridge(path,c)
    well(c)
if __name__=='__main__':main()
