"""Original low-poly arrow. Blender headless; no downloaded geometry or rig edits."""
from pathlib import Path
import math
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def material(name, color, metallic=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = .55
    return result


def build_arrow():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    wood = material("Ash shaft", (.32, .18, .07))
    steel = material("Silver arrowhead", (.70, .77, .80), .55)
    feathers = material("Copper fletching", (.93, .47, .18))
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=.021, depth=.78,
                                      location=(0, -.03, .065), rotation=(math.pi/2, 0, 0))
    shaft = bpy.context.object
    shaft.name = "arrow_shaft"
    shaft.data.materials.append(wood)
    vertices = [(0, .62, .065), (-.075, .33, .065), (0, .37, .105),
                (.075, .33, .065), (0, .37, .025), (0, .30, .065)]
    faces = [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
             (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)]
    mesh = bpy.data.meshes.new("arrowhead")
    mesh.from_pydata(vertices, [], faces)
    head = bpy.data.objects.new("arrowhead", mesh)
    bpy.context.collection.objects.link(head)
    head.data.materials.append(steel)
    for index in range(3):
        angle = index * math.tau / 3
        dx, dz = math.cos(angle), math.sin(angle)
        verts = [(dx*.02, -.42, .065+dz*.02), (dx*.075, -.41, .065+dz*.075),
                 (dx*.07, -.20, .065+dz*.07), (dx*.02, -.16, .065+dz*.02)]
        mesh = bpy.data.meshes.new("feather")
        mesh.from_pydata(verts, [], [(0, 1, 2), (0, 2, 3), (2, 1, 0), (3, 2, 0)])
        feather = bpy.data.objects.new("fletching_%d" % index, mesh)
        bpy.context.collection.objects.link(feather)
        feather.data.materials.append(feathers)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    objects = list(bpy.context.selected_objects)
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    offset = Vector(((min(v.x for v in corners)+max(v.x for v in corners))*.5,
                     (min(v.y for v in corners)+max(v.y for v in corners))*.5,
                     min(v.z for v in corners)))
    for obj in objects:
        obj.location -= offset
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    out = ROOT / "assets/models/bone_arrow.glb"
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                             export_apply=True, export_yup=True, use_selection=True)
    triangles = sum(len(face.vertices)-2 for obj in bpy.context.scene.objects
                    if obj.type == "MESH" for face in obj.data.polygons)
    print(json.dumps({"path": str(out.relative_to(ROOT)), "triangles": triangles,
                      "length": 1.04, "forward": "-Z in Godot", "pivot": "base center"}))


if __name__ == "__main__":
    build_arrow()
