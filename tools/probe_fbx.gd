extends SceneTree

const FILES := [
	"res://assets/third_party/mixamo/x-bot/X Bot.fbx",
	"res://assets/third_party/mixamo/y-bot/Y Bot.fbx",
	"res://assets/third_party/mixamo-library/animations/cross_punch__c9c7f89ab96c11e4a8020aaa78deedf9_inplace.fbx",
	"res://assets/third_party/mixamo-library/animations/spin_flip_kick__c9caafaab96c11e4a8020aaa78deedf9.fbx",
	"res://assets/third_party/rapa-motion/animefanpackfreebies01/Mixamo/AS_Anime_Rasengan_Attack_Ybot.fbx",
]


func _init() -> void:
	for f in FILES:
		print("==== ", f)
		var ps: PackedScene = load(f)
		var root := ps.instantiate()
		_dump(root, 0)
		var ap := _find(root, "AnimationPlayer") as AnimationPlayer
		if ap:
			for n in ap.get_animation_list():
				var a := ap.get_animation(n)
				print("  anim '%s' len=%.3f tracks=%d loop=%d" % [n, a.length, a.get_track_count(), a.loop_mode])
				for i in mini(a.get_track_count(), 4):
					print("    ", a.track_get_type(i), " ", a.track_get_path(i))
		var sk := _find(root, "Skeleton3D") as Skeleton3D
		if sk:
			print("  bones=", sk.get_bone_count(), " first=", sk.get_bone_name(0), " hips_rest=", sk.get_bone_rest(0).origin, " scale=", sk.global_transform.basis.get_scale() if sk.is_inside_tree() else sk.transform.basis.get_scale())
		root.free()
	quit()


func _dump(n: Node, depth: int) -> void:
	if depth > 4:
		return
	var extra := ""
	if n is Node3D:
		extra = " pos=%s scale=%s" % [(n as Node3D).position, (n as Node3D).scale]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra += " surfaces=%d" % (mi.mesh.get_surface_count() if mi.mesh else 0)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				extra += " mat%d=%s" % [s, m.resource_name if m else "null"]
	print("  ".repeat(depth + 1), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_dump(c, depth + 1)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
