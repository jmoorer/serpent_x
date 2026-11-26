extends SceneTree

## Bakes the Mixamo / Rapa FBX clips into one AnimationLibrary for the fighter rig.
## Run: godot --headless --path . --script res://tools/build_anim_library.gd

const OUT := "res://assets/anims/fighter_anims.res"
const MIX := "res://assets/third_party/mixamo-library/animations/"
const RAPA := "res://assets/third_party/rapa-motion/animefanpackfreebies01/Mixamo/"
const RIG := "res://assets/third_party/mixamo/y-bot/Y Bot.fbx"
const FPS := 30.0
const LIMBS := ["mixamorig_RightHand", "mixamorig_LeftHand", "mixamorig_RightFoot", "mixamorig_LeftFoot"]

# name: [dir, file prefix, mode, a, b]
#   loop   -> whole clip, looped
#   once   -> whole clip
#   range  -> crop [a, b] seconds
#   strike -> auto impact; crop [impact - a, impact + b]
const CLIPS := {
	"idle_turtle": [MIX, "bouncing_fight_idle", "loop"],
	"idle_fight": [MIX, "fight_idle", "loop"],
	"idle_fighting": [MIX, "fighting_idle", "loop"],
	"idle_ginga": [MIX, "capoeira", "loop"],
	"walk_f": [MIX, "walking__093f", "loop"],
	"walk_b": [MIX, "walking-backwards__44b5", "loop"],
	"walk_l": [MIX, "left-strafe-walking", "loop"],
	"walk_r": [MIX, "right-strafe-walking", "loop"],
	"block": [MIX, "standing-block-idle", "loop"],
	"dizzy": [MIX, "dizzy-idle", "loop"],
	"air": [MIX, "falling_idle", "loop"],
	"victory": [MIX, "victory-idle", "loop"],
	"charge": [RAPA, "AS_Anime_Mudra_Pose_02_Rabbit_Ybot", "loop"],
	"seal": [RAPA, "AS_Anime_Mudra_Pose_01_Ox_Ybot", "once"],
	"dash_f": [MIX, "standing_dodge_forward", "once"],
	"dash_b": [MIX, "dodging_back", "once"],
	"dash_l": [MIX, "standing_dodge_left", "once"],
	"dash_r": [MIX, "standing_dodge_right", "once"],
	"hit_light": [MIX, "head_hit", "once"],
	"hit_heavy": [MIX, "hit_reaction", "once"],
	"block_hit": [MIX, "standing-block-react-large", "once"],
	"fall": [MIX, "falling-back-death", "once"],
	"getup": [MIX, "getting-up", "range", 2.8, 6.2],
	"death": [MIX, "death__", "once"],
	"taunt": [MIX, "fist-pump", "once"],
	"hop": [MIX, "forward_jump", "once"],
	"jab": [MIX, "punching__c9c5f7", "strike", 0.2, 0.45, "H"],
	"jab2": [MIX, "punching__c9c5fa", "strike", 0.2, 0.45, "H"],
	"cross": [MIX, "cross_punch", "strike", 0.22, 0.5, "H"],
	"hook": [MIX, "hook__c9cb0f", "strike", 0.28, 0.5, "H"],
	"hook2": [MIX, "hook__c9cb13", "strike", 0.28, 0.5, "H"],
	"right_hook": [MIX, "right_hook", "strike", 0.28, 0.5, "H"],
	"elbow": [MIX, "elbow_punch", "strike", 0.25, 0.5, "H"],
	"elbow_back": [MIX, "illegal-elbow-punch__4963", "strike", 0.3, 0.55, "H"],
	"jab_elbow": [MIX, "jab_to_elbow_punch", "strike", 0.35, 0.5, "H"],
	"uppercut": [MIX, "uppercut__", "strike", 0.3, 0.6, "U"],
	"uppercut_jab": [MIX, "uppercut-jab", "strike", 0.35, 0.6, "H"],
	"roundhouse": [MIX, "roundhouse_kick__c9c63d", "strike", 0.35, 0.6, "F"],
	"roundhouse2": [MIX, "roundhouse_kick__c9c7fc", "strike", 0.35, 0.6, "F"],
	"mma_kick": [MIX, "mma_kick__c9cd28", "strike", 0.35, 0.6, "F"],
	"mma_kick2": [MIX, "mma_kick__c9cd38", "strike", 0.35, 0.6, "F"],
	"crescent": [MIX, "inside_crescent_kick", "strike", 0.4, 0.6, "F"],
	"knee": [MIX, "illegal_knee", "strike", 0.3, 0.55, "F"],
	"knee_lead": [MIX, "knee_kick_lead", "strike", 0.3, 0.55, "F"],
	"spin_flip": [MIX, "spin_flip_kick__c9caafaa", "strike", 0.5, 0.8, "F"],
	"spin_flip2": [MIX, "spin-flip-kick__52bd", "strike", 0.5, 0.8, "F"],
	"flying_kick": [MIX, "flying_kick", "strike", 0.4, 0.6, "F"],
	"armada": [MIX, "armada", "strike", 0.45, 0.6, "F"],
	"martelo": [MIX, "martelo_3", "strike", 0.4, 0.6, "F"],
	"meia_lua": [MIX, "meia_lua_de_frente", "strike", 0.45, 0.6, "F"],
	"compasso": [MIX, "meia_lua_de_compasso", "strike", 0.5, 0.7, "F"],
	"chapa_gira": [MIX, "chapa_giratoria_2", "strike", 0.45, 0.6, "F"],
	"chapa": [MIX, "chapa_2", "strike", 0.35, 0.6, "F"],
	"bencao": [MIX, "bencao", "strike", 0.35, 0.6, "F"],
	"palm_blast": [MIX, "standing_2h_magic_attack_02", "strike", 0.55, 0.7, "H"],
	"palm_blast3": [MIX, "standing_2h_magic_attack_03", "strike", 0.55, 0.7, "H"],
	"palm_blast5": [MIX, "standing_2h_magic_attack_05", "strike", 0.55, 0.7, "H"],
	"magic_1h": [MIX, "standing_1h_magic_attack_01", "strike", 0.45, 0.6, "H"],
	"area_burst": [MIX, "standing-2h-magic-area-attack-01", "strike", 0.6, 0.7, "H"],
	"rasengan": [RAPA, "AS_Anime_Rasengan_Attack_Ybot", "strike", 0.7, 0.8, "H"],
	"chidori": [RAPA, "AS_Anime_Chidori_Attack_02_Ybot", "strike", 0.7, 0.8, "H"],
	"rasengan_hit": [RAPA, "AS_Anime_Rasengan_Hit_Ybot", "once"],
}

