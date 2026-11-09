## Recurso serializable (`.tres`) que define las propiedades y comportamientos de una carta.
## Contiene un arreglo de `CardEffect` que dictan su impacto en la resolución del combate.
extends Resource
class_name CardData

@export_group("Identity")
@export var title: String = "Carta Base"
@export var rarity: RaritySystem.Tier = RaritySystem.Tier.COMMON
## Flag explícito que identifica si la carta es de naturaleza mágica/arcana.
@export var is_magical: bool = false
## Textura o Sprite 2D opcional que se renderiza en el recuadro central de arte de `CardUI`.
@export var artwork: Texture2D

## Determina si la carta se envía al cementerio tras jugarse (Agotada), impidiendo que vuelva a barajarse en el mismo combate.
@export var single_use: bool = false
@export_group("Effects and Cost")
@export var effects: Array[CardEffect] = []
@export_multiline var description: String = "Una carta común y corriente"
@export var cost: int = 1

@export_group("Synergy")
## ¿Qué tipo de arma exige esta carta para desatar su efecto real?
@export var required_weapon_class: Array[WeaponData.Class] = [WeaponData.Class.ANY]

## Si es true, al daño base de la carta se le suma el daño del arma + el escalado de stats.
@export var uses_weapon_damage: bool = true

## Daño miserable que hace la carta si el jugador NO tiene el arma requerida equipada (Fallback).
@export var fallback_damage: int = 2

## Evalúa si la carta es mágica ya sea por su flag explícito `is_magical`, por exigir Báculo (`STAFF`),
## o porque alguno de sus `CardEffect` está marcado con `is_magical = true`.
func is_magic_card() -> bool:
	if is_magical:
		return true
	if required_weapon_class.has(WeaponData.Class.STAFF):
		return true
	for effect in effects:
		if effect and effect.is_magical:
			return true
	return false

## Determina el color funcional del nombre de la carta (`TitleLabel`) según qué hace:
## - Escudo (`DefenseEffect`): Azul.
## - Sanación (`HealEffect`): Verde.
## - Daño Mágico / Sobrecarga (`is_magic_card()` ofensiva o `MultiplyEffect`): Violeta Mágico.
## - Robo (`StealEffect`): Violeta Índigo (distinto al mágico).
## - Daño Físico: Rojo.
func get_color() -> Color:
	var has_defense := false
	var has_heal := false
	var has_steal := false
	var has_multiply := false
	var has_offense := false

	for effect in effects:
		if effect == null:
			continue
		if effect is DefenseEffect:
			has_defense = true
		elif effect is HealEffect:
			has_heal = true
		elif effect is StealEffect:
			has_steal = true
		elif effect is MultiplyEffect:
			has_multiply = true
		elif effect is DamageEffect or effect is BurnEffect or effect is PoisonEffect or effect is FreezeEffect or effect is ShockEffect or effect is HemorrhageEffect or effect is ApplyStatusEffect:
			has_offense = true

	if has_defense and not has_offense:
		return Color(0.32, 0.72, 1.0) # Azul (Escudo)
	if has_heal and not has_offense:
		return Color(0.28, 0.92, 0.48) # Verde (Sanación)
	if has_multiply and not has_offense:
		return Color(0.86, 0.36, 1.0) # Violeta Púrpura (Sobrecarga / Multi)
	if has_steal and not has_offense:
		return Color(0.58, 0.50, 1.0) # Violeta Índigo (Robo)
	if has_offense or uses_weapon_damage:
		if is_magic_card():
			return Color(0.82, 0.36, 1.0) # Violeta Mágico (Daño y Mágico)
		return Color(1.0, 0.32, 0.34) # Rojo (Daño Físico)

	return Color(0.90, 0.94, 0.98)

## Devuelve el color específico del efecto elemental o principal para teñir el recuadro de arte (`ArtPanel`).
func get_art_accent_color() -> Color:
	for effect in effects:
		if effect and not (effect is DamageEffect):
			return effect.get_color()
	for effect in effects:
		if effect:
			return effect.get_color()
	return get_color()

## Devuelve el ícono compacto para la esquina superior derecha de la carta según la familia de arma requerida.
func get_weapon_icon() -> String:
	if required_weapon_class.is_empty() or required_weapon_class.has(WeaponData.Class.ANY):
		return "✦"
	var first_class: WeaponData.Class = required_weapon_class[0]
	match first_class:
		WeaponData.Class.SWORD:
			return "⚔"
		WeaponData.Class.HEAVY:
			return "🪓"
		WeaponData.Class.STAFF:
			return "🪄"
		WeaponData.Class.DAGGER:
			return "🗡"
		WeaponData.Class.KATANA:
			return "⚔"
		_:
			return "✦"

