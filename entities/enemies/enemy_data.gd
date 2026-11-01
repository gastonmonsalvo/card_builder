## Plantilla de datos estáticos para definir enemigos desde el Inspector de Godot.
## Guarda las estadísticas base inmutables (como un bestiario) que luego el motor de combate usará para instanciar al enemigo vivo.
extends Resource
class_name EnemyData

## Nombre de la criatura para mostrar en el HUD de combate.
@export var enemy_name: String = "Enemigo Desconocido"

## Puntos de vida (HP) base del enemigo antes de aplicar escalados por planta.
@export var base_hp: int = 50

## Daño base que intentará infligir en su turno antes de escalados.
@export var base_damage: int = 10

## Bandera que define si esta criatura es un guardián de final de planta (Jefe).
## Útil para mecánicas de reliquias anti-jefes o para inmunidades.
@export var is_boss: bool = false

## (Opcional) Textura o imagen representativa del enemigo para mostrar en la mesa.
@export var artwork: Texture2D
