## Orquestador principal de la interfaz y flujo del juego (Patrón Mediator).
## Coordina la navegación y transición de estados entre el 
## Menú Principal, el Selector de Guardado, el Mapa de Expedición, la Tienda y la Mesa de Combate.
## `MainMenuView`, `MapView`, `ShopView` y `BattleTable`.
extends RefCounted
class_name RunDirector

## Máquina de estados de la run.
var state_machine: RunStateMachine = RunStateMachine.new()
## Cache de las recompensas actuales para saber qué aplicar cuando el jugador elige
var current_rewards: Dictionary = {}
## Referencia inyectada a la Mesa de Combate (`BattleTable`).
var table: Variant
## Referencia inyectada al estado vivo de la partida (`RunState`).
var run: RunState
## Vista principal de navegación del grafo (matriz `8x8`).
var map_view: MapView
## Vista del menú principal con el resumen del perfil activo.
var main_menu: MainMenuView
## Vista dedicada para la selección de héroe e ingreso opcional de semilla (`HeroSelectView`).
var hero_select_view: HeroSelectView
## Vista interactiva de la tienda mercantil.
var shop_view: ShopView
## Vista del gestor de perfiles y ranuras de guardado (Slots).
var slot_view: SlotSelectView
## Vista modal sobrepuesta para el menú de pausa.
var pause_menu: PauseMenuView

## Constructor del Director. Instancia las vistas principales 
## (`MapView`, `PauseMenuView`, `MainMenuView`, `HeroSelectView`, `ShopView`, `SlotSelectView`) como hijas de la mesa.
## Conecta las señales de transición, precarga el catálogo de héroes y 
## determina el flujo de arranque inicial evaluando si existe un último slot jugado.
func _init(p_table: Control, p_run: RunState) -> void:
	table = p_table
	run = p_run
	
	# 1. Mapa
	map_view = MapView.new()
	map_view.visible = false
	table.add_child(map_view)
	map_view.room_selected.connect(_on_map_room_selected)
	run.weapon_equipped.connect(_on_run_weapon_equipped)
	
	# Menú de Pausa
	pause_menu = PauseMenuView.new()
	table.add_child(pause_menu)
	pause_menu.abandon_run_requested.connect(_on_pause_abandon_run)
	pause_menu.quit_game_requested.connect(_on_pause_quit_game)
	
	# 2. Menú Principal (arranca oculto hasta validar el último slot jugado)
	main_menu = MainMenuView.new()
	main_menu.visible = false
	main_menu.new_run_requested.connect(_on_new_run_requested)
	main_menu.change_slot_requested.connect(_on_change_slot_requested)
	main_menu.quit_requested.connect(_on_main_menu_quit_requested)
	table.add_child(main_menu)

	# 2b. Pantalla dedicada de Selección de Héroe y Semilla
	hero_select_view = HeroSelectView.new()
	hero_select_view.visible = false
	hero_select_view.start_random_run_requested.connect(_on_start_random_run)
	hero_select_view.start_seeded_run_requested.connect(_on_start_seeded_run)
	hero_select_view.cancelled.connect(_on_hero_select_cancelled)
	table.add_child(hero_select_view)
	
	# 3. Tienda
	shop_view = ShopView.new()
	shop_view.visible = false
	table.add_child(shop_view)
	shop_view.closed.connect(_on_shop_closed)
	shop_view.card_bought.connect(_on_shop_card_bought)
	shop_view.relic_bought.connect(_on_shop_relic_bought)

	# 4. Señales de Combate de la Mesa
	table.combat_won.connect(_on_combat_won)
	table.combat_lost.connect(_on_combat_lost)
	
	# 5. Vista de Ranuras de Guardado
	slot_view = SlotSelectView.new()
	table.add_child(slot_view)
	slot_view.slot_chosen.connect(_on_slot_confirmed)
	
	# 6. Precarga del catálogo de héroes en HeroSelectView
	var heroes: Array[HeroData] = GameDatabase.load_all_heroes()
	hero_select_view.setup_heroes(heroes)
	
	# Escuchar transiciones de la FSM
	state_machine.state_changed.connect(_on_state_changed)

	# 7. Bifurcación de arranque: Auto-login con el último perfil jugado o Selector de Ranuras
	var last_slot: int = PersistenceManager.get_last_played_slot()
	
	if last_slot > 0 and PersistenceManager.select_slot(last_slot):
		# Encontró el último slot jugado: ocultamos el selector de ranuras
		slot_view.visible = false
		
		# Si ese slot tenía una run activa guardada, la reanudamos directamente donde quedó
		if PersistenceManager.has_active_run():
			if PersistenceManager.load_active_run(run, table.deck):
				_resume_loaded_run(last_slot)
				return
		
		# Si no tenía una run viva, entra directo al Menú Principal con su perfil ya cargado
		main_menu.visible = true
		main_menu.show_menu()
	else:
		# Primera vez que abre el juego o todos los slots vacíos: va al selector de perfil
		main_menu.visible = false
		hero_select_view.visible = false
		slot_view.refresh_slots()
		slot_view.visible = true