var _rig: Node3D
var _sk: Skeleton3D


func _init() -> void:
	_rig = (load(RIG) as PackedScene).instantiate() as Node3D
	_sk = _rig.get_node("Skeleton3D") as Skeleton3D

	var lib := AnimationLibrary.new()
	var report := PackedStringArray()
	for clip_name: String in CLIPS:
		var spec: Array = CLIPS[clip_name]
		var path := _find_file(spec[0], spec[1])
		if path.is_empty():
			push_error("missing source for %s (%s)" % [clip_name, spec[1]])
			continue
		var src := _source_anim(path)
		if src == null:
			push_error("no animation in %s" % path)
			continue
		var mode: String = spec[2]
		var full := _resample(src, 0.0, src.length)
		var from := 0.0
		var to := full.length
		var impact := -1.0
		var limb := ""
		match mode:
			"range":
				from = spec[3]
				to = minf(spec[4], full.length)
			"strike":
				var res := _find_impact(full, spec[5] == "F", spec[5] == "U")
				impact = res[0]
				limb = res[1]
				from = maxf(impact - float(spec[3]), 0.0)
				to = minf(impact + float(spec[4]), full.length)
		var out := full if (from <= 0.0 and to >= full.length) else _crop(full, from, to)
		out.loop_mode = Animation.LOOP_LINEAR if mode == "loop" else Animation.LOOP_NONE
		if impact >= 0.0:
			out.set_meta(&"impact", impact - from)
			out.set_meta(&"limb", limb)
		lib.add_animation(StringName(clip_name), out)
		report.append("%-14s src=%5.2fs out=%5.2fs impact=%5.2f (raw %5.2f) limb=%s" % [clip_name, src.length, out.length, (impact - from) if impact >= 0.0 else -1.0, impact, limb])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("\n".join(report))
	print("saved %s (%d clips) err=%d" % [OUT, lib.get_animation_list().size(), err])
	_rig.free()
	quit()


func _find_file(dir: String, prefix: String) -> String:
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and f.get_extension().to_lower() == "fbx":
			return dir + f
	return ""


func _source_anim(path: String) -> Animation:
	var scene := (load(path) as PackedScene).instantiate()
	var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var best: Animation
	if ap:
		for n in ap.get_animation_list():
			var a := ap.get_animation(n)
			if best == null or a.length > best.length:
				best = a
	scene.free()
	return best


