## Recurso serializable (`.tres`) que define las propiedades y comportamientos de una carta.
## Contiene un arreglo de `CardEffect` que dictan su impacto en la resolución del combate.
extends Resource
class_name CardData

@export_group("Identity")
@export var title: String = "Carta Base"
@export var rarity: RaritySystem.Tier = RaritySystem.Tier.COMMON

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

## Extrae el color representativo de la carta consultando el primer efecto válido de su lista.
## Retorna un gris oscuro por defecto si la carta no posee efectos.
func get_color() -> Color:
	for effect in effects:
		if effect:
			return effect.get_color()
	return Color(0.3, 0.3, 0.3)

## Construye un bloque de texto multilínea para la interfaz consolidando las descripciones de los efectos,
## el costo de energía, la etiqueta de rareza y el indicador de uso único (si corresponde).
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
