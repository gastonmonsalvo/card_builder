# Architecture

Documento de referencia para todo desarrollo en `card-prototype`. Define qué va en cada carpeta, reglas de responsabilidad y decisiones de diseño.

**Lectura obligatoria** antes de agregar un archivo nuevo al proyecto.

---

## Tabla de contenidos

1. [Árbol de directorios](#árbol-de-directorios)
2. [Capas y responsabilidades](#capas-y-responsabilidades)
3. [Detalle archivo por archivo](#detalle-archivo-por-archivo)
4. [Reglas de oro](#reglas-de-oro)
5. [Patrones de diseño aplicados](#patrones-de-diseño-aplicados)
	6. [DecisionesTecnicas ] (#Decisiones Tecnicas)
		6.1 [Decision: Por qué CombatResolver no usa Command pattern] (#¿Por qué CombatResolver no usa Command pattern?)
		6.2 [Decisión: Data vs Instance](#decisión-data-vs-instance)
		6.3 [Decisión: `scenes/` vs `ui/`](#decisión-scenes-vs-ui)
		6.4 [Decisión: `¿Por qué RewardView se construye 100% en código ?`](#¿Por qué RewardView se construye 100% en código (sin .tscn)?)
		6.5[Decisión: `¿Por qué RewardView no genera sus propias recompensas?`](#¿Por qué RewardView no genera sus propias recompensas?)
8. [Guía de migración desde la arquitectura anterior](#guía-de-migración-desde-la-arquitectura-anterior)
9. [Checklist: agregar X al proyecto](#checklist-agregar-x-al-proyecto)

---

## Árbol de directorios

```
card-prototype/
├── README.md
├── .gitignore
├── project.godot
│
├── docs/
│   ├── GDD.md
│   └── ARCHITECTURE.md
│
├── autoload/
│   ├── game_database.gd
│   ├── persistence_manager.gd
│   └── signal_bus.gd
│
├── core/
│   ├── combat/
│   │   ├── combat_resolver.gd
│   │   ├── combat_action.gd        # FALTA
│   │   └── actions/                 # FALTA
│   │       ├── play_card_action.gd	 # FALTA
│   │       ├── take_damage_action.gd	 # FALTA
│   │       ├── apply_status_action.gd	 # FALTA
│   │       └── end_turn_action.gd	 # FALTA
│   │  
│   ├── deck/
│   │   ├── deck_manager.gd
│   │   └── card_pile.gd
│   ├── enemies/
│   │   ├── enemy_ai.gd
│   │   └── behaviors/
│   ├── run/
│   │   ├── run_director.gd
│   │   ├── run_state.gd
│   │   ├── run_state_machine.gd  #FSM
│   │   └── rarity_system.gd
│   ├── map/
│   │   ├── floor_generator.gd
│   │   └── room_data.gd
│   └── constants/
│       └── combat_constants.gd
│
├── systems/
│   ├── statuses/
│   │   ├── status_data.gd
│   │   ├── status_instance.gd
│   │   ├── status_manager.gd
│   │   └── data/
│   │       ├── poison.tres
│   │       ├── vulnerable.tres
│   │       ├── weak.tres
│   │       ├── strength.tres
│   │       └── dexterity.tres
│   ├── modifiers/
│   │   ├── modifier_data.gd
│   │   └── modifier_manager.gd
│   └── events/
│       ├── event_data.gd
│       ├── event_choice.gd
│       ├── event_resolver.gd
│       └── data/
│           ├── campfire.tres
│           └── shop.tres
│
├── entities/
│   ├── hero/
│   │   ├── hero_data.gd
│   │   ├──hero_ability.gd 	
│   │   └── data/
│   │       ├── guerrero.tres
│   │       ├── mago.tres
│   │       └── picaro.tres
│   └── enemies/
│       ├── enemy_data.gd
│       └── data/
│           ├── esqueleto.tres
│           ├── goblin.tres
│           └── jefe_ogro.tres
│
├── cards/
│   ├── card_data.gd
│   ├── card_instance.gd
│   ├── data/
│   │   ├── tajo.tres
│   │   ├── estocada.tres
│   │   ├── bloqueo.tres
│   │   └── meditar.tres
│   └── effects/
│       ├── card_effect.gd
│       ├── damage_effect.gd
│       ├── block_effect.gd
│       ├── draw_effect.gd
│       ├── apply_status_effect.gd
│       └── heal_effect.gd
│
├── relics/
│   ├── relic_data.gd
│   ├── relic_instance.gd	# FALTA
│   ├── data/
│   │   ├── anillo_brasas.tres
│   │   ├── cenizas_fenix.tres
│   │   └── ...
│   └── effects/
│       ├── relic_effect.gd
│       ├── on_play_card_effect.gd	#FALTA
│       ├── on_take_damage_effect.gd
│       ├── on_turn_start_effect.gd
│       └── on_kill_enemy_effect.gd
│
├── weapons/
│   ├── weapon_data.gd
│   └── data/
│       ├── arma_basica.tres
│       ├── baculo.tres
│       ├── espadon.tres
│       └── katana_basica.tres
│
├── scenes/
│   ├── battle/
│   │   ├── battle_table.tscn
│   │   ├── battle_table.gd
│   │   └── hand_controller.gd
│   ├── map/
│   │   └── map_view.gd
│   ├── event/
│   │   ├── event_view.tscn   FALTA
│   │   └── event_view.gd
│   │
│   ├── reward/
│   │  └── reward_view.gd
│   │
│   ├── shop/                    
│   │   └── shop_view.gd
│   └── menus/                    
│       ├── main_menu_view.gd
│       ├── slot_select_view.gd
│       └── hero_select_view.gd
├── ui/
│   ├── cards/
│   │   ├── card_ui.tscn
│   │   └── card_ui.gd
│   ├── battle/
│   │   ├── battle_hud.gd          
│   │   ├── player_hud.gd   
│   │   ├── enemy_hud.gd          
│   │   ├── combo_banner.gd 
│   │   └── pile_inspector.gd  
│   ├── inventory/
│   │   └── inventory_modal.gd
│   ├── map/
│   │   ├── map_node.gd
│   │   ├── sanctuary_view.gd
│   ├── menus/
│   │   ├── slot_select.gd
│   │   └── hero_select.gd
│   └── system/
│       ├── pause_menu.gd
│       └── debug_overlay.gd
│
├── assets/
│   ├── art/
│   │   ├── cards/
│   │   ├── enemies/
│   │   ├── heroes/
│   │   ├── relics/
│   │   ├── ui/
│   │   └── map/
│   ├── audio/
│   │   ├── sfx/
│   │   ├── music/
│   │   └── ui/
│   └── fonts/
│
├── addons/
│   └── gut/
│
└── tests/
	├── combat/
	│   ├── test_combat_resolver.gd
	│   ├── test_status_manager.gd
	│   └── test_actions.gd
	├── deck/
	│   └── test_deck_manager.gd
	├── run/
	│   ├── test_rarity_system.gd
	│   └── test_run_state_machine.gd
	└── run_tests.cfg
```

---

## Capas y responsabilidades

| Capa | Carpeta | Conoce | No conoce |
|---|---|---|---|
| **Servicios globales** | `autoload/` | Todo | — |
| **Lógica de dominio** | `core/` | `systems/`, `entities/`, `cards/`, `relics/`, `weapons/` | `scenes/`, `ui/`, `assets/` |
| **Subsistemas** | `systems/` | Sus propios datos | Otras `systems/` (habla por signal bus) |
| **Definición de entidades** | `entities/` | `core/hero`, `core/enemies` (tipos) | Lógica de juego |
| **Datos de cartas** | `cards/` | `systems/statuses` (referencias) | `scenes/`, `ui/` |
| **Datos de reliquias** | `relics/` | `autoload/signal_bus` | `scenes/`, `ui/` |
| **Escenas** | `scenes/` | Todo | — |
| **UI atómica** | `ui/` | `core/` (vía signal bus) | Otras `ui/` (composición manual) |

**Flecha de dependencias**: `scenes` → `core` → `systems` → `entities` → `cards/relics/weapons`

**NUNCA al revés.** Si un `.gd` en `core/` necesita cargar una escena, está mal diseñado.

---

## Detalle archivo por archivo

### `autoload/` — Singletons globales

| Archivo | Contenido | Por qué |
|---|---|---|
| `signal_bus.gd` | Solo `signal` declarations y nada más. Ej: `card_played(card_instance)`, `enemy_died(enemy)`, `turn_started`. | Bus de eventos central. Cualquier subsistema emite/escucha sin acoplamiento. **Crítico** para reliquias reactivas. |
| `game_database.gd` | Diccionarios `cards: Dictionary`, `relics`, `weapons`, `enemies`, `statuses`. Se carga con `load()` de los `.tres` en `_init()`. | Registro central. Evita hacer `load("res://...")` desparramado por todo el código. |
| `persistence_manager.gd` | `save_game(slot: int)`, `load_game(slot)`, `save_run_stats()`. Usa `ConfigFile` para runs y JSON para stats globales. | Guardado/carga. 3 slots + stats de meta-progreso. |

---
| Archivo | Contenido | Por qué |
|---|---|---|
| `combat_resolver.gd` | `extends RefCounted`, `class_name CombatResolver`. Todos los métodos `static`. Métodos puros: `calculate_sequential_preview`, `calculate_final_card_damage`, `_apply_card_effects_to_combo`, `_is_status_effect`, `process_card_in_combo`, `finalize_combo`, `tick_enemy_statuses`, `resolve_enemy_turn`, `calculate_instant_card`. | **Stateless**. No tiene estado mutable compartido, así que no necesita Command pattern. La orquestación de UI + animaciones vive en `scenes/battle/battle_table.gd`, que llama a estos métodos estáticos. |


---

### `core/deck/` — Pilas de cartas

| Archivo | Contenido | Por qué |
|---|---|---|
| `card_pile.gd` | `class_name CardPile`. Array de `CardInstance`. Métodos `add()`, `draw() -> CardInstance`, `shuffle()`, `peek_top()`. | Pila genérica. Robo, descarte y mazo son instancias de esto. |
| `deck_manager.gd` | 3 `CardPile`: `draw_pile`, `hand`, `discard`. Métodos `draw_card()`, `play_card()`, `discard_hand()`, `shuffle_discard_into_draw()`. | Maneja el ciclo de vida de la mano. Cuando `draw_pile` está vacío y piden robar, mezcla el descarte. |

---

### `core/hero/` y `core/enemies/` — Lógica de actores

| Archivo | Contenido | Por qué |
|---|---|---|
| `enemy_ai.gd` | `class_name EnemyAI`. `static func decide_intent(enemy, run, turn_count) -> EnemyIntent`. Itera los behaviors de `enemy.data.intent_pattern` y devuelve el primer intent no-null. Fallback a Attack. | Orquestador de IA. |
| `behaviors/enemy_behavior.gd` | `class_name EnemyBehavior extends Resource`. Abstract: `decide(context) -> EnemyIntent`. | Clase base para estrategias de IA. Es Resource para que aparezca en el Inspector. |
| `behaviors/enemy_intent.gd` | `class_name EnemyIntent extends RefCounted`. Enum Type { ATTACK, DEFEND, CHARGE, APPLY_STATUS, NOTHING }. Campos: `damage`, `block`, `status_id`, `description`. | Tipo de dato que viaja entre el behavior y el resolver. |
| `behaviors/enemy_context.gd` | `class_name EnemyContext extends RefCounted`. Campos: `enemy`, `run`, `turn_count`. | Contexto inyectado en `decide()`. |
| `behaviors/attack_behavior.gd` | `class_name AttackBehavior`. `@export var damage, every_n_turns`. `decide()` retorna `AttackIntent`. | Ataca cada N turnos. |
| `behaviors/defend_behavior.gd` | `class_name DefendBehavior`. `@export var block, every_n_turns`. `decide()` retorna `DefendIntent`. | Gana escudo cada N turnos. |
| `behaviors/charge_behavior.gd` | `class_name ChargeBehavior`. `@export var bonus_multiplier, every_n_turns`. `decide()` retorna `Charge` el primer turno y `Attack` cargado el siguiente. | Carga + golpe devastador. |
**Composición de IA**: un enemigo puede tener `[AttackBehavior, FleeBehavior]`. El `enemy_ai.gd` itera los behaviors y elige según prioridad.

---

### `core/run/` — Estado de la partida

| Archivo | Contenido | Por qué |
|---|---|---|
| `run_state.gd` | Datos: `floor`, `gold`, `current_hero`, `deck`, `relics`, `hp`, `max_hp`. Métodos de negocio: `generate_combat_rewards()`, `apply_combat_rewards()`, `start_new_run()`, `rest_at_campfire()`. | Estado serializable + lógica de negocio. Lo que se guarda/carga. |
| `run_director.gd` | Orquestador. Genera recompensas, crea `RewardView`, escucha señales de UI, llama a `RunState.apply_combat_rewards()`. | El "director de película" de la run. Conecta UI con lógica de dominio. |
| `run_state_machine.gd` | `enum State { MENU, MAP, BATTLE, REWARD, EVENT, SHOP, DEAD, VICTORY }`. `transition_to(state) -> bool` valida si la transición es legal. Emite `state_changed`. | FSM explícita. Evita bugs de transiciones simultáneas. |
| `rarity_system.gd` | `roll_tier(rng, floor, luck, bonus) -> Tier`. Pesos dinámicos por piso y suerte. | Sorteo determinista de rarezas. |
| Archivo | Contenido | Por qué |
|---|---|---|
| `reward_view.gd` | `extends Control`. Recibe `rewards: Dictionary` en `setup()`. Anima cartas (idle, hover, pop-in). Emite `card_chosen(card_data)` o `skipped()`. | Vista pura: no muta estado del juego. Toda la lógica de "qué recompensas tocaron" vive en `RunState.generate_combat_rewards()`. |

Flujo de recompensas:

1. BattleTable emite combat_won cuando el enemigo muere.
2. RunDirector._on_combat_won() transiciona FSM a REWARD y abre RewardView.
3. RewardView muestra las recompensas ya generadas y anima las cartas.
4. Jugador elige carta o skippea → RewardView emite card_chosen o skipped.
5. RunDirector escucha, aplica recompensas vía RunState.apply_combat_rewards() y transiciona FSM a MAP.

---

### `core/map/` — Generación procedural

| Archivo | Contenido | Por qué |
|---|---|---|
| `room_data.gd` | `class_name RoomData`. `type: Enum { BATTLE, ELITE, EVENT, SHOP, REST, TREASURE, BOSS }`, `position: Vector2i`, `connections: Array[Vector2i]`, `visited: bool`. | Data de una habitación. Inmutable. |
| `floor_generator.gd` | `generate_floor(floor_num: int) -> Array[RoomData]`. Algoritmo: generar nodos en columnas, conectar vecinos, garantizar camino al boss. | Procedural. Semilla para reproducibilidad. |

---

### `core/constants/`

| Archivo | Contenido |
|---|---|
| `combat_constants.gd` | `const STARTING_ENERGY = 3`, `const HAND_SIZE = 5`, `const STARTING_HP = 50`, `const BLOCK_DECAY_AT_TURN_END = true`, etc. |

---

### `systems/statuses/` — Sistema de buffs/debuffs

| Archivo | Contenido | Por qué |
|---|---|---|
| `status_data.gd` | `class_name StatusData extends Resource`. `id: String`, `name: String`, `icon: Texture2D`, `stack_behavior: Enum { REPLACE, ADD, MAX_CAP }`, `tick_type: Enum { NONE, TURN_START, TURN_END }`. | La **definición** inmutable del status. No tiene lógica de aplicación. |
| `status_instance.gd` | `class_name StatusInstance extends RefCounted`. `data: StatusData`, `stacks: int`, `duration: int`. Métodos `add_stacks(n)`, `tick() -> bool` (devuelve true si expiró). | El estado runtime. Cada enemigo tiene su propia instancia de veneno con stacks distintos. |
| `status_manager.gd` | `class_name StatusManager`. Una instancia por entidad. `apply(data, stacks)`, `get_stacks(id) -> int`, `tick_all()`, `has_status(id) -> bool`. | Orquesta todas las instancias de una entidad. Lo llama `combat_resolver` al fin de turno. |
| `data/poison.tres` | tick TURN_END, stack_behavior ADD. Daño = stacks al final de turno. | |
| `data/vulnerable.tres` | duration 3, stack_behavior REPLACE. +50% daño recibido. | |
| `data/weak.tres` | duration 3. Ataques hacen -25% daño. | |
| `data/strength.tres` | Permanente mientras dure el combate. +1 daño por stack a ataques. | |
| `data/dexterity.tres` | Permanente. +1 block por stack. | |

---

### `systems/modifiers/` — Modificadores de atributos

Diferencia con statuses: modifiers son **operaciones** sobre atributos base (multiplicar daño, sumar block), statuses son **estados** con duración/stacks.

| Archivo | Contenido | Por qué |
|---|---|---|
| `modifier_data.gd` | `class_name ModifierData extends Resource`. `target_attribute: Enum { DAMAGE, BLOCK, ENERGY, DRAW }`, `operation: Enum { ADD, MULTIPLY }`, `value: float`, `condition: String` (opcional). | Ej: "cartas de ataque hacen +50% daño" = `DAMAGE, MULTIPLY, 1.5, condition="card.tags.has(ATTACK)"`. |
| `modifier_manager.gd` | `class_name ModifierManager`. `add(mod)`, `remove(mod)`, `calculate(base_value, context) -> float`. | Apila modifiers y calcula valor final. Permanente o temporal. |

**Cuándo usar modifier vs status**:
- Status: temporal con stacks (veneno x3, vulnerable 2 turnos).
- Modifier: permanente o condicional ("relíquia: +1 energía en turnos pares").

---

### `systems/events/` — Eventos de mapa

| Archivo | Contenido | Por qué |
|---|---|---|
| `event_data.gd` | `class_name EventData extends Resource`. `id`, `title`, `description`, `choices: Array[EventChoice]`. | La definición del evento. |
| `event_choice.gd` | `class_name EventChoice`. `label`, `outcome: Callable` o `effect_id`. | Cada opción del evento. |
| `event_resolver.gd` | `apply_choice(event, choice, run_state) -> Result`. | Ejecuta la elección del jugador y modifica el run_state. |
| `data/campfire.tres` | Choices: `[Descansar (+30% HP), Forjar (+5 max HP)]`. | |
| `data/shop.tres` | Choices dinámicos: comprar carta, comprar relic, comprar poción. Precio por item. | |

---

### `entities/` — Definición de actores (solo data)

| Archivo | Contenido | Por qué |
|---|---|---|
| `hero_data.gd` | `class_name HeroData extends Resource`. `id`, `name`, `max_hp`, `starting_deck: Array[CardData]`, `starting_relic: RelicData`, `portrait: Texture2D`. | Definición del héroe. |
| `enemies/enemy_data.gd` | `class_name EnemyData extends Resource`. `id`, `name`, `max_hp_range: Vector2i`, `ai: EnemyAI`, `intent_pattern: Array`, `loot_table: Dictionary`. | Definición del enemigo. El `ai` es un resource con la composición de behaviors. |

**Instancias concretas**:
- `hero/data/guerrero.tres`, `mago.tres`, `picaro.tres`.
- `enemies/data/esqueleto.tres`, `goblin.tres`, `jefe_ogro.tres`.

---

### `cards/` — Sistema de cartas (solo data + effects)

| Archivo | Contenido | Por qué |
|---|---|---|
| `card_data.gd` | `class_name CardData extends Resource`. `id`, `name`, `description`, `cost: int`, `tags: Array[String]`, `rarity: Rarity`, `effects: Array[CardEffect]`, `art: Texture2D`. | La plantilla inmutable. |
| `card_instance.gd` | `class_name CardInstance extends RefCounted`. `data: CardData`, `cost_override: int` (null si no modificado), `upgrades: int`, `temporary_modifiers: Array`. Métodos `get_cost() -> int`, `upgrade()`. | El runtime. Una carta en el mazo es un `CardInstance` apuntando a un `CardData`. Permite upgrades, modificadores temporales, sin tocar el `.tres`. |
| `data/tajo.tres` | cost 1, effects `[DamageEffect(amount=6)]`, tags `["attack"]`. | |
| `data/estocada.tres` | cost 1, effects `[DamageEffect(amount=4), DrawEffect(amount=1)]`. | |
| `data/bloqueo.tres` | cost 1, effects `[BlockEffect(amount=5)]`, tags `["skill"]`. | |
| `data/meditar.tres` | cost 0, effects `[DrawEffect(amount=2)]`, tags `["skill"]`. | |
| `effects/card_effect.gd` | Clase abstracta `class_name CardEffect extends Resource`. `execute(context: CombatContext) -> void`. | Strategy pattern. Cada efecto es su propio resource. |
| `effects/damage_effect.gd` | `extends CardEffect`. `amount: int`. `execute()` crea `TakeDamageAction` y lo manda al resolver. | Encapsula "hacer X daño". |
| `effects/block_effect.gd` | `amount: int`. Aplica `block` al hero. | |
| `effects/draw_effect.gd` | `amount: int`. Llama `deck_manager.draw_card()` n veces. | |
| `effects/apply_status_effect.gd` | `status: StatusData`, `stacks: int`, `target: Enum { SELF, ALL_ENEMIES, RANDOM_ENEMY }`. | |
| `effects/heal_effect.gd` | `amount: int`. | |

---

### `relics/` — Sistema de reliquias

| Archivo | Contenido | Por qué |
|---|---|---|
| `relic_data.gd` | `class_name RelicData extends Resource`. `id`, `name`, `description`, `rarity`, `effects: Array[RelicEffect]`, `counter: int` (0 = pasivo, >0 = cargas). | Definición. |
| `relic_instance.gd` | `class_name RelicInstance`. `data: RelicData`, `counter: int`, `enabled: bool`. Métodos `tick()`, `consume_charge()`. | Runtime: cuenta cuántas veces se activó, cuántas cargas le quedan. |
| `effects/relic_effect.gd` | Abstracto. `on_event(event_name: String, context) -> void`. | Se suscribe al signal_bus. |
| `effects/on_play_card_effect.gd` | Escucha `SignalBus.card_played`. Ej: "Anillo de Brasas — al jugar carta de ataque, +2 daño". | |
| `effects/on_take_damage_effect.gd` | Escucha `SignalBus.hero_damaged`. Ej: "Cenizas de Fénix — al morir, resucitar con 50% HP". | |
| `effects/on_turn_start_effect.gd` | Escucha `SignalBus.turn_started`. Ej: "+1 energía en el primer turno". | |
| `effects/on_kill_enemy_effect.gd` | Escucha `SignalBus.enemy_died`. Ej: "+5 oro por cada kill". | |

**Instancias concretas en `data/`**:
- `anillo_brasas.tres`: rarity COMMON. Effect: OnPlayCard (condición: tags.has("attack") → +2 daño).
- `cenizas_fenix.tres`: rarity RARE. Effect: OnTakeDamage (condición: hp ≤ 0 → resucitar con 50% HP, consumir carga).
- `ojo_auditivo.tres`: rarity UNCOMMON. Effect: OnTurnStart (primer turno → +1 energía).

---

### `weapons/` — Armas equipables

| Archivo | Contenido | Por qué |
|---|---|---|
| `weapon_data.gd` | `class_name WeaponData extends Resource`. `id`, `name`, `damage_bonus: int`, `block_bonus: int`, `slots: int` (1 o 2 manos), `tags: Array[String]`, `special_effect: CardEffect` (opcional). | Definición. El `special_effect` permite armas con efecto único ("Katana: al atacar, aplicas sangrado"). |
| `data/arma_basica.tres` | damage +1. | |
| `data/baculo.tres` | damage +0, special_effect: ApplyStatusEffect(strength, 1) al inicio de combate. | |
| `data/espadon.tres` | damage +4, slots 2 (ocupa 2 manos). | |
| `data/katana_basica.tres` | damage +3, special_effect: ApplyStatusEffect(sangrado, 2). | |

---

### `scenes/` — Escenas raíz

**Regla**: cada escena raíz tiene un `.tscn` + un `.gd` controlador. La escena instancia componentes de `ui/` y orquesta lógica de `core/`.

| Carpeta | Contenido | Por qué |
|---|---|---|
| `scenes/battle/battle_table.tscn` | Escena principal de combate. Instancia enemigos, mano, HUD. | La "pantalla" de batalla. |
| `scenes/battle/battle_table.gd` | Controlador. Escucha `SignalBus` para actualizar vista. Llama a `CombatResolver` en respuesta a input del jugador. | Vista + input → core. |
| `scenes/battle/hand_controller.gd` | Maneja el layout espacial de la mano (fan, posición de cartas, hover). Recibe orden de `DeckManager`. | Separado de la lógica de mazo. |
| `scenes/map/map_view.tscn` + `.gd` | Renderiza los `RoomData` del floor actual. Click en nodo → `RunStateMachine.transition_to(BATTLE)`. | |
| `scenes/event/event_view.tscn` + `.gd` | Muestra `EventData` y sus `EventChoice`. Click → `EventResolver.apply_choice()`. | |
| `scenes/reward/reward_view.gd` | Pantalla post-batalla: elegir carta, oro, relic. | |

---

### `ui/` — Componentes de interfaz reutilizables

**Regla de oro**: `ui/` = componentes atómicos reutilizables. `scenes/` = pantallas completas que los instancian.

| Carpeta | Contenido | Por qué |
|---|---|---|
| `ui/cards/card_ui.tscn` + `.gd` | Representación visual de UNA carta. Recibe un `CardInstance`. Muestra cost, nombre, art, description. Hover/play animations. | Separado de `cards/data/` para que la lógica sea testeable sin escena. |
| `ui/battle/hp_bar.tscn` | Barra de HP reutilizable (hero y enemigos la usan). Recibe `max_hp, current_hp`. | Componente atómico. |
| `ui/battle/intent_display.tscn` | Muestra qué va a hacer el enemigo (icono de espada + número). | |
| `ui/battle/energy_counter.tscn` | "3/3" de energía. | |
| `ui/battle/block_indicator.tscn` | Escudo sobre HP. | |
| `ui/inventory/inventory_modal.tscn` + `.gd` | Modal que abre con Tab/Esc. Muestra mazo actual, reliquias, arma equipada. | |
| `ui/map/map_node.tscn` | Nodo visual del mapa (un círculo con icono de tipo). | |
| `ui/map/sanctuary_view.tscn` | Vista de descanso (descansar/forjar). | |
| `ui/map/room_inspector.tscn` | Tooltip al hacer hover sobre un nodo: muestra tipo y recompensa potencial. | |
| `ui/menus/main_menu.tscn` | "Nuevo Juego / Cargar / Opciones / Salir". | |
| `ui/menus/slot_select.tscn` | 3 slots de guardado. | |
| `ui/menus/hero_select.tscn` | Selección de héroe al iniciar run. | |
| `ui/run/hud_battle.tscn` | HUD superior: piso, oro, HP del héroe, mapa mini. | |
| `ui/run/map_overlay.tscn` | Overlay del mapa entre pisos. | |
| `ui/run/shop_view.tscn` | Vista de tienda. | |
| `ui/system/pause_menu.tscn` | Pausa: continuar/guardar/salir. | |
| `ui/system/debug_overlay.tscn` | Overlay de debug: mostrar hitboxes, FPS, forzar evento. **Solo en builds de debug.** | |

---

### `assets/` — Recursos binarios

| Subcarpeta | Contenido |
|---|---|
| `art/cards/` | Arte de cartas. |
| `art/enemies/` | Sprites de enemigos. |
| `art/heroes/` | Retratos/sprites de héroes. |
| `art/relics/` | Iconos de reliquias. |
| `art/ui/` | Iconos genéricos (energía, oro, escudo). |
| `art/map/` | Iconos de tipos de sala, background de mapa. |
| `audio/sfx/` | Sonidos: golpe, robo, descarte. |
| `audio/music/` | Música por zona. |
| `audio/ui/` | Clicks, hovers. |
| `fonts/` | Tipografías. Recomendado: Noto Sans para UI, una display font para títulos. |

---

### `tests/` — GUT

| Archivo | Contenido | Por qué |
|---|---|---|
| `combat/test_combat_resolver.gd` | Test integral: jugar carta de daño, verificar HP enemigo, verificar energía gastada, verificar carta en descarte. | El combate es lo más crítico. |
| `combat/test_status_manager.gd` | Aplicar veneno x5, tick, verificar daño aplicado, verificar expira a los 3 turnos. | |
| `combat/test_actions.gd` | PlayCard, undo, verificar estado revertido. | Validar Command pattern. |
| `deck/test_deck_manager.gd` | Robo hasta vaciar mazo, verificar mezcla de descarte, verificar no se pierden cartas. | |
| `run/test_rarity_system.gd` | Simular 1000 rolls, verificar distribución aproxima a los pesos. | |
| `run/test_run_state_machine.gd` | Transiciones válidas/inválidas. No permite BATTLE→EVENT sin pasar por REWARD. | |
| `run_tests.cfg` | Config GUT: qué tests correr, con qué flags. | Permite `godot --script run_tests.cfg` en CI. |

---

## Reglas de oro

1. **`core/` no conoce `scenes/` ni `ui/`.** La lógica de juego es testeable sin levantar escenas.RunState.generate_combat_rewards() no sabe que existe un RewardView.
2. **Data vs Instance**: cada `.tres` es plantilla inmutable; el runtime usa `*_instance.gd` con estado.
3. **Signal bus primero**: si dos subsistemas necesitan hablar, usan `SignalBus`, no referencias directas.
4. **No `load()` desparramado**: todo recurso se pide a `GameDatabase`.
5. **Tests obligatorios** para `combat_resolver`, `status_manager`, `deck_manager`, `run_state_machine` y `rarity_system`.
6. **No crear acoplamientos nuevos entre `systems/`**: si `statuses` necesita hablar con `events`, lo hace por signal bus.
7. **Una acción = un `CombatAction`**: cualquier cosa que modifique estado de combate va por el command pattern.
8. **`*.tres` solo data, nunca lógica**: si un resource necesita comportamiento, vá a `effects/` con un script.
9. **Las vistas no mutan dominio** : RewardView no llama a run.player_gold += ... directamente. Emite señales (card_chosen, skipped) y el RunDirector aplica los cambios vía RunState.apply_combat_rewards().

---

## Patrones de diseño aplicados

| Patrón | Dónde | Para qué |
|---|---|---|
| **Singleton** | `autoload/` | Servicios globales: signal bus, database, persistence. |
| **Strategy** | `cards/effects/`, `relics/effects/`, `enemies/behaviors/` | Cambiar comportamiento sin tocar la clase base. |
| **Observer** | `signal_bus.gd` | Desacoplar emisores de receptores. |
| **State Machine** | `core/run/run_state_machine.gd` | Transiciones de run explícitas. |
| **Data-Resource** | Todos los `*.tres` | Configuración editable desde el inspector. |
| **Flyweight** | `*_data.gd` + `*_instance.gd` | Compartir data inmutable entre instancias runtime. |
| **Composition over inheritance** | `enemies/behaviors/` | IA compuesta por behaviors, no herencia rígida. |

---
## Decisiones Tecnicas
---
## ¿Por qué RewardView no genera sus propias recompensas?
RewardView es una vista pura. No decide qué recompensas tocaron, no muta el estado del juego. Toda la lógica de "qué oro/cartas/relic salen" vive en RunState.generate_combat_rewards(), que es determinista (usa FloorGenerator.get_floor_subseed()) y testeable con GUT.

Beneficios:

Determinismo: al recargar una partida, las recompensas son las mismas.
Testeable: generate_combat_rewards() es una función pura, se puede testear sin escena.
Reusabilidad: si en el futuro se quiere mostrar un panel "recompensas obtenidas" en el inventario, se llama al mismo método de RunState.
Separación de capas: la vista solo muestra y emite señales; el orquestador (RunDirector) muta el estado.

## ¿Por qué RewardView se construye 100% en código (sin .tscn)?
Porque RewardView es un modal transitorio que se crea y destruye en runtime, con muchas animaciones procedurales (tweens, hover magnético, idle float). Construirlo en código:

Evita problemas de layout (top_level = true, set_anchors_and_offsets_preset).
Permite forzar top_level = true para que se dibuje sobre todo, sin heredar el transform del padre.
Centraliza las animaciones en un solo lugar (sin repartirlas entre .gd y .tscn).
Las escenas .tscn se reservan para layouts estáticos que se diseñan visualmente en el editor. RewardView no es eso.

## ¿Por qué CombatResolver no usa Command pattern?
El CombatResolver es stateless: todos sus métodos son static, no mantieneestado mutable entre llamadas, y cada cálculo es puro (entrada → salida sinside effects). Esto significa que no hay estado que proteger con comandosreversibles.

La separación de responsabilidades se logra con el patrón Pure Logic + UI Orchestrator:

core/combat/combat_resolver.gd → lógica pura, testeable sin escena.
scenes/battle/battle_table.gd → orquestación de turnos + UI + animaciones(await, hud.set_banner_message(), card.pulse(), card.queue_free()).
El BattleTable llama a métodos estáticos del CombatResolver y maneja elfeedback visual entre medio.

Si en el futuro se necesita:

Undo para debugging → implementar Command pattern encima del resolver actual.
Replay de partidas → loggear llamadas al resolver.
Logging de balance → ya tenés los métodos puros, solo agregar print.
Ninguno de estos escenarios rompe la arquitectura actual.

## Decisión: Data vs Instance

El patrón más importante del proyecto. Aplica a `cards`, `relics` y `statuses`.

### El problema

Si mutás un `.tres` en runtime, **rompés todo el mazo**. Ejemplo clásico:
- Jugás una carta que dice "esta carta cuesta 1 menos este turno".
- Si escribís en `card_data.cost -= 1`, estás modificando el `.tres`.
- La próxima vez que robes esa carta del mazo, va a tener costo reducido para siempre.
- Al guardar la partida, persistís el costo reducido. Bug.

### La solución

Dos clases por cada concepto:

```
CardData (.tres)               CardInstance (RefCounted, runtime)
─────────────────              ─────────────────────────────────
id: "card_tajo"                data: CardData
name: "Tajo"                   cost_override: int (null = usar data.cost)
cost: 1                        upgrades: int
tags: ["attack"]               temporary_modifiers: Array
effects: [DamageEffect(6)]     played_this_turn: bool
rarity: COMMON
							   get_cost() -> int:
INMUTABLE                          return cost_override if not null
								   return data.cost
```

- El `.tres` no se toca nunca en runtime.
- El `CardInstance` es lo que vive en el mazo, mano y descarte.
- Una misma carta (`tajo.tres`) puede tener 3 `CardInstance` en el mazo, cada uno con su propio estado.

### Aplicación

| Concepto | Data | Instance |
|---|---|---|
| Carta | `card_data.gd` | `card_instance.gd` |
| Reliquia | `relic_data.gd` | `relic_instance.gd` |
| Status | `status_data.gd` | `status_instance.gd` |

---

## Decisión: `scenes/` vs `ui/`

Sin regla clara, esto se vuelve caos. Definición:

| | `scenes/` | `ui/` |
|---|---|---|
| **Qué** | Pantallas completas | Componentes atómicos |
| **Instancia** | Una por vez (la pantalla activa) | Múltiples instancias (10 cartas en mano, 3 enemigos) |
| **Ejemplos** | `battle_table.tscn`, `map_view.tscn` | `card_ui.tscn`, `hp_bar.tscn`, `intent_display.tscn` |
| **Conoce** | `core/`, instancia `ui/` | Solo su data de input, emite señales al signal bus |
| **Controlador** | `*.gd` orquesta subsistemas | `*.gd` solo maneja presentación |

### Test: ¿va en `scenes/` o `ui/`?

- ¿Se instancia una vez por partida? → `scenes/`
- ¿Se instancia múltiples veces? → `ui/`
- ¿Es una "pantalla" completa? → `scenes/`
- ¿Es un componente que otra pantalla instancia? → `ui/`

---

## Checklist: agregar X al proyecto

### Agregar una carta nueva

- [ ] Crear `cards/data/<nombre>.tres` con tipo `CardData`.
- [ ] Configurar `id`, `name`, `description`, `cost`, `tags`, `rarity`.
- [ ] Si el efecto es estándar (damage, block, draw), instanciar un `Effect` existente.
- [ ] Si el efecto es nuevo, crear `cards/effects/<nombre>_effect.gd` heredando de `CardEffect`.
- [ ] Agregar el `.tres` al catálogo en `game_database.gd`.
- [ ] Si tiene lógica compleja, escribir test en `tests/cards/test_<nombre>.gd`.
- [ ] Verificar que el `card_ui.tscn` renderiza bien la carta.

### Agregar una reliquia nueva

- [ ] Crear `relics/data/<nombre>.tres` con tipo `RelicData`.
- [ ] Crear el effect en `relics/effects/on_<evento>_effect.gd` si no existe.
- [ ] Conectar el effect al signal bus correspondiente.
- [ ] Agregar al `game_database.gd`.
- [ ] Test: simular el evento, verificar que la reliquia reacciona.

### Agregar un enemigo nuevo

- [ ] Crear `entities/enemies/data/<nombre>.tres` con tipo `EnemyData`.
- [ ] Si la IA es estándar, componer behaviors existentes.
- [ ] Si la IA es nueva, crear `core/enemies/behaviors/<nombre>_behavior.gd`.
- [ ] Definir `intent_pattern` y `loot_table`.
- [ ] Agregar al `game_database.gd`.
- [ ] Test de IA: simular N turnos, verificar que las acciones tienen sentido.

### Agregar un status nuevo

- [ ] Crear `systems/statuses/data/<nombre>.tres` con tipo `StatusData`.
- [ ] Definir `stack_behavior` y `tick_type`.
- [ ] Si tiene lógica custom al aplicarse (no estándar), crear effect dedicado.
- [ ] Test: aplicar, tick, expirar.

### Agregar una escena/pantalla nueva

- [ ] Crear `scenes/<area>/<nombre>_view.tscn` + `.gd`.
- [ ] El `.gd` solo orquesta: escucha signal bus, llama a `core/`, instancia componentes de `ui/`.
- [ ] Agregar transición desde `run_state_machine.gd` si es parte del loop de run.
- [ ] No meter lógica de `core/` en el `.gd`.

### Agregar un componente UI

- [ ] Crear `ui/<area>/<nombre>.tscn` + `.gd`.
- [ ] Recibe data por setter o constructor.
- [ ] Emite señales propias (no usa signal bus si es atómico).
- [ ] Reutilizable: no hardcodear IDs o referencias a escenas concretas.

---

## FAQ

**¿Por qué `core/` y no `game/`?**
`core/` es más explícito: lógica central, sin UI. `game/` era ambiguo (¿todo el juego o solo lógica?).

**¿Por qué separar `entities/` de `core/`?**
`entities/` solo tiene data (`*_data.gd`). `core/` tiene lógica. Si los mezclás, terminás con scripts de lógica referencing recursos visuales.

**¿Por qué `systems/` no está dentro de `core/`?**
`systems/` son subsistemas transversales que pueden ser usados por `core/combat`, `core/run`, etc. Si los metés dentro de `core/`, generás dependencias circulares conceptuales.

**¿Puedo saltear el Command pattern al principio?**
Sí, pero te vas a arrepentir. El `combat_resolver` se vuelve inmanejable a las 20 cartas. Empezá con `combat_action.gd` abstracto y 2 acciones concretas, ya está.

**¿Por qué GUT y no los tests nativos de Godot?**
Godot 4 no tiene testing framework nativo. GUT es el estándar de facto, mantiene con Godot 4, y tiene CLI para CI.

**¿Necesito `addons/gut/` commiteado?**
Sí. Si no lo commiteás, CI no tiene cómo correr tests sin descargar GUT primero. GUT oficial recomienda commitearlo.
