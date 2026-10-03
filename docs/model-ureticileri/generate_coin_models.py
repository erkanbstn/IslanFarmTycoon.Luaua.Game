"""Three readable gold coin props; origin is each cluster's motion center."""
from pathlib import Path
import importlib.util
import math
import xml.etree.ElementTree as E
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'client-assets'/'Coin'
GOLD=(228,169,49)
FACE=(251,207,83)
STAMP=(255,238,166)

def rz(angle):
    c,s=math.cos(angle),math.sin(angle)
    return np.array(((c,-s,0),(s,c,0),(0,0,1)))

def ry(angle):
    c,s=math.cos(angle),math.sin(angle)
    return np.array(((c,0,s),(0,1,0),(-s,0,c)))

def frame(parent,name,pos,rot,pivot=False):
    node=E.SubElement(parent,'OptionalCoordinateFrame' if pivot else 'CoordinateFrame',name=name)
    if pivot:node=E.SubElement(node,'CFrame')
    for a,v in zip('XYZ',pos):E.SubElement(node,a).text=f'{v:.8f}'
    for i in range(3):
        for j in range(3):E.SubElement(node,f'R{i}{j}').text=f'{rot[i,j]:.8f}'

def produce(name,coins,bottom=False):
    parts=[]
    def add(label,size,pos,rot,color,shape):
        parts.append((label,np.array(size),np.array(pos),rot,color,shape))
    for i,(diameter,thickness,pos,orientation) in enumerate(coins,1):
        pos=np.array(pos);discrot=orientation@rz(math.pi/2)
        # Cylinder length is X: rotated 90 degrees around Z for horizontal coins.
        add(f'Edge_{i}',(thickness,diameter,diameter),pos,discrot,GOLD,2)
        face=.008
        add(f'Face_{i}',(face,diameter*.79,diameter*.79),pos+orientation@np.array((0,thickness/2+face/2,0)),discrot,FACE,2)
        add(f'Seal_{i}',(diameter*.18,.012,diameter*.18),pos+orientation@np.array((0,thickness/2+face+.006,0)),orientation@ry(math.pi/4),STAMP,1)
        if bottom:
            add('Face_Bottom',(face,diameter*.79,diameter*.79),pos+orientation@np.array((0,-thickness/2-face/2,0)),discrot,FACE,2)
            add('Seal_Bottom',(diameter*.18,.012,diameter*.18),pos+orientation@np.array((0,-thickness/2-face-.006,0)),orientation@ry(math.pi/4),STAMP,1)
    assert len(parts)<=12
    r=E.Element('roblox',version='4');E.SubElement(r,'Meta',name='ExplicitAutoJoints').text='true'
    m=E.SubElement(r,'Item',{'class':'Model','referent':'RBXMODEL'});p=E.SubElement(m,'Properties');E.SubElement(p,'string',name='Name').text=name;frame(p,'WorldPivotData',np.zeros(3),np.eye(3),True)
    for i,(label,size,pos,rot,color,shape) in enumerate(parts,1):
        item=E.SubElement(m,'Item',{'class':'Part','referent':f'RBXPART{i}'});p=E.SubElement(item,'Properties');E.SubElement(p,'string',name='Name').text=label
        vec=E.SubElement(p,'Vector3',name='Size')
        for a,v in zip('XYZ',size):E.SubElement(vec,a).text=f'{v:.8f}'
        frame(p,'CFrame',pos,rot);col=E.SubElement(p,'Color3',name='Color')
        for a,v in zip('RGB',color):E.SubElement(col,a).text=str(v/255)
        E.SubElement(p,'token',name='Shape').text=str(shape);E.SubElement(p,'token',name='Material').text='1088';E.SubElement(p,'float',name='Reflectance').text='.05'
        for key in ('Anchored','CanCollide','CanQuery','CanTouch','CastShadow'):E.SubElement(p,'bool',name=key).text='true' if key=='Anchored' else 'false'
    OUT.mkdir(parents=True,exist_ok=True);path=OUT/f'{name}.rbxmx';E.indent(r,space='  ');E.ElementTree(r).write(path,encoding='utf-8',xml_declaration=False)
    spec=importlib.util.spec_from_file_location('checker',ROOT/'scripts'/'check-assets.py');checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
    assert not checker.inspect(path,'client/Coin')
    # Exact analytic cylinder AABB: axial projection + perpendicular radial extent.
    lows=[];highs=[]
    for label,size,pos,rot,color,shape in parts:
        if shape==2:
            axis=rot[:,0];extent=np.abs(axis)*size[0]/2+np.sqrt(np.maximum(0,1-axis**2))*size[1]/2
        else:extent=np.abs(rot)@(size/2)
        lows.append(pos-extent);highs.append(pos+extent)
    print(name,len(parts),'XYZ',np.round(np.max(highs,axis=0)-np.min(lows,axis=0),5))

if __name__=='__main__':
    produce('Coin_Small',[(.65,.10,(0,0,0),np.eye(3))],True)
    produce('Coin_Stack',[(.64,.09,(x,(i-1.5)*.11,z),np.eye(3)) for i,(x,z) in enumerate(((-.07,-.03),(.06,.06),(-.02,-.08),(.08,.02)))])
    produce('CoinBurst_Chunk',[(.38,.075,(-.28,.025,-.06),rz(math.radians(-22))),(.38,.075,(.03,-.055,.18),rz(math.radians(18))),(.38,.075,(.27,.055,-.10),rz(math.radians(32)))])
