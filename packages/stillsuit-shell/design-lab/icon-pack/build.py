"""Build the Soft icon pack as fill-only SVGs plus a self-contained review page."""
from pathlib import Path
import json
import math
import re
import shutil
import sys

from soft_v2 import draw_soft

ROOT = Path(__file__).resolve().parent
SHELL_ICON = (ROOT / '../../src/ui/ShellIcon.qml').resolve()
PRODUCTION = (ROOT / '../../src/ui/icons').resolve()
SOURCES = ROOT / 'sources'
CATALOG = re.findall(r'"([a-z0-9-]+)"', SHELL_ICON.read_text().split('return [')[1].split(']')[0])


def number(value: float) -> str:
    text = f'{value:.2f}'.rstrip('0').rstrip('.')
    return '0' if text in ('-0', '') else text


class Glyph:
    width = 1.8

    def __init__(self) -> None:
        self.polygons: list[list[tuple[float, float]]] = []

    def solid(self, points: list[tuple[float, float]]) -> None:
        area = sum(x*b-a*y for (x,y),(a,b) in zip(points, points[1:]+points[:1]))
        self.polygons.append(points if area >= 0 else list(reversed(points)))

    def disk(self, x: float, y: float, r: float) -> None:
        n = 24
        self.solid([(x + r * math.cos(i * 2 * math.pi / n), y + r * math.sin(i * 2 * math.pi / n)) for i in range(n)])

    def line(self, *points: tuple[float, float]) -> None:
        r = self.width / 2
        for (x, y), (a, b) in zip(points, points[1:]):
            d = math.hypot(a-x, b-y)
            if not d:
                continue
            u, v = -(b-y)*r/d, (a-x)*r/d
            self.solid([(x+u,y+v),(a+u,b+v),(a-u,b-v),(x-u,y-v)])
        for i, point in enumerate(points):
            if 0 < i < len(points) - 1 and self._joint(points[i-1], point, points[i+1], r):
                continue
            self.disk(*point, r)

    # Between two nearly collinear segments the quads leave a notch shallower
    # than 0.01 units; a wedge on each side covers it with 6 points instead of
    # a 24-point disk. Sharper turns and terminals keep the round cap.
    def _joint(self, previous: tuple[float, float], point: tuple[float, float], following: tuple[float, float], r: float) -> bool:
        (px, py), (x, y), (fx, fy) = previous, point, following
        d1, d2 = math.hypot(x-px, y-py), math.hypot(fx-x, fy-y)
        if not d1 or not d2:
            return False
        n1 = (-(y-py)*r/d1, (x-px)*r/d1)
        n2 = (-(fy-y)*r/d2, (fx-x)*r/d2)
        cosine = ((x-px)*(fx-x) + (y-py)*(fy-y)) / (d1*d2)
        if cosine < math.cos(math.radians(15)):
            return False
        for sign in (1, -1):
            self.solid([(x, y), (x+sign*n1[0], y+sign*n1[1]), (x+sign*n2[0], y+sign*n2[1])])
        return True

    def arc(self, x: float, y: float, r: float, start: float = 0, end: float = 360) -> None:
        steps = max(2, int(abs(end-start)/12))
        self.line(*[(x+r*math.cos(math.radians(start+(end-start)*i/steps)), y+r*math.sin(math.radians(start+(end-start)*i/steps))) for i in range(steps+1)])

    def rounded(self, points: list[tuple[float, float]], radius: float, filled: bool = False) -> None:
        outline: list[tuple[float, float]] = []
        for i, (x, y) in enumerate(points):
            previous, following = points[i-1], points[(i+1) % len(points)]
            a, b = math.dist((x,y), previous), math.dist((x,y), following)
            trim = min(radius, a / 2, b / 2)
            start = (x + (previous[0]-x)*trim/a, y + (previous[1]-y)*trim/a)
            end = (x + (following[0]-x)*trim/b, y + (following[1]-y)*trim/b)
            for j in range(13):
                t = j / 12
                outline.append(((1-t)**2*start[0]+2*(1-t)*t*x+t*t*end[0],
                                (1-t)**2*start[1]+2*(1-t)*t*y+t*t*end[1]))
        if filled:
            self.solid(outline)
        else:
            self.line(*outline, outline[0])

    def box(self, x: float, y: float, w: float, h: float) -> None:
        self.rounded([(x,y),(x+w,y),(x+w,y+h),(x,y+h)], min(2.2,w/2,h/2))

    def svg(self) -> str:
        d = ''.join('M' + ' '.join(self._vertices(p)) + 'Z' for p in self.polygons)
        return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="{d}"/></svg>'

    @staticmethod
    def _vertices(polygon: list[tuple[float, float]]) -> list[str]:
        vertices: list[str] = []
        for x, y in polygon:
            vertex = f'{number(x)},{number(y)}'
            if vertex != (vertices[-1] if vertices else None):
                vertices.append(vertex)
        if len(vertices) > 1 and vertices[0] == vertices[-1]:
            vertices.pop()
        return vertices


