## Efecto de reliquia que aplica estados alterados al enemigo al iniciar el combate.
## Permite configurar acumulaciones de Quemadura, Veneno, Congelamiento, Shock y Hemorragia.

extends RelicEffect
class_name RelicStartStatusEffect

## Acumulaciones iniciales del estado alterado a aplicar.
@export var start_burn: int = 0
@export var start_poison: int = 0
@export var start_freeze: int = 0
@export var start_shock: int = 0
@export var start_hemorrhage: int = 0

## Inyecta los estados alterados configurados directamente al enemigo en el turno 0.
func on_combat_start(enemy: Enemy) -> void:
	if start_burn > 0 or start_poison > 0 or start_freeze > 0 or start_shock > 0 or start_hemorrhage > 0:
		enemy.add_statuses(start_burn, start_poison, start_freeze, start_shock, start_hemorrhage)
		
## Construye un texto dinámico para la interfaz uniendo solo los estados que tengan valores mayores a 0.
func get_description() -> String:
	var parts: Array[String] = []
	if start_burn > 0:
		parts.append("+%d Quemadura inicial" % start_burn)
	if start_poison > 0:
		parts.append("+%d Veneno inicial" % start_poison)
	if start_freeze>0:
		parts.append("+%d Congelamiento inicial" % start_freeze)
	if start_shock >0:
		parts.append("+%d Electrocutado inicial" % start_shock)
	if start_hemorrhage >0:
		parts.append("+%d Hemorragia inicial" % start_hemorrhage)
	return ", ".join(parts)
