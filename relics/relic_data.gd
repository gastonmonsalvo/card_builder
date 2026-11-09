## Recurso serializable (`.tres`) que define una reliquia pasiva.
## Actúa como contenedor de múltiples `RelicEffect` y delega los eventos del juego a cada uno de ellos.
extends Resource
class_name RelicData

@export var title: String = "Reliquia Misteriosa"
@export var rarity: RaritySystem.Tier = RaritySystem.Tier.COMMON

@export var effects: Array[RelicEffect] = []
@export_multiline var description: String = "Un objeto extraño"

## Recorre todos los efectos internos y ejecuta su lógica de inicialización (`on_equipped`) al adquirir la reliquia en el `RunState`.
func trigger_on_equipped(run) -> void:
	for effect in effects:
		if effect:
			effect.on_equipped(run)

## Recorre los efectos y los dispara al inicio de un encuentro (`on_combat_start`),
## permitiendo aplicar estados o alteraciones al enemigo en el turno 0.
func trigger_on_combat_start(enemy: Enemy) -> void:
	for effect in effects:
		if effect:
			effect.on_combat_start(enemy)

## Dispara los efectos reactivos (`on_combo_evaluated`) tras calcular una cadena de combo en la mesa,
## pasando el estado final del combo y la cantidad de cartas jugadas.
func trigger_on_combo_evaluated(combo_state: Dictionary, card_count: int) -> void:
	for effect in effects:
		if effect:
			effect.on_combo_evaluated(combo_state, card_count)

## Delega la evaluación de daño letal a sus efectos (`on_player_lethal_damage`).
## Retorna `true` inmediatamente si algún efecto logra salvar al jugador de la muerte.
func trigger_on_lethal_damage(run) -> bool:
	for effect in effects:
		if effect and effect.on_player_lethal_damage(run):
			return true
	return false

## Recopila y concatena los textos técnicos automáticos de cada efecto interno
## (ej. "+2 Suerte, +1 Energía") en una sola cadena.
func get_effects_description() -> String:
	var parts: Array[String] = []
	for effect in effects:
		if effect:
			var desc: String = effect.get_description()
			if desc != "":
				parts.append(desc)
	return ", ".join(parts)

## Construye un bloque de texto detallado y formateado para la interfaz que incluye la rareza,
## título, descripción base y la suma de sus efectos técnicos.
func get_inspector_text() -> String:
	var tier_label: String = RaritySystem.get_tier_name(rarity)
	var eff_text: String = get_effects_description()
	
	var txt: String = "[%s] %s\n%s" % [tier_label, title, description]
	if eff_text != "":
		txt += "\nEfectos: " + eff_text
	return txt
