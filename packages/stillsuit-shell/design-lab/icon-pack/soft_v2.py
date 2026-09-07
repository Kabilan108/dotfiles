"""Soft revision 2: original geometry informed by the user's shape references."""
from __future__ import annotations

import math
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from build import Glyph


def draw_soft(name: str, g: Glyph) -> bool:
    """Draw revised silhouettes; return False for shared outline primitives."""
    line, arc, box, disk, rounded = g.line, g.arc, g.box, g.disk, g.rounded

    if name.startswith('battery'):
        # Build the housing and bands upright, then rotate to a right-hand terminal.
        box(6, 4, 12, 17)
        rounded([(10,2),(14,2),(14,4),(10,4)], .65, True)
        if name in ('battery', 'battery-level-full'):
            charge = 1.0
        elif name.startswith('battery-level-'):
            # Representative fill levels for the existing eight shell states.
            charge = [0, .125, .25, .375, .5, .75, .875][int(name[-1])]
        else:
            charge = 0
        for band in range(4):
            fraction = min(1, max(0, charge * 4 - band))
            if fraction:
                bottom = 18.9 - band * 3.35
                height = 2.4 * fraction
                rounded([(8.1,bottom-height),(15.9,bottom-height),(15.9,bottom),(8.1,bottom)], min(.4,height/2), True)
        g.polygons = [[(24-y, x) for x,y in polygon] for polygon in g.polygons]
        symbol_start = len(g.polygons)
        if name == 'battery-charging':
            rounded([(13.4,7),(9,12.9),(12,12.9),(10.6,18),(15,11.6),(12.2,11.6)], .25, True)
        elif name == 'battery-alert':
            line((12,8.5),(12,13)); disk(12,16.5,1)
        elif name == 'battery-question':
            arc(12,10.3,2.2,190,360); arc(12,10.3,2.2,0,65)
            line((12.93,12.29),(12,13),(12,13.5)); disk(12,16.5,1)
        # Keep the bolt and punctuation upright inside the horizontal housing.
        g.polygons[symbol_start:] = [
            [(11.5 + (x-12)*.8, 12 + (y-12.5)*.8) for x,y in polygon]
            for polygon in g.polygons[symbol_start:]
        ]
    elif name in ('wifi', 'network', 'wifi-off'):
        # Broad, low arches and a generous dot, with less vertical sprawl.
        # Split disabled arcs around the slash so the junction stays legible.
        if name == 'wifi-off':
            for r in (13.7,9.5,5.3):
                arc(12,19,r,226,230); arc(12,19,r,251,314)
            line((3.1,3.1),(20.9,20.9))
        else:
            for r in (13.7,9.5,5.3): arc(12,19,r,226,314)
        disk(12,19,1.45)
    elif name == 'cpu':
        box(5.5,5.5,13,13); box(9,9,6,6)
        for position in (8,12,16):
            line((position,2.6),(position,5.5)); line((position,18.5),(position,21.4))
            line((2.6,position),(5.5,position)); line((18.5,position),(21.4,position))
    elif name == 'agent':
        box(3.5,11,17,9.5); arc(12,4.8,2)
        line((12,6.8),(12,11)); disk(8,15.8,1); disk(16,15.8,1)
    elif name == 'memory':
        rounded([(2.5,6),(21.5,6),(21.5,16),(2.5,16)],1.2)
        # Equal 3.2-unit gaps, including the space to the inside housing edges.
        for x in (7,12,17):
            rounded([(x-.9,8.6),(x+.9,8.6),(x+.9,13.4),(x-.9,13.4)],.35,True)
        rounded([(4,15.8),(20,15.8),(20,19),(4,19)],.5,True)
    elif name == 'ethernet':
        # Root and two leaves, rather than an RJ45 socket.
        rounded([(9,2.8),(15,2.8),(15,8.3),(9,8.3)],.8)
        line((12,8.3),(12,11.8)); line((5.5,15),(5.5,11.8),(18.5,11.8),(18.5,15))
        rounded([(2.5,15),(8.5,15),(8.5,20.7),(2.5,20.7)],.8)
        rounded([(15.5,15),(21.5,15),(21.5,20.7),(15.5,20.7)],.8)
    elif name == 'folder':
        rounded([(3,5),(10,5),(12.5,7.2),(21,7.2),(21,19),(3,19)],2.4)
    elif name == 'pause':
        box(5,4,5,16); box(14,4,5,16)
    elif name in ('play','skip-next','skip-previous'):
        if name == 'play':
            rounded([(6.5,3.8),(20,12),(6.5,20.2)],1.6,True)
        else:
            points = [(5.5,5),(16.5,12),(5.5,19)]
            if name == 'skip-previous': points=[(24-x,y) for x,y in points]
            rounded(points,1.2,True)
            x = 19.5 if name=='skip-next' else 4.5
            line((x,5),(x,19))
    elif name == 'copy':
        # Front square at bottom left, interrupted rear square at top right.
        box(3.5,9,11.5,11.5)
        points=[(9,7),(9,5.5)]
        for i in range(13):
            a=math.radians(180+90*i/12); points.append((11+2*math.cos(a),5.5+2*math.sin(a)))
        points.append((18.5,3.5))
        for i in range(13):
            a=math.radians(270+90*i/12); points.append((18.5+2*math.cos(a),5.5+2*math.sin(a)))
        points.append((20.5,13))
        for i in range(13):
            a=math.radians(90*i/12); points.append((18.5+2*math.cos(a),13+2*math.sin(a)))
        points.append((17,15)); line(*points)
    elif name in ('danger','warning'):
        rounded([(12,2.4),(22,20.4),(2,20.4)],4.5)
        line((12,9),(12,13.6)); disk(12,17,1)
    elif name == 'record':
        arc(12,12,9); disk(12,12,5)
    elif name == 'settings':
        # Six rounded teeth connected into a single silhouette.
        points=[]
        for tooth in range(6):
            for offset,radius in ((-30,7.1),(-17,7.1),(-13,9.2),(13,9.2),(17,7.1)):
                a=math.radians(tooth*60-90+offset)
                points.append((12+radius*math.cos(a),12+radius*math.sin(a)))
        rounded(points,.75); arc(12,12,3.15)
    elif name in ('audio','volume-up','volume-down','volume-mute'):
        rounded([(3.5,8.5),(7.5,8.5),(12,5),(12,19),(7.5,15.5),(3.5,15.5)],.8)
        if name in ('audio','volume-up'): arc(11,12,10,-42,42)
        if name!='volume-mute': arc(11,12,5.5,-40,40)
        else:
            line((16,9.5),(21,14.5)); line((21,9.5),(16,14.5))
    elif name == 'delete':
        line((4,7),(20,7)); box(6,7,12,14)
        # Rounded handle and straight walls under one continuous lid.
        arc(11,5,2,180,270); line((11,3),(13,3)); arc(13,5,2,270,360)
        line((9,5),(9,7)); line((15,5),(15,7))
        line((10,11),(10,17)); line((14,11),(14,17))
    elif name in ('lock','unlock'):
        box(5,11,14,10)
        arc(12,8,4.5,180,360 if name=='lock' else 320)
        line((7.5,8),(7.5,11))
        if name=='lock': line((16.5,8),(16.5,11))
        disk(12,15.5,1); line((12,16),(12,17.5))
    elif name in ('forward-10','replay-10'):
        arc(12,13,8.5,-40,284)
        line((12,1.8),(14.05,4.75),(11,5.25))
        if name=='replay-10':
            g.polygons = [[(24-x,y) for x,y in reversed(p)] for p in g.polygons]
        g.width=1.55
        line((7.7,11.3),(9.2,9.8),(9.2,15.8)); box(12,9.8,4,6)
    elif name == 'refresh':
        arc(12,12,7.7,180,315); line((4.3,12),(4.3,14))
        line((1.8,11.5),(4.3,14),(6.8,11.5))
        arc(12,12,7.7,0,135); line((19.7,12),(19.7,10))
        line((17.2,12.5),(19.7,10),(22.2,12.5))
    elif name == 'repeat':
        line((3,5.5),(15.5,5.5)); arc(15.5,11,5.5,270,360)
        line((21,11),(21,13)); line((6,2.5),(3,5.5),(6,8.5))
        line((21,18.5),(8.5,18.5)); arc(8.5,13,5.5,90,180)
        line((3,13),(3,11)); line((18,15.5),(21,18.5),(18,21.5))
    elif name == 'shuffle':
        # Smooth shoulders leading into the crossing diagonals.
        def route(points: list[tuple[float, float]]) -> None:
            outline=[points[0]]
            for i in range(1,len(points)-1):
                x,y=points[i]; prev=points[i-1]; nxt=points[i+1]
                a=math.dist((x,y),prev); b=math.dist((x,y),nxt); trim=min(1,a/2,b/2)
                start=(x+(prev[0]-x)*trim/a,y+(prev[1]-y)*trim/a)
                end=(x+(nxt[0]-x)*trim/b,y+(nxt[1]-y)*trim/b)
                for j in range(13):
                    t=j/12
                    outline.append(((1-t)**2*start[0]+2*(1-t)*t*x+t*t*end[0],(1-t)**2*start[1]+2*(1-t)*t*y+t*t*end[1]))
            line(*outline,points[-1])
        route([(3,6.5),(8,6.5),(16,17.5),(21,17.5)])
        route([(3,17.5),(8,17.5),(16,6.5),(21,6.5)])
        line((18.5,4),(21,6.5),(18.5,9)); line((18.5,15),(21,17.5),(18.5,20))
    elif name == 'vpn':
        rounded([(2,4),(22,4),(22,20),(2,20)],2.5,True)
        holes=len(g.polygons)
        rounded([(3.6,8),(4.9,8),(6.2,13.7),(7.5,8),(8.8,8),(6.9,16),(5.5,16)],.15,True)
        rounded([(9.6,8),(14,8),(14,12.8),(10.9,12.8),(10.9,16),(9.6,16)],.35,True)
        rounded([(15.3,16),(15.3,8),(16.6,8),(19,13.2),(19,8),(20.3,8),(20.3,16),(19,16),(16.6,10.8),(16.6,16)],.15,True)
        # Letter cutouts remain transparent and follow ShellIcon's inherited fill.
        g.polygons[holes:]=[list(reversed(polygon)) for polygon in g.polygons[holes:]]
        rounded([(10.9,9.3),(12.7,9.3),(12.7,11.5),(10.9,11.5)],.3,True)
    else:
        return False
    return True
