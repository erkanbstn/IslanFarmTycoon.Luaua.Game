"""Primitive, additive lineage ornaments for twelve small animal species.

All coordinates are transformed into the actual Body PrimaryPart frame.
The generator checks budgets, source contact, cumulative bounds and OBB
nonintersection between every tier and the source animal.
"""
from pathlib import Path
import importlib.util
import itertools
import math
import xml.etree.ElementTree as ET
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/AnimalLineage'
IDS = 'bee chicken duck falcon parrot peacock pigeon quail silkworm snail tortoise turkey'.split()
COLORS = {2: (166, 196, 218), 3: (221, 172, 65), 4: (56, 211, 210)}
I = np.eye(3)

def corners(p):
    return np.array(list(itertools.product(*[(-s/2, s/2) for s in p['s']]))) @ p['r'].T + p['p']

def overlap(a, b):
    # Exact OBB SAT. For wedges/spheres this is deliberately conservative.
    if a.get('shape') == 0 or b.get('shape') == 0:
        sphere, box = (a, b) if a.get('shape') == 0 else (b, a)
        local = box['r'].T @ (sphere['p']-box['p'])
        closest = np.clip(local, -box['s']/2, box['s']/2)
        return np.linalg.norm(local-closest) < min(sphere['s'])/2-1e-5
    d = b['p']-a['p']
    axes = [*a['r'].T, *b['r'].T]
    axes += [np.cross(x, y) for x in a['r'].T for y in b['r'].T]
    for axis in axes:
        if np.linalg.norm(axis) < 1e-8:
            continue
        ra = sum(abs(axis @ a['r'][:, j])*a['s'][j]/2 for j in range(3))
        rb = sum(abs(axis @ b['r'][:, j])*b['s'][j]/2 for j in range(3))
        if abs(axis @ d) >= ra+rb-1e-5:
            return False
    return True

def part(n, s, p, tier, r=I, shape=1, cls='Part'):
    return dict(n='Lineage_'+n, s=np.array(s), p=np.array(p), r=np.array(r), color=COLORS[tier], shape=shape, cls=cls)

def read_base(id):
    model = ET.parse(ROOT / f'assets/Animals/{id}.rbxmx').getroot().find('Item')
    primary = model.find("Properties/Ref[@name='PrimaryPart']").text
    rows = []
    for item in model.iter('Item'):
        if item.get('class') not in ('Part', 'WedgePart'):
            continue
        p = item.find('Properties')
        cf = p.find("CoordinateFrame[@name='CFrame']")
        s = p.find("Vector3[@name='Size']")
        shape = p.find("token[@name='Shape']")
        rows.append(dict(n=p.find("string[@name='Name']").text,
            s=np.array([float(s.find(k).text) for k in 'XYZ']),
            p=np.array([float(cf.find(k).text) for k in 'XYZ']),
            r=np.array([[float(cf.find(f'R{a}{b}').text) for b in range(3)] for a in range(3)]),
            cls=item.get('class'), shape=int(shape.text) if shape is not None else 1,
            ref=item.get('referent')))
    body = next(p for p in rows if p['ref']==primary)
    origin, rot = body['p'].copy(), body['r'].copy()
    for p in rows:
        p['p'] = rot.T @ (p['p']-origin)
        p['r'] = rot.T @ p['r']
    return rows, body

