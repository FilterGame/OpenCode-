class_name BattleView
extends Node2D

const Entities = preload("res://scripts/battle/entities.gd")

const UNIT_SCENE = preload("res://scenes/battle/unit_visual.tscn")
const BUILDING_SCENE = preload("res://scenes/battle/building_visual.tscn")
const SPELL_SCENE = preload("res://scenes/battle/spell_visual.tscn")
const PROJECTILE_SCENE = preload("res://scenes/battle/projectile_visual.tscn")
const PARTICLE_SCENE = preload("res://scenes/battle/particle_visual.tscn")

var arena_size = Vector2.ZERO
var bridge_y = 0.0

var _object_nodes: Dictionary = {}
var _tower_nodes: Dictionary = {}
var _particle_nodes: Dictionary = {}


func configure_arena(arena_bounds: Vector2, bridge_center_y: float) -> void:
	arena_size = arena_bounds
	bridge_y = bridge_center_y


func on_tower_spawned(player_id: int, tower: Variant) -> void:
	var key = _tower_key(player_id, tower)
	if key.is_empty():
		return
	if tower.is_destroyed or tower.hp <= 0.0:
		_remove_tower_node(key)
		return
	var node: Node2D = _tower_nodes.get(key)
	if node == null:
		node = _create_visual_node("building")
		if node == null:
			return
		node.name = "Tower_%s" % key
		add_child(node)
		_tower_nodes[key] = node
	node.bind_to_object(_extract_object_id(tower), tower, player_id)


func on_tower_updated(player_id: int, tower: Variant) -> void:
	if tower == null:
		return
	if tower.is_destroyed or tower.hp <= 0.0:
		on_tower_removed(player_id, tower)
		return
	on_tower_spawned(player_id, tower)


func on_tower_removed(player_id: int, tower: Variant) -> void:
	var key = _tower_key(player_id, tower)
	if key.is_empty():
		return
	_remove_tower_node(key)


func on_object_spawned(obj: Variant) -> void:
	var object_id = _extract_object_id(obj)
	if object_id < 0:
		return
	if obj.is_destroyed:
		_remove_object_node(object_id)
		return
	var kind = _detect_object_kind(obj)
	if kind.is_empty():
		return
	var node: Node2D = _object_nodes.get(object_id)
	if node == null:
		node = _create_visual_node(kind)
		if node == null:
			return
		node.name = "%s_%d" % [kind.capitalize(), object_id]
		add_child(node)
		_object_nodes[object_id] = node
	node.bind_to_object(object_id, obj)


func on_object_updated(obj: Variant) -> void:
	if obj == null:
		return
	if obj.is_destroyed:
		on_object_removed(obj)
		return
	on_object_spawned(obj)


func on_object_removed(obj: Variant) -> void:
	var object_id = _extract_object_id(obj)
	if object_id < 0:
		return
	_remove_object_node(object_id)


func on_particle_spawned(particle: Variant) -> void:
	if particle.is_finished():
		on_particle_removed(particle)
		return
	var key = _particle_key(particle)
	if key < 0:
		return
	var node: Node2D = _particle_nodes.get(key)
	if node == null:
		node = _create_visual_node("particle")
		if node == null:
			return
		node.name = "Particle_%d" % key
		add_child(node)
		_particle_nodes[key] = node
	node.bind_to_object(key, particle)


func on_particle_updated(particle: Variant) -> void:
	if particle == null:
		return
	if particle.is_finished():
		on_particle_removed(particle)
		return
	on_particle_spawned(particle)


func on_particle_removed(particle: Variant) -> void:
	var key = _particle_key(particle)
	if key < 0:
		return
	_remove_particle_node(key)


func sync_from_match(match: Variant) -> void:
	if match == null:
		return
	var live_towers := {}
	for player in match.players:
		for tower in player.towers:
			var key = _tower_key(player.id, tower)
			if key.is_empty():
				continue
			live_towers[key] = true
			on_tower_updated(player.id, tower)
	for key in _tower_nodes.keys():
		if not live_towers.has(key):
			_remove_tower_node(str(key))

	var live_objects := {}
	for obj in match.game_objects:
		var object_id = _extract_object_id(obj)
		if object_id < 0:
			continue
		live_objects[object_id] = true
		on_object_updated(obj)
	for object_id in _object_nodes.keys():
		if not live_objects.has(object_id):
			_remove_object_node(Entities.as_int(object_id, -1))

	var live_particles := {}
	for particle in match.particles:
		var particle_id = _particle_key(particle)
		if particle_id < 0:
			continue
		live_particles[particle_id] = true
		on_particle_updated(particle)
	for particle_id in _particle_nodes.keys():
		if not live_particles.has(particle_id):
			_remove_particle_node(Entities.as_int(particle_id, -1))


func clear_all() -> void:
	for key in _tower_nodes.keys():
		_remove_tower_node(str(key))
	for object_id in _object_nodes.keys():
		_remove_object_node(Entities.as_int(object_id, -1))
	for particle_id in _particle_nodes.keys():
		_remove_particle_node(Entities.as_int(particle_id, -1))


func _create_visual_node(kind: String) -> Node2D:
	var packed_scene: PackedScene = null
	match kind:
		"unit":
			packed_scene = UNIT_SCENE
		"building":
			packed_scene = BUILDING_SCENE
		"spell":
			packed_scene = SPELL_SCENE
		"projectile":
			packed_scene = PROJECTILE_SCENE
		"particle":
			packed_scene = PARTICLE_SCENE
		_:
			return null
	var instance = packed_scene.instantiate()
	if instance is Node2D:
		return instance
	return null


func _detect_object_kind(obj: Variant) -> String:
	if obj is Entities.Unit:
		return "unit"
	if obj is Entities.Building:
		return "building"
	if obj is Entities.Spell:
		return "spell"
	if obj is Entities.Projectile:
		return "projectile"
	var movement = str(obj.movement_type)
	if movement == "spell":
		return "spell"
	if movement == "projectile":
		return "projectile"
	return ""


func _extract_object_id(obj: Variant) -> int:
	if obj == null:
		return -1
	if obj is Object:
		return Entities.as_int((obj as Object).get("id"), -1)
	return -1


func _tower_key(player_id: int, tower: Variant) -> String:
	var tower_id = _extract_object_id(tower)
	if tower_id < 0:
		return ""
	return "%d_%d" % [player_id, tower_id]


func _particle_key(particle: Variant) -> int:
	if particle == null:
		return -1
	if particle is Object:
		return (particle as Object).get_instance_id()
	return -1


func _remove_tower_node(key: String) -> void:
	if not _tower_nodes.has(key):
		return
	var node: Node = _tower_nodes[key]
	if node != null and is_instance_valid(node):
		node.queue_free()
	_tower_nodes.erase(key)


func _remove_object_node(object_id: int) -> void:
	if object_id < 0 or not _object_nodes.has(object_id):
		return
	var node: Node = _object_nodes[object_id]
	if node != null and is_instance_valid(node):
		node.queue_free()
	_object_nodes.erase(object_id)


func _remove_particle_node(particle_id: int) -> void:
	if particle_id < 0 or not _particle_nodes.has(particle_id):
		return
	var node: Node = _particle_nodes[particle_id]
	if node != null and is_instance_valid(node):
		node.queue_free()
	_particle_nodes.erase(particle_id)
