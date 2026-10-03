"""Distinct primitive tool/staff shop models in the existing avatar anchor space."""
from pathlib import Path
import base64
import importlib.util
import math
import struct
import xml.etree.ElementTree as E
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets'/'Items'
WOOD=(120,85,55)
GOLD=(255,200,70)
IVORY=(244,230,187)
STEEL=(150,155,165)

def rz(a):
    c,s=math.cos(a),math.sin(a);return np.array(((c,-s,0),(s,c,0),(0,0,1)))

def ry(a):
    c,s=math.cos(a),math.sin(a);return np.array(((c,0,s),(0,1,0),(-s,0,c)))

def frame(p,name,pos,rot,optional=False):
    node=E.SubElement(p,'OptionalCoordinateFrame' if optional else 'CoordinateFrame',name=name)
    if optional:node=E.SubElement(node,'CFrame')
    for a,v in zip('XYZ',pos):E.SubElement(node,a).text=f'{v:.8f}'
    for i in range(3):
        for j in range(3):E.SubElement(node,f'R{i}{j}').text=f'{rot[i,j]:.8f}'

def attachment(value):
    key=b'Attach';val=value.encode('utf-8')
    return base64.b64encode(struct.pack('<II',1,len(key))+key+b'\x02'+struct.pack('<I',len(val))+val).decode('ascii')

class Design:
    def __init__(self,name,attach):self.name=name;self.attach=attach;self.parts=[]
    def add(self,name,size,pos,color,material=1088,shape=1,kind='Part',rot=None):
        self.parts.append((name,np.array(size,float),np.array(pos,float),color,material,shape,kind,np.eye(3) if rot is None else rot))
    def rod(self,name,a,b,width,color,material=1088):
        a,b=np.array(a,float),np.array(b,float);direction=b-a;length=np.linalg.norm(direction);x=direction/length
        temp=np.array((0,1,0)) if abs(x[1])<.9 else np.array((0,0,1));z=np.cross(x,temp);z/=np.linalg.norm(z);y=np.cross(z,x)
        self.add(name,(length,width,width),(a+b)/2,color,material,2,rot=np.column_stack((x,y,z)))
    def ball(self,name,d,pos,color,material=272):self.add(name,(d,d,d),pos,color,material,0)
    def save(self):
        limit=14 if self.attach=='hip' else 20;minimum=6 if self.attach=='hip' else 10;assert minimum<=len(self.parts)<=limit
        root=E.Element('roblox',version='4');E.SubElement(root,'Meta',name='ExplicitAutoJoints').text='true';model=E.SubElement(root,'Item',{'class':'Model','referent':'RBXMODEL'});props=E.SubElement(model,'Properties')
        E.SubElement(props,'string',name='Name').text=self.name;E.SubElement(props,'BinaryString',name='AttributesSerialize').text=attachment(self.attach);frame(props,'WorldPivotData',np.zeros(3),np.eye(3),True)
        lows=[];highs=[]
        for i,(name,size,pos,color,material,shape,kind,rot) in enumerate(self.parts):
            item=E.SubElement(model,'Item',{'class':kind,'referent':f'RBXPART{i+1}'});p=E.SubElement(item,'Properties');E.SubElement(p,'string',name='Name').text=name;v=E.SubElement(p,'Vector3',name='Size')
            assert min(size)>0
            for a,val in zip('XYZ',size):E.SubElement(v,a).text=f'{val:.8f}'
            frame(p,'CFrame',pos,rot);c=E.SubElement(p,'Color3',name='Color')
            for a,val in zip('RGB',color):E.SubElement(c,a).text=str(val/255)
            E.SubElement(p,'token',name='Material').text=str(material)
            if kind=='Part':E.SubElement(p,'token',name='Shape').text=str(shape)
            for key in ('Anchored','Massless','CanCollide','CanQuery','CanTouch','CastShadow'):E.SubElement(p,'bool',name=key).text='true' if key in ('Anchored','Massless') else 'false'
            if shape==2:
                axis=rot[:,0];extent=np.abs(axis)*size[0]/2+np.sqrt(np.maximum(0,1-axis**2))*size[1]/2
            elif shape==0:extent=size/2
            else:extent=np.abs(rot)@(size/2)
            lows.append(pos-extent);highs.append(pos+extent)
        OUT.mkdir(exist_ok=True);path=OUT/f'{self.name}.rbxmx';E.indent(root,space='  ');E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=False)
        spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts'/'check-assets.py');checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker);assert not checker.inspect(path,'Items')
        print(self.name,'Attach='+self.attach,'parts='+str(len(self.parts)),'XYZ='+','.join(f'{x:.4f}' for x in np.max(highs,axis=0)-np.min(lows,axis=0)))

