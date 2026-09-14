"""Original low-poly reliquary props. Blender 4/5, headless, no external inputs."""
import bpy
import math
import os
import json
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models")
RENDER = os.path.join(ROOT, "screenshots/ember")
os.makedirs(OUT, exist_ok=True)
os.makedirs(RENDER, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = .65
    shader.inputs["Metallic"].default_value = metallic
    return mat


stone = material("Midnight basalt", (.12, .19, .22))
edge = material("Carved blue stone", (.25, .33, .35))
gold = material("Antique brass", (.64, .39, .12), .65)
dark = material("Blackened iron", (.035, .055, .065), .6)
ember = material("Amber crystal", (1, .32, .055), .25)


def cube(name, location, scale, mat, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Chiselled edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, z, radius, depth, mat, vertices=8, r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                   radius2=radius if r2 is None else r2,
                                   depth=depth, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("Edge light", "BEVEL")
    mod.width = .018
    mod.segments = 1
    obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
    return obj


def make_altar():
    cylinder("octagonal_plinth", .10, .87, .20, stone)
    cylinder("plinth_brass_edge", .225, .78, .05, gold)
    cylinder("stepped_base", .32, .72, .14, edge, r2=.56)
    cylinder("pedestal", .60, .43, .45, stone, r2=.36)
    cylinder("collar", .84, .51, .10, gold)
    cylinder("bowl", 1.02, .48, .28, edge, r2=.70)
    cylinder("bowl_lip", 1.18, .73, .07, gold)
    cylinder("coal_bed", 1.205, .58, .06, dark, vertices=12)
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 4
        x, y = math.cos(angle) * .56, math.sin(angle) * .56
        obj = cube("crown_prong", (x, y, 1.4), (.08, .08, .48), gold, .012)
        obj.rotation_euler = (math.sin(angle) * .22, -math.cos(angle) * .22, angle)
    cylinder("ember_core", 1.43, .20, .45, ember, vertices=5, r2=.02)
    for i in range(8):
        angle = i * math.pi / 4
        obj = cube("pedestal_inlay", (math.sin(angle) * .395, math.cos(angle) * .395, .59),
                   (.07, .045, .27), gold, .005)
        obj.rotation_euler.z = -angle


def make_crown():
    cylinder("seal_base", .045, 1.0, .09, stone, vertices=48)
    cylinder("seal_rim", .101, .93, .025, gold, vertices=48)
    cylinder("seal_face", .122, .86, .026, stone, vertices=48)
    for i in range(12):
        a = i * math.pi / 6
        obj = cube("sunray", (math.sin(a) * .63, math.cos(a) * .63, .146),
                   (.035, .22, .012), gold, 0)
        obj.rotation_euler.z = -a
    for x in [-.21, 0, .21]:
        cube("crown_point", (x, 0, .149), (.055, .35 if x == 0 else .26, .014), gold, 0)
    cube("crown_base", (0, -.17, .149), (.48, .055, .014), gold, 0)


def export_model(name, builder):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    builder()
    for obj in list(bpy.context.scene.objects):
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        if obj.type == "MESH":
            for mod in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True,
                              export_yup=True, export_animations=False)
    tri_count = sum(len(p.vertices) - 2 for obj in bpy.context.scene.objects
                    if obj.type == "MESH" for p in obj.data.polygons)
    print(f"MODEL {name}: {tri_count} triangles")
    return tri_count


triangles = {}
triangles["ember_altar"] = export_model("ember_altar", make_altar)
triangles["crown_seal"] = export_model("crown_seal", make_crown)
# A combined inspection render with physical lighting.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
make_altar()
for obj in list(bpy.context.scene.objects):
    obj.location.x -= 1.2
before = set(bpy.context.scene.objects)
make_crown()
for obj in set(bpy.context.scene.objects) - before:
    obj.location.x += 1.2
cube("studio_floor", (0, 0, -.08), (200, 200, .1), stone, 0)
world = bpy.context.scene.world or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.18, .23, .30, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .5
for location, power, color, size in [
    ((1, -3, 7), 1100, (1, .79, .49), 5),
    ((-4, 0, 4), 900, (.40, .72, 1), 4),
]:
    bpy.ops.object.light_add(type="AREA", location=location)
    lamp = bpy.context.object
    lamp.data.energy, lamp.data.color, lamp.data.shape, lamp.data.size = power, color, "DISK", size
    lamp.rotation_euler = (Vector((0, 0, .6)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add(location=(4, -6, 5))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, .65)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 5.2
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 20
scene.render.resolution_x, scene.render.resolution_y = 1000, 700
scene.render.resolution_percentage = 100
scene.render.filepath = os.path.join(RENDER, "props.png")
bpy.ops.render.render(write_still=True)
with open(os.path.join(ROOT, "tools/ember_prop_metrics.json"), "w") as f:
    json.dump(triangles, f, indent=2)
