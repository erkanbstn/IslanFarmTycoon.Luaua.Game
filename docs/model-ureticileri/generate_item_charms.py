"""Eleven primitive shop charms in HumanoidRootPart-local chest space."""
from pathlib import Path
import base64
import importlib.util
import math
import struct
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/Items'
I=(1,0,0,0,1,0,0,0,1)
COIN=(0,0,-1,0,1,0,1,0,0)  # Cylinder axis X -> Z.
GOLD=(222,174,63); SILVER=(167,179,190); WOOD=(138,92,56); DARK=(69,51,43)

def scalar(p,tag,name,value): ET.SubElement(p,tag,{'name':name}).text=str(value)
def rz(angle):
    c,s=math.cos(angle),math.sin(angle)
    return (c,-s,0,s,c,0,0,0,1)
def frame(p,pos,rot,optional=False):
    if optional:n=ET.SubElement(ET.SubElement(p,'OptionalCoordinateFrame',{'name':'WorldPivotData'}),'CFrame')
    else:n=ET.SubElement(p,'CoordinateFrame',{'name':'CFrame'})
    for k,v in zip('XYZ',pos):ET.SubElement(n,k).text=f'{v:.8f}'
    for j,v in enumerate(rot):ET.SubElement(n,f'R{j//3}{j%3}').text=f'{v:.8f}'
def attributes():
    key,value=b'Attach',b'chest'
    raw=struct.pack('<II',1,len(key))+key+b'\x02'+struct.pack('<I',len(value))+value
    # Verify exact string encoding, including no zero terminators.
    count,kl=struct.unpack_from('<II',raw); assert count==1
    assert raw[8:8+kl]==key and raw[8+kl]==2
    vl=struct.unpack_from('<I',raw,9+kl)[0];assert raw[13+kl:13+kl+vl]==value
    return base64.b64encode(raw).decode()