func _bone_of(path: NodePath) -> String:
	var bone := String(path.get_concatenated_subnames())
	if bone.is_empty():
		return ""
	if not bone.begins_with("mixamorig_"):
		bone = "mixamorig_" + bone.trim_prefix("mixamorig:")
	return bone


## Keeps hips position (pinned in XZ) + bone rotations, resampled at FPS.
func _resample(src: Animation, from: float, to: float) -> Animation:
	var out := Animation.new()
	out.length = to - from
	out.step = 1.0 / FPS
	var frames := int(ceil(out.length * FPS)) + 1
	for i in src.get_track_count():
		var bone := _bone_of(src.track_get_path(i))
		if bone.is_empty() or _sk.find_bone(bone) < 0:
			continue
		var t := src.track_get_type(i)
		if t == Animation.TYPE_ROTATION_3D:
			var ti := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(ti, NodePath("Skeleton3D:" + bone))
			for f in frames:
				var tt := minf(f / FPS, out.length)
				out.rotation_track_insert_key(ti, tt, src.rotation_track_interpolate(i, from + tt))
		elif t == Animation.TYPE_POSITION_3D and bone == "mixamorig_Hips":
			var ti := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(ti, NodePath("Skeleton3D:" + bone))
			for f in frames:
				var tt := minf(f / FPS, out.length)
				var p := src.position_track_interpolate(i, from + tt)
				out.position_track_insert_key(ti, tt, Vector3(0.0, p.y, 0.0))
	return out


func _crop(full: Animation, from: float, to: float) -> Animation:
	var out := Animation.new()
	out.length = to - from
	out.step = 1.0 / FPS
	var frames := int(ceil(out.length * FPS)) + 1
	for i in full.get_track_count():
		var t := full.track_get_type(i)
		var ti := out.add_track(t)
		out.track_set_path(ti, full.track_get_path(i))
		for f in frames:
			var tt := minf(f / FPS, out.length)
			if t == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(ti, tt, full.rotation_track_interpolate(i, from + tt))
			else:
				out.position_track_insert_key(ti, tt, full.position_track_interpolate(i, from + tt))
	return out


## Impact = time the striking limb reaches furthest forward (+Z, Mixamo facing).
## Kicks also score foot height so roundhouses peak at contact, not on the step-in.
func _find_impact(anim: Animation, feet: bool, upward: bool = false) -> Array:
	var rot_tracks := {}
	var hips_pos_track := -1
	for i in anim.get_track_count():
		var bone := _sk.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot_tracks[bone] = i
		elif bone == 0:
			hips_pos_track = i
	var limb_ids: Array[int] = []
	for limb: String in LIMBS:
		limb_ids.append(_sk.find_bone(limb))
	var base := PackedFloat32Array([0, 0, 0, 0])
	var peak := PackedFloat32Array([-INF, -INF, -INF, -INF])
	var peak_t := PackedFloat32Array([0, 0, 0, 0])
	var t := 0.0
	while t <= anim.length:
		var g := _global_pose(anim, t, rot_tracks, hips_pos_track)
		var hips_o: Vector3 = (g[0] as Transform3D).origin
		for k in 4:
			if (k >= 2) != feet:
				continue
			var o: Vector3 = (g[limb_ids[k]] as Transform3D).origin
			var reach: float = o.z - hips_o.z
			if feet:
				reach += o.y
			elif upward:
				reach = o.y - hips_o.y
			if t == 0.0:
				base[k] = reach
			if reach > peak[k]:
				peak[k] = reach
				peak_t[k] = t
		t += 1.0 / 60.0
	var best := 2 if feet else 0
	for k in 4:
		if (k >= 2) == feet and peak[k] - base[k] > peak[best] - base[best]:
			best = k
	return [peak_t[best], String(LIMBS[best]).trim_prefix("mixamorig_")]


func _global_pose(anim: Animation, t: float, rot_tracks: Dictionary, hips_pos_track: int) -> Array:
	var n := _sk.get_bone_count()
	var out := []
	out.resize(n)
	for b in n:
		var rest := _sk.get_bone_rest(b)
		var basis := rest.basis
		if rot_tracks.has(b):
			basis = Basis(anim.rotation_track_interpolate(rot_tracks[b], t))
		var origin := rest.origin
		if b == 0 and hips_pos_track >= 0:
			origin = anim.position_track_interpolate(hips_pos_track, t)
		var local := Transform3D(basis, origin)
		var parent := _sk.get_bone_parent(b)
		out[b] = local if parent < 0 else (out[parent] as Transform3D) * local
	return out
