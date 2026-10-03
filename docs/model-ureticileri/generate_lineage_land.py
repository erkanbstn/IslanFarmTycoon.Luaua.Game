"""Produce additive, species-specific land animal lineage cosmetics.

Coordinates are derived from each current adult Body PrimaryPart. Run using
the bundled Python runtime (numpy) from the repository root.
"""
from pathlib import Path
import importlib.util
import itertools
import xml.etree.ElementTree as ET
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
IDS = 'cow buffalo camel deer goat horse llama pig rabbit sheep yak squirrel'.split()
COLORS = {2:(139,191,220),3:(228,179,66),4:(67,221,221)}
IDENTITY = np.eye(3)

def frame(el):
    return np.array([float(el.find(a).text) for a in 'XYZ']), np.array([[float(el.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])

def load_base(id):
    model = ET.parse(ROOT/'assets'/'Animals'/f'{id}.rbxmx').getroot().find('Item')
    rows=[]
    body = next(p for p in model.findall('Item') if p.find("Properties/string[@name='Name']").text=='Body')
    origin, rotation = frame(body.find("Properties/CoordinateFrame[@name='CFrame']"))
    for item in model.findall('Item'):
        p=item.find('Properties'); size=p.find("Vector3[@name='Size']")
        if size is None: continue
        pos,rot=frame(p.find("CoordinateFrame[@name='CFrame']"))
        rows.append(dict(name=p.find("string[@name='Name']").text,pos=rotation.T@(pos-origin),rot=rotation.T@rot,size=np.array([float(size.find(a).text) for a in 'XYZ'])))
    return rows

def bounds(rows):
    points=[r['pos']+r['rot']@(r['size']*np.array(s)/2) for r in rows for s in itertools.product((-1,1),repeat=3)]
    return np.min(points,axis=0),np.max(points,axis=0)

def volume_overlap(a,b):
    """Exact SAT for authored blocks; tangent contact is allowed."""
    axes=list(a['rot'].T)+list(b['rot'].T)+[np.cross(x,y) for x in a['rot'].T for y in b['rot'].T]
    for axis in axes:
        if np.linalg.norm(axis)<1e-8: continue
        axis=axis/np.linalg.norm(axis)
        radius=sum(abs(axis@a['rot'][:,i])*a['size'][i]/2+abs(axis@b['rot'][:,i])*b['size'][i]/2 for i in range(3))
        if abs(axis@(a['pos']-b['pos']))>=radius-.00001: return False
    return True

def write_frame(parent,name,pos,rot,optional=False):
    el=ET.SubElement(parent,'OptionalCoordinateFrame' if optional else 'CoordinateFrame',name=name)
    if optional: el=ET.SubElement(el,'CFrame')
    for a,v in zip('XYZ',pos): ET.SubElement(el,a).text=f'{v:.8f}'
    for i in range(3):
        for j in range(3): ET.SubElement(el,f'R{i}{j}').text=f'{rot[i,j]:.8f}'

def produce(id):
    base=load_base(id); tiers={2:[],3:[],4:[]}
    def source(name,index=0): return [r for r in base if r['name']==name][index]
    def mount(tier,name,part,axis,sign,extent,offset=(0,0),index=0,mat=1088):
        """Thin surface applique; extent follows the source part's axes.

        offset contains offsets along the other two source axes. No embedding:
        inner face touches the authored source face exactly.
        """
        src=source(part,index); size=np.array(extent,float); local=np.zeros(3)
        local[axis]=sign*(src['size'][axis]/2+size[axis]/2)
        others=[a for a in range(3) if a!=axis]
        for a,v in zip(others,offset): local[a]=v
        row=dict(name='Lineage_'+name,pos=src['pos']+src['rot']@local,rot=src['rot'].copy(),size=size,mat=mat,tier=tier)
        tiers[tier].append(row); return row
    def top(t,n,p,w,d,index=0,off=(0,0),h=.075,mat=1088): return mount(t,n,p,1,1,(w,h,d),off,index,mat)
    def front(t,n,p,w,h,index=0,off=(0,0),th=.07,mat=1088): return mount(t,n,p,2,-1,(w,h,th),off,index,mat)
    def side(t,n,p,h,d,sign,index=0,off=(0,0),th=.075,mat=1088): return mount(t,n,p,0,sign,(th,h,d),off,index,mat)
    def gems_on(row,tier,name,count=3):
        # Gems are on the exterior of a parent cosmetic, not coplanar with it.
        normal=np.argmin(row['size']); others=sorted((a for a in range(3) if a!=normal),key=lambda a:row['size'][a])
        sign=1 if normal in (0,1) else -1
        if normal==0: sign=1 if row['pos'][0]>0 else -1
        span=row['size'][others[1]]*.65
        for i in range(count):
            size=np.full(3,min(.12,max(.06,row['size'][others[0]]*.25)))
            loc=np.zeros(3);loc[normal]=sign*(row['size'][normal]/2+size[normal]/2)
            loc[others[1]]=(i-(count-1)/2)*span/max(1,count-1)
            tiers[tier].append(dict(name='Lineage_'+name+str(i+1),pos=row['pos']+row['rot']@loc,rot=row['rot'].copy(),size=size,mat=272,tier=tier))
    if id=='cow':
        front(2,'SilverMuzzleBridge','Snout',1.15,.10,off=(0,.18))
        mount(2,'DairyBell','Head',1,-1,(.28,.24,.24),offset=(0,.10))
        for i in range(5): top(3,'FlowerWreath'+str(i),'Head',.22,.22,off=((i-2)*.27,-.30))
        for i in range(2): top(4,'TurquoiseHornCap'+str(i),'Horn',.29,.29,i,h=.13)
    elif id=='buffalo':
        for i in range(2): top(2,'SilverHornCuff'+str(i),'HornBase',.50,.34,i)
        for i in range(3): top(3,'ShoulderArmor'+str(i),'Shoulder',.48,.90,off=((i-1)*.56,0))
        plate=front(4,'DiamondBrow','Head',.55,.25,off=(0,.53));gems_on(plate,4,'BrowGem',3)
    elif id=='camel':
        for s in (-1,1): side(2,'CaravanNeckRibbon'+str(s),'Neck',.32,.50,s,off=(.34,0),mat=1312)
        for i,p in enumerate(('Hump1','Hump2')): top(3,'GoldenHumpSaddle'+str(i),p,.92,.65,mat=1312)
        for i,p in enumerate(('Hump1','Hump2')):
            for s in (-1,1): side(4,'TurquoiseSaddleMedallion'+str(i)+str(s),p,.30,.38,s,mat=272)
    elif id=='deer':
        front(2,'ForestNeckBrooch','Neck',.34,.26,off=(0,.2))
        for i in range(2): top(3,'GoldAntlerTip'+str(i),'Antler',.15,.15,i,h=.14)
        row=front(4,'ForestDiadem','Head',.42,.16,off=(0,.20));gems_on(row,4,'ForestCrystal',3)
    elif id=='goat':
        front(2,'MountainBell','Head',.23,.22,off=(0,-.28),th=.16)
        for i in range(2): top(3,'GoldHornTip'+str(i),'Horn',.23,.23,i,h=.14)
        for s in (-1,1):
            row=side(4,'CliffDiamondPlate'+str(s),'Patch',.32,.46,s,off=(-.15,-.10));gems_on(row,4,'CliffGem'+str(s),3)
    elif id=='horse':
        panels=[]
        for s in (-1,1): panels.append(side(2,'BlueSaddlecloth'+str(s),'Body',.85,1.25,s,off=(.28,.24),mat=1312))
        for i in range(3): mount(3,'GoldManeClip'+str(i),'Mane',2,1,(.30,.13,.075),offset=(0,(i-1)*.42))
        for i,row in enumerate(panels): gems_on(row,4,'SaddleJewel'+str(i),3)
        top(4,'TurquoiseBrowCrest','Head',.38,.45,off=(0,-.35),h=.12)
    elif id=='llama':
        top(2,'SilverBlanketStripe','Blanket',1.20,.15,off=(0,.10),mat=1312)
        for s in (-1,1): side(3,'AndeanNeckTassel'+str(s),'Neck',.52,.20,s,off=(.40,0),mat=1312)
        for i in range(3): top(4,'AndeanTuftGem'+str(i),'Tuft',.10,.15,off=((i-1)*.14,0),h=.10)
    elif id=='pig':
        top(2,'BlueFarmBow','Head',.62,.23,off=(0,.18),mat=1312)
        for s in (-1,1): side(3,'GoldenHarvestRosette'+str(s),'Body',.35,.35,s,off=(.26,.20))
        for i in range(2): front(4,'TurquoiseEarClip'+str(i),'Ear',.20,.17,i,off=(0,.10),mat=272)
    elif id=='rabbit':
        for i in range(2): front(2,'SilverEarBand'+str(i),'EarInner',.20,.12,i,off=(0,.38))
        top(3,'GardenRibbon','Head',.38,.20,off=(0,-.25),mat=1312)
        for s in (-1,1):
            row=side(4,'GardenFlower'+str(s),'Body',.25,.25,s,off=(.24,-.08));gems_on(row,4,'GardenDiamond'+str(s),1)
    elif id=='sheep':
        mount(2,'ShepherdBell','Head',1,-1,(.25,.20,.20),offset=(0,.10))
        for i in range(3): front(3,'GoldenFringeFlower'+str(i),'Fringe',.18,.18,off=((i-1)*.31,0))
        for i in range(2):
            row=top(4,'WoolCrystalMount'+str(i),'Wool',.35,.45,i,h=.065);gems_on(row,4,'WoolCrystal'+str(i),2)
    elif id=='yak':
        for i in range(2): front(2,'SilverHornBridle'+str(i),'HornBase',.60,.13,i)
        for i in range(3): top(3,'HighlandSaddleWeave'+str(i),'Hump',.50,.90,off=((i-1)*.59,0),mat=1312)
        for i in range(3): front(4,'GlacierForelockJewel'+str(i),'Forelock',.19,.20,off=((i-1)*.32,0),mat=272)
    elif id=='squirrel':
        top(2,'BlueForagerCap','Head',.30,.25,off=(0,-.19),mat=1312)
        for s in (-1,1):
            row=side(3,'GoldenAcornPouch'+str(s),'Body',.30,.40,s,off=(.05,.03),th=.035,mat=1312)
            gems_on(row,3,'AcornClasp'+str(s),1)
        for i in range(2): front(4,'ForestEarCrystal'+str(i),'Ear',.12,.13,i,off=(0,.03),mat=272)
    output=ROOT/'assets'/'AnimalLineage';output.mkdir(exist_ok=True)
    spec=importlib.util.spec_from_file_location('asset_check',ROOT/'scripts'/'check-assets.py');checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
    for tier,rows in tiers.items():
        assert 0<len(rows)<=14
        name=f'{id}_T{tier}';root=ET.Element('roblox',version='4');model=ET.SubElement(root,'Item',{'class':'Model','referent':'RBXMODEL'});props=ET.SubElement(model,'Properties');ET.SubElement(props,'string',name='Name').text=name
        write_frame(props,'WorldPivotData',np.zeros(3),IDENTITY,True)
        for index,row in enumerate(rows):
            item=ET.SubElement(model,'Item',{'class':'Part','referent':f'RBXPART{index+1}'});p=ET.SubElement(item,'Properties');ET.SubElement(p,'string',name='Name').text=row['name'];vec=ET.SubElement(p,'Vector3',name='Size')
            for a,v in zip('XYZ',row['size']):ET.SubElement(vec,a).text=f'{v:.8f}'
            write_frame(p,'CFrame',row['pos'],row['rot']);color=ET.SubElement(p,'Color3',name='Color')
            for a,v in zip('RGB',COLORS[tier]):ET.SubElement(color,a).text=str(v/255)
            ET.SubElement(p,'token',name='Material').text=str(row['mat']);ET.SubElement(p,'token',name='Shape').text='1'
            for k in ('Anchored','CanCollide','CanQuery','CanTouch','CastShadow'):ET.SubElement(p,'bool',name=k).text='true' if k=='Anchored' else 'false'
        ET.indent(root,space='  ');path=output/f'{name}.rbxmx';ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=False)
        errors=checker.inspect(path,'AnimalLineage');assert not errors,(name,errors)
        lo,hi=bounds(rows);print(name,len(rows),'cosmeticXYZ',','.join(f'{v:.4f}' for v in hi-lo))
    low,high=bounds(base);cl,ch=bounds(base+sum(tiers.values(),[]));ratio=(ch-cl)/(high-low)
    assert max(ratio)<=1.25,(id,ratio)
    added=sum(tiers.values(),[])
    assert not [(a['name'],b['name']) for a,b in itertools.combinations(added,2) if volume_overlap(a,b)],id
    # SAT on the base bounding boxes is conservative for wedges/ellipsoids:
    # no candidate intersects even their enclosing boxes.
    assert not [(a['name'],b['name']) for a in added for b in base if volume_overlap(a,b)],id
    print(id,'combinedRatio',ratio.round(5),'totalparts',sum(map(len,tiers.values())))
    return tiers

if __name__=='__main__':
    results={id:produce(id) for id in IDS}
    print('TOTAL',len(results)*3,'files',sum(len(rows) for tiers in results.values() for rows in tiers.values()),'parts')


