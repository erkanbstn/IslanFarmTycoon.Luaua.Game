"""Generate the 15 primitive, avatar-local head and back shop models."""
from pathlib import Path
import base64
import math
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'Items'
FABRIC, WOOD, METAL, PLASTIC = 1312, 512, 1088, 272
GOLD = (255, 200, 60)


def attr_string(name, value):
    n, v = name.encode(), value.encode()
    return base64.b64encode(struct.pack('<II', 1, len(n)) + n + b'\x02' + struct.pack('<I', len(v)) + v).decode()


def rotation(rx=0, ry=0, rz=0):
    x, y, z = map(math.radians, (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    return [[cy*cz, -cy*sz, sy], [cx*sz+sx*sy*cz, cx*cz-sx*sy*sz, -sx*cy], [sx*sz-cx*sy*cz, sx*cz+cx*sy*sz, cx*cy]]


class Builder:
    def __init__(self, name, attach):
        self.name, self.attach, self.parts = name, attach, []
        self.root = ET.Element('roblox', version='4')
        self.model = ET.SubElement(self.root, 'Item', {'class': 'Model', 'referent': name})
        p = ET.SubElement(self.model, 'Properties')
        ET.SubElement(p, 'string', name='Name').text = name
        ET.SubElement(p, 'BinaryString', name='AttributesSerialize').text = attr_string('Attach', attach)
        o = ET.SubElement(p, 'OptionalCoordinateFrame', name='WorldPivotData')
        self.cf(ET.SubElement(o, 'CFrame'), (0, 0, 0), rotation())

    @staticmethod
    def cf(cf, pos, rot):
        for a, v in zip('XYZ', pos): ET.SubElement(cf, a).text = f'{v:.8f}'
        for i in range(3):
            for j in range(3): ET.SubElement(cf, f'R{i}{j}').text = f'{rot[i][j]:.10f}'

    def part(self, name, size, pos, color, material=FABRIC, angle=(0, 0, 0), shape=1, wedge=False):
        if shape == 0: assert max(size)-min(size) < 1e-8
        r = rotation(*angle)
        item = ET.SubElement(self.model, 'Item', {'class': 'WedgePart' if wedge else 'Part', 'referent': f'{self.name}_{len(self.parts)}'})
        p = ET.SubElement(item, 'Properties')
        ET.SubElement(p, 'string', name='Name').text = name
        for n, v in [('Anchored', True), ('Massless', True), ('CanCollide', False), ('CanTouch', False), ('CanQuery', False), ('CastShadow', False)]:
            ET.SubElement(p, 'bool', name=n).text = str(v).lower()
        ET.SubElement(p, 'token', name='Material').text = str(material)
        if not wedge: ET.SubElement(p, 'token', name='Shape').text = str(shape)
        c = ET.SubElement(p, 'Color3', name='Color')
        for a, v in zip('RGB', color): ET.SubElement(c, a).text = str(v/255)
        s = ET.SubElement(p, 'Vector3', name='Size')
        for a, v in zip('XYZ', size): ET.SubElement(s, a).text = str(v)
        self.cf(ET.SubElement(p, 'CoordinateFrame', name='CFrame'), pos, r)
        ET.SubElement(p, 'float', name='Transparency').text = '0'
        self.parts.append((name, size, pos, r))

    def ball(self, name, d, pos, color, material=PLASTIC): self.part(name, (d, d, d), pos, color, material, shape=0)

    def ring(self, name, width, depth, y, h, t, color, material=FABRIC):
        self.part(name+'Front', (width, h, t), (0, y, -depth/2+t/2), color, material)
        self.part(name+'Back', (width, h, t), (0, y, depth/2-t/2), color, material)
        self.part(name+'Left', (t, h, depth-2*t), (-width/2+t/2, y, 0), color, material)
        self.part(name+'Right', (t, h, depth-2*t), (width/2-t/2, y, 0), color, material)

    def brim(self, width, depth, color, curled=False):
        self.part('FrontBrim', (width-.35, .12, (depth-1.35)/2), (0, .57, -(depth+1.35)/4), color)
        self.part('RearBrim', (width-.35, .12, (depth-1.35)/2), (0, .57, (depth+1.35)/4), color)
        for s in (-1, 1): self.part('CurledBrim' if curled else 'SideBrim', ((width-1.85)/2, .14, depth), (s*(width+1.85)/4, .64 if curled else .57, 0), color, angle=(0, 0, s*15 if curled else 0))

    def save(self):
        target = (8, 16) if self.attach == 'head' else (10, 20)
        assert target[0] <= len(self.parts) <= target[1], (self.name, len(self.parts))
        OUT.mkdir(exist_ok=True)
        ET.indent(self.root, space='  ')
        path = OUT / f'{self.name}.rbxmx'
        ET.ElementTree(self.root).write(path, encoding='utf-8', xml_declaration=True)
        r = ET.parse(path).getroot().find('Item')
        encoded = base64.b64decode(r.find("Properties/BinaryString[@name='AttributesSerialize']").text)
        expected = struct.pack('<II', 1, 6) + b'Attach\x02' + struct.pack('<I', len(self.attach)) + self.attach.encode()
        assert encoded == expected and r.find("Properties/Ref[@name='PrimaryPart']") is None
        bounds = []
        for i in range(3):
            bounds.append((min(p[i]-sum(abs(rot[i][j])*size[j]/2 for j in range(3)) for _, size, p, rot in self.parts), max(p[i]+sum(abs(rot[i][j])*size[j]/2 for j in range(3)) for _, size, p, rot in self.parts)))
        print(self.name, len(self.parts), self.attach, 'bounds', tuple(tuple(round(v, 3) for v in a) for a in bounds))


def hats():
    for ident, color, band, width, depth, height in [
        ('farmer_hat', (225,195,110), (170,45,38), 3,3,.75),
        ('cowboy_hat', (130,85,50), (60,40,30), 3.4,2.6,.95),
        ('straw_hat', (232,205,120), (110,150,80), 3.6,3.6,.85)]:
        b = Builder(ident, 'head'); b.brim(width, depth, color, ident == 'cowboy_hat')
        b.ring('HollowCrown', 1.85,1.7,.64+height/2,height,.13,color)
        b.ring('Ribbon',1.89,1.74,.76,.18,.14,band)
        if ident == 'cowboy_hat':
            for s in (-1,1): b.part('CreasedCrownTop',(.94,.16,1.72),(s*.44,1.61,0),color,angle=(0,0,s*13))
        elif ident == 'straw_hat':
            b.part('WovenCrownTop',(1.85,.16,1.7),(0,1.52,0),color)
            b.part('RaisedWeave',(1.45,.11,1.35),(0,1.655,0),(245,221,150))
        else: b.part('CrownTop',(1.85,.18,1.7),(0,1.48,0),color)
        b.part('RibbonBuckle',(.27,.23,.08),(.42,.76,-.91),(195,154,65),METAL)
        b.save()
    b=Builder('flat_cap','head'); blue=(70,90,140)
    b.ring('CapShell',1.92,1.65,.73,.30,.13,blue)
    b.part('SlopedCapTop',(1.93,.28,1.72),(0,.99,-.03),blue,angle=(-9,0,0))
    b.part('ShortVisor',(1.5,.12,.82),(0,.55,-1.04),(50,65,105),angle=(-7,0,0))
    for s in (-1,1): b.part('Seam',(.05,.045,1.43),(s*.42,1.14,-.04),(102,120,163),angle=(-9,0,0))
    b.ball('TopButton',.14,(0,1.18,.15),(50,65,105));b.save()
    b=Builder('chicken_hat','head'); white=(250,250,250)
    b.ring('ChickenShell',1.96,1.8,.88,.55,.15,white)
    b.part('ChickenTop',(1.96,.25,1.8),(0,1.275,0),white)
    for s in (-1,1):
        b.ball('Eye',.21,(s*.57,1.08,-.96),(32,28,26))
        b.part('SideWing',(.19,.32,1.04),(s*1.02,.98,.08),(220,223,226),angle=(0,0,-s*12))
    b.part('Beak',(.50,.25,.54),(0,.76,-1.09),(250,190,50),wedge=True)
    for i in range(3): b.ball('Comb',.40,(0,1.55,-.4+i*.4),(220,50,50))
    b.ball('Wattle',.24,(0,.57,-1.04),(200,42,45));b.save()
    b=Builder('golden_crown','head');b.ring('OpenGoldBand',1.98,1.78,.75,.34,.14,GOLD,METAL)
    for x,z in [(-.82,-.71),(.82,-.71),(-.82,.71),(.82,.71)]:
        b.part('RoyalPoint',(.30,.59,.27),(x,1.20,z),GOLD,METAL,wedge=True)
        b.ball('PointGem',.20,(x,1.57,z),(230,87,69))
    b.part('Crest',(.56,.39,.10),(0,.94,-.91),(221,167,49),METAL)
    b.ball('Ruby',.26,(0,.97,-1.00),(220,40,70));b.save()
    b=Builder('beanie','head');red=(200,60,70)
    b.ring('KnitShell',2.02,1.8,.82,.46,.15,red)
    b.ring('RolledCuff',2.09,1.88,.63,.21,.18,(155,40,54))
    b.part('SoftCapTop',(1.99,.24,1.78),(0,1.16,0),red)
    b.part('GatheredTop',(1.48,.15,1.28),(0,1.345,0),(221,77,85))
    b.ball('PomPom',.55,(0,1.69,0),(250,250,250))
    for s in (-1,1): b.part('KnitRib',(.04,.38,.055),(s*.55,.90,-.93),(227,96,100))
    b.save()
    b=Builder('flower_crown','head');b.ring('VineRing',2.04,1.78,.64,.16,.13,(90,160,80),WOOD)
    for i,(x,z) in enumerate([(-.84,-.73),(.84,-.73),(-.84,.73),(.84,.73)]):
        b.ball('FlowerPetals',.39,(x,.83,z),(240,120,150) if i in (0,3) else (250,215,90))
        b.ball('FlowerCenter',.13,(x,.94,z-.15),(255,240,158))
        b.part('Leaf',(.30,.12,.13),(x+(.16 if x<0 else -.16),.74,z),(77,132,63),angle=(0,0,25 if x<0 else -25),wedge=True)
    b.save()


def straps(b, color=(83,57,38)):
    for s in (-1,1): b.part('ShoulderStrap',(.14,1.66,.12),(s*.53,.62,.55),color,angle=(0,0,-s*5))


def backs():
    b=Builder('backpack','back'); brown=(130,90,55)
    b.part('PackBody',(1.58,1.8,.70),(0,.35,.97),brown)
    b.part('RoundedLid',(1.65,.34,.76),(0,1.42,.97),(100,70,45),wedge=True)
    b.part('FrontPocket',(1.02,.62,.20),(0,.15,1.42),(158,110,65))
    b.part('PocketFlap',(1.05,.16,.22),(0,.54,1.44),(92,63,43))
    straps(b)
    for s in (-1,1):
        b.part('SidePouch',(.25,.88,.58),(s*.86,.10,.99),(100,70,45))
        b.part('LeatherFastener',(.10,1.45,.07),(s*.51,.58,1.36),(67,45,31))
        b.part('Buckle',(.19,.20,.09),(s*.51,.94,1.43),(185,148,66),METAL)
    for s in (-1,1): b.part('HandleLeg',(.12,.24,.13),(s*.25,1.65,.94),brown)
    b.part('CarryHandle',(.62,.12,.13),(0,1.80,.94),brown);b.save()
    b=Builder('red_cape','back')
    for i in range(4):
        x=(i-1.5)*.53
        b.part('CapeFold',(.56,2.8,.075),(x,-.1,.80+(.06 if i%2 else 0)),(190-i*6,40,50),angle=(8,0,(-1 if i<2 else 1)*3))
    for s in (-1,1):
        b.part('ShoulderMantle',(.65,.22,.23),(s*.55,1.27,.68),(138,28,43),angle=(0,0,s*12))
        b.part('BorderBraid',(.07,2.64,.08),(s*1.0,-.09,1.05),(221,151,62),angle=(8,0,s*3))
        b.part('HemBinding',(.91,.13,.10),(s*.50,-1.49,1.02),(221,151,62))
    b.part('CapeClasp',(.28,.22,.10),(0,1.28,.85),GOLD,METAL);b.save()
    for ident,golden in [('angel_wings',False),('golden_wings',True)]:
        b=Builder(ident,'back');base=GOLD if golden else (250,250,255);shade=(222,161,52) if golden else (205,216,230)
        straps(b,(117,82,39) if golden else (198,207,221))
        b.part('WingHarness',(.95,.42,.19),(0,.88,.72),shade,METAL if golden else FABRIC)
        for s in (-1,1):
            b.part('WingRoot',(.46,1.24,.22),(s*.69,.85,.90),shade,angle=(0,0,-s*24))
            for i in range(5):
                x=s*(.83+i*(.27 if golden else .22));y=.82-i*.20;length=1.5+i*.13+(.38 if golden else 0)
                b.part('FlightFeather',(.38 if golden else .32,length,.14),(x,y,1.06+i*.015),base,METAL if golden else FABRIC,angle=(0,0,-s*(20+i*9 if golden else 16+i*9)),wedge=True)
            for i in range(2): b.part('WingCovert',(.40,.82,.18),(s*(.98+i*.31),1.04-i*.18,1.19),shade,angle=(0,0,-s*(24+i*17)),wedge=True)
        b.save()
    b=Builder('harvest_basket','back'); straw=(150,105,60)
    b.part('BasketFloor',(1.78,.14,.96),(0,-.47,1.04),straw,WOOD)
    for s in (-1,1):
        b.part('BasketSide',(.14,1.20,.96),(s*.82,.18,1.04),straw,WOOD)
        b.part('WovenRimSide',(.17,.13,1.04),(s*.82,.83,1.04),(191,145,83),WOOD)
    for s in (-1,1):
        b.part('BasketWall',(1.64,1.20,.14),(0,.18,1.04+s*.41),straw,WOOD)
        b.part('WovenRim',(1.80,.13,.17),(0,.83,1.04+s*.41),(191,145,83),WOOD)
    straps(b)
    for i in range(3):
        x=(i-1)*.38; y=1.30+(.10 if i==1 else 0)
        b.part('WheatStem',(.07,.95,.07),(x,y-.29,1.03),(199,163,73),WOOD,angle=(0,0,(i-1)*-12))
        b.part('WheatEar',(.19,.50,.16),(x,y+.32,1.03),(235,200,90),FABRIC,wedge=True)
    b.ball('HarvestApple',.37,(-.45,.94,1.30),(195,56,39))
    b.ball('HarvestSquash',.42,(.45,.96,1.23),(231,151,38))
    b.part('CarryLoop',(.70,.15,.15),(0,1.08,.66),straw,WOOD);b.save()
    b=Builder('leaf_cloak','back')
    for i in range(3): b.part('CloakFold',(.74,2.8,.08),((i-1)*.70,-.1,.85),(63+i*12,131+i*9,62),angle=(9,0,0))
    for s in (-1,1):
        b.part('ShoulderLeaf',(.70,.25,.15),(s*.53,1.27,.76),(108,168,75),angle=(0,0,-s*20),wedge=True)
        for i in range(3): b.part('LayeredLeaf',(.63,.87,.13),(s*(.42+i*.12),.82-i*.78,1.02+i*.10),(120-i*13,190-i*15,100-i*12),angle=(8,0,-s*(18+i*3)),wedge=True)
    for i in range(3): b.part('LeafVein',(.05,.63,.06),(0,.80-i*.77,1.07+i*.12),(173,190,96),angle=(8,0,0))
    b.ball('AcornClasp',.22,(0,1.26,.88),(166,115,55),WOOD);b.save()
    b=Builder('peacock_tail','back');straps(b,(56,99,88))
    b.part('TailRoot',(.72,.45,.28),(0,-.22,.77),(43,110,92))
    for i in range(5):
        angle=(i-2)*-22;rad=math.radians(angle);length=2.45 if abs(i-2)==2 else 2.95 if abs(i-2)==1 else 3.3
        x=-math.sin(rad)*length*.46;y=-.15+math.cos(rad)*length*.46
        color=[(40,170,160),(50,130,200),(60,200,130),(50,130,200),(40,170,160)][i]
        b.part('FanFeather',(.47,length,.14),(x,y,.86),color,angle=(0,0,angle),wedge=True)
        tx=-math.sin(rad)*length*.91;ty=-.15+math.cos(rad)*length*.91
        b.ball('FeatherTip',.47,(tx,ty,.86),color)
        b.ball('FeatherEye',.28,(tx,ty,.66),(218,182,56),METAL)
    b.ball('TailBrooch',.24,(0,-.20,1.00),(51,93,142));b.save()


if __name__ == '__main__':
    hats()
    backs()
