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
6. [Decisión: Data vs Instance](#decisión-data-vs-instance)
7. [Decisión: `scenes/` vs `ui/`](#decisión-scenes-vs-ui)
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
│   │   ├── combat_action.gd
│   │   └── actions/
│   │       ├── play_card_action.gd
│   │       ├── take_damage_action.gd
│   │       ├── apply_status_action.gd
│   │       └── end_turn_action.gd
│   ├── deck/
│   │   ├── deck_manager.gd
│   │   └── card_pile.gd
│   ├── hero/
│   │   └── hero_ability.gd
│   ├── enemies/
│   │   ├── enemy_ai.gd
│   │   └── behaviors/
│   │       ├── attack_behavior.gd
│   │       ├── defend_behavior.gd
│   │       └── flee_behavior.gd
│   ├── run/
│   │   ├── run_director.gd
│   │   ├── run_state.gd
│   │   ├── run_state_machine.gd
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
│   ├── relic_instance.gd
│   ├── data/
│   │   ├── anillo_brasas.tres
│   │   ├── cenizas_fenix.tres
│   │   └── ojo_auditivo.tres
│   └── effects/
│       ├── relic_effect.gd
│       ├── on_play_card_effect.gd
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
│   │   ├── map_view.tscn
│   │   └── map_view.gd
│   ├── event/
│   │   ├── event_view.tscn
│   │   └── event_view.gd
│   └── reward/
│       ├── reward_view.tscn
│       └── reward_view.gd
│
├── ui/
│   ├── cards/
│   │   ├── card_ui.tscn
│   │   └── card_ui.gd
│   ├── battle/
│   │   ├── hp_bar.tscn
│   │   ├── intent_display.tscn
│   │   ├── energy_counter.tscn
│   │   └── block_indicator.tscn
│   ├── inventory/
│   │   ├── inventory_modal.tscn
│   │   └── inventory_modal.gd
│   ├── map/
│   │   ├── map_node.tscn
│   │   ├── sanctuary_view.tscn
│   │   └── room_inspector.tscn
│   ├── menus/
│   │   ├── main_menu.tscn
│   │   ├── slot_select.tscn
│   │   └── hero_select.tscn
│   ├── run/
│   │   ├── hud_battle.tscn
│   │   ├── map_overlay.tscn
│   │   └── shop_view.tscn
│   └── system/
│       ├── pause_menu.tscn
│       └── debug_overlay.tscn
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

### `core/combat/` — Resolución de combate (lógica pura)

| Archivo | Contenido | Por qué |
|---|---|---|
| `combat_action.gd` | Clase abstracta: `class_name CombatAction`. Métodos `execute() -> void` (abstract) y `undo() -> void` (abstract). Guarda referencia al `CombatResolver`. | **Command pattern**. Cada acción (jugar carta, recibir daño) es un objeto. Te regala undo (para debug), replay, y limpieza determinística al fin de turno. |
| `combat_resolver.gd` | Stack de `CombatAction`, HP actual de hero/enemies, energía, turno actual, referencias al `StatusManager` y `DeckManager`. Métodos `play_card(card)`, `end_turn()`, `start_turn()`. | El orquestador. No implementa daño directo: despacha a acciones. |
| `actions/play_card_action.gd` | Hereda de `CombatAction`. `execute()` verifica energía, gasta energía, llama al `CardEffect` de la carta. `undo()` revierte. | Acción atómica jugable. |
| `actions/take_damage_action.gd` | `execute()` reduce HP y aplica statuses derivados (si vulnerable, +50%). `undo()` restaura. | El daño no es solo restar HP: hay que reaccionar a vulnerable, block, etc. |
| `actions/apply_status_action.gd` | `execute()` llama a `StatusManager.apply(target, status_data, stacks)`. | |
| `actions/end_turn_action.gd` | `execute()` ticlea statuses, descarta mano, roba 5, resetea energía. `undo()` revierte todo eso. | Fin de turno es donde más cosas se rompen. |

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
| `hero_ability.gd` | Clase abstracta `class_name HeroAbility`. `activate(combat_resolver) -> void`. Subclases concretas definen skills. | Skills activables del héroe (no son cartas). Ej: "Curar 5 HP", "Robar 2 cartas". |
| `enemy_ai.gd` | Clase abstracta. `decide_action(enemy, combat_state) -> CombatAction`. El enemigo recibe contexto y devuelve una acción. | Separar dato (EnemyData) de comportamiento. |
| `enemies/behaviors/attack_behavior.gd` | `extends Behavior`. `decide()` devuelve `TakeDamageAction` al héroe. | Estrategia de IA compuesta. |
| `enemies/behaviors/defend_behavior.gd` | `decide()` aplica `Block` a sí mismo. | |
| `enemies/behaviors/flee_behavior.gd` | `decide()` decide huir si HP < umbral. | |

**Composición de IA**: un enemigo puede tener `[AttackBehavior, FleeBehavior]`. El `enemy_ai.gd` itera los behaviors y elige según prioridad.

---

### `core/run/` — Estado de la partida

| Archivo | Contenido | Por qué |
|---|---|---|
| `run_state.gd` | Datos: `floor: int`, `gold: int`, `current_hero: HeroData`, `deck: Array[CardInstance]`, `relics: Array[RelicInstance]`, `hp: int`, `max_hp: int`. | El estado serializable. Lo que se guarda/carga. |
| `run_state_machine.gd` | Enum `State { MENU, MAP, BATTLE, REWARD, EVENT, SHOP, DEAD, VICTORY }`. `transition_to(new_state)`. Emite señales por signal_bus. | **FSM explícita**. Evita el bug clásico de "entré a batalla y al evento al mismo tiempo". |
| `run_director.gd` | Orquestador de alto nivel. Decide qué hacer en cada transición: si `BATTLE → REWARD`, llama al `floor_generator` para ver si ganaste el piso. | El "director de película" de la run. |
| `rarity_system.gd` | Pesos de rareza: `COMMON = 70`, `UNCOMMON = 25`, `RARE = 5`. `roll_rarity()` devuelve un enum. Pool bonus por floor. | StS-style: a mayor floor, más chances de rarezas. |

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
| `hero_data.gd` | `class_name HeroData extends Resource`. `id`, `name`, `max_hp`, `starting_deck: Array[CardData]`, `starting_relic: RelicData`, `ability: HeroAbility`, `portrait: Texture2D`. | Definición del héroe. El `ability` se carga como sub-resource o por id. |
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
| `scenes/reward/reward_view.tscn` + `.gd` | Pantalla post-batalla: elegir carta, oro, relic. | |

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

1. **`core/` no conoce `scenes/` ni `ui/`.** La lógica de juego es testeable sin levantar escenas.
2. **Data vs Instance**: cada `.tres` es plantilla inmutable; el runtime usa `*_instance.gd` con estado.
3. **Signal bus primero**: si dos subsistemas necesitan hablar, usan `SignalBus`, no referencias directas.
4. **No `load()` desparramado**: todo recurso se pide a `GameDatabase`.
5. **Tests obligatorios** para `combat_resolver`, `status_manager`, `deck_manager`, `run_state_machine` y `rarity_system`.
6. **No crear acoplamientos nuevos entre `systems/`**: si `statuses` necesita hablar con `events`, lo hace por signal bus.
7. **Una acción = un `CombatAction`**: cualquier cosa que modifique estado de combate va por el command pattern.
8. **`*.tres` solo data, nunca lógica**: si un resource necesita comportamiento, vá a `effects/` con un script.

---

## Patrones de diseño aplicados

| Patrón | Dónde | Para qué |
|---|---|---|
| **Singleton** | `autoload/` | Servicios globales: signal bus, database, persistence. |
| **Command** | `core/combat/actions/` | Acciones reversibles, undo, replay, debug. |
| **Strategy** | `cards/effects/`, `relics/effects/`, `enemies/behaviors/` | Cambiar comportamiento sin tocar la clase base. |
| **Observer** | `signal_bus.gd` | Desacoplar emisores de receptores. |
| **State Machine** | `core/run/run_state_machine.gd` | Transiciones de run explícitas. |
| **Data-Resource** | Todos los `*.tres` | Configuración editable desde el inspector. |
| **Flyweight** | `*_data.gd` + `*_instance.gd` | Compartir data inmutable entre instancias runtime. |
| **Composition over inheritance** | `enemies/behaviors/` | IA compuesta por behaviors, no herencia rígida. |

---

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

## Guía de migración desde la arquitectura anterior

Si venís de la versión con `game/` monolítico, esta es la migración sugerida:

### Paso a paso (un commit por paso)

1. **Crear la estructura de carpetas vacías** con archivos `.gd` placeholder (`class_name` declarado, `## TODO` en el cuerpo).

2. **Mover autoloads** (si cambiaron path):
   - `autoload/game_database.gd` → igual
   - `autoload/persistence_manager.gd` → igual
   - `autoload/signal_bus.gd` → igual
   - Actualizar paths en `project.godot` (sección `[autoload]`).

3. **Mover `game/battleTable/` → `scenes/battle/`**:
   - `battle_table.gd` → `scenes/battle/battle_table.gd`
   - `battle_table.tscn` → `scenes/battle/battle_table.tscn`
   - `card_board_controller.gd` → `scenes/battle/hand_controller.gd` (renombrar)

4. **Mover lógica de `game/` → `core/`**:
   - `game/combat/combat_resolver.gd` → `core/combat/combat_resolver.gd`
   - `game/deck/deck_manager.gd, card_pile.gd` → `core/deck/`
   - `game/run/run_director.gd, run_state.gd, rarity_system.gd` → `core/run/`
   - `game/map/floor_generator.gd, room_data.gd` → `core/map/`
   - `game/constants/combat_constants.gd` → `core/constants/`

5. **Crear `core/hero/`** (nuevo, simetría con enemies):
   - `hero_ability.gd` (clase abstracta vacía).

6. **Mover `game/enemies/` → `core/enemies/` + `entities/enemies/`**:
   - Lógica IA → `core/enemies/enemy_ai.gd` + `behaviors/`
   - Data → `entities/enemies/enemy_data.gd` + `data/`

7. **Mover `game/hero/` → `entities/hero/`**:
   - `heroData.gd` → `entities/hero/hero_data.gd` (renombrar a snake_case)
   - `data/*.tres` → `entities/hero/data/`

8. **Separar UI de cartas**:
   - `cards/card_data.gd` → `cards/card_data.gd` (igual)
   - `cards/card_ui.gd, .tscn` → `ui/cards/card_ui.gd, .tscn`
   - `cards/data/*.tres` → `cards/data/`
   - `cards/effects/` → `cards/effects/`

9. **Crear `card_instance.gd`** (nuevo). Migrar runtime state que estaba en `card_ui.gd` o donde sea.

10. **Crear `systems/statuses/`** (nuevo):
    - `status_data.gd`, `status_instance.gd`, `status_manager.gd`
    - Migrar status logic que estaba desparramada en `combat_resolver.gd`.

11. **Crear `systems/modifiers/`** (nuevo).

12. **Crear `systems/events/`** (nuevo):
    - Migrar eventos que estaban en `game/map/` o en `ui/map/`.

13. **Crear `core/combat/actions/`** (nuevo):
    - Refactor `combat_resolver.gd` para despachar acciones en vez de mutar directamente.
    - Crear `combat_action.gd`, `play_card_action.gd`, `take_damage_action.gd`, `apply_status_action.gd`, `end_turn_action.gd`.

14. **Crear `core/run/run_state_machine.gd`** (nuevo):
    - Si ya tenías lógica de transiciones, moverla acá.

15. **Crear `assets/`, `addons/gut/`, `tests/`**:
    - Mover arte y audio a `assets/`.
    - Instalar GUT en `addons/gut/`.
    - Escribir tests prioritarios: `test_combat_resolver.gd`, `test_deck_manager.gd`.

16. **Actualizar todos los `preload`/`load`** que apunten a los viejos paths. Godot te va a marcar los rotos en el editor.

17. **Correr el juego y verificar que funciona igual que antes.**

18. **Commit final: "refactor: migrate to layered architecture"**.

### Consejos

- Hacelo en un branch dedicado: `refactor/architecture`.
- Un commit por paso. Si rompés algo, revertís un commit, no todo.
- Corré el juego después de cada paso.
- Los `.tres` no se rompen al moverlos (Godot guarda UIDs). Pero si renombrás clases (`class_name`), tenés que actualizar los `.tres` que las referencian.

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
