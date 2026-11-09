## Recurso serializable (`.tres`) que define una reliquia pasiva.
## Actúa como contenedor de múltiples `RelicEffect` y delega los eventos del juego a cada uno de ellos.
extends Resource
class_name RelicData

@export var title: String = "Reliquia Misteriosa"
@export var rarity: RaritySystem.Tier = RaritySystem.Tier.COMMON
## Sprite 2D opcional que se muestra sobre el pedestal central en `RelicUI`.
@export var artwork: Texture2D

@export var effects: Array[RelicEffect] = []
@export_multiline var description: String = "Un objeto extraño"
## Párrafo narrativo de trasfondo (Lore / Historia del objeto) que se muestra atenuado en cursiva en el bloque inferior de `RelicUI`.
@export_multiline var lore: String = ""

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

## Devuelve el texto corto y claro de la mecánica de juego para el bloque de EFECTO en `RelicUI`.
func get_effect_summary_text() -> String:
	var eff_text: String = get_effects_description()
	if eff_text != "":
		return eff_text
	return description.strip_edges()

## Devuelve el párrafo narrativo de historia (Lore) entre comillas para el bloque inferior de `RelicUI`.
func get_lore_text() -> String:
	var raw_lore: String = lore.strip_edges() if lore.strip_edges() != "" else description.strip_edges()
	if raw_lore == "":
		return ""
	if raw_lore.begins_with("\"") and raw_lore.ends_with("\""):
		return raw_lore
	return "\"%s\"" % raw_lore

## Devuelve un glifo/emblema representativo del objeto para el pedestal cuando `artwork` no está asignado.
func get_placeholder_emblem() -> String:
	var lower_title: String = title.to_lower()
	if lower_title.contains("anillo") or lower_title.contains("brasa"):
		return "💍"
	if lower_title.contains("fenix") or lower_title.contains("ceniza"):
		return "🪶"
	if lower_title.contains("trebol"):
		return "🍀"
	if lower_title.contains("bolsillo"):
		return "🌀"
	if lower_title.contains("catalizador"):
		return "⚙️"
	if lower_title.contains("colmillo") or lower_title.contains("vibora"):
		return "🐍"
	if lower_title.contains("nucleo"):
		return "🔮"
	if lower_title.contains("conejo") or lower_title.contains("pata"):
		return "🐾"
	return "🏺"

## Construye un bloque de texto detallado y formateado para la interfaz que incluye la rareza,
## título, descripción base y la suma de sus efectos técnicos.
func get_inspector_text() -> String:
	var tier_label: String = RaritySystem.get_tier_name(rarity)
	var eff_text: String = get_effects_description()
	
	var txt: String = "[%s] %s\n%s" % [tier_label, title, description]
	if eff_text != "":
		txt += "\nEfectos: " + eff_text
	return txt
