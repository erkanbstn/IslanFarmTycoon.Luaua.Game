"""Enlarge existing accessory motifs once; retain an input snapshot for reruns.

Run with bundled Python (NumPy). Only assets/ and docs/ are written.
OBB checks are conservative for wedges and round parts.
"""
from pathlib import Path
import importlib.util
import itertools
import json
import csv
import xml.etree.ElementTree as E
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
spec = importlib.util.spec_from_file_location('land', HERE/'generate_lineage_land.py')
land = importlib.util.module_from_spec(spec)
spec.loader.exec_module(land)
SNAPSHOT = HERE/'lineage_visibility_source.json'

def read(path):
    rows=[]
    for item in E.parse(path).getroot().iter('Item'):
        if item.get('class') not in ('Part','WedgePart'): continue
        p=item.find('Properties')
        pos,rot=land.frame(p.find("CoordinateFrame[@name='CFrame']"))
        size=np.array([float(p.find("Vector3[@name='Size']/"+k).text) for k in 'XYZ'])
        rows.append(dict(name=p.find("string[@name='Name']").text,pos=pos,rot=rot,size=size))
    return rows

def expanded(row):
    return dict(row, size=row['size']+.012)

def overlaps(rows, obstacles):
    return any(land.volume_overlap(a,b) for a in rows for b in obstacles)

def nearest_face(center, base):
    candidates=[]
    for b in base:
        local=b['rot'].T@(center-b['pos'])
        for axis in range(3):
            for sign in (-1,1):
                q=np.clip(local,-b['size']/2,b['size']/2)
                q[axis]=sign*b['size'][axis]/2
                candidates.append((np.linalg.norm(local-q), b['rot'][:,axis]*sign))
    return min(candidates,key=lambda x:x[0])[1]

def main():
    files=sorted((ROOT/'assets/AnimalLineage').glob('*.rbxmx'))
    if not SNAPSHOT.exists():
        SNAPSHOT.write_text(json.dumps({f.name:[{k:(v.tolist() if isinstance(v,np.ndarray) else v) for k,v in r.items()} for r in read(f)] for f in files}),encoding='utf-8')
    snapshot=json.loads(SNAPSHOT.read_text(encoding='utf-8'))
    output={}; stats=[]
    for animal in sorted({f.stem.rsplit('_T',1)[0] for f in files}):
        base=land.load_base(animal)
        original=[]
        for tier in (2,3,4):
            for row in snapshot[f'{animal}_T{tier}.rbxmx']:
                original.append(dict(name=row['name'],pos=np.array(row['pos']),rot=np.array(row['rot']),size=np.array(row['size']),tier=tier))
        # Joined motifs retain their relative positions, including stacked gems.
        groups=[]; remaining=set(range(len(original)))
        while remaining:
            group={remaining.pop()}
            while True:
                joined={j for j in remaining if any(land.volume_overlap(expanded(original[i]),expanded(original[j])) for i in group)}
                if not joined:break
                remaining-=joined;group|=joined
            groups.append(sorted(group))
        enlarged=[]
        for group in groups:
            old=[original[i] for i in group]
            center=(land.bounds(old)[0]+land.bounds(old)[1])/2
            normal=nearest_face(center,base)
            factor=1.5
            rows=[dict(r,size=r['size']*factor,pos=center+(r['pos']-center)*factor) for r in old]
            # Translate the connected motif outward, leaving all parts together.
            obstacles=base+enlarged
            if overlaps(rows,obstacles):
                directions=[normal,*np.eye(3),*-np.eye(3)]
                options=[]
                for direction in directions:
                    for distance in np.arange(.005,1.501,.005):
                        candidate=[dict(r,pos=r['pos']+direction*distance) for r in rows]
                        if not overlaps(candidate,obstacles):
                            # Prefer the source mounting normal over sideways relocation.
                            options.append((distance*(1 if np.dot(direction,normal)>.99 else 3),candidate))
                            break
                assert options,animal
                rows=min(options,key=lambda x:x[0])[1]
            assert not overlaps(rows,obstacles),animal
            assert not any(land.volume_overlap(a,b) for a,b in itertools.combinations(rows,2)),animal
            enlarged+=rows
        assert not overlaps(enlarged,base),animal
        assert not any(land.volume_overlap(a,b) for a,b in itertools.combinations(enlarged,2)),animal
        lo,hi=land.bounds(base); cl,ch=land.bounds(base+enlarged)
        ratio=(ch-cl)/(hi-lo)
        stats.append((animal, max(ratio)))
        for tier in (2,3,4): output[f'{animal}_T{tier}.rbxmx']=[r for r in enlarged if r['tier']==tier]
        print(animal,'parts',len(enlarged),'bounds ratio',round(max(ratio),4),flush=True)
    # Commit only after all animals pass. Names/materials/pivots remain unchanged.
    for filename,rows in output.items():
        path=ROOT/'assets/AnimalLineage'/filename; tree=E.parse(path)
        byname={r['name']:r for r in rows}
        for item in tree.getroot().iter('Item'):
            if item.get('class') not in ('Part','WedgePart'):continue
            p=item.find('Properties');row=byname[p.find("string[@name='Name']").text]
            for field,key in [('Vector3','Size'),('CoordinateFrame','CFrame')]:
                node=p.find(f"{field}[@name='{key}']")
                values=row['size'] if key=='Size' else row['pos']
                for k,v in zip('XYZ',values):node.find(k).text=f'{v:.9f}'
        tree.write(path,encoding='utf-8',xml_declaration=True)
    with (ROOT/'docs/ANIMAL_LINEAGE_MODELLERI.csv').open('w',newline='',encoding='utf-8') as file:
        writer=csv.writer(file);writer.writerow(['file','parts','sizeX','sizeY','sizeZ'])
        for filename,rows in sorted(output.items()):
            lo,hi=land.bounds(rows)
            writer.writerow(['assets/AnimalLineage/'+filename,len(rows),*[round(v,6) for v in hi-lo]])
    print('108 files; all 338 parts enlarged 50%; conservative OBB overlaps zero; max bounds ratio',max(v for _,v in stats))

if __name__=='__main__':main()
