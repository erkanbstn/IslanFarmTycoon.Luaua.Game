"""Fish lineage additions; models are local to the adult Body primary pivot."""
from pathlib import Path
import importlib.util
import math
import xml.etree.ElementTree as E
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/AnimalLineage'
IDS = ['anchovy','seabass','red_mullet','sea_bream','sardine','bluefish',
       'whiting','turbot','trout','salmon','koi','tuna']
SILVER = (173,195,210)
BLUE = (69,124,150)
GOLD = (203,158,69)
CYAN = (91,210,215)


def prop(p,tag,name,value):
    E.SubElement(p,tag,{'name':name}).text=str(value)


def frame(p,name,pos,rot,optional=False):
    if optional:
        node=E.SubElement(E.SubElement(p,'OptionalCoordinateFrame',{'name':name}),'CFrame')
    else:
        node=E.SubElement(p,'CoordinateFrame',{'name':name})
    for k,v in zip(('X','Y','Z'),pos):E.SubElement(node,k).text=f'{v:.9f}'
    for a in range(3):
        for b in range(3):E.SubElement(node,f'R{a}{b}').text=f'{rot[a,b]:.9f}'


def base_data(name):
    model=E.parse(ROOT/f'assets/Animals/{name}.rbxmx').getroot().find('Item')
    ref=model.find("Properties/Ref[@name='PrimaryPart']").text
    body=next(i for i in model.iter('Item') if i.get('referent')==ref)
    p=body.find('Properties');s=p.find("Vector3[@name='Size']")
    return np.array([float(s.find(k).text) for k in ('X','Y','Z')])


def produce(name,index,checker):
    w,h,l=base_data(name);tiers={2:[],3:[],4:[]}
    def add(t,label,size,pos,color,shape=1,kind='Part',rot=None):
        tiers[t].append((label,np.array(size),np.array(pos),color,shape,kind,np.eye(3) if rot is None else rot))
    # Raised silver upper flank marks: these lanes avoid the original stripes/patches.
    count=3 if name in ('sardine','trout','tuna') else 2
    if name=='turbot':
        # Flat fish: patterns are on the upward face, outside the pre-existing Back plate.
        for side in (-1,1):
            add(2,'SilverScale',(.07*w,.012*h,.13*l),(side*w*.455,h/2+.006*h,-l*.19),SILVER)
            add(2,'BlueScale',(.07*w,.012*h,.13*l),(side*w*.455,h/2+.006*h,l*.17),BLUE)
    else:
        for side in (-1,1):
            for j in range(count):
                z=(-.31+j*.24/(count-1))*l
                if name=='trout':
                    d=min(w,h)*.07
                    add(2,'SilverSpot',(d,d,d),(side*(w/2+d*.5),.405*h,z),SILVER,shape=0)
                else:
                    kind='WedgePart' if name in ('bluefish','sea_bream','tuna') else 'Part'
                    add(2,'SilverGill' if name in ('red_mullet','whiting','sea_bream') else 'SilverScale',
                        (.014*w,.08*h,.08*l),(side*(w/2+.007*w),.405*h,z),SILVER if j%2==0 else BLUE,kind=kind)
    # Gold motifs occupy a separate lower lane; no repeated T2 pieces.
    if name=='turbot':
        for side in (-1,1):
            add(3,'GoldScale',(.08*w,.012*h,.14*l),(side*w*.465,h/2+.006*h,0),GOLD)
    else:
        for side in (-1,1):
            for j in range(2 if name in ('sea_bream','salmon','koi','tuna') else 1):
                z=(-.25+j*.5)*l
                if name=='koi':
                    d=min(w,h)*.08
                    add(3,'GoldPearl',(d,d,d),(side*(w/2+d*.5),-.405*h,z),GOLD,shape=0)
                else:
                    kind='WedgePart' if name in ('salmon','sea_bream') else 'Part'
                    add(3,'GoldFlank',(.015*w,.08*h,.13*l),(side*(w/2+.0075*w),-.405*h,z),GOLD,kind=kind)
    # Symmetric turquoise pearls attach to the Body top, away from the central dorsal fin.
    diameter=min(w,h)*.105
    top=h/2
    if name=='turbot':
        source=E.parse(ROOT/f'assets/Animals/{name}.rbxmx').getroot()
        back=next(i.find('Properties') for i in source.iter('Item')
                  if i.find("Properties/string[@name='Name']") is not None
                  and i.find("Properties/string[@name='Name']").text=='Back')
        top=float(back.find("CoordinateFrame[@name='CFrame']/Y").text)+float(back.find("Vector3[@name='Size']/Y").text)/2
    for side in (-1,1):
        add(4,'DiamondPearl',(diameter,)*3,(side*w*.31,top+diameter*.5,l*.29),CYAN,shape=0)
        if name=='turbot':
            add(4,'CrystalBand',(.10*w,.012*h,.10*l),(side*w*.31,h/2+.006*h,l*.42),(133,224,226))
        else:
            add(4,'CrystalBand',(.014*w,.06*h,.1*l),(side*(w/2+.007*w),0,l*.42),(133,224,226))
    OUT.mkdir(parents=True,exist_ok=True)
    for tier,pieces in tiers.items():
        assert len(pieces)<=8
        ident=f'{name}_T{tier}';r=E.Element('roblox',{'version':'4'})
        E.SubElement(r,'Meta',{'name':'ExplicitAutoJoints'}).text='true'
        m=E.SubElement(r,'Item',{'class':'Model','referent':f'RBX_{ident}'})
        p=E.SubElement(m,'Properties');prop(p,'string','Name',ident)
        frame(p,'WorldPivotData',(0,0,0),np.eye(3),True)
        for j,(label,size,pos,color,shape,kind,rot) in enumerate(pieces):
            i=E.SubElement(m,'Item',{'class':kind,'referent':f'RBX_{ident}_{j}'})
            p=E.SubElement(i,'Properties');prop(p,'string','Name',f'Lineage_T{tier}_{label}_{j}')
            s=E.SubElement(p,'Vector3',{'name':'Size'})
            for k,v in zip(('X','Y','Z'),size):E.SubElement(s,k).text=f'{v:.9f}'
            frame(p,'CFrame',pos,rot)
            c=E.SubElement(p,'Color3',{'name':'Color'})
            for k,v in zip(('R','G','B'),color):E.SubElement(c,k).text=f'{v/255:.9f}'
            prop(p,'token','Material',272)
            if kind=='Part':prop(p,'token','Shape',shape)
            for key,v in [('Anchored',True),('CanCollide',False),('CanQuery',False),('CanTouch',False),('CastShadow',False)]:
                prop(p,'bool',key,str(v).lower())
            prop(p,'float','Transparency',0);prop(p,'float','Reflectance',0)
        E.indent(r,space='  ');path=OUT/f'{ident}.rbxmx'
        E.ElementTree(r).write(path,encoding='utf-8',xml_declaration=True)
        problems=checker.inspect(path,'AnimalLineage');assert not problems,(ident,problems)
        print(ident,len(pieces))


if __name__=='__main__':
    spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts/check-assets.py')
    checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
    for index,name in enumerate(IDS):produce(name,index,checker)