## Abre la pantalla dedicada de selección de héroe (`HeroSelectView`) desde el menú principal.
func _on_new_run_requested() -> void:
	main_menu.visible = false
	hero_select_view.show_view()

## Regresa desde `HeroSelectView` hacia `MainMenuView` manteniendo el perfil activo cargado.
func _on_hero_select_cancelled() -> void:
	hero_select_view.visible = false
	main_menu.show_menu()

## Oculta el selector de héroes, reinicia el estado de la partida con una semilla procedimental (`-1`),
## construye el mazo inicial basado en el héroe elegido y transiciona al mapa.
func _on_start_random_run(hero: HeroData) -> void:
	_start_new_run(hero, -1, "Partida iniciada con: %s" % hero.hero_name)

## Inicia una partida con semilla personalizada elegida desde `HeroSelectView`.
func _on_start_seeded_run(hero: HeroData, custom_seed: int) -> void:
	_start_new_run(hero, custom_seed, "Partida iniciada con %s | Semilla: %d" % [hero.hero_name, custom_seed])

## Limpia los elementos efímeros de la run anterior antes de crear una nueva.
func _start_new_run(hero: HeroData, p_seed: int, map_message: String) -> void:
	main_menu.visible = false
	hero_select_view.visible = false
	map_view.visible = false
	shop_view.visible = false
	map_view.free_travel_enabled = false
	PersistenceManager.delete_active_run()

	table.is_resolving = false
	table.clear_board_visuals()
	table.enemy = null
	table.player_block = 0
	table.attack_button.disabled = false
	table.discard_button.disabled = false

	run.start_new_run(p_seed, hero)
	table.deck.build_initial_deck_for_hero(run)
	table.current_energy = run.max_energy
	table.discards_remaining = run.discards_per_combat
	state_machine.transition_to(RunStateMachine.State.MAP) 
	open_map(map_message)

## Persiste los cambios de equipo realizados desde el mapa para evitar perderlos al cerrar el juego.
func _on_run_weapon_equipped(_weapon: WeaponData) -> void:
	if not map_view or not map_view.visible:
		return
	if PersistenceManager.current_slot <= 0 or run.is_player_dead():
		return
	PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())

## Recopila las cartas activas, invoca el autoguardado y sincroniza todas las métricas 
## del jugador con el nodo visual `MapView`.
## Despliega el mapa en pantalla actualizando su leyenda inferior.
## Si el modo Dios está activo, deshabilita la niebla de guerra.
func open_map(custom_info: String = "") -> void:
	shop_view.visible = false
	map_view.visible = true

	if PersistenceManager.current_slot > 0 and not run.is_player_dead():
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
		
	if run.god_mode:
		run.reveal_entire_floor()
		map_view.free_travel_enabled = true

	var board_cards: Array[CardData] = _get_active_board_cards()

	map_view.setup_floor(
		run,
		table.deck.get_all_owned_cards(board_cards)
	)
	if custom_info != "":
		map_view.legend_label.text = custom_info