def motif(id, tier, w, length):
    """Small distinct, connected motifs lying on the same top face."""
    result = []
    def add(n, sz, x, z, y=None, cls='Part', rot=I):
        result.append(part(n, sz, (x, sz[1]/2 if y is None else y, z), tier, rot, cls=cls))
    t = .045
    if tier == 2:
        if id in ('chicken', 'turkey', 'falcon'):
            for j in range(3):
                add('SilverPinion'+str(j), (w*.25, t, length*(.7+.1*j)), (j-1)*w*.32, 0)
        elif id in ('parrot', 'pigeon'):
            add('SilverMessengerPlate', (w, t, length*.7), 0, 0)
            add('BlueSeal', (w*.35, t, length*.25), 0, 0, t+t/2)
            result[-1]['color']=(77, 119, 172)
        elif id in ('duck', 'peacock'):
            for j in range(2):
                add('SilverWaterBand'+str(j), (w, t, length*.22), 0, (j-.5)*length*.6)
        elif id == 'quail':
            for j in range(3):
                add('SilverDapple'+str(j), (w*.4,t,length*.22), (j%2-.5)*w*.5,(j-1)*length*.32)
        else:
            add('SilverThoraxPlate', (w,t,length),0,0)
    elif tier == 3:
        if id in ('peacock', 'turkey'):
            for j in range(3):
                add('GoldenFanTile'+str(j),(w*.28,t,length*(.55+.17*j)),(j-1)*w*.34,0)
        elif id in ('duck', 'pigeon'):
            add('GoldenCarrierPlate',(w,t,length),0,0)
            add('GoldenMailSeal',(w*.35,t,length*.33),0,0,t+t/2)
        elif id in ('chicken','falcon','parrot'):
            for j in range(2):
                add('GoldenPinion'+str(j),(w*.42,t,length), (j-.5)*w*.56,0)
        elif id == 'quail':
            add('GoldenBackTile',(w,t,length),0,0)
            add('GoldenSeedSeal',(w*.32,t,length*.3),0,0,t+t/2)
        else:
            add('GoldenThoraxTile',(w,t,length),0,0)
            add('GoldenHoneySeal',(w*.35,t,length*.35),0,0,t+t/2)
    else:
        if id == 'bee':
            add('DiamondHoneyPlate',(w,t,length),0,0)
            for j in range(3):
                h=.10 if j!=1 else .16
                add('DiamondHoneyProng'+str(j),(w*.2,h,length*.3),(j-1)*w*.32,0,t+h/2)
        elif id in ('chicken','falcon'):
            add('DiamondPinionBase',(w,t,length),0,0)
            for j in range(2):
                add('DiamondPinionFacet'+str(j),(w*.4,.10,length*.8),(j-.5)*w*.53,0,t+.05,cls='WedgePart')
        elif id=='duck':
            for j in range(3):
                add('DiamondWave'+str(j),(w*(.55+.18*j),t,length*.18),0,(j-1)*length*.3)
        elif id=='peacock':
            add('DiamondEyespotBase',(w,t,length),0,0)
            add('DiamondEyespot',(w*.68,t,length*.66),0,0,t+t/2)
            add('DiamondEyespotCenter',(w*.26,t,length*.26),0,0,2*t+t/2)
            result[-1]['color']=(207,250,248)
        elif id=='pigeon':
            add('DiamondCourierSeal',(w,t,length),0,0)
            add('DiamondCourierRibbon',(w*.32,t,length*.9),0,0,t+t/2)
            add('DiamondCourierGem',(w*.48,t,length*.30),0,0,2*t+t/2)
        elif id=='quail':
            add('DiamondDappleBase',(w,t,length),0,0)
            for j in range(3):
                add('DiamondDapple'+str(j),(w*.5,t,length*.15),0,(j-1)*length*.27,t+t/2)
        elif id=='turkey':
            for j in range(3):
                add('DiamondFanPinion'+str(j),(w*.27,t,length*(.6+.13*j)),(j-1)*w*.34,0)
                add('DiamondFanTip'+str(j),(w*.2,t,length*.2),(j-1)*w*.34,length*.16,t+t/2)
        else:
            add('DiamondRidgeBase',(w,t,length),0,0)
            add('DiamondRidgeFacet',(w*.7,t,length*.72),0,0,t+t/2)
            add('DiamondRidgeCut',(w*.4,t,length*.45),0,0,2*t+t/2)
    return result

def place_flat(cluster, source, previous, body, tier):
    """Search exposed Body top, then small fixed dorsal source details."""
    width=max(p['s'][0] for p in cluster)
    length=max(p['s'][2]+2*abs(p['p'][2]) for p in cluster)
    slots = {2: -.27, 3: .27, 4: 0}
    anchors=[body]+[p for p in source if p['n'] in ('Spot','Scute','ChestSpot','Head','Cap') and p['shape']==1 and p['cls']=='Part']
    for anchor in anchors:
        if not np.allclose(anchor['r'], I, atol=1e-5):
            continue
        for zfrac in (0,.15,-.15,.3,-.3):
            x=anchor['p'][0]+slots[tier]*anchor['s'][0]
            z=anchor['p'][2]+zfrac*anchor['s'][2]
            if abs(x-anchor['p'][0])+width/2 > anchor['s'][0]/2 or abs(z-anchor['p'][2])+length/2 > anchor['s'][2]/2:
                continue
            pos=np.array((x,anchor['p'][1]+anchor['s'][1]/2,z))
            candidate=[dict(p, p=p['p']+pos) for p in cluster]
            if any(overlap(a,b) for a in candidate for b in source+previous):
                continue
            return candidate
    raise AssertionError(f'{body["n"]} tier {tier}: no exposed supported face')

