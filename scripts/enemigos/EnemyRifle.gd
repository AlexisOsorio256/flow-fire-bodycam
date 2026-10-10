class_name EnemyRifle
extends RefCounted

const SPEED := 900.0
const DROP_KG := 3.2
const SIDEARM_KG := 0.67


static func set_weapon(enemy: Enemy, id: String) -> void:
	enemy.weapon_id = id
	var model: EnemyModel = enemy.model
	if model == null:
		return
	var pistol := model.find_child("Gun", true, false) as Node3D
	if id != "rifle":
		if pistol != null:
			pistol.visible = true
		if enemy.rifle != null:
			enemy.rifle.visible = false
		return
	if pistol != null:
		pistol.visible = false
	if enemy.rifle == null:
		var w := RifleWeapon.new()
		w.name = "Rifle3P"
		if not w.build():
			w.queue_free()
			if pistol != null:
				pistol.visible = true
			enemy.weapon_id = "glock"
			return
		var parent := pistol.get_parent() if pistol != null else model
		parent.add_child(w)
		if pistol != null:
			w.transform = pistol.transform
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = EnemyModel.LAYER_BIT
		enemy.rifle = w
	enemy.rifle.visible = true


static func drop(enemy: Enemy, throw: Vector3) -> void:
	var gun := enemy.model.find_child("Gun", true, false) as Node3D
	if enemy.rifle != null and enemy.rifle.visible:
		var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
		DroppedProp.spawn(enemy.get_tree().current_scene, enemy.rifle, DROP_KG, throw + Vector3(0, 0.6, 0), spin,
			"mag_drop", 24.0)
		enemy.rifle.visible = false
		if gun != null:
			gun.visible = false
		return
	if gun == null or not gun.visible:
		return
	var toss := Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
	DroppedProp.spawn(enemy.get_tree().current_scene, gun, SIDEARM_KG, throw + Vector3(0, 0.6, 0), toss,
		"mag_drop", 24.0)
	gun.visible = false
