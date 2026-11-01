# 🃏 Card Prototype — Arquitectura y Documentación Técnica


### Características Principales

* **Sistema de Combate Basado en Cartas y Efectos Modulares:** Las cartas ejecutan secuencias de efectos desacoplados (Daño, Defensa, Quemadura, Congelación, Veneno, Hemorragia, Electrocución/Shock, Robo, Multiplicadores).

* **Mecánica de Armas (`weapons/`):** Los héroes equipan armas (Espadón, Katana, Báculo, etc.) que interactúan con el combate y escalan o condicionan las jugadas.

* **Sistema de Reliquias (`relics/`):** Ítems pasivos que otorgan bonificaciones de estadísticas, aplican estados al inicio del combate, crean sinergias de combos o permiten revivir (ej. *Cenizas de Fénix*, *Catalizador de Combo*).

* **Generación Procedural de Pisos (`floor_generator.gd`):** Creación dinámica del mapa de nodos (`map_node_view.gd`), permitiendo elegir rutas hacia combates, tiendas o santuarios.

* **Sistema de Rarezas y Economía (`rarity_system.gd`, `shop_view.gd`):** Probabilidades ponderadas para la aparición de cartas y reliquias según su rareza.

* **Persistencia Multi-Slot (`persistence_manager.gd`):** Guardado y carga del estado de la partida en diferentes ranuras (*slots*).

* **Herramientas de Desarrollo Integradas (`debug_overlay.gd`):** Panel de depuración en tiempo real para probar cartas, alterar estados o saltar salas.

## 🏗️ 2. Arquitectura General y Árbol del Proyecto

El proyecto sigue una **arquitectura orientada a datos (Data-Driven Design)** apoyada en recursos personalizados de Godot (`Resource` / `.tres`) y una **arquitectura desacoplada por eventos** mediante un bus de señales global (`SignalBus`).

```
card-prototype/
├── autoload/                  # Singletons globales (Estado global, Base de datos y Eventos)
│   ├── game_database.gd       # Registro centralizado de todas las cartas, reliquias, armas y héroes
│   ├── persistence_manager.gd # Sistema de guardado/carga por slots en disco
│   └── signal_bus.gd          # Bus de eventos global para desacoplar UI de la lógica
│
├── cards/                     # Sistema de Cartas
│   ├── card_data.gd           # Clase Resource base para definir una carta
│   ├── card_ui.gd / .tscn     # Representación visual e interactiva de la carta en mano/mesa
│   ├── data/                  # Archivos .tres de cartas (tajo, estocada, sobre_carga, etc.)
│   └── effects/               # Lógica modular de efectos (burn, damage, defense, freeze, etc.)
│
├── relics/                    # Sistema de Reliquias (Pasivas)
│   ├── relic_data.gd          # Clase Resource base para definir una reliquia
│   ├── data/                  # Archivos .tres de reliquias (anillo_brasas, pata_conejo, etc.)
│   └── effects/               # Efectos pasivos/triggers (combo_synergy, revive, stat_bonus, etc.)
│
├── weapons/                   # Sistema de Armas
│   ├── weapon_data.gd         # Clase Resource base para definir armas
│   └── data/                  # Archivos .tres de armas (arma_basica, baculo, espadon, katana_basica)
│
├── game/                      # Núcleo Jugable (Core Loop)
│   ├── battleTable/           # Escena principal y orquestador maestro (`battle_table.gd/.tscn`)
│   ├── combat/                # Motor matemático y de reglas de combate (`combat_resolver.gd`)
│   ├── constants/             # Constantes globales y enumeraciones (`combat_constants.gd`)
│   ├── deck/                  # Gestión de pilas: robo, descarte, mano (`deck_manager.gd`, `card_pile.gd`)
│   ├── hand/                  # Controlador espacial de las cartas en mano (`card_board_controller.gd`)
│   ├── hero/                  # Definición de clases de personaje (`heroData.gd` y `.tres` en `data/`)
│   ├── enemies/               # Lógica de IA/estado enemigo (`enemy.gd`, `enemyData.gd` y `data/`)
│   ├── map/                   # Generador de pisos y datos de salas (`floor_generator.gd`, `room_data.gd`)
│   └── run/                   # Estado y dirección de la partida (`run_director.gd`, `run_state.gd`, `rarity_system.gd`)
│
└── ui/                        # Capas de Interfaz de Usuario (Vistas y Modales)
    ├── menus/                 # Menú principal, selección de slot y selección de héroe
    ├── run/                   # HUD de batalla, vista del mapa y vista de tienda
    ├── map/                   # Modales de santuario e inspector de salas/nodos
    ├── inventory/             # Modal de inventario, mazo y reliquias activas
    └── system/                # Menú de pausa y Debug Overlay

```