## Intercepta el clic en una celda del mapa, actualiza la posición virtual del jugador 
## y emite `SignalBus.room_entered`.
## Evalúa el tipo de sala (`room_type`) para disparar el evento correspondiente 
## (Tesoros, Hogueras, Santuarios, Tienda o iniciar un Combate).
func _on_map_room_selected(room: RoomData) -> void:
	run.player_grid_pos = room.grid_pos
	run.current_room = room
	SignalBus.room_entered.emit(room)

	if room.cleared:
		open_map("Te desplazaste a una sala ya asegurada.")
		return
	match room.room_type:
		#Otorga reliquia aleatoria, limpia la sala y actualiza el mapa.
		RoomData.Type.TREASURE:
			var relic_msg: String = run.grant_random_relic()
			run.clear_and_discover_room(room)
			open_map("SALA DE RELIQUIA! Obtuviste: " + relic_msg)
		#Cura en la hoguera (+25 a 50 HP segun suerte), limpia la sala y actualiza el mapa.
		RoomData.Type.REST:
			var healed: int = run.rest_at_campfire()
			run.clear_and_discover_room(room)
			open_map("HOGUERA: Recuperaste +%d HP (HP: %d/%d)." % [healed, run.player_hp, run.max_player_hp])
		#Abre el modal de bendición en `map_view` con sus dos callbacks.
		RoomData.Type.SANCTUARY:
			map_view.show_sanctuary_modal(
				func():
					var msg1: String = run.apply_sanctuary_relic_and_full_heal()
					run.clear_and_discover_room(room)
					table.refresh_ui()
					open_map("SANTUARIO: " + msg1),
				func():
					var msg2: String = run.apply_sanctuary_max_hp_blessing()
					run.clear_and_discover_room(room)
					table.refresh_ui()
					open_map("SANTUARIO: " + msg2)
			)
		#Oculta el mapa e inicia el encuentro en `table.start_combat_encounter(is_boss)`.
		RoomData.Type.COMBAT, RoomData.Type.ELITE:
			state_machine.transition_to(RunStateMachine.State.BATTLE)
			map_view.visible = false
			table.start_combat_encounter(false)
		RoomData.Type.BOSS:
			state_machine.transition_to(RunStateMachine.State.BATTLE)  # NUEVO
			map_view.visible = false
			table.start_combat_encounter(true)
		# Genera el stock de la tienda una sola vez y abre `shop_view`.
		RoomData.Type.SHOP:
			state_machine.transition_to(RunStateMachine.State.SHOP)  # NUEVO
			# No llamamos a clear_and_discover_room para que la tienda no se cierre
			# Solo descubrimos sus vecinos para poder seguir moviéndonos
			var rooms: Dictionary = run.floor_data.get("rooms", {})
			for n_pos in room.neighbors:
				if rooms.has(n_pos):
					rooms[n_pos].discovered = true
			_open_shop_for_room(room)

## Genera el stock una sola vez y abre la tienda para una sala concreta.
## El stock se serializa en RunState para que las compras no reaparezcan al cargar.
func _open_shop_for_room(room: RoomData) -> void:
	if room == null:
		return
	if not room.shop_initialized:
		room.shop_initialized = true
		room.shop_cards = run.generate_shop_cards(room.grid_pos, 3)
		room.shop_relics = run.generate_shop_relics(room.grid_pos, 2)
	map_view.visible = false
	shop_view.open_shop(run.player_gold, room.shop_cards, room.shop_relics)

## Disparado tras la victoria en un encuentro. 
##Guarda el estado después de aplicar la victoria.
## Ahora transiciona a REWARD en vez de ir directo al mapa.
func _on_combat_won() -> void:
	
	state_machine.transition_to(RunStateMachine.State.REWARD)


## Ejecuta la secuencia de muerte definitiva (Permadeath) cuando el jugador cae en combate.
## Transiciona la FSM a `DEAD`, elimina el archivo de guardado activo, registra la derrota en el perfil
## y devuelve al jugador al menú principal tras una pausa dramática.
func _on_combat_lost() -> void:
	var defeated_floor: int = run.current_floor
	var enemy_name: String = table.enemy.enemy_name if table.enemy else "un enemigo"
	state_machine.transition_to(RunStateMachine.State.DEAD)  

	# La muerte es definitiva: el snapshot anterior no debe poder reanudarse.
	PersistenceManager.delete_active_run()
	PersistenceManager.record_run_finished(false, defeated_floor)

	table.hud.set_banner_message("YOU DIED CAYENDO EN LA PLANTA %d..." % defeated_floor)
	table.attack_button.text = "DERROTA"
	await table.get_tree().create_timer(1.6).timeout

	map_view.visible = false
	shop_view.visible = false
	hero_select_view.visible = false
	map_view.free_travel_enabled = false
	table.is_resolving = false
	table.clear_board_visuals()
	table.enemy = null
	table.attack_button.disabled = false
	main_menu.visible = true
	main_menu.show_menu("HAS MUERTO en la Planta %d ante %s." % [defeated_floor, enemy_name])

