# 🃏 Card Prototype — Roguelike Deckbuilder (Godot 4)

Prototipo de juego **2D Roguelike Deckbuilder** desarrollado en **Godot Engine 4.x (GDScript)**. El proyecto implementa una arquitectura desacoplada basada en recursos personalizados (`Resource`), un bus de eventos global (`SignalBus`), generación procedural de mapas por semillas (`FloorGenerator`), sistema de rarezas ponderadas, sinergias de reliquias, armas equipables y persistencia en múltiples ranuras de guardado.

---

## 📑 Tabla de contenidos

1. [Requisitos y ejecución](#-requisitos-y-ejecución)
2. [Cómo correr los tests](#-cómo-correr-los-tests)
3. [Arquitectura general y principios de diseño](#-arquitectura-general-y-principios-de-diseño)
4. [Estructura de directorios](#-estructura-de-directorios)
5. [Flujo de ejecución](#-flujo-de-ejecución-execution-flow)
6. [Relación entre componentes principales](#-relación-entre-componentes-principales)
7. [Guía de edición y extensibilidad](#-guía-de-edición-y-extensibilidad)
8. [Herramientas de desarrollo y debugging](#-herramientas-de-desarrollo-y-debugging)
9. [Reglas de oro](#-reglas-de-oro)
10. [Convenciones](#-convenciones)
11. [Git](#-git)
12. [Documentación adicional](#-documentación-adicional)
13. [Roadmap](#-roadmap)

---

## 🚀 Requisitos y ejecución

### Requisitos

- **Godot Engine 4.3+** (recomendado 4.4 por estabilidad de `Resource` UIDs).
- **GUT (Godot Unit Test)** incluido en `addons/gut/`.
- Opcional: **GDScript LSP** para tu editor (VSCode, Neovim).

### Setup

```bash
# 1. Clonar
git clone <repo-url> card-prototype
cd card-prototype

# 2. Abrir el proyecto en Godot
# Godot Launcher → Import → seleccionar project.godot

# 3. GUT ya viene commiteado en addons/gut/, no hace falta instalar nada.
```

### Cómo correr el juego

```bash
# Desde Godot Editor
F5  → corre la escena principal (main_menu.tscn)
F6  → corre la escena actual (útil para probar battle_table.tscn aislada)

# Desde CLI
godot --path .                          # abre el editor
godot --path . --main-scene res://ui/menus/main_menu.tscn
```

---

## 🧪 Cómo correr los tests

```bash
# CLI (para CI / pre-commit)
godot --path . --script res://tests/run_tests.cfg

# Desde el editor
# Panel inferior → GUT → Run All
```

Resultados esperados: **todos los tests en `tests/` deben pasar en verde** antes de cualquier commit a `main`.

Tests prioritarios cubren: `combat_resolver`, `status_manager`, `deck_manager`, `run_state_machine`, `rarity_system`.

---

## 📐 Arquitectura general y principios de diseño

El proyecto está diseñado bajo tres pilares técnicos para evitar el acoplamiento rígido entre la interfaz (UI) y la lógica de negocio:

### 1. Diseño Orientado a Datos (Data-Driven Design con `Resource`)

Toda entidad estática o configurable (Cartas, Efectos de Cartas, Héroes, Enemigos, Reliquias, Efectos de Reliquias, Armas y Statuses) hereda de `Resource`. La lógica de ejecución se inyecta mediante composición de recursos (patrón *Strategy*), permitiendo crear nuevas cartas o reliquias desde el Inspector de Godot combinando scripts de efectos sin modificar el motor de combate.

**Patrón Data vs Instance**: cada `.tres` es plantilla inmutable; el runtime usa `*_instance.gd` con estado. Esto evita el bug clásico de mutar el `.tres` y romper todo el mazo (ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#decisión-data-vs-instance)).

### 2. Arquitectura Dirigida por Eventos (`SignalBus`)

Los componentes de UI (`battle_hud`, `map_view`, `card_ui`) y los controladores de lógica (`combat_resolver`, `run_director`, `deck_manager`) se comunican a través de un *Autoload* centralizado (`SignalBus`), evitando referencias cruzadas frágiles (`get_node("../../..")`).

Es el bus de eventos central. Cualquier subsistema emite/escucha sin acoplamiento — **crítico** para reliquias reactivas (que se suscriben a `card_played`, `enemy_died`, `turn_started`, etc.).

### 3. Estado Centralizado de Partida (`RunState` & `RunDirector`)

El estado mutable de una *run* (HP actual/máximo, oro, piso, semilla, mazo actual, reliquias equipadas, arma activa y mapa generado) vive en `RunState`, mientras que `RunDirector` orquesta las transiciones entre escenas/vistas (Menú → Selección de Héroe → Mapa → Combate / Tienda / Santuario) y gestiona el guardado automático mediante `PersistenceManager`.

La máquina de estados explícita (`run_state_machine.gd`) define las transiciones válidas y evita el bug clásico de "entré a batalla y al evento al mismo tiempo".

---

## 📂 Estructura de directorios

```text
card-prototype/
├── README.md
├── .gitignore
├── project.godot
│
├── docs/                       # Documentación
│   ├── GDD.md                  # Game Design Document
│   └── ARCHITECTURE.md         # Detalle técnico archivo por archivo
│
├── autoload/                   # Singletons globales (Autoloads)
│   ├── game_database.gd        # Registro central y catálogo de recursos (.tres)
│   ├── persistence_manager.gd  # Guardado/Carga en JSON/ConfigFile (3 slots + stats)
│   └── signal_bus.gd           # Bus de señales globales desacopladas
│
├── core/                       # LÓGICA PURA (sin .tscn, sin escenas)
│   ├── combat/                 # Resolución de turnos y daño
│   ├── deck/                   # Pilas: robo, mano, descarte (deck_manager, card_pile)
│   ├── enemies/                # IA enemiga: orquestador + behaviors
│   │   ├── enemy_ai.gd
│   │   └── behaviors/          # Attack, Defend, Charge (componibles)
│   ├── run/                    # Estado de run, FSM, director, rarezas
│   │   ├── run_director.gd
│   │   ├── run_state.gd
│   │   ├── run_state_machine.gd
│   │   └── rarity_system.gd
│   ├── map/                    # Generación procedural (floor_generator, room_data)
│   └── constants/              # combat_constants.gd
│
├── systems/                    # Subsistemas transversales
│   ├── statuses/               # Buffs/debuffs: data + instance + manager
│   ├── modifiers/              # Modificadores de atributos
│   └── events/                 # Eventos de mapa (data + choice + resolver)
│
├── entities/                   # Definición de actores (solo data)
│   ├── hero/                   # hero_data.gd + data/*.tres
│   └── enemies/                # enemy_data.gd + data/*.tres
│
├── cards/                      # SOLO DATA de cartas
│   ├── card_data.gd            # Resource base de definición
│   ├── card_instance.gd        # Runtime state (cost override, upgrades) FALTA
│   ├── data/                   # Instancias .tres (tajo, estocada, etc.)
│   └── effects/                # Estrategias modulares (CardEffect)
│
├── relics/                     # Sistema de Reliquias
│   ├── relic_data.gd           # Resource base
│   ├── relic_instance.gd       # Runtime (contador, cargas)
│   ├── data/                   # .tres (anillo_brasas, cenizas_fenix, etc.)
│   └── effects/                # Lógica modular (RelicEffect)
│
├── weapons/                    # Armas equipables
│   ├── weapon_data.gd
│   └── data/                   # .tres (arma_basica, bacuto, espadon, katana_basica)
│
├── scenes/                     # Escenas raíz (.tscn + controlador .gd)
│   ├── battle/                 # battle_table.tscn, battle_table.gd, hand_controller.gd
│   ├── map/                    # map_view.tscn + .gd
│   ├── event/                  # event_view.tscn + .gd   FALTA
│   ├── reward/                 # reward_view.gd (UI EN CODIGO)
│   ├── shop/                   # TIENDA
│   └── menus/                  # Menús principales 
│
├── ui/                         # Componentes UI atómicos reutilizables
│   ├── cards/                  # card_ui.tscn + .gd (separado de cards/data)
│   ├── battle/                 # hp_bar, intent_display, energy_counter, block_indicator
│   ├── inventory/              # Modal de inventario y equipamiento
│   ├── map/                    # map_node, sanctuary_view, room_inspector
│   ├── menus/                  # main_menu, slot_select, hero_select
│   ├── run/                    # HUD de batalla, overlay de mapa, tienda
│   └── system/                 # Pausa y Debug Overlay
│
├── assets/                     # Recursos binarios
│   ├── art/                    # cards, enemies, heroes, relics, ui, map
│   ├── audio/                  # sfx, music, ui
│   └── fonts/
│
├── addons/
│   └── gut/                    # Godot Unit Test (commiteado)
│
└── tests/                      # Tests con GUT
	├── combat/
	├── deck/
	├── run/
	└── run_tests.cfg
```

> **Regla de oro**: `scenes/` = pantallas completas (una instancia activa por vez). `ui/` = componentes atómicos (múltiples instancias). Detalle en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#decisión-scenes-vs-ui).

---

## 🔄 Flujo de ejecución (Execution Flow)

### 1. Inicialización y Menús (`ui/menus/`)

1. Al iniciar el proyecto, se cargan en memoria los Autoloads: `SignalBus`, `GameDatabase` (indexando todas las cartas, reliquias, héroes, armas y enemigos disponibles) y `PersistenceManager`.
2. **`main_menu.tscn`** presenta el ingreso principal y deriva a **`slot_select.tscn`**.
3. En **`slot_select.tscn`**, el jugador elige entre **3 ranuras de guardado (Save Slots)**:
   - Si el slot tiene una partida activa, `PersistenceManager` deserializa el estado hacia `RunState` y `RunDirector` reanuda la partida en la vista del mapa (`map_view.tscn`).
   - Si el slot está vacío (o se borra), se transiciona a **`hero_select.tscn`**, donde se instancian tarjetas visuales leyendo los recursos de `entities/hero/data/`.

### 2. Creación de la Run y Generación Procedural (`core/run/` & `core/map/`)

1. Al confirmar un héroe (`guerrero.tres`, `mago.tres`, `picaro.tres`), **`RunDirector`** inicializa un nuevo **`RunState`**:
   - Asigna estadísticas base del `HeroData` (HP máximo, energía base, oro inicial, arma inicial y mazo de origen).
   - Genera o asigna la **semilla (Seed)** de la partida para garantizar determinismo en la generación aleatoria.
2. **`FloorGenerator`** construye la topología del piso actual creando una red/grilla de objetos **`RoomData`** (Salas de Combate normal, Élite, Jefe, Tienda, Tesoro y Santuario/Descanso).
3. Se guarda el estado inicial en el slot activo mediante `PersistenceManager` y se despliega **`map_view.tscn`**.

### 3. Navegación en el Mapa (`scenes/map/` & `ui/map/`)

- El jugador visualiza los nodos (`map_node.tscn`) conectados. Puede inspeccionar detalles con `room_inspector.tscn` o abrir su inventario/mazo con `inventory_modal.tscn`.
- Al seleccionar un nodo adyacente válido, `RunDirector` evalúa el tipo de `RoomData`:
  - **Santuario (`sanctuary_view.tscn`):** Permite curar un porcentaje de HP o mejorar/modificar recursos antes de seguir.
  - **Tienda (`shop_view.tscn`):** Utiliza `RaritySystem` y `GameDatabase` para ofertar cartas, reliquias y armas a cambio de oro.
  - **Evento (`event_view.tscn`):** Muestra `EventData` y sus `EventChoice`, ejecuta `EventResolver.apply_choice()`.
  - **Combate / Jefe (`battle_table.tscn`):** Transiciona a la mesa de batalla instanciando al enemigo correspondiente (`esqueleto.tres`, `jefe_ogro.tres`).

### 4. Ciclo de Combate (`scenes/battle/battle_table.gd` & `core/combat/combat_resolver.gd`)

El combate sigue una máquina de estados por turnos orquestada entre `battle_table.gd`, `combat_resolver.gd` y `deck_manager.gd`:

1. **Inicio del Combate (`Battle Start`):**
   - `DeckManager` clona el mazo de `RunState` en la pila de robo (`draw_pile` vía `CardPile`) y la baraja.
   - Se disparan los efectos de reliquias de inicio de combate (suscriptos a `SignalBus.battle_started`).
   - Se inicializa `hud_battle.tscn` mostrando vida, escudo, energía, arma equipada y estados alterados.
2. **Inicio del Turno del Jugador (`Player Turn Start`):**
   - Se restaura la energía máxima del jugador y se resetea o actualiza el bloqueo según las reglas de `combat_constants.gd`.
   - Se procesan estados de inicio de turno sobre el jugador (ej. daño por quemadura/veneno si aplica).
   - `DeckManager` roba $N$ cartas de `draw_pile` hacia `hand` (si `draw_pile` se vacía, recicla y baraja `discard_pile`).
   - `hand_controller.gd` organiza visualmente las instancias de `card_ui.tscn` en la mano.
3. **Fase de Acción (Juego de Cartas y Armas):**
   - Cuando el jugador arrastra o selecciona una carta (`card_ui.gd`), se verifica si tiene energía suficiente.
   - Al jugarse, `CombatResolver` despacha un `PlayCardAction` (Command pattern) que itera sobre el array `effects: Array[CardEffect]` del `CardData` (y aplica modificadores del arma activa en `WeaponData` o sinergias de combo como `on_play_card_effect.gd`).
   - Cada `CardEffect` ejecuta su método polimórfico aplicando daño, defensa, robo de cartas o estados alterados.
   - La carta jugada pasa a `discard_pile` y se emite señal por `SignalBus` para actualizar el HUD.
4. **Fin del Turno y Turno Enemigo (`Enemy Turn`):**
   - Las cartas restantes en mano se descartan.
   - El enemigo (`enemy_data.gd` + `enemy_ai.gd` + `behaviors/`) ejecuta su intención declarada (ataque, bloqueo o aplicación de estado).
   - Se procesan los *ticks* de estados alterados de fin de turno (Veneno, Quemadura, Hemorragia, Congelación, Shock).
5. **Resolución del Combate (`Victory / Defeat`):**
   - Si el HP del jugador llega a 0, `CombatResolver` verifica si posee una reliquia de resurrección (`on_take_damage_effect.gd` como *Cenizas de Fénix*). Si no, declara derrota, actualiza estadísticas globales en `PersistenceManager` y limpia la *run* activa del slot.
   - Si el enemigo muere, se otorga recompensa de oro/cartas/reliquias ponderadas por `RaritySystem`, se actualiza `RunState`, se guarda el progreso y se regresa a `map_view.tscn`.

---

## 🧩 Relación entre componentes principales

| Componente | Responsabilidad Principal | Se comunica con... |
| :--- | :--- | :--- |
| **`SignalBus`** *(Autoload)* | Canal central de notificaciones (cambios de HP, energía, robo de cartas, fin de turno, navegación). | Todos los nodos de UI y controladores de combate/run. |
| **`GameDatabase`** *(Autoload)* | Carga y expone diccionarios/arrays con todas las cartas, reliquias, armas, héroes y enemigos del juego por ID. | `PersistenceManager`, `ShopView`, `RaritySystem`, `DebugOverlay`. |
| **`PersistenceManager`** *(Autoload)* | Serializa `RunState` en disco para los 3 slots y registra métricas históricas de partidas. | `RunDirector`, `SlotSelectView`, `GameDatabase`. |
| **`RunDirector` & `RunState`** | Mantiene los datos vivos de la partida actual y controla qué pantalla se muestra en cada momento. | `FloorGenerator`, `BattleTable`, `MapView`, `ShopView`, `SanctuaryView`. |
| **`RunStateMachine`** | FSM explícita: `MENU → MAP → BATTLE → REWARD → EVENT → SHOP → DEAD → VICTORY`. | `RunDirector`, `SignalBus`. |
| **`CombatResolver`** | Calcula daños finales, bloqueos, resistencias, estados alterados, bonus de armas y triggers de reliquias. Despacha `CombatAction` (Command pattern). | `BattleTable`, `Enemy`, `CardEffect`, `RelicEffect`, `WeaponData`, `StatusManager`. |
| **`DeckManager` & `CardPile`** | Administra el ciclo de vida lógico de las cartas entre Pila de Robo, Mano y Pila de Descarte. | `BattleTable`, `HandController`, `DrawEffect`. |
| **`StatusManager`** | Aplica, hace tick y expira statuses por entidad (poison, vulnerable, weak, strength, etc.). | `CombatResolver`, `CombatAction`. |
| **`DebugOverlay`** | Consola/panel in-game para alterar oro, vida, agregar cartas/reliquias/armas en caliente o forzar victorias. | `RunState`, `CombatResolver`, `DeckManager`, `GameDatabase`. |
| **`EnemyAI`** | Orquestador de IA enemiga. Itera los behaviors del `EnemyData.intent_pattern` y devuelve el primer `EnemyIntent` no-null. Fallback a Attack. | `Enemy`, `EnemyBehavior`, `EnemyIntent`. |
| **`RunStateMachine`** | FSM explícita de la run. Valida transiciones legales (`BATTLE → REWARD → MAP`). Evita bugs de estados simultáneos. | `RunDirector`, `SignalBus`. |
| **`RewardView`** | Vista pura de recompensas. Muestra oro + 3 cartas + relic. Anima con tweens. Emite `card_chosen` o `skipped`. No muta dominio. | `RunDirector`, `RunState` (vía signals). |

---

## 🛠️ Guía de edición y extensibilidad

Gracias a la arquitectura basada en `Resource`, **no necesitás tocar el código del motor de combate para agregar contenido**. Todo se edita desde el Inspector de Godot.

### 1. Cómo crear o editar una Carta (`CardData`)

1. En el panel *FileSystem* de Godot, navegá a `res://cards/data/`.
2. Hacé clic derecho → **Create New → Resource...** y buscá la clase **`CardData`** (`card_data.gd`). Guardala como `mi_nueva_carta.tres`.
3. En el **Inspector**, configurá sus propiedades exportadas (`@export`):
   - **Identificación y UI:** ID único, Nombre, Descripción, Icono/Textura y Costo de Energía.
   - **Rareza / Tipo:** Ataque, Habilidad, Poder, y su nivel de rareza (usado por `RaritySystem`).
   - **Efectos (`effects`):** En el array de efectos, agregá nuevos elementos instanciando subclases de `CardEffect` (ubicadas en `res://cards/effects/`):
	 - `damage_effect.gd`: Daño directo.
	 - `defense_effect.gd`: Otorga escudo/bloqueo.
	 - `burn_effect.gd`: Aplica acumulaciones de Quemadura.
	 - `poison_effect.gd`: Aplica Veneno.
	 - `freeze_effect.gd`: Aplica Congelación.
	 - `hemorrhage_effect.gd`: Aplica Sangrado/Hemorragia.
	 - `shock_effect.gd`: Aplica Electrocución/Shock.
	 - `steal_effect.gd`: Roba cartas adicionales del `DeckManager`.
	 - `apply_status_effect.gd`: Aplica un status genérico.	FALTA
	 - `heal_effect.gd`: Cura al héroe.	 FALTA
	 - `multiply_effect.gd`: Multiplica valores de estado o daño.
4. Registrá o verificá que la ruta esté indexada en `autoload/game_database.gd` si el cargador no escanea el directorio automáticamente.

### 2. Cómo crear un Nuevo Efecto de Carta (`CardEffect`)

Si querés una mecánica que no existe (ej. curar vida al golpear):

1. Creá un nuevo script en `res://cards/effects/heal_effect.gd` que herede de `CardEffect` (`extends CardEffect`).
2. Declarale un `class_name HealEffect` y tus variables `@export var heal_amount: int = 5`.
3. Sobrescribí el método de ejecución (`execute` / `apply`) recibiendo el contexto del `CombatResolver` / objetivo, y modificá el estado correspondiente. Automáticamente aparecerá en el desplegable del Inspector para cualquier carta.

### 3. Cómo crear o editar un Héroe (`HeroData`)

1. Andá a `res://entities/hero/data/` y hacé doble clic en cualquiera de los existentes (`guerrero.tres`, `mago.tres`, `picaro.tres`) o creá un nuevo recurso de tipo **`HeroData`** (`hero_data.gd`).
2. Desde el Inspector podés modificar:
   - Nombre de clase, descripción y retrato.
   - Vida máxima inicial (`max_hp`), Energía por turno y Oro inicial.
   - **Arma inicial:** Arrastrá un archivo `.tres` de `res://weapons/data/` al slot de arma inicial.
   - **Mazo inicial (`starting_deck`):** Arrastrá los archivos `.tres` de `res://cards/data/` que conforman las cartas iniciales del personaje.

### 4. Cómo crear o editar un Arma (`WeaponData`)

1. Navegá a `res://weapons/data/` (ej. `arma_basica.tres`, `baculo.tres`, `espadon.tres`, `katana_basica.tres`).
2. Creá o editá un recurso **`WeaponData`** (`weapon_data.gd`).
3. Ajustá sus modificadores de daño base, escalado elemental/físico, pasivas asociadas o sinergias con tipos de cartas. El campo `special_effect` puede referenciar un `CardEffect` para habilidades únicas (ej. "Katana: al atacar, aplicar Sangrado").

### 5. Cómo crear o editar una Reliquia (`RelicData`)

1. En `res://relics/data/`, creá un recurso de tipo **`RelicData`** (`relic_data.gd`).
2. Configurá su nombre, icono, rareza, descripción y asignale uno o más recursos hijos de **`RelicEffect`** (`res://relics/effects/`):
   - `on_play_card_effect.gd`: Trigger al jugar una carta (ej. *Anillo de Brasas*: +2 daño en cartas de ataque).
   - `on_take_damage_effect.gd`: Trigger al recibir daño (ej. *Cenizas de Fénix*: revive al morir con 50% HP).
   - `on_turn_start_effect.gd`: Trigger al inicio de turno (ej. *Ojo Auditivo*: +1 energía en el primer turno).
   - `on_kill_enemy_effect.gd`: Trigger al matar enemigo (ej. +5 oro por kill).
   - `relic_stat_bonus_effect.gd`: Modifica stats máximos (ej. +HP, +Energía como *Núcleo Sobrecargado*, +Tamaño de mano como *Bolsillo Dimensional*).
   - `relic_start_status_effect.gd`: Aplica estados al enemigo o al jugador al iniciar la pelea (ej. *Colmillo de Víbora*).
   - `relic_combo_synergy_effect.gd`: Otorga bonificaciones al encadenar múltiples cartas en un mismo turno (ej. *Catalizador de Combo*).
   - `relic_revive_effect.gd`: Impide la muerte del jugador una vez y restaura vida.

### 6. Cómo crear o editar un Enemigo (`EnemyData`)

6. Cómo crear o editar un Enemigo (EnemyData)
1. En `res://entities/enemies/data/`, creá un recurso de tipo EnemyData (enemy_data.gd).
2. Configurá: `enemy_name`, `base_hp`, `base_damage`, `is_boss`, `artwork`.
3. Patrón de IA (intent_pattern): agregá behaviors desde el Inspector. El EnemyAI los itera en orden y usa el primer intent no-null.
	AttackBehavior(damage=8, every=1) — ataca cada turno.
	DefendBehavior(block=10, every=3) — gana escudo cada 3 turnos.
	ChargeBehavior(bonus=1.5, every=3) — carga un turno, golpea fuerte el siguiente.
4. El bloqueo del enemigo persiste 2 turnos: gana block en su turno, lo usa contra tu combo del turno siguiente, y se resetea al inicio de su próximo turno.
5. Ejemplo: esqueleto.tres con [DefendBehavior(5, every=3), AttackBehavior(8, every=1)] → defiende cada 3, ataca el resto.

UI fuera del resolver: CombatResolver es stateless (todos static). Cualquier cosa con await, hud, card.pulse(), card.queue_free() va en scenes/battle/battle_table.gd, no en core/combat/.
### 7. Cómo crear o editar un Status (`StatusData`)

1. En `res://systems/statuses/data/`, creá un recurso **`StatusData`** (`status_data.gd`).
2. Configurá: `id`, `name`, `icon`, `stack_behavior` (REPLACE / ADD / MAX_CAP), `tick_type` (NONE / TURN_START / TURN_END).
3. Si tiene lógica custom al aplicarse, creá un `CardEffect` dedicado que dispare `StatusManager.apply()`.

### 8. Cómo crear o editar un Evento de mapa (`EventData`)

1. En `res://systems/events/data/`, creá un recurso **`EventData`** (`event_data.gd`).
2. Configurá `title`, `description` y un array de `EventChoice` (`event_choice.gd`), cada uno con `label` y un `outcome` (Callable o `effect_id`).
3. `EventResolver.apply_choice()` ejecuta la lógica al elegir.

### 9 Cómo crear o editar Recompensas de combate ### 
Las recompensas se generan en RunState.generate_combat_rewards() (lógica de dominio, determinista). Para modificar los parámetros:
1. Abrí run_state.gd → generate_combat_rewards().
2. Oro base: gold := 10 + (current_floor * 2) + randi() % 5. Ajustá la fórmula.
3. Cantidad de cartas: el for i in range(3) controla cuántas cartas se ofrecen.
4. Chance de relic: if rng.randf() < 0.3 → ajustá el 0.3 (30%).
5. Seed determinista: usa FloorGenerator.get_floor_subseed(master_seed, current_floor * 1000 + combat_index). Cada sala tiene recompensas únicas y reproducibles.
r
Para agregar un nuevo tipo de recompensa (ej: pociones), agregá el campo al Dictionary retornado y manejalo en apply_combat_rewards() y en RewardView._render_rewards().
---

## 🔧 Herramientas de desarrollo y debugging

El proyecto incluye un **`DebugOverlay`** (`res://ui/system/debug_overlay.tscn`) integrado para acelerar el testeo y balanceo sin tener que jugar toda la *run*:

- Permite inyectar oro, curar o dañar al héroe en tiempo real.
- Permite agregar cualquier carta, reliquia o arma registrada en `GameDatabase` directamente al inventario o a la mano actual.
- Permite matar instantáneamente enemigos para probar recompensas y transiciones de pisos en `FloorGenerator`.
- **Solo en builds de debug** (se desactiva en release vía flag de compilación).

---

## 🥇 Reglas de oro

1. **`core/` no conoce `scenes/` ni `ui/`.** La lógica de juego es testeable sin levantar escenas.
2. **Data vs Instance**: cada `.tres` es plantilla inmutable; el runtime usa `*_instance.gd` con estado.
3. **Signal bus primero**: si dos subsistemas necesitan hablar, usan `SignalBus`, no referencias directas.
4. **No `load()` desparramado**: todo recurso se pide a `GameDatabase`.
5. **Tests obligatorios** para `combat_resolver`, `status_manager`, `deck_manager`, `run_state_machine` y `rarity_system`.
6. **No crear acoplamientos nuevos entre `systems/`**: si `statuses` necesita hablar con `events`, lo hace por signal bus.
7. **UI fuera del resolver: `**: CombatResolver es stateless (todos static). Cualquier cosa con await, hud, card.pulse(), card.queue_free() va en scenes/battle/battle_table.gd, no en core/combat/.
8. **`*.tres` solo data, nunca lógica**: si un resource necesita comportamiento, vá a `effects/` con un script.
9. **`Las vistas no mutan dominio**:  RewardView no llama a run.player_gold += ... directamente. Emite señales (card_chosen, skipped) y el RunDirector aplica los cambios vía RunState.apply_combat_rewards().
---

## 📐 Convenciones

- **Nombres de archivos**: `snake_case.gd`, `snake_case.tscn`, `snake_case.tres`.
- **Nombres de clases**: `PascalCase` con `class_name` declarado.
- **Recursos `.tres`**: nombres descriptivos en español (`tajo.tres`, `cenizas_fenix.tres`).
- **IDs**: strings en minúsculas con guion bajo (`"card_tajo"`, `"relic_anillo_brasas"`).
- **Señales del signal bus**: pasado simple (`card_played`, `enemy_died`, `turn_started`).
- **`scenes/` vs `ui/`**: pantallas completas en `scenes/`, componentes atómicos reutilizables en `ui/`.

---

## 🔧 Git

### `.gitignore` recomendado

```gitignore
# Godot
.godot/
*.import
export_presets.cfg
/android/

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
```

### Commits

- Commitear `addons/gut/` completo (evita reinstalar en CI).
- **No commitear** `*.import` ni `.godot/` (regenerados por Godot).

---

## 📚 Documentación adicional

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — reglas de "qué va dónde", detalle archivo por archivo, patrones aplicados, decisión Data/Instance, `scenes/` vs `ui/`, guía de migración, checklists por tipo de adición.
- [`docs/GDD.md`](docs/GDD.md) — Game Design Document: visión, core loop, mecánicas, 3 héroes detallados, catálogo de cartas/reliquias/armas, statuses, enemigos, mapa procedural, eventos, rarezas, economía, balance numérico, UI/UX, roadmap.

---

## 🗺️ Roadmap

1. **MVP**: combate 1v1, mazo básico, 1 héroe, 1 enemigo, 1 piso.
2. **Run loop**: mapa procedural, 3 pisos, 1 boss, recompensas.
3. **Sistemas**: statuses, reliquias, tienda, eventos.
4. **Contenido**: 3 héroes, 30 cartas, 15 reliquias, 10 enemigos, 3 bosses.
5. **Meta-progreso**: 3 slots, stats globales, unlocks.

---

## 📄 Licencia

Por definir. Sugerido: MIT para código, CC-BY 4.0 para assets.