def create(id,d,checker):
    pieces=[]; z=-(.45+d*.2)
    def add(n,s,p,color=GOLD,material=1088,rot=I,shape=1,cls='Part'):
        pieces.append(dict(n=n,s=tuple(x*d for x in s),p=(p[0]*d,.6+p[1]*d,z+p[2]*d),color=color,material=material,rot=rot,shape=shape,cls=cls))
    def block(n,s,p,color=GOLD,material=1088,rot=I):add(n,s,p,color,material,rot)
    def disk(n,diameter,thickness,p,color=GOLD):add(n,(thickness,diameter,diameter),p,color,1088,COIN,2)
    def ball(n,size,p,color):add(n,(size,size,size),p,color,272,I,0)
    def hanger():
        # Flat pendant eyelet; outside torso rather than buried through chest.
        for side in (-1,1):block('PendantLoopSide',(.055,.22,.055),(side*.095,.425,0))
        block('PendantLoopTop',(.245,.055,.055),(0,.54,0))
    if id.startswith('storage'):
        if id.endswith('1'):
            block('ChestBody',(.70,.48,.12),(0,-.03,0),WOOD,512)
            block('ChestLid',(.76,.14,.13),(0,.26,0),(177,119,66),512)
            for side in (-1,1):block('ChestBand',(.085,.57,.035),(side*.25,.015,-.087),GOLD)
            block('ChestLatch',(.14,.19,.035),(0,.06,-.09),GOLD)
            block('ChestKeyhole',(.037,.075,.014),(0,.045,-.119),DARK,272)
        else:
            block('StorageVault',(.78,.64,.10),(0,0,0),(118,92,58),512)
            block('VaultFace',(.65,.53,.028),(0,0,-.07),(179,132,65))
            for side in (-1,1):block('VaultHinge',(.05,.12,.03),(-.34,side*.18,-.075),SILVER)
            disk('VaultLock',.22,.035,(.14,0,-.105),GOLD)
            block('VaultLockSlot',(.025,.105,.014),(.14,0,-.13),DARK,272)
            block('VaultHandle',(.045,.22,.035),(-.16,0,-.105),GOLD)
        hanger()
    elif id.startswith('growth'):
        block('Planter',(.47,.27,.105),(0,-.27,0),(154,99,67),512)
        block('PlanterRim',(.54,.07,.12),(0,-.10,-.005),(210,152,91),512)
        block('PlantStem',(.045,.51,.04),(0,.13,-.035),(62,135,76),272)
        for side in (-1,1):
            block('PlantLeaf',(.14,.28,.04),(side*.10,.20,-.045),(86,182,101),272,rz(-side*.55))
        if id.endswith('2'):
            for j in range(5):
                a=j*2*math.pi/5
                ball('BloomPetal',.145,(math.sin(a)*.13,.44+math.cos(a)*.13,-.035),(144,218,139))
            ball('BloomCenter',.135,(0,.44,-.115),(247,220,116))
        else:
            block('SeedSprout',(.12,.20,.035),(0,.43,-.035),(151,215,119),272)
    elif id.startswith('income'):
        if id.endswith('1'):
            block('WheatStem',(.04,.81,.035),(0,0,0),GOLD)
            for side in (-1,1):
                for j in range(3):block('WheatGrain',(.09,.19,.05),(side*.09,-.02+j*.17,-.04),(236,195,84),1088,rz(-side*.6))
            block('WheatTie',(.20,.07,.07),(0,-.27,-.045),(157,111,57))
        elif id.endswith('2'):
            for j in range(3):disk('SavingsCoin',.52,.042,((j-1)*.16,(j-1)*.16,-.035-j*.047),GOLD)
            block('CoinMintBar',(.11,.28,.016),(.16,.16,-.154),(249,220,139))
            for side in (-1,1):block('CoinMintStroke',(.20,.03,.016),(.16,.16+side*.09,-.154),(249,220,139))
            for j in range(2):block('CoinGlint',(.14,.025,.025),(-.24,-.09,-.062),(240,222,151),1088,rz(j*math.pi/2))
        else:
            disk('ProsperitySun',.52,.048,(0,0,0),(226,180,65))
            disk('SunFace',.39,.016,(0,0,-.036),(247,217,119))
            for j in range(8):
                a=j*math.pi/4
                block('SunRay',(.05,.19,.035),(math.sin(a)*.38,math.cos(a)*.38,0),(226,180,65),1088,rz(-a))
            ball('SunHeart',.09,(0,0,-.088),(250,242,196))
    elif id.startswith('barn'):
        color=SILVER if id.endswith('1') else GOLD
        for side in (-1,1):
            block('KeyBowSide',(.065,.28,.055),(side*.15,.25,0),color)
            block('KeyBowCrossbar',(.30,.065,.055),(0,.25+side*.14,0),color)
        block('KeyStem',(.07,.55,.06),(0,-.145,0),color)
        for j in range(2 if id.endswith('1') else 3):block('KeyTooth',(.18,.065,.06),(.075,-.22-j*.09,0),color)
        if id.endswith('2'):
            block('KeyGemBrace',(.32,.035,.055),(0,.25,0),color)
            ball('KeyJewel',.105,(0,.25,-.067),(79,160,165))
            block('KeyShaftCollar',(.14,.075,.075),(0,-.045,0),color)
    elif id.startswith('contract'):
        color=(85,131,183) if id.endswith('1') else (57,96,153)
        block('LedgerPages',(.53,.66,.09),(.025,0,0),(226,213,174),272)
        block('LedgerBack',(.66,.76,.03),(0,0,.06),color,272)
        block('LedgerCover',(.66,.76,.03),(0,0,-.06),color,272)
        block('LedgerSpine',(.09,.76,.145),(-.285,0,0),(44,74,112),272)
        for j in range(2):block('LedgerTitleLine',(.35,.032,.018),(.045,.21-j*.10,-.088),GOLD)
        disk('MerchantSeal',.19,.025,(.12,-.17,-.092),GOLD)
        if id.endswith('2'):
            block('LedgerStrap',(.075,.76,.025),(.21,0,-.09),(169,122,66),512)
            block('LedgerBuckle',(.12,.12,.025),(.21,0,-.117),GOLD)
            block('LedgerRibbon',(.06,.17,.025),(-.13,-.425,-.08),(209,158,74),272)
    assert 6<=len(pieces)<=14,(id,len(pieces))
    # Deliberate assembled joints/metal overlays are connected; every solid
    # remains in front of the standard HRP torso face Z=-0.5.
    bounds=[]
    for piece in pieces:
        s,p,r=piece['s'],piece['p'],piece['rot']
        extent=[sum(abs(r[a*3+b])*s[b]/2 for b in range(3))for a in range(3)]
        bounds.append(([p[a]-extent[a]for a in range(3)],[p[a]+extent[a]for a in range(3)]))
    lo=[min(b[0][a]for b in bounds)for a in range(3)];hi=[max(b[1][a]for b in bounds)for a in range(3)]
    assert hi[2]<=-.5+1e-6,(id,hi[2])
    root=ET.Element('roblox',{'version':'4'});ET.SubElement(root,'Meta',{'name':'ExplicitAutoJoints'}).text='true'
    m=ET.SubElement(root,'Item',{'class':'Model','referent':'MODEL'});p=ET.SubElement(m,'Properties')
    scalar(p,'string','Name',id);frame(p,(0,0,0),I,True);scalar(p,'BinaryString','AttributesSerialize',attributes())
    for j,piece in enumerate(pieces):
        item=ET.SubElement(m,'Item',{'class':piece['cls'],'referent':f'PART{j}'})
        p=ET.SubElement(item,'Properties');scalar(p,'string','Name',piece['n'])
        n=ET.SubElement(p,'Vector3',{'name':'Size'})
        for k,v in zip('XYZ',piece['s']):ET.SubElement(n,k).text=f'{v:.8f}'
        frame(p,piece['p'],piece['rot']);n=ET.SubElement(p,'Color3',{'name':'Color'})
        for k,v in zip('RGB',piece['color']):ET.SubElement(n,k).text=f'{v/255:.8f}'
        scalar(p,'token','Material',piece['material']);scalar(p,'token','Shape',piece['shape'])
        for key,val in [('Anchored','true'),('Massless','true'),('CanCollide','false'),('CanQuery','false'),('CanTouch','false'),('CastShadow','false')]:scalar(p,'bool',key,val)
        scalar(p,'float','Transparency',0)
    ET.indent(root,space='  ');path=OUT/f'{id}.rbxmx';ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    assert not checker.inspect(path,'Items'),checker.inspect(path,'Items')
    assert m.find("Properties/Ref[@name='PrimaryPart']")is None
    print(id,len(pieces),'boundsXYZ',[round(hi[a]-lo[a],4)for a in range(3)],'backZ',round(hi[2],4))
    return len(pieces)

def main():
    spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts/check-assets.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
    OUT.mkdir(parents=True,exist_ok=True)
    ids=[(f'{kind}_charm_{tier}',.6 if tier==1 else .8 if tier==2 else 1)for kind,tiers in [('storage',2),('growth',2),('income',3),('barn',2),('contract',2)]for tier in range(1,tiers+1)]
    total=sum(create(id,d,c)for id,d in ids)
    print('11 models',total,'parts; Attach=chest Base64',attributes())
if __name__=='__main__':main()
