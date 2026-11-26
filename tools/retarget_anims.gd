extends SceneTree

## Retargets the Y Bot fighter AnimationLibrary onto each Meshy-rigged character.
## Writes res://assets/anims/fighter_anims_<id>.res per res://assets/characters/<id>/<id>.glb.
## Run: godot --headless --path . --script res://tools/retarget_anims.gd [-- id ...]

const SRC_LIB := "res://assets/anims/fighter_anims.res"
const SRC_RIG := "res://assets/third_party/mixamo/y-bot/Y Bot.fbx"
const CHAR_DIR := "res://assets/characters/"
const OUT := "res://assets/anims/fighter_anims_%s.res"
const FPS := 30.0

## Meshy bone -> Y Bot bone. Meshy's spine is numbered top-down (Spine02 sits on the hips).
const MAP := {
	"Hips": "mixamorig_Hips",
	"Spine02": "mixamorig_Spine",
	"Spine01": "mixamorig_Spine1",
	"Spine": "mixamorig_Spine2",
	"neck": "mixamorig_Neck",
	"Head": "mixamorig_Head",
	"LeftShoulder": "mixamorig_LeftShoulder",
	"LeftArm": "mixamorig_LeftArm",
	"LeftForeArm": "mixamorig_LeftForeArm",
	"LeftHand": "mixamorig_LeftHand",
	"RightShoulder": "mixamorig_RightShoulder",
	"RightArm": "mixamorig_RightArm",
	"RightForeArm": "mixamorig_RightForeArm",
	"RightHand": "mixamorig_RightHand",
	"LeftUpLeg": "mixamorig_LeftUpLeg",
	"LeftLeg": "mixamorig_LeftLeg",
	"LeftFoot": "mixamorig_LeftFoot",
	"LeftToeBase": "mixamorig_LeftToeBase",
	"RightUpLeg": "mixamorig_RightUpLeg",
	"RightLeg": "mixamorig_RightLeg",
	"RightFoot": "mixamorig_RightFoot",
	"RightToeBase": "mixamorig_RightToeBase",
}
## Bone whose rest direction (head -> child head) is matched between rigs before retargeting.
## Bones without a usable child borrow the aim correction of the bone named here.
const AIM_CHILD := {
	"Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head",
	"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
	"RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
	"RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
}
const AIM_BORROW := {
	"LeftHand": "LeftForeArm", "RightHand": "RightForeArm",
	"LeftToeBase": "LeftFoot", "RightToeBase": "RightFoot",
}


class Rig:
	var root: Node3D
	var sk: Skeleton3D
	var path: String
	var to_root: Transform3D
	var rot: Quaternion
	var order: PackedInt32Array
	var rest_global: Array[Quaternion] = []
	var rest_pos: Array[Vector3] = []

	func _init(scene: PackedScene) -> void:
		root = scene.instantiate() as Node3D
		sk = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		path = String(root.get_path_to(sk))
		var c: Node = sk
		while c != root:
			to_root = (c as Node3D).transform * to_root
			c = c.get_parent()
		rot = to_root.basis.get_rotation_quaternion()
		var n := sk.get_bone_count()
		var done := {}
		while order.size() < n:
			for b in n:
				var p := sk.get_bone_parent(b)
				if not done.has(b) and (p < 0 or done.has(p)):
					order.append(b)
					done[b] = true
		rest_global.resize(n)
		rest_pos.resize(n)
		for b in n:
			var g := to_root * sk.get_bone_global_rest(b)
			rest_global[b] = g.basis.get_rotation_quaternion()
			rest_pos[b] = g.origin

	func id(bone: String) -> int:
		return sk.find_bone(bone)