## Genera la etiqueta compacta de familia de arma compatible para la franja central de `CardUI`.
func get_weapon_tag_text() -> String:
	if required_weapon_class.is_empty() or required_weapon_class.has(WeaponData.Class.ANY):
		return "🏷️ Cualquier Arma"
	var names: Array[String] = []
	for w_class in required_weapon_class:
		match w_class:
			WeaponData.Class.SWORD:
				names.append("Espada")
			WeaponData.Class.HEAVY:
				names.append("Pesada")
			WeaponData.Class.STAFF:
				names.append("Báculo")
			WeaponData.Class.DAGGER:
				names.append("Daga")
			WeaponData.Class.KATANA:
				names.append("Katana")
			_:
				names.append("Libre")
	return "🏷️ " + " / ".join(names)

## Devuelve un glifo/emblema visual representativo de los efectos de la carta para usar como placeholder cuando no hay `artwork`.
func get_placeholder_emblem() -> String:
	for effect in effects:
		if effect is BurnEffect:
			return "🔥"
		if effect is FreezeEffect:
			return "❄️"
		if effect is PoisonEffect:
			return "🧪"
		if effect is ShockEffect:
			return "⚡"
		if effect is HemorrhageEffect:
			return "🩸"
		if effect is DefenseEffect:
			return "🛡️"
		if effect is HealEffect:
			return "💚"
		if effect is MultiplyEffect:
			return "✨"
		if effect is StealEffect:
			return "🃏"
		if effect is ApplyStatusEffect:
			return "🎲"
		if effect is DamageEffect:
			return "⚔️"
	return "⚔️"

## Construye el texto de descripción/efectos de la carta para mostrarse centrado en `CardUI`.
## Omite el texto redundante de escalado de arma (ya visible en el tag superior/central).
func get_rules_text() -> String:
	var lines: Array[String] = []
	for effect in effects:
		if effect:
			lines.append(effect.get_description())
	if lines.is_empty() and description.strip_edges() != "":
		lines.append(description.strip_edges())
	if single_use:
		lines.append("[ÚNICO USO]")
	return "\n".join(lines)

## Devuelve los emojis de los efectos de estado alterados que la carta produce en el enemigo
## (Hemorragia `🩸`, Quemadura `🔥`, Congelamiento `❄️`, Veneno `🧪`, Electrocución `⚡` o Aleatorio `🎲`)
## para mostrarse en la esquina inferior izquierda de `CardUI`.
func get_enemy_status_icons() -> String:
	var icons: Array[String] = []
	for effect in effects:
		if effect == null:
			continue
		var icon := ""
		if effect is HemorrhageEffect:
			icon = "🩸"
		elif effect is BurnEffect:
			icon = "🔥"
		elif effect is FreezeEffect:
			icon = "❄️"
		elif effect is PoisonEffect:
			icon = "🧪"
		elif effect is ShockEffect:
			icon = "⚡"
		elif effect is ApplyStatusEffect:
			var status_eff := effect as ApplyStatusEffect
			match status_eff.status_type:
				ApplyStatusEffect.StatusType.HEMORRHAGE:
					icon = "🩸"
				ApplyStatusEffect.StatusType.BURN:
					icon = "🔥"
				ApplyStatusEffect.StatusType.FREEZE:
					icon = "❄️"
				ApplyStatusEffect.StatusType.POISON:
					icon = "🧪"
				ApplyStatusEffect.StatusType.SHOCK:
					icon = "⚡"
				ApplyStatusEffect.StatusType.RANDOM:
					icon = "🎲"
		if icon != "" and not icons.has(icon):
			icons.append(icon)
	return " ".join(icons)

## Construye un bloque de texto multilínea completo (usado por modales e inspectores) consolidando efectos,
## costo de energía, rareza e indicador de uso único.
func get_stats_text() -> String:
	var lines: Array[String] = []
	for effect in effects:
		if effect:
			lines.append(effect.get_description())
	lines.append("Costo: %d" % cost)
	lines.append("[%s]" % RaritySystem.get_tier_name(rarity))
	if single_use:
		lines.append("[UNICO USO]")
	return "\n".join(lines)

## Itera secuencialmente sobre el arreglo de efectos y ejecuta su lógica de alteración mutando el diccionario `combo_state`.
func apply_effects(combo_state: Dictionary) -> void:
	for effect in effects:
		if effect:
			effect.apply(combo_state)

## Evalúa si la carta es de resolución instantánea (se ejecuta y descarta directamente sin encolarse en la mesa).
## Retorna `true` únicamente si todos sus efectos son de tipo instantáneo.
func is_instant_card() -> bool:
	if effects.is_empty():
		return false
	for effect in effects:
		if effect and not effect.is_instant():
			return false
	return true
