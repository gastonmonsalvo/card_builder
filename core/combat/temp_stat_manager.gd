## Gestor de modificadores temporales de estadísticas del jugador durante el combate.
## Trackea modificadores temporales a los stats del jugador y los hace expirar por turnos.
## Realiza el seguimiento de ventajas y desventajas aplicadas, gestionando su expiración por turnos.
class_name TempStatManager
extends RefCounted

## Lista interna con los modificadores activos.
## Estructura por elemento: {"stat": String, "amount": int, "turns_remaining": int}
var _active_mods: Array[Dictionary] = []


## Registra un nuevo modificador temporal de estadística con una duración definida en turnos.
func add_mod(stat: String, amount: int, turns: int) -> void:
	_active_mods.append({
		"stat": stat,
		"amount": amount,
		"turns_remaining": turns
	})


## Reduce en uno la duración de todos los modificadores activos y purga aquellos que hayan expirado.
## Debe invocarse al concluir la fase del turno del jugador.
func tick_turn() -> void:
	var expired_indices: Array[int] = []
	for i in range(_active_mods.size()):
		_active_mods[i]["turns_remaining"] -= 1
		if _active_mods[i]["turns_remaining"] <= 0:
			expired_indices.append(i)
	
	# Eliminar expirados en orden inverso para no alterar los índices subsiguientes
	expired_indices.reverse()
	for i in expired_indices:
		_active_mods.remove_at(i)


## Calcula la sumatoria neta de todas las alteraciones vigentes sobre una estadística específica.
func get_total_mod(stat: String) -> int:
	var total: int = 0
	for mod in _active_mods:
		if mod["stat"] == stat:
			total += mod["amount"]
	return total


## Comprueba si existe al menos una alteración activa registrada para la estadística indicada.
func has_mod(stat: String) -> bool:
	for mod in _active_mods:
		if mod["stat"] == stat:
			return true
	return false


## Elimina la totalidad de los modificadores activos y reinicia el estado de seguimiento.
## Debe invocarse al cerrar o reiniciar el encuentro de combate.
func clear() -> void:
	_active_mods.clear()


## Construye una cadena descriptiva para el HUD con los modificadores activos y sus turnos restantes.
func get_active_mods_summary() -> String:
	if _active_mods.is_empty():
		return ""
	var parts: Array[String] = []
	for mod in _active_mods:
		var sign: String = "+" if mod["amount"] >= 0 else ""
		parts.append("%s%s %s (%dt)" % [sign, mod["amount"], mod["stat"].to_upper(), mod["turns_remaining"]])
	return " | ".join(parts)
