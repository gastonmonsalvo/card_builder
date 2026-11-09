# core/cards/effects/apply_status_effect.gd
## Efecto genérico para aplicar estados alterados sobre el combo_state acumulado.
## Admite estados fijos o resolución aleatoria ponderada mediante RaritySystem.
class_name ApplyStatusEffect
extends CardEffect

## Tipos de estados alterados disponibles, incluyendo la opción de sorteo aleatorio.
enum StatusType { BURN, POISON, FREEZE, SHOCK, HEMORRHAGE, RANDOM }

## Tipo de estado alterado configurado para la carta.
@export var status_type: StatusType = StatusType.BURN

## Cantidad de acumulaciones del estado que se aplicarán al combo.
@export var stacks: int = 2

## Inicializa el efecto marcándolo por defecto como mágico/arcano.
func _init() -> void:
	is_magical = true

## Tabla de pesos para la resolución ponderada de estados aleatorios.
const STATUS_WEIGHTS := {
	StatusType.BURN: 30.0,
	StatusType.POISON: 30.0,
	StatusType.FREEZE: 20.0,
	StatusType.SHOCK: 15.0,
	StatusType.HEMORRHAGE: 5.0,
}


## Aplica las acumulaciones del estado configurado al diccionario del combo.
## Si está en modo aleatorio, resuelve el tipo mediante selección ponderada determinista.
func apply(combo_state: Dictionary) -> void:
	var chosen_type: StatusType = status_type
	
	if status_type == StatusType.RANDOM:
		var run_state: RunState = combo_state.get("run_state")
		if run_state and run_state.combat_rng:
			# El RNG avanza naturalmente
			chosen_type = RaritySystem.roll_weighted(STATUS_WEIGHTS, run_state.combat_rng) as StatusType
		else:
			chosen_type = StatusType.BURN # Fallback por si algo falla
	
	match chosen_type:
		StatusType.BURN: combo_state["burn"] += stacks
		StatusType.POISON: combo_state["poison"] += stacks
		StatusType.FREEZE: combo_state["freeze"] += stacks
		StatusType.SHOCK: combo_state["shock"] += stacks
		StatusType.HEMORRHAGE: combo_state["hemorrhage"] += stacks
		
## Devuelve la descripción localizada y formateada para la interfaz de la carta.
func get_description() -> String:
	if status_type == StatusType.RANDOM:
		return "+%d Status Aleatorio" % stacks
	return "+%d %s" % [stacks, _get_status_name(status_type)]


## Determina el color representativo del estado alterado para etiquetas e indicadores visuales.
func get_color() -> Color:
	match status_type:
		StatusType.BURN: return Color(1.0, 0.4, 0.1)
		StatusType.POISON: return Color(0.3, 0.8, 0.2)
		StatusType.FREEZE: return Color(0.4, 0.7, 1.0)
		StatusType.SHOCK: return Color(0.9, 0.9, 0.3)
		StatusType.HEMORRHAGE: return Color(0.8, 0.1, 0.1)
		StatusType.RANDOM: return Color(0.9, 0.5, 1.0)
	return Color.WHITE


## Devuelve el nombre en texto plano asignado al identificador del estado.
func _get_status_name(type: StatusType) -> String:
	match type:
		StatusType.BURN: return "Quemadura"
		StatusType.POISON: return "Veneno"
		StatusType.FREEZE: return "Congelamiento"
		StatusType.SHOCK: return "Electrocución"
		StatusType.HEMORRHAGE: return "Hemorragia"
		StatusType.RANDOM: return "Aleatorio"
	return ""

func is_status_effect() -> bool:
	return true

func get_status_icon() -> String:
	match status_type:
		StatusType.HEMORRHAGE: return "🩸"
		StatusType.BURN: return "🔥"
		StatusType.FREEZE: return "❄️"
		StatusType.POISON: return "🧪"
		StatusType.SHOCK: return "⚡"
		StatusType.RANDOM: return "🎲"
	return "🎲"

func get_emblem_icon() -> String:
	return "🎲" if status_type == StatusType.RANDOM else get_status_icon()