## Cierra la vista de la tienda, transiciona la máquina de estados de regreso a `MAP` y refresca el mapa.
func _on_shop_closed() -> void:
	state_machine.transition_to(RunStateMachine.State.MAP) 
	table.refresh_ui()
	open_map("Saliste de la tienda.")

## Procesa la compra de una carta en la tienda. Debita el oro, marca el slot de la sala como vendido (`null`),
## clona y sella la carta dentro del `draw_pile` y persiste el estado de la partida.
func _on_shop_card_bought(card: CardData, cost: int) -> void:
	if card == null or cost < 0 or run.player_gold < cost:
		return
	if table.deck == null or table.deck.draw_pile == null:
		push_error("No se pudo comprar la carta: el mazo de robo no está disponible.")
		return

	# 1. Descontar oro PRIMERO (transacción atómica)
	run.player_gold -= cost

	# 2. Marcar el slot como vendido ANTES de cualquier operación propensa a fallar
	if run.current_room and run.current_room.room_type == RoomData.Type.SHOP:
		var idx: int = run.current_room.shop_cards.find(card)
		if idx != -1:
			run.current_room.shop_cards[idx] = null

	# 3. Agregar la carta al mazo. No usamos ResourceLoader.exists porque
	#    generate_shop_cards() devuelve duplicates en memoria sin resource_path.
	var copy := card.duplicate() as CardData
	if copy:
		if card.resource_path != "":
			copy.resource_name = card.resource_path
		elif card.resource_name != "":
			copy.resource_name = card.resource_name
		table.deck.draw_pile.add_card(copy)
	else:
		push_warning("No se pudo duplicar la carta '%s', pero el oro ya se debitó." % card.title)

	# 4. Refrescar UI y persistir
	shop_view.update_after_purchase(run.player_gold)
	table.refresh_ui()
	if PersistenceManager.current_slot > 0:
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())

## Procesa la compra de una reliquia en la tienda. Debita el oro, equipa la reliquia en el `RunState`,
## anula su slot en el stock de la sala y guarda automáticamente la partida.
func _on_shop_relic_bought(relic: RelicData, cost: int) -> void:
	if relic == null or cost < 0 or run.player_gold < cost:
		return

	run.player_gold -= cost
	run.equip_specific_relic(relic)

	if run.current_room and run.current_room.room_type == RoomData.Type.SHOP:
		var idx: int = run.current_room.shop_relics.find(relic)
		if idx != -1:
			run.current_room.shop_relics[idx] = null

	shop_view.update_after_purchase(run.player_gold)
	table.refresh_ui()
	if PersistenceManager.current_slot > 0:
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())

## Callback disparado al elegir o crear una ranura de guardado en `SlotSelectView`.
## Si el slot contiene una partida activa en curso, la restaura y reanuda; de lo contrario, abre el menú principal con el perfil cargado.
func _on_slot_confirmed() -> void:
	slot_view.visible = false
	hero_select_view.visible = false
	state_machine.transition_to(RunStateMachine.State.MENU)
	# Si el slot tenía una run congelada, restaurarla
	if PersistenceManager.has_active_run():
		if PersistenceManager.load_active_run(run, table.deck):
			_resume_loaded_run(PersistenceManager.current_slot)
			return
			
	# Si no hay partida viva, pasar al menú principal con el perfil ya cargado
	map_view.free_travel_enabled = false
	main_menu.visible = true
	main_menu.show_menu()
	
## Intercepta el botón de "Cambiar Perfil" del menú principal para volver a mostrar el selector de ranuras.
func _on_change_slot_requested() -> void:
	main_menu.visible = false
	hero_select_view.visible = false
	slot_view.refresh_slots()
	slot_view.visible = true