def hammer(name,color,style):
    d=Design(name,'hip');y=-.85;z=.62
    d.add('Handle',(1.9,.22,.22),(0,y,z),WOOD,512)
    for i in range(3):d.add(f'GripBand{i+1}',(.14,.255,.255),(-.58+i*.22,y,z),(74,50,35),1312)
    d.add('ButtCap',(.10,.29,.29),(-.98,y,z),color)
    d.add('Head',(0.50,.75,.55),(.95,y,z),color)
    if style==0:
        d.add('CopperStrikeFace',(.55,.085,.60),(.95,y+.4125,z),(208,143,75))
        d.add('CopperHeel',(.53,.07,.58),(.95,y-.41,z),(140,86,45))
        for side in (-1,1):d.add('HeadRivet'+str(side),(.13,.13,.05),(.95,y,z+side*.30),IVORY)
    elif style==1:
        d.add('SteelStrikeFace',(.62,.08,.62),(.95,y+.415,z),(188,194,205))
        for side in (-1,1):d.add('ForgedClaw'+str(side),(.18,.37,.22),(.95+side*.17,y-.51,z),(100,108,120),kind='WedgePart',rot=ry(side*.25))
        d.add('EyePlate',(.21,.28,.055),(.95,y,z-.3025),(75,83,92))
    elif style==2:
        d.add('GoldStrikeFace',(.62,.10,.63),(.95,y+.425,z),(247,217,129))
        d.add('GoldPeen',(.24,.32,.48),(.95,y-.50,z),(189,133,34),kind='WedgePart')
        for side in (-1,1):d.add('Filigree'+str(side),(.37,.09,.045),(.95,y+.18,z+side*.298),IVORY)
        d.add('RoyalSeal',(.20,.20,.055),(.95,y,z-.3025),(163,71,105),rot=rz(math.pi/4))
    else:
        d.add('CrystalStrikeFace',(.58,.16,.62),(.95,y+.445,z),(173,239,255),272)
        for side in (-1,1):d.add('CrystalFacet'+str(side),(.23,.34,.59),(.95+side*.16,y-.44,z),(62,159,202),272,kind='WedgePart',rot=ry(side*math.pi/2))
        d.add('DiamondSeal',(.20,.20,.055),(.95,y,z-.3025),(224,251,255),272,rot=rz(math.pi/4))
        d.add('SilverHeadBand',(.53,.11,.585),(.95,y+.14,z),IVORY)
    d.save()