func _init() -> void:
	var src_lib := load(SRC_LIB) as AnimationLibrary
	var src := Rig.new(load(SRC_RIG) as PackedScene)
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		for d in DirAccess.get_directories_at(CHAR_DIR):
			if FileAccess.file_exists("%s%s/%s.glb" % [CHAR_DIR, d, d]):
				ids.append(d)
	var failed := false
	for cid in ids:
		var glb := "%s%s/%s.glb" % [CHAR_DIR, cid, cid]
		var tgt := Rig.new(load(glb) as PackedScene)
		for bone: String in MAP:
			if tgt.id(bone) < 0 or src.id(MAP[bone]) < 0:
				push_error("%s: missing bone %s / %s" % [cid, bone, MAP[bone]])
				failed = true
		var aim := _aim_corrections(src, tgt)
		var lib := AnimationLibrary.new()
		for clip in src_lib.get_animation_list():
			lib.add_animation(clip, _retarget(src_lib.get_animation(clip), src, tgt, aim))
		var out := OUT % cid
		var err := ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS)
		print("%-9s %d clips -> %s err=%d (hips %.3f m vs src %.3f m)" % [cid, lib.get_animation_list().size(), out, err, tgt.rest_pos[0].y, src.rest_pos[0].y])
		failed = failed or err != OK
		tgt.root.free()
	src.root.free()
	quit(1 if failed else 0)


## Per target bone: the rotation that swings its rest direction onto the source bone's.
func _aim_corrections(src: Rig, tgt: Rig) -> Dictionary:
	var aim := {}
	for bone: String in AIM_CHILD:
		var child: String = AIM_CHILD[bone]
		var dt := tgt.rest_pos[tgt.id(child)] - tgt.rest_pos[tgt.id(bone)]
		var ds := src.rest_pos[src.id(MAP[child])] - src.rest_pos[src.id(MAP[bone])]
		aim[bone] = Quaternion(dt.normalized(), ds.normalized())
	for bone: String in AIM_BORROW:
		aim[bone] = aim[AIM_BORROW[bone]]
	return aim


func _retarget(a: Animation, src: Rig, tgt: Rig, aim: Dictionary) -> Animation:
	var src_rot := {}
	var hips_pos := -1
	for i in a.get_track_count():
		var b := src.id(String(a.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			src_rot[b] = i
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D and b == 0:
			hips_pos = i

	var out := Animation.new()
	out.length = a.length
	out.step = 1.0 / FPS
	out.loop_mode = a.loop_mode
	for m in a.get_meta_list():
		out.set_meta(m, a.get_meta(m))

	var tracks := {}
	for bone: String in MAP:
		var ti := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(ti, NodePath("%s:%s" % [tgt.path, bone]))
		tracks[tgt.id(bone)] = ti
	var hips_t := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_t, NodePath("%s:Hips" % tgt.path))

	var hips_scale := tgt.rest_pos[0].y / src.rest_pos[0].y
	var src_hips_rest := src.sk.get_bone_rest(0).origin
	var tgt_hips_rest := tgt.sk.get_bone_rest(tgt.id("Hips")).origin
	var tgt_inv := tgt.to_root.basis.inverse()
	var src_basis := src.to_root.basis

	var map_ids := {}
	for bone: String in MAP:
		map_ids[tgt.id(bone)] = [src.id(MAP[bone]), aim.get(bone, Quaternion.IDENTITY)]

	var frames := int(round(a.length * FPS)) + 1
	var gs: Array[Quaternion] = []
	gs.resize(src.sk.get_bone_count())
	var gt: Array[Quaternion] = []
	gt.resize(tgt.sk.get_bone_count())
	for f in frames:
		var t := minf(f / FPS, a.length)
		for b in src.order:
			var local := a.rotation_track_interpolate(src_rot[b], t) if src_rot.has(b) else src.sk.get_bone_rest(b).basis.get_rotation_quaternion()
			var p := src.sk.get_bone_parent(b)
			gs[b] = (gs[p] if p >= 0 else src.rot) * local
		for b in tgt.order:
			var p := tgt.sk.get_bone_parent(b)
			var parent_g: Quaternion = gt[p] if p >= 0 else tgt.rot
			if map_ids.has(b):
				var s: int = map_ids[b][0]
				var delta := gs[s] * src.rest_global[s].inverse()
				gt[b] = delta * (map_ids[b][1] as Quaternion) * tgt.rest_global[b]
				out.rotation_track_insert_key(tracks[b], t, (parent_g.inverse() * gt[b]).normalized())
			else:
				gt[b] = parent_g * tgt.sk.get_bone_rest(b).basis.get_rotation_quaternion()
		var hp := a.position_track_interpolate(hips_pos, t) if hips_pos >= 0 else src_hips_rest
		var offset := tgt_inv * (src_basis * (hp - src_hips_rest) * hips_scale)
		out.position_track_insert_key(hips_t, t, tgt_hips_rest + offset)
	return out
