
extends RefCounted
class_name EnemyIntent

enum Type { ATTACK, DEFEND, CHARGE, APPLY_STATUS, NOTHING }

@export var type: Type = Type.ATTACK
@export var damage: int = 0
@export var block: int = 0
@export var status_id: String = ""
@export var status_stacks: int = 0
@export var description: String = ""

func _init(p_type: Type = Type.ATTACK, p_damage: int = 0, p_block: int = 0, p_desc: String = "") -> void:
	type = p_type
	damage = p_damage
	block = p_block
	description = p_desc