## Captura la pulsación de ESC con prioridad jerárquica:
## 1. Si hay un modal abierto (Inventario General, Inspector de Mazo o Inspector de Pila), lo cierra (vuelve atrás) sin abrir el menú de pausa.
## 2. Si está en `HeroSelectView`, regresa a `MainMenuView`.
## 3. Si no hay modales superpuestos ni menús de inicio activos, abre el menú de pausa.
func handle_unhandled_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# 1. Si el Inventario General está abierto (en el Mapa o en Combate), ESC lo cierra y vuelve atrás
			if map_view and map_view.inventory_modal and map_view.inventory_modal.visible:
				map_view.inventory_modal.visible = false
				table.get_viewport().set_input_as_handled()
				return
			if table and table.hud and table.hud.inventory_modal and table.hud.inventory_modal.visible:
				table.hud.inventory_modal.visible = false
				table.get_viewport().set_input_as_handled()
				return

			# 2. Si el Inspector de Mazo o de Pilas está abierto, ESC también lo cierra y vuelve atrás
			if map_view and map_view.inspector_modal and map_view.inspector_modal.visible:
				map_view.inspector_modal.visible = false
				table.get_viewport().set_input_as_handled()
				return
			if table and table.hud and table.hud.pile_inspector and table.hud.pile_inspector.visible:
				table.hud.pile_inspector.visible = false
				table.get_viewport().set_input_as_handled()
				return

			# 3. Si está en Selección de Héroe, regresa al Menú Principal
			if hero_select_view and hero_select_view.visible:
				_on_hero_select_cancelled()
				table.get_viewport().set_input_as_handled()
				return

			# 4. Solo permitimos abrir Pausa si no estamos en menús de inicio ni con otros modales abiertos
			if not slot_view.visible and not main_menu.visible and not pause_menu.visible:
				pause_menu.open_pause()
				table.get_viewport().set_input_as_handled()

## Elimina permanentemente la partida en curso del disco duro y computa la derrota en las estadísticas del perfil.
## Purga las vistas actuales y regresa al menú principal con el perfil cargado.
func _on_pause_abandon_run() -> void:
	state_machine.transition_to(RunStateMachine.State.MENU) 
	# Eliminamos el snapshot y registramos el abandono como una derrota.
	PersistenceManager.delete_active_run()
	PersistenceManager.record_run_finished(false, run.current_floor)

	map_view.visible = false
	shop_view.visible = false
	hero_select_view.visible = false
	map_view.free_travel_enabled = false
	table.clear_board_visuals()
	table.enemy = null
	table.is_resolving = false

	main_menu.visible = true
	main_menu.show_menu("Has abandonado la expedición.")

## Guarda el estado actual de la partida en el slot activo (o limpia el snapshot si el jugador ya había muerto)
## y cierra ordenadamente la aplicación desde el menú de pausa.
func _on_pause_quit_game() -> void:
	if PersistenceManager.current_slot > 0:
		if run.is_player_dead():
			# Si se sale durante la secuencia de derrota, tampoco debe quedar
			# un snapshot que permita reanudar una partida terminada.
			PersistenceManager.delete_active_run()
			PersistenceManager.record_run_finished(false, run.current_floor)
		else:
			PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
	table.get_tree().quit()
	
## Cierra de forma segura el ejecutable directamente desde el menú base.
func _on_main_menu_quit_requested() -> void:
	table.get_tree().quit()

## Reacciona a los cambios de estado de la FSM.
func _on_state_changed(new_state: RunStateMachine.State) -> void:
	match new_state:
		RunStateMachine.State.REWARD:
			_open_reward_view()
		_:
			pass


## Crea y muestra la vista de recompensas post-batalla.
func _open_reward_view() -> void:
	map_view.visible = false
	shop_view.visible = false

	# Pausar el BattleTable para que no reciba input detrás del RewardView
	table.process_mode = Node.PROCESS_MODE_DISABLED

	# Generar recompensas en RunState (lógica de dominio, determinista)
	current_rewards = run.generate_combat_rewards()

	# Crear el RewardView en código (sin .tscn)
	var reward_view := RewardView.new()
	table.add_child(reward_view)

	# El RewardView sí funciona aunque el BattleTable esté pausado
	reward_view.process_mode = Node.PROCESS_MODE_ALWAYS

	# Pasarle las recompensas YA GENERADAS (no las genera RewardView)
	reward_view.setup(run, state_machine, table, current_rewards)

	# Escuchar las señales que emite RewardView
	reward_view.card_chosen.connect(_on_reward_card_chosen)
	reward_view.skipped.connect(_on_reward_skipped)

## Handler cuando el jugador ELIGIÓ una carta.
func _on_reward_card_chosen(chosen_card: CardData) -> void:
	# Aplicar recompensas al estado del juego (lógica de dominio)
	run.apply_combat_rewards(
		chosen_card,
		int(current_rewards["gold"]),
		current_rewards["relic"],
		table.deck
	)

	# Reactivar el BattleTable
	table.process_mode = Node.PROCESS_MODE_INHERIT

	# NUEVO: transicionar la FSM a MAP antes de abrir el mapa
	state_machine.transition_to(RunStateMachine.State.MAP)

	# Limpiar la sala y avanzar
	_clear_room_after_combat()

	# Limpiar cache
	current_rewards = {}
