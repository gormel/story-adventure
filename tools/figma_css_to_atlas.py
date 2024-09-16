import io
import json
import re

class Stream:
    def __init__(self, buffer: str):
        self.buffer = buffer
        self.position = 0
    
    def look(self, count: int):
        real_count = min(count, len(self.buffer) - self.position - 1)
        return (real_count, self.buffer[self.position:self.position + real_count])

    def look_until(self, substr: str):
        pos = self.position
        while (pos < len(self.buffer) and not self.buffer[pos:].startswith(substr)):
            pos += 1
        
        return (pos - self.position, self.buffer[self.position:pos])
    
    def read(self, count: int):
        real_count = min(count, len(self.buffer) - self.position - 1)

        text = self.buffer[self.position:self.position + real_count]
        self.position += real_count
        return (real_count, text)
    
def skip_empty(stream: Stream):
    (has, letter) = stream.look(1)
    while (has == 1 and letter.isspace()):
        stream.read(1)
        (has, letter) = stream.look(1)

def read_prop_name(stream: Stream):
    skip_empty(stream)
    (count, prop_name) = stream.look_until(":")
    stream.read(count + 1)
    return prop_name

def read_prop_value(stream: Stream):
    skip_empty(stream)
    (count, prop_value) = stream.look_until("\n")
    stream.read(count)
    return prop_value

def read_prop(stream: Stream):
    skip_empty(stream)
    (one, symbol) = stream.look(1)
    if (not symbol.isalpha()):
        return False
    
    return (read_prop_name(stream), read_prop_value(stream))

def read_header(stream: Stream):
    skip_empty(stream)
    (to_start, empty) = stream.look_until("/*")
    if (to_start > 0):
        return False
    stream.read(2)
    skip_empty(stream)
    (to_end, header_value) = stream.look_until("*/")
    stream.read(to_end + 2)
    return header_value.rstrip()

def read_obj(stream: Stream):
    obj = {}
    obj["props"] = {}
    header = read_header(stream)
    if (header == False):
        return False
    obj["header"] = header

    prop = read_prop(stream)
    while (prop != False):
        obj["props"][prop[0]] = prop[1]
        prop = read_prop(stream)

    return obj

def read_objs(stream: Stream):
    objs = []
    obj = read_obj(stream)
    while (obj != False):
        objs.append(obj)
        obj = read_obj(stream)
    
    return objs

def to_px(prop_value: str):
    match = re.match(r'([0-9]+)px', prop_value, re.M | re.I)
    return int(match.group(1))

with io.open('in.txt') as fp:
    source = fp.read()
    stream = Stream(source)
    objs = read_objs(stream)
    
    atlas = {}
    atlas["tex"] = "resources/textures/" + objs[0]["header"] + ".png"
    atlas["sprites"] = []
    atlas["animations"] = []
    
    for obj in objs:
        if ("background" in obj["props"].keys()):
            sprite = {}
            sprite["name"] = obj["header"]
            sprite["x"] = to_px(obj["props"]["left"])
            sprite["y"] = to_px(obj["props"]["top"])
            sprite["w"] = to_px(obj["props"]["width"])
            sprite["h"] = to_px(obj["props"]["height"])
            atlas["sprites"].append(sprite)

            match = re.match("^anm-([a-zA-Z_]+)-([0-9]+(\.[0-9]+)?)-([0-9]+)", sprite["name"])
            if (match != None):
                anim_name = match.group(1)
                frame_idx = int(match.group(4))
                found_anims = [x for x in atlas["animations"] if x["name"] == anim_name]
                if (len(found_anims) == 0):
                    anim = {}
                    anim["name"] = anim_name
                    anim["duration"] = float(match.group(2))
                    anim["frames"] = []
                    atlas["animations"].append(anim)
                    found_anims.append(anim)

                anim = found_anims[0]
                while (len(anim["frames"]) <= frame_idx):
                    anim["frames"].append(None)
                
                anim["frames"][frame_idx] = sprite["name"]
    
    with io.open('out.json', 'w+') as out_fp:
        json.dump(atlas, out_fp)
        out_fp.flush()

print("OK")