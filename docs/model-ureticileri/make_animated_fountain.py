"""Stepped stone fountain, authored geometry only. Water motion is a persistent effect."""
from pathlib import Path
import math
import xml.etree.ElementTree as E

root=E.Element('roblox',version='4')
E.SubElement(root,'Meta',name='ExplicitAutoJoints').text='true'
model=E.SubElement(root,'Item',{'class':'Model','referent':'RBX_FOUNTAIN'})
props=E.SubElement(model,'Properties')
E.SubElement(props,'string',name='Name').text='Fountain'

def cf(parent,tag,name,pos,matrix):
 n=E.SubElement(parent,tag,name=name)
 for key,value in zip(['X','Y','Z']+[f'R{r}{c}'for r in range(3)for c in range(3)],list(pos)+list(matrix)):
  E.SubElement(n,key).text=str(value)
 return n

identity=[1,0,0,0,1,0,0,0,1]
vertical=[0,-1,0,1,0,0,0,0,1]
pivot=E.SubElement(props,'OptionalCoordinateFrame',name='WorldPivotData')
cf(pivot,'CFrame','unused',(0,0,0),identity).attrib.clear()
count=0

def part(name,size,pos,color,material=912,shape=1,rotation=None,solid=True,transparency=0):
 global count
 count+=1
 item=E.SubElement(model,'Item',{'class':'Part','referent':f'RBX_FOUNTAIN_{count}'})
 p=E.SubElement(item,'Properties')
 E.SubElement(p,'string',name='Name').text=name
 vector=E.SubElement(p,'Vector3',name='Size')
 for axis,value in zip('XYZ',size):E.SubElement(vector,axis).text=str(value)
 cf(p,'CoordinateFrame','CFrame',pos,rotation or identity)
 c=E.SubElement(p,'Color3',name='Color')
 for axis,value in zip('RGB',color):E.SubElement(c,axis).text=str(value/255)
 E.SubElement(p,'token',name='Material').text=str(material)
 E.SubElement(p,'token',name='Shape').text=str(shape)
 for key,value in {'Anchored':True,'CanCollide':solid,'CanQuery':solid,'CanTouch':False,'CastShadow':solid}.items():
  E.SubElement(p,'bool',name=key).text=str(value).lower()
 E.SubElement(p,'float',name='Transparency').text=str(transparency)
 if name in ('Water','TopWater'):E.SubElement(p,'float',name='Reflectance').text='.025'

stone=(209,200,176)
dark=(142,145,137)
edge=(224,215,190)
water=(99,196,213)
bronze=(133,105,61)
part('Foundation',(.30,8.5,8.5),(0,.15,0),dark,800,2,vertical)
part('Basin',(.26,7.9,7.9),(0,.43,0),stone,912,2,vertical)
part('BasinFloor',(.18,7.05,7.05),(0,.64,0),edge,912,2,vertical)
for i in range(8):
 a=i*math.pi/4
 rotation=[math.cos(a),0,math.sin(a),0,1,0,-math.sin(a),0,math.cos(a)]
 pos=(math.sin(a)*3.6,.94,math.cos(a)*3.6)
 part('BasinWall',(2.98,.84,.42),pos,stone,912,rotation=rotation)
 part('BasinCoping',(3.02,.20,.60),(pos[0],1.46,pos[2]),edge,912,rotation=rotation)
part('Water',(.10,6.86,6.86),(0,.94,0),water,1568,2,vertical,False,.32)
part('PillarFoot',(.24,1.90,1.90),(0,.86,0),dark,800,2,vertical)
part('Pillar',(2.52,1.12,1.12),(0,2.24,0),stone,912,2,vertical)
part('PillarCapital',(.22,1.62,1.62),(0,3.54,0),edge,912,2,vertical)
part('UpperBowl',(.40,3.20,3.20),(0,3.85,0),edge,912,2,vertical)
part('TopWater',(.08,2.80,2.80),(0,4.09,0),water,1568,2,vertical,False,.30)
part('Finial',(.44,.72,.72),(0,4.35,0),bronze,1088,2,vertical)
part('MainJetNozzle',(.20,.12,.20),(0,4.62,0),bronze,1088,solid=False)
for i in range(4):
 a=i*math.pi/2
 rotation=[math.cos(a),0,math.sin(a),0,1,0,-math.sin(a),0,math.cos(a)]
 part(f'Spout{i+1}',(.28,.18,.52),(math.sin(a)*1.50,4.0,math.cos(a)*1.50),bronze,1088,rotation=rotation,solid=False)

E.indent(root,space='  ')
path=Path(__file__).resolve().parents[2]/'assets/HubProps/Fountain.rbxmx'
E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
print('Fountain:',count,'parts, ground pivot, width8.5; stone solid/water decor noncollide')