def special(id, tier, source, previous, body):
    if id=='snail':
        cap=max((p for p in source if p['n']=='Shell'),key=lambda p:p['s'][0])
        result=[]
        radius={2:.235,3:.13,4:0}[tier]
        count={2:5,3:3,4:1}[tier]
        for side in (-1,1):
            for j in range(count):
                angle=j*2*math.pi/count
                size=.058 if tier<4 else .085
                pos=cap['p']+np.array((side*(cap['s'][0]/2+size/2), radius*math.cos(angle),radius*math.sin(angle)))
                result.append(part(f'ShellSpiral{side}_{j}',(size,size,size),pos,tier))
        return result
    if id=='silkworm':
        target={2:-.8,3:.7,4:0}[tier]
        anchor=min((p for p in source if p['n'] in ('Body','Segment')),key=lambda p:abs(p['p'][2]-target))
        # Sphere-cap tangent: tiny fixed flat tile rests at exact pole.
        width=.19 if tier<4 else .23
        top=anchor['p']+np.array((0,anchor['s'][1]/2,0))
        result=[part('SilkSegmentTile',(width,.045,.22),top+np.array((0,.0225,0)),tier)]
        result.append(part('SilkSegmentGem',(.105,.045,.105),top+np.array((0,.0675,0)),tier))
        return result
    if id=='tortoise':
        if tier<4:
            side=-1 if tier==2 else 1
            result=[]
            for j,anchor in enumerate(p for p in source if p['n']=='Scute' and p['p'][0]*side>0):
                top=anchor['p']+np.array((side*.20,anchor['s'][1]/2,0))
                result.append(part('ShellScuteTile'+str(j),(.16,.045,.31),top+np.array((0,.0225,0)),tier))
                if tier==3:
                    result.append(part('ShellScuteGoldSeal'+str(j),(.10,.04,.13),top+np.array((0,.065,0)),tier))
            return result
        shell=next(p for p in source if p['n']=='Shell')
        z=-shell['s'][2]/2+.22
        top=np.array((0,shell['p'][1]+shell['s'][1]/2,z))
        return [part('ShellDiamondBar',(.5,.045,.22),top+np.array((0,.0225,0)),tier),part('ShellDiamondInset',(.25,.055,.15),top+np.array((0,.0725,0)),tier)]

def scalar(p,tag,name,value):
    ET.SubElement(p,tag,{'name':name}).text=str(value)

def frame(p,pos,rot,optional=False):
    if optional:
        node=ET.SubElement(ET.SubElement(p,'OptionalCoordinateFrame',{'name':'WorldPivotData'}),'CFrame')
    else:
        node=ET.SubElement(p,'CoordinateFrame',{'name':'CFrame'})
    for k,v in zip('XYZ',pos): ET.SubElement(node,k).text=f'{v:.8f}'
    for a in range(3):
        for b in range(3): ET.SubElement(node,f'R{a}{b}').text=f'{rot[a,b]:.8f}'

def save(id,tier,parts,checker):
    name=f'{id}_T{tier}'
    root=ET.Element('roblox',{'version':'4'})
    ET.SubElement(root,'Meta',{'name':'ExplicitAutoJoints'}).text='true'
    model=ET.SubElement(root,'Item',{'class':'Model','referent':'MODEL'})
    p=ET.SubElement(model,'Properties'); scalar(p,'string','Name',name); frame(p,np.zeros(3),I,True)
    for j,row in enumerate(parts):
        item=ET.SubElement(model,'Item',{'class':row['cls'],'referent':f'PART{j}'})
        p=ET.SubElement(item,'Properties'); scalar(p,'string','Name',row['n'])
        node=ET.SubElement(p,'Vector3',{'name':'Size'})
        for k,v in zip('XYZ',row['s']): ET.SubElement(node,k).text=f'{v:.8f}'
        frame(p,row['p'],row['r'])
        node=ET.SubElement(p,'Color3',{'name':'Color'})
        for k,v in zip('RGB',row['color']): ET.SubElement(node,k).text=f'{v/255:.8f}'
        scalar(p,'token','Material',1088)
        if row['cls']=='Part': scalar(p,'token','Shape',row['shape'])
        for key,val in [('Anchored','true'),('CanCollide','false'),('CanQuery','false'),('CanTouch','false'),('CastShadow','false')]: scalar(p,'bool',key,val)
        scalar(p,'float','Transparency',0)
    ET.indent(root,space='  ')
    path=OUT/f'{name}.rbxmx'; ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    assert not checker.inspect(path,'AnimalLineage'),checker.inspect(path,'AnimalLineage')

def main():
    spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts/check-assets.py'); checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
    OUT.mkdir(exist_ok=True)
    total=0
    for id in IDS:
        source,body=read_base(id); cumulative=[]; counts=[]
        basevertices=np.concatenate([corners(p)for p in source]); base_size=np.ptp(basevertices,axis=0)
        for tier in (2,3,4):
            if id in ('snail','silkworm','tortoise'):
                parts=special(id,tier,source,cumulative,body)
            else:
                cluster=motif(id,tier,body['s'][0]*.18,body['s'][2]*.25)
                parts=place_flat(cluster,source,cumulative,body,tier)
            assert len(parts)<=14
            assert not any(overlap(a,b)for a in parts for b in source+cumulative),id+' embeds source or previous tier'
            # Motif elements touch but never occupy the same volume.
            assert not any(overlap(a,b)for i,a in enumerate(parts)for b in parts[i+1:]),id+' internal overlap'
            cumulative+=parts
            vertices=np.concatenate([basevertices]+[corners(p)for p in cumulative]); ratio=np.ptp(vertices,axis=0)/base_size
            assert max(ratio)<=1.25+1e-6,(id,ratio)
            save(id,tier,parts,checker); counts.append(len(parts));total+=len(parts)
        print(id,'counts',counts,'cumulative bounds ratio',np.round(ratio,4).tolist())
    print('36 models; total parts',total,'all XML/bounds/budget/source-contact/cumulative OBB tests passed')

if __name__=='__main__': main()