## Handler cuando el jugador SKIPPEÓ (no eligió carta).
func _on_reward_skipped() -> void:
	# Aplicar oro y relic (si la hubo), pero no carta
	run.player_gold += int(current_rewards["gold"])
	if current_rewards["relic"]:
		run.equip_specific_relic(current_rewards["relic"])

	# Reactivar el BattleTable
	table.process_mode = Node.PROCESS_MODE_INHERIT

	#  transicionar la FSM a MAP antes de abrir el mapa
	state_machine.transition_to(RunStateMachine.State.MAP)

	# Limpiar la sala y avanzar
	_clear_room_after_combat()

	# Limpiar cache
	current_rewards = {}
## Lógica común para limpiar la sala, consolidar las cartas de la mesa de vuelta al mazo y volver al mapa.
func _clear_room_after_combat() -> void:
	if table and table.deck:
		table.deck.reset_for_new_combat(_get_active_board_cards())
		table.clear_board_visuals()
		table.refresh_ui()

	if run.current_room:
		run.clear_and_discover_room(run.current_room)

	if run.current_room and run.current_room.room_type == RoomData.Type.BOSS:
		table.hud.set_banner_message("JEFE DERROTADO! AVANZANDO A LA PLANTA %d..." % (run.current_floor + 1))
		await table.get_tree().create_timer(1.4).timeout
		run.start_floor(run.current_floor + 1)
		map_view.free_travel_enabled = run.god_mode
		if run.god_mode:
			run.reveal_entire_floor()
		SignalBus.floor_started.emit(run.current_floor)
		open_map("Bienvenido a la Planta %d! La matriz se ha regenerado con una nueva sub-semilla." % run.current_floor)
	else:
		table.hud.set_banner_message("COMBATE GANADO! VOLVIENDO AL MAPA...")
		await table.get_tree().create_timer(1.2).timeout
		open_map("Sala despejada! Nuevos pasillos descubiertos en el mapa.")

## Recolecta todos los datos (`CardData`) de las cartas que actualmente están flotando 
## visualmente en la mano o en la zona de combo, para poder serializarlas junto al mazo durante el autoguardado.
func _get_active_board_cards() -> Array[CardData]:
	var board_cards: Array[CardData] = []
	if table and table.board:
		for c in table.board.hand_cards:
			if c and c.card_data:
				board_cards.append(c.card_data)
		for c in table.board.combo_cards:
			if c and c.card_data:
				board_cards.append(c.card_data)
	return board_cards
	
## Evalúa contextual e instantáneamente en qué estado se encontraba la partida restaurada.
## Si el jugador guardó (o se cerró el juego) a mitad de un combate activo sin finalizar,
##  reinicia el encuentro. Si estaba pacífico en el mapa, abre la vista de expedición.
func _resume_loaded_run(slot: int) -> void:
	var room: RoomData = run.current_room
	main_menu.visible = false
	hero_select_view.visible = false
	map_view.free_travel_enabled = run.god_mode
	table.clear_board_visuals()
	table.enemy = null
	table.is_resolving = false

	if room and not room.cleared:
		if room.room_type == RoomData.Type.COMBAT or room.room_type == RoomData.Type.ELITE:
			state_machine.transition_to(RunStateMachine.State.MAP)  #: primero MAP
			state_machine.transition_to(RunStateMachine.State.BATTLE)  # después BATTLE
			map_view.visible = false
			table.start_combat_encounter(false)
			return
		elif room.room_type == RoomData.Type.BOSS:
			state_machine.transition_to(RunStateMachine.State.MAP)  
			state_machine.transition_to(RunStateMachine.State.BATTLE) 
			map_view.visible = false
			table.start_combat_encounter(true)
			return
		elif room.room_type == RoomData.Type.SHOP:
			state_machine.transition_to(RunStateMachine.State.MAP) 
			state_machine.transition_to(RunStateMachine.State.SHOP)  
			_open_shop_for_room(room)
			return

	# Si ya estaba despejada o es cualquier otra sala, va al mapa.
	state_machine.transition_to(RunStateMachine.State.MAP)
	open_map("Continuando partida anterior (Ranura %d)" % slot)