def staff(id,season,stage):
    name=f'{"season" if season else "weather"}_staff_{id}';d=Design(name,'hand')
    rods=[WOOD,(90,60,110),(60,40,90),GOLD] if season else [WOOD,(60,90,130),(40,70,120),(220,235,250)]
    rodcolor=rods[stage]
    d.rod('Rod',(0,-1.2,0),(0,3.8,0),.25,rodcolor,512)
    for i in range(3):d.rod(f'GripWrap{i+1}',(0,-.13+i*.20,0),(0,-.02+i*.20,0),.29,(64,53,49),1312)
    for label,y in [('LowerCollar',-.65),('UpperCollar',2.92)]:d.rod(label,(0,y-.065,0),(0,y+.065,0),.32,GOLD)
    d.rod('Heel',(0,-1.27,0),(0,-1.12,0),.30,GOLD)
    d.add('HeadSeat',(.60,.15,.60),(0,3.50,0),GOLD)
    d.rod('HeadStem',(0,3.70,0),(0,3.99,0),.19,GOLD)
    if season and stage==0:
        d.ball('SpringBud',.74,(0,4.10,0),(120,230,120))
        for s in (-1,1):d.add('YoungLeaf'+str(s),(.42,.28,.17),(s*.35,3.88,0),(65,155,70),272,kind='WedgePart',rot=rz(s*.34))
    elif season and stage==1:
        d.ball('SummerHeart',.58,(0,4.10,0),(173,239,112))
        for i in range(4):
            a=i*math.pi/2;d.add('BroadLeaf'+str(i),(.38,.50,.17),(.34*math.cos(a),4.10+.34*math.sin(a),0),(72,168,79),272,kind='WedgePart',rot=rz(a-math.pi/2))
    elif season and stage==2:
        d.ball('AutumnHeart',.58,(0,4.10,0),(232,170,63))
        for i in range(5):
            a=i*2*math.pi/5;d.add('AutumnPetal'+str(i),(.32,.48,.16),(.34*math.cos(a),4.10+.34*math.sin(a),0),(185+12*i,83+9*i,48),272,kind='WedgePart',rot=rz(a-math.pi/2))
        d.add('BranchKnot',(.35,.16,.35),(0,3.74,0),(134,87,46))
    elif season:
        d.ball('SeasonHeart',.46,(0,4.10,0),(255,230,120))
        shades=[(103,219,128),(247,201,72),(219,120,63),(160,224,244)]
        for i,color in enumerate(shades):
            a=i*math.pi/2;end=(.46*math.cos(a),4.10+.46*math.sin(a),0)
            d.rod('SeasonBranch'+str(i),(0,4.10,0),end,.09,GOLD);d.ball('SeasonGem'+str(i),.28,end,color)
        d.add('EternalRoot',(.26,.28,.30),(0,3.74,0),IVORY,kind='WedgePart')
    elif stage==0:
        for i,(x,y,diam) in enumerate(((-.28,4.06,.42),(0,4.22,.58),(.28,4.06,.42))):d.ball('CloudLobe'+str(i),diam,(x,y,0),(193,225,247))
        d.add('RainDrop',(.16,.27,.13),(0,3.88,-.14),(82,160,211),272,kind='WedgePart')
    elif stage==1:
        d.ball('MoonHeart',.46,(0,4.10,0),(110,180,255))
        for i in range(5):
            a=math.radians(-65+i*35);pos=(.34*math.cos(a)-.14,4.10+.34*math.sin(a),0)
            d.add('MoonArc'+str(i),(.24,.23,.16),pos,(225,239,251),272,rot=rz(a))
        d.ball('MoonPearl',.16,(-.17,4.10,-.24),(191,227,255))
    elif stage==2:
        d.ball('StormHeart',.49,(0,4.10,0),(73,140,201))
        for i,(x,y,ang) in enumerate(((-.19,4.45,-.45),(.03,4.10,-.45),(.22,3.76,-.45))):d.add('LightningBolt'+str(i),(.23,.50,.20),(x,y,-.21),(251,216,102),272,kind='WedgePart',rot=rz(ang))
        for s in (-1,1):d.add('StormFin'+str(s),(.23,.44,.22),(s*.36,4.08,0),(177,215,242),272,kind='WedgePart',rot=rz(s*.55))
    else:
        d.ball('SunHeart',.55,(0,4.10,0),(200,240,255))
        for i in range(8):
            a=i*math.pi/4;d.add('SunRay'+str(i),(.15,.38,.16),(.36*math.cos(a),4.10+.36*math.sin(a),0),GOLD,kind='WedgePart',rot=rz(a-math.pi/2))
        d.add('SkySeal',(.20,.20,.08),(0,4.10,-.28),(106,175,215),272,rot=rz(math.pi/4))
    d.save()

if __name__=='__main__':
    for n,c,s in [('copper_hammer',(184,115,51),0),('iron_hammer',STEEL,1),('gold_hammer',GOLD,2),('diamond_hammer',(110,220,255),3)]:hammer(n,c,s)
    for season in (True,False):
        for stage,id in enumerate(('1','3','5','inf')):staff(id,season,stage)
