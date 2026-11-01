# core/combat/combat_action.gd
class_name CombatAction
extends RefCounted

## Clase base para acciones de combate reversibles.
## Por ahora no se usa; el CombatResolver es stateless y no requiere Command pattern.
## Implementar si en el futuro se necesita undo/replay/logging.

var resolver: CombatResolver

func _init(r: CombatResolver) -> void:
	resolver = r

func execute() -> void:
	push_error("CombatAction.execute() must be overridden")
	pass

func undo() -> void:
	push_error("CombatAction.undo() must be overridden")
	pass