## ⚙️ 3. Componentes Principales y su Relación

### 3.1. Autoloads (Singletons)

1. **`SignalBus` (`autoload/signal_bus.gd`):**

   * **Rol:** Evita referencias directas frágiles (`get_node()`) entre nodos lejanos.

   * **Relación:** Cuando una carta se juega, un enemigo recibe daño, o cambia el estado de la *Run*, el componente emisor dispara una señal en `SignalBus` y las vistas (`battle_hud.gd`, `inventory_modal_view.gd`) reaccionan actualizando la pantalla.

2. **`GameDatabase` (`autoload/game_database.gd`):**

   * **Rol:** Carga y mantiene un catálogo indexado de todos los recursos `.tres` (Cartas, Reliquias, Armas, Héroes y Enemigos).

   * **Relación:** Es consultado por `RaritySystem`, `ShopView`, `FloorGenerator` y `PersistenceManager` (para reconstruir objetos a partir de sus IDs al cargar una partida).

3. **`PersistenceManager` (`autoload/persistence_manager.gd`):**

   * **Rol:** Serializa y deserializa el objeto `RunState` y los datos del perfil en archivos locales por ranura (*Slot*).

### 3.2. Gestión de la Partida (`game/run/` y `game/map/`)

* **`RunState` (`run_state.gd`):** Contiene la "fotografía" actual de la partida: vida actual/máxima del héroe, oro, piso actual, mazo de cartas acumulado, reliquias equipadas, arma activa y el grafo del mapa.

* **`RunDirector` (`run_director.gd`):** Es el director de orquesta de alto nivel. Decide qué vista mostrar (Menú $\rightarrow$ Selección de Héroe $\rightarrow$ Mapa $\rightarrow$ Combate / Tienda / Santuario) y gestiona las transiciones entre salas.

* **`FloorGenerator` (`floor_generator.gd`) y `RoomData` (`room_data.gd`):** Generan la estructura del piso asignando tipos de salas (Combate normal, Élite, Jefe, Tienda, Santuario) en instancias de `RoomData`.

### 3.3. Motor de Combate y Mesa (`game/battleTable/`, `combat/`, `deck/`, `hand/`)

* **`BattleTable` (`battle_table.gd`):** Nodo raíz de la escena principal de juego. Conecta a los controladores lógicos (`CombatResolver`, `DeckManager`, `RunDirector`) con las capas de UI.

* **`DeckManager` (`deck_manager.gd`) y `CardPile` (`card_pile.gd`):**

  * `CardPile` administra una colección de `CardData` (barajar, extraer, meter al fondo, vaciar).

  * `DeckManager` coordina las pilas de **Robo (Draw Pile)**, **Mano (Hand)** y **Descarte (Discard Pile)** al inicio de cada turno.

* **`CardBoardController` (`card_board_controller.gd`):** Controla la disposición visual en la mesa/mano, el *drag & drop* o selección de instancias de `CardUI`, y valida si la carta puede jugarse.

* **`CombatResolver` (`combat_resolver.gd`):**

  * **Rol:** Es el cerebro matemático del combate.

  * **Relación:** Recibe la carta jugada o el ataque del arma, consulta las reliquias activas en `RunState` (por ejemplo, `RelicComboSynergyEffect`), ejecuta secuencialmente cada `CardEffect` de la carta sobre el objetivo (`Enemy` o Héroe), procesa estados alterados (Quemadura, Veneno, Congelación, Shock, Hemorragia) y verifica condiciones de victoria o derrota (incluyendo `RelicReviveEffect`).

## 🔄 4. Flujo de Ejecución (Execution Flow)

