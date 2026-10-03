"""Validate shop XML and render primitive contact sheets for visual review.

Standalone geometry preview, not a Roblox rendering or live avatar test.
Run using the bundled Python runtime; PNGs are temporary output.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import struct, base64, re, csv, math, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]

def read(path):
    model=E.parse(path).getroot().find('Item');p=model.find('Properties')
    data=base64.b64decode(p.find("BinaryString[@name='AttributesSerialize']").text)
    assert struct.unpack_from('<I',data)[0]==1
    n=struct.unpack_from('<I',data,4)[0];assert data[8:8+n]==b'Attach'
    offset=8+n;assert data[offset]==2
    length=struct.unpack_from('<I',data,offset+1)[0]
    attach=data[offset+5:offset+5+length].decode();assert offset+5+length==len(data)
    pivot=p.find("OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
    assert pivot is not None and all(abs(float(pivot.find(k).text))<1e-7 for k in 'XYZ')
    assert p.find("Ref[@name='PrimaryPart']") is None
    parts=[]
    for item in model.iter('Item'):
        cls=item.get('class'); assert cls in ('Model','Part','WedgePart'),(path,cls)
        if cls=='Model':continue
        p=item.find('Properties');cf=p.find("CoordinateFrame[@name='CFrame']")
        size=np.array([float(p.find("Vector3[@name='Size']/"+k).text) for k in 'XYZ'])
        pos=np.array([float(cf.find(k).text) for k in 'XYZ'])
        rot=np.array([[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])
        assert np.allclose(rot.T@rot,np.eye(3),atol=1e-6)
        for name in ('CanCollide','CanQuery','CanTouch','CastShadow'):assert p.find(f"bool[@name='{name}']").text=='false'
        assert p.find("bool[@name='Massless']").text=='true'
        shape=int(p.find("token[@name='Shape']").text) if cls=='Part' else 3
        if shape==0:assert max(size)-min(size)<1e-6
        color=np.array([float(p.find("Color3[@name='Color']/"+k).text)*255 for k in 'RGB'])
        parts.append(dict(size=size,pos=pos,rot=rot,shape=shape,color=color))
    assert 6<=len(parts)<= (16 if attach=='head' else 14 if attach in ('chest','hip') else 20),(path,len(parts))
    return attach,parts

def geometry(part):
    x,y,z=part['size']/2
    shape=part['shape']
    if shape==2:
        verts=[(sign*x,y*math.cos(a*math.pi/8),z*math.sin(a*math.pi/8)) for sign in (-1,1) for a in range(16)]
        faces=[list(range(16)),list(range(16,32))]+[[j,(j+1)%16,(j+1)%16+16,j+16] for j in range(16)]
    elif shape==3:
        verts=[(-x,-y,-z),(x,-y,-z),(-x,-y,z),(x,-y,z),(-x,y,z),(x,y,z)]
        faces=[[0,1,3,2],[2,3,5,4],[0,2,4],[1,3,5],[0,1,5,4]]
    else:
        verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        faces=[[0,1,2,3],[4,5,6,7],[0,1,5,4],[2,3,7,6],[0,3,7,4],[1,2,6,5]]
    verts=np.array(verts)@part['rot'].T+part['pos']
    return verts,faces

def render(group,out):
    width=360;height=320;cols=4;rows=math.ceil(len(group)/cols)
    img=Image.new('RGB',(cols*width,rows*height),(229,234,237));draw=ImageDraw.Draw(img)
    direction=np.array((4,3,-6),float);direction/=np.linalg.norm(direction)
    right=np.cross(np.array((0,1,0)),direction);right/=np.linalg.norm(right)
    up=np.cross(direction,right);transform=np.stack((right,-up,direction))
    for index,(path,attach,parts) in enumerate(group):
        px=index%cols*width;py=index//cols*height
        draw.rectangle((px+5,py+5,px+width-5,py+height-5),fill=(248,247,242))
        draw.text((px+15,py+12),path.stem,fill=(35,40,45))
        draw.text((px+15,py+30),f'{attach} / {len(parts)} parts',fill=(90,95,100))
        transformed=[]
        for part in parts:
            verts,faces=geometry(part);transformed.append((part,verts@transform.T,faces))
        points=np.concatenate([x[1] for x in transformed]);lo=points.min(0);hi=points.max(0)
        scale=min((width-60)/(hi[0]-lo[0]),(height-95)/(hi[1]-lo[1]));center=(lo+hi)/2
        polygons=[]
        for part,verts,faces in transformed:
            if part['shape']==0:
                c=part['pos']@transform.T;radius=part['size'].min()/2*scale
                xy=(c[:2]-center[:2])*scale+np.array((px+width/2,py+height/2+20))
                polygons.append((c[2], 'ball', (xy,radius),tuple(part['color'].astype(int))))
                continue
            for j,face in enumerate(faces):
                faceverts=verts[face];xy=(faceverts[:,:2]-center[:2])*scale+np.array((px+width/2,py+height/2+20))
                color=tuple(np.clip(part['color']*(.76+.045*(j%5)),0,255).astype(int))
                polygons.append((faceverts[:,2].mean(),'polygon',xy,color))
        for depth,kind,coords,color in sorted(polygons,key=lambda x:x[0]):
            if kind=='ball':
                xy,r=coords;draw.ellipse((xy[0]-r,xy[1]-r,xy[0]+r,xy[1]+r),fill=color)
            else:draw.polygon([tuple(x) for x in coords],fill=color)
    img.save(out)

def main():
    text=(ROOT/'src/shared/Config/Items.luau').read_text(encoding='utf-8-sig')
    config={id:slot for id,slot in re.findall(r'id = "(\w+)".*?slot = "(\w+)"',text,re.S)}
    mapping={'tool':'hip','staff':'hand','charm':'chest','head':'head','back':'back'}
    found={p.stem:p for p in (ROOT/'assets/Items').glob('*.rbxmx')}
    assert found.keys()==config.keys(),('missing',config.keys()-found.keys(),'extra',found.keys()-config.keys())
    groups={'tools':[],'charms':[],'wearables':[]};total=0
    with (ROOT/'docs/ITEM_MODEL_TESLIMI.csv').open('w',newline='',encoding='utf-8') as file:
        writer=csv.writer(file);writer.writerow(['id','attach','parts','sizeX','sizeY','sizeZ'])
        for id in config:
            path=found[id];attach,parts=read(path);assert attach==mapping[config[id]]
            group='tools' if attach in ('hip','hand') else 'charms' if attach=='chest' else 'wearables'
            groups[group].append((path,attach,parts));total+=len(parts)
            bounds=np.concatenate([geometry(p)[0] for p in parts]);size=np.ptp(bounds,axis=0)
            writer.writerow([id,attach,len(parts),*[round(v,5) for v in size]])
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    for name,group in groups.items():render(group,out/(name+'.png'))
    print('38 models,',total,'parts; coverage, Attach, pivots, budget, rotations, physics, equal Ball checks pass')
    print(out)

if __name__=='__main__':main()