def draw(name: str) -> str:
    source = SOURCES / f'{name}.svg'
    if source.exists():
        return source.read_text().strip()
    g = Glyph()
    if draw_soft(name, g):
        return g.svg()
    L, A, B, D = g.line, g.arc, g.box, g.disk
    if name == 'bluetooth': L((7,7),(17,16),(12,21),(12,3),(17,8),(7,17))
    elif name == 'brightness':
        A(12,12,4)
        for i in range(8):
            a = i*math.pi/4; L((12+7*math.cos(a),12+7*math.sin(a)),(12+9*math.cos(a),12+9*math.sin(a)))
    elif name in ('check','success'):
        if name=='success': A(12,12,9)
        L((7,12),(10.5,15.5),(17,9))
    elif name == 'info': A(12,12,9); D(12,7,1); L((12,11),(12,17))
    elif name == 'circle': D(12,12,7)
    elif name == 'add': L((5,12),(19,12)); L((12,5),(12,19))
    elif name == 'close': L((6,6),(18,18)); L((18,6),(6,18))
    elif name in ('chevron-left','chevron-right','expand-less','expand-more'):
        pts={'chevron-left':[(14,6),(8,12),(14,18)],'chevron-right':[(10,6),(16,12),(10,18)],'expand-less':[(6,14),(12,8),(18,14)],'expand-more':[(6,10),(12,16),(18,10)]}; L(*pts[name])
    elif name=='edit': L((4,16),(16,4),(20,8),(8,20),(3,21),(4,16)); L((13,7),(17,11))
    elif name=='headphones': A(12,12,8,180,360); B(4,12,4,8); B(16,12,4,8)
    elif name=='microphone': B(9,3,6,12); A(12,11,7,0,180); L((12,18),(12,21)); L((8,21),(16,21))
    elif name=='more':
        for y in (5,12,19): D(12,y,1.5)
    elif name=='power': A(12,12,9,-55,235); L((12,2),(12,11))
    elif name=='search': A(10,10,6.5); L((15,15),(21,21))
    else: raise ValueError(name)
    return g.svg()


def main(argv: list[str]) -> None:
    folder = ROOT / 'soft'
    folder.mkdir(exist_ok=True)
    pack = {}
    for name in CATALOG:
        svg = draw(name)
        (folder / f'{name}.svg').write_text(svg+'\n')
        pack[name] = svg
    template = (ROOT / 'gallery.template.html').read_text()
    (ROOT / 'index.html').write_text(template.replace('__PACKS__',json.dumps({'soft': pack})))
    print(f'Built {len(CATALOG)} icons into {folder.relative_to(ROOT)} and index.html')
    if '--install' in argv:
        for name in CATALOG:
            shutil.copyfile(folder / f'{name}.svg', PRODUCTION / f'{name}.svg')
        print(f'Installed {len(CATALOG)} icons into {PRODUCTION}')


if __name__ == '__main__':
    main(sys.argv[1:])