```
[Inicio del Juego]
       │
       ▼
┌──────────────────────┐
│   MainMenuView       │ ──► Selección de Slot (`SlotSelectView`)
└──────────────────────┘
       │ (Nueva Partida o Continuar vía `PersistenceManager`)
       ▼
┌──────────────────────┐
│   HeroSelectView     │ ──► Lee `hero/data/*.tres` desde `GameDatabase`
└──────────────────────┘     Inicializa `RunState` (Mazo base + Arma + Reliquia inicial)
       │
       ▼
┌──────────────────────┐
│   RunDirector        │ ──► Llama a `FloorGenerator` para crear el mapa de `RoomData`
└──────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        BUCLE DE LA RUN (`MapView`)              │
│  El jugador selecciona un nodo disponible (`MapNodeView`)       │
└──────┬──────────────────────┬──────────────────────────┬────────┘
       │                      │                          │
  [Sala Combate/Jefe]    [Sala Tienda]            [Sala Santuario]
       │                      │                          │
       ▼                      ▼                          ▼
┌──────────────┐      ┌───────────────┐         ┌────────────────────┐
│ BattleTable  │      │   ShopView    │         │ SanctuaryModalView │
└──────┬───────┘      └───────┬───────┘         └────────┬───────────┘
       │                      │                          │
       └──────────────────────┴──────────────────────────┘
                              │ (Al completar sala, actualiza `RunState`,
                              ▼  guarda progreso y vuelve a `MapView`)

```

### Flujo Detallado de un Turno de Combate

1. **Inicio del Combate:**

   * `BattleTable` instancia al enemigo basado en `EnemyData` (`enemigo_basico.tres`, `jefe_basico.tres`).

   * Se disparan las reliquias de inicio de combate (`RelicStartStatusEffect`, `RelicStatBonusEffect`).

   * `DeckManager` clona el mazo de `RunState` en la pila de robo y la baraja.

2. **Fase de Robo y Preparación:**

   * `DeckManager` roba $N$ cartas hacia la mano. Si la pila de robo se vacía, recicla y baraja la pila de descarte.

   * `CardBoardController` instancia los nodos `card_ui.tscn` y los posiciona en pantalla.

   * El enemigo calcula y anuncia su intención para el turno.

3. **Fase de Acción del Jugador:**

   * El jugador selecciona/juega cartas (`CardUI`) o utiliza su arma (`WeaponData`).

   * `CombatResolver` recibe la acción, aplica modificadores de armas/reliquias y ejecuta el array de `CardEffect` de la carta.

   * La carta jugada pasa a la pila de descarte y `BattleHUD` se actualiza mediante `SignalBus`.

4. **Fin del Turno del Jugador y Turno Enemigo:**

   * Se resuelven efectos de daño por turno (Veneno, Quemadura, Hemorragia) y estados de control (Congelación, Shock).

   * Si el enemigo sigue vivo y no está incapacitado, ejecuta su acción contra el héroe.

5. **Resolución del Encuentro:**

   * **Si el Héroe muere:** `CombatResolver` verifica si posee una reliquia con `RelicReviveEffect` (ej. *Cenizas de Fénix*). Si no, termina la *Run*.

   * **Si el Enemigo muere:** Se otorgan recompensas apoyadas en `RaritySystem`, se guarda el estado con `PersistenceManager` y se regresa al mapa.

## 🛠️ 5. Guía de Edición: ¿Cómo crear o modificar elementos?

Gracias al diseño basado en `Resource` de Godot, **no necesitas tocar el código del motor de combate para agregar contenido nuevo**. Todo se edita desde el Inspector de Godot o creando archivos `.tres`.

### 5.1. ¿Cómo crear o editar una Carta?

1. Ve a la carpeta `cards/data/`.

2. Haz clic derecho en el FileSystem de Godot $\rightarrow$ **Create New** $\rightarrow$ **Resource** y selecciona `CardData` (o duplica una existente como `tajo.tres` o `golpe_fuego.tres`).

3. En el **Inspector**, configura sus propiedades:

   * Nombre, descripción, costo de energía/uso, rareza y textura/icono.

   * **Array de Efectos (`effects`):** Agrega uno o más recursos hijos que hereden de `CardEffect`:

     * `DamageEffect` (`damage_effect.gd`): Daño directo.

     * `DefenseEffect` (`defense_effect.gd`): Otorga escudo/bloqueo.

     * `BurnEffect` (`burn_effect.gd`): Aplica acumulaciones de quemadura.

     * `FreezeEffect` (`freeze_effect.gd`): Aplica congelación.

     * `PoisonEffect` (`poison_effect.gd`): Aplica veneno.

     * `HemorrhageEffect` (`hemorrhage_effect.gd`): Aplica sangrado/hemorragia.

     * `ShockEffect` (`shock_effect.gd`): Aplica electrocución.

     * `StealEffect` (`steal_effect.gd`): Roba cartas o recursos.

     * `MultiplyEffect` (`multiply_effect.gd`): Multiplica valores o efectos previos/siguientes.

4. Guarda el archivo `.tres` en `cards/data/` (asegúrate de que `GameDatabase` lo escanee o esté registrado en su lista).

### 5.2. ¿Cómo crear un Nuevo Efecto de Carta desde cero?

1. Crea un nuevo script en `cards/effects/` que extienda de `CardEffect` (`extends CardEffect`).

2. Declara un `class_name MiNuevoEffect` al inicio del archivo para que aparezca en el Inspector de Godot.

3. Exporta las variables configurables con `@export` (ej. `@export var amount: int = 5`).

4. Sobrescribe el método de ejecución de `CardEffect` para aplicar la lógica sobre el objetivo o el `CombatResolver`.

### 5.3. ¿Cómo crear o editar un Héroe?

1. Ve a `game/hero/data/` (donde están `warrior_hero.tres`, `samurai_hero.tres`, `magic_hero.tres`, `fenix.tres`).

2. Crea o selecciona un recurso de tipo `HeroData` (`heroData.gd`).

3. Edita desde el Inspector:

   * Nombre de la clase, retrato, vida máxima inicial (`max_hp`).

   * **Mazo Inicial:** Array de referencias a recursos `.tres` de `cards/data/`.

   * **Arma Inicial:** Referencia a un recurso `.tres` de `weapons/data/`.

   * **Reliquia Inicial:** Referencia a un recurso `.tres` de `relics/data/`.

### 5.4. ¿Cómo crear o editar una Reliquia?

1. Ve a `relics/data/` (ej. `anillo_brasas.tres`, `catalizador_combo.tres`, `trebol_abismo.tres`).

2. Crea un recurso de tipo `RelicData` (`relic_data.gd`).

3. Asígnale nombre, descripción, rareza, precio en tienda y su efecto modular desde `relics/effects/`:

   * `RelicStatBonusEffect`: Aumenta estadísticas base.

   * `RelicStartStatusEffect`: Aplica un estado al héroe o a los enemigos al empezar la batalla.

   * `RelicComboSynergyEffect`: Reacciona cuando se cumplen secuencias o combos de cartas.

   * `RelicReviveEffect`: Intercepta la muerte del jugador y restaura vida.

### 5.5. ¿Cómo crear o editar un Arma?

1. Ve a `weapons/data/` (`espadon.tres`, `katana_basica.tres`, `baculo.tres`).

2. Edita las propiedades definidas en `weapon_data.gd` (daño base, modificadores pasivos, sinergias con tipos de carta).

### 5.6. ¿Cómo crear o editar un Enemigo?

1. Ve a `game/enemies/data/` (`enemigo_basico.tres`, `jefe_basico.tres`).

2. Crea un recurso de tipo `EnemyData` (`enemyData.gd`).

3. Configura su vida máxima, nombre, sprite, categoría (Normal, Élite, Jefe) y sus patrones de ataque/intenciones que luego ejecutará `enemy.gd`.

## 🧹 6. Notas de Mantenimiento y Buenas Prácticas del Proyecto

* **Constantes de Combate:** Si deseas ajustar valores globales, topes de estados alterados o identificadores de tipos de daño, edita siempre `game/constants/combat_constants.gd` en lugar de usar "números mágicos" dentro de los efectos.

* **Limpieza de Archivos Temporales:** En el directorio `game/battleTable/` existen múltiples archivos temporales generados por Godot (`battle_table.tscn*.tmp`). Es seguro eliminarlos y agregar `*.tmp` a tu `.gitignore`.

* **Uso del Debug Overlay:** Durante las pruebas en el editor, utiliza `ui/system/debug_overlay.gd` para inyectar cartas específicas a tu mano, otorgar oro o forzar saltos de piso sin tener que jugar toda la partida.