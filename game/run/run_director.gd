## Orquestador principal de la interfaz y flujo del juego (Patrón Mediator).
## Coordina la navegación y transición de estados entre el 
## Menú Principal, el Selector de Guardado, el Mapa de Expedición, la Tienda y la Mesa de Combate.
## `MainMenuView`, `MapView`, `ShopView` y `BattleTable`.
extends RefCounted
class_name RunDirector

## Referencia inyectada a la Mesa de Combate (`BattleTable`).
var table: Control
## Referencia inyectada al estado vivo de la partida (`RunState`).
var run: RunState
## Vista principal de navegación del grafo (matriz `8x8`).
var map_view: MapView
## Vista del menú principal para selección de héroes e ingreso de semilla custom.
var main_menu: MainMenuView
## Vista interactiva de la tienda mercantil.
var shop_view: ShopView
## Vista del gestor de perfiles y ranuras de guardado (Slots).
var slot_view: SlotSelectView
## Vista modal sobrepuesta para el menú de pausa.
var pause_menu: PauseMenuView
## Constructor del Director. Instancia las vistas principales 
## (`MapView`, `PauseMenuView`, `MainMenuView`, `ShopView`, `SlotSelectView`) como hijas de la mesa.
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
	
	# Menú de Pausa
	pause_menu = PauseMenuView.new()
	table.add_child(pause_menu)
	pause_menu.abandon_run_requested.connect(_on_pause_abandon_run)
	pause_menu.quit_game_requested.connect(_on_pause_quit_game)
	
	# 2. Menú Principal (arranca oculto hasta elegir slot)
	main_menu = MainMenuView.new()
	main_menu.visible = false
	main_menu.quit_requested.connect(_on_main_menu_quit_requested)
	table.add_child(main_menu)
	main_menu.start_random_run_requested.connect(_on_start_random_run)
	main_menu.start_seeded_run_requested.connect(_on_start_seeded_run)
	main_menu.change_slot_requested.connect(_on_change_slot_requested)
	
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
	
	# 5. Vista de Ranuras de Guardado (Primer elemento visible)
	slot_view = SlotSelectView.new()
	table.add_child(slot_view)
	slot_view.slot_chosen.connect(_on_slot_confirmed)
	
	# 6. Precarga de héroes para tener el menú listo de fondo
	var heroes: Array[HeroData] = GameDatabase.load_all_heroes()
	main_menu.setup_heroes(heroes)
	
	# 7. Bifurcación de arranque: Auto-login o Selector de Ranuras
	var last_slot: int = PersistenceManager.get_last_played_slot()
	
	if last_slot > 0 and PersistenceManager.select_slot(last_slot):
		# Encontró el último slot jugado: ocultamos el selector de ranuras
		slot_view.visible = false
		
		# Si ese slot tenía una run en pausa en el mapa, la levantamos de una
		if PersistenceManager.has_active_run():
			if PersistenceManager.load_active_run(run, table.deck):
				_resume_loaded_run(last_slot) # 
				return
		
		# Si no tenía una run viva, lo mandamos al menú con su perfil cargado
		main_menu.visible = true
		main_menu.show_menu()
	else:
		# Primera vez que abre el juego o todos los slots vacíos: va al selector
		main_menu.visible = false
		slot_view.refresh_slots()
		slot_view.visible = true
	
## Oculta el menú principal, reinicia el estado de la partida con una semilla procedimental (`-1`),
## construye el mazo inicial basado en el héroe elegido y transiciona al mapa.
func _on_start_random_run(hero: HeroData) -> void:
	main_menu.visible = false
	run.start_new_run(-1, hero)
	table.deck.build_initial_deck_for_hero(run)
	open_map("Partida iniciada con: %s" % hero.hero_name)

## Recopila las cartas activas, invoca el autoguardado y sincroniza todas las métricas del jugador 
## con el nodo visual `MapView`.
## Despliega el mapa en pantalla actualizando su leyenda inferior
## . Si el modo Dios está activo, deshabilita la niebla de guerra.
func _on_start_seeded_run(hero: HeroData, custom_seed: int) -> void:
	main_menu.visible = false
	run.start_new_run(custom_seed,hero)
	table.deck.build_initial_deck_for_hero(run)
	open_map("Partida iniciada con %s | Semilla: %d" % [hero.hero_name, custom_seed])

## Recopila las cartas activas, invoca el autoguardado y sincroniza todas las métricas 
## del jugador con el nodo visual `MapView`.
## Despliega el mapa en pantalla actualizando su leyenda inferior.
## Si el modo Dios está activo, deshabilita la niebla de guerra.
func open_map(custom_info: String = "") -> void:

	if PersistenceManager.current_slot > 0 and not run.is_player_dead():
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
		
	if run.god_mode:
		run.reveal_entire_floor()
		map_view.free_travel_enabled = true

	var board_cards: Array[CardData] = []
	for c in table.board.hand_cards:
		if c.card_data:
			board_cards.append(c.card_data)
	for c in table.board.combo_cards:
		if c.card_data:
			board_cards.append(c.card_data)

	map_view.setup_floor(
		run.current_floor,
		run.master_seed,
		run.floor_data["sub_seed"],
		run.floor_data["rooms"],
		run.player_grid_pos,
		run.player_hp,
		run.max_player_hp,
		run.max_energy,
		run.player_luck,
		run.active_relics.size(),
		run.get_relics_detailed_text(),
		table.deck.get_total_cards_count(board_cards.size()),
		table.deck.get_full_deck_detailed_text(board_cards),
		run.player_gold
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
		RoomData.Type.COMBAT:
			map_view.visible = false
			table.start_combat_encounter(false)
		RoomData.Type.BOSS:
			map_view.visible = false
			table.start_combat_encounter(true)
		#Genera 3 cartas (`_get_random_shop_cards`) y 2 reliquias
		 #(`run.generate_shop_relics`), marca la sala como visitada y abre `shop_view`.
		RoomData.Type.SHOP:
			# No llamamos a clear_and_discover_room para que la tienda no se cierre
			# Solo descubrimos sus vecinos para poder seguir moviéndonos
			var rooms: Dictionary = run.floor_data.get("rooms", {})
			for n_pos in room.neighbors:
				if rooms.has(n_pos):
					rooms[n_pos].discovered = true
			
			# Si la tienda no tiene stock generado todavía, lo generamos y guardamos en la sala
			if not room.shop_initialized:
				room.shop_initialized = true
				room.shop_cards = _get_random_shop_cards(room.grid_pos, 3)
				room.shop_relics = run.generate_shop_relics(room.grid_pos, 2)
		
			map_view.visible = false
			# Abrimos la tienda pasándole el stock persistente de esta sala en particular
			shop_view.open_shop(run.player_gold, room.shop_cards, room.shop_relics)

## Disparado tras la victoria en un encuentro. Efectúa el autoguardado rápido.
## Si era un Jefe, orquesta el avance a la siguiente planta. 
## Si era un enemigo estándar, despeja la sala actual y devuelve el foco al mapa.
func _on_combat_won() -> void:
	if PersistenceManager.current_slot > 0 and not run.is_player_dead():
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
		
	if run.current_room and run.current_room.room_type == RoomData.Type.BOSS:
		table.hud.set_banner_message("JEFE DERROTADO! AVANZANDO A LA PLANTA %d..." % (run.current_floor + 1))
		table.attack_button.text = "SUBIENDO DE PLANTA..."
		await table.get_tree().create_timer(1.4).timeout
		run.start_floor(run.current_floor + 1)
		SignalBus.floor_started.emit(run.current_floor)
		open_map("Bienvenido a la Planta %d! La matriz se ha regenerado con una nueva sub-semilla." % run.current_floor)
	else:
		table.hud.set_banner_message("COMBATE GANADO! VOLVIENDO AL MAPA...")
		table.attack_button.text = "VICTORIA!"
		run.clear_and_discover_room(run.current_room)
		await table.get_tree().create_timer(1.2).timeout
		open_map("Sala despejada! Nuevos pasillos descubiertos en el mapa.")

## Disparado tras la muerte definitiva del jugador.
## Muestra el mensaje de caída, oculta la capa de expedición 
## y retorna al menú principal purificando el estado vivo de la partida (Permadeath).
func _on_combat_lost() -> void:
	table.hud.set_banner_message("YOU DIED CAYENDO EN LA PLANTA %d..." % run.current_floor)
	table.attack_button.text = "DERROTA"
	await table.get_tree().create_timer(1.6).timeout
	map_view.visible = false
	main_menu.show_menu("HAS MUERTO en la Planta %d ante %s." % [run.current_floor, table.enemy.enemy_name])

## Disparado al salir de la vista de comercio. Aplica un autoguardado rápido, 
## refresca las etiquetas numéricas de la mesa y vuelve a abrir el mapa.
func _on_shop_closed() -> void:
	if PersistenceManager.current_slot > 0 and not run.is_player_dead():
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
	table.refresh_ui()
	open_map("Saliste de la tienda.")
	
## Valida los fondos, debita el oro y transfiere una copia serializada segura de la carta adquirida 
## hacia la pila de robo del mazo activo.
## Desactiva su disponibilidad en el stock persistente de la sala actual y refresca la UI de la tienda.
func _on_shop_card_bought(card: CardData, cost: int) -> void:
	if run.player_gold >= cost:
		run.player_gold -= cost
		
		var copy := card.duplicate()
		# Sellamos la ruta original en la copia
		copy.resource_name = card.resource_path if card.resource_path != "" else card.resource_name
		
		# Agregamos la carta a la pila de robo
		if table.deck and table.deck.draw_pile:
			if table.deck.draw_pile.has_method("add_card"):
				table.deck.draw_pile.add_card(copy)
			elif "cards" in table.deck.draw_pile:
				table.deck.draw_pile.cards.append(copy)
				
		if run.current_room and run.current_room.room_type == RoomData.Type.SHOP:
			var idx = run.current_room.shop_cards.find(card)
			if idx != -1: run.current_room.shop_cards[idx] = null
				
		shop_view.update_after_purchase(run.player_gold)
		table.refresh_ui()

## Valida los fondos, debita el oro, equipa la reliquia adquirida en el jugador y dispara su gancho `on_equipped`.
## Desactiva la reliquia del stock de la sala actual, emite `relic_acquired` y refresca la UI.
func _on_shop_relic_bought(relic: RelicData, cost: int) -> void:
	if run.player_gold >= cost:
		run.player_gold -= cost
		run.active_relics.append(relic)
		relic.trigger_on_equipped(run)
		SignalBus.relic_acquired.emit(relic)
		
		# Marcamos la reliquia como null en el stock de la sala actual
		if run.current_room and run.current_room.room_type == RoomData.Type.SHOP:
			var idx = run.current_room.shop_relics.find(relic)
			if idx != -1:
				run.current_room.shop_relics[idx] = null
				
		shop_view.update_after_purchase(run.player_gold)
		table.refresh_ui()
		
## Genera aleatoriamente 3 cartas únicas utilizando un motor RNG determinista atado a las coordenadas de la sala y al piso actual.
## Filtra los candidatos usando el sorteador ponderado de rarezas (`RaritySystem`).
func _get_random_shop_cards(room_pos: Vector2i, amount: int = 3) -> Array[CardData]:
	var all_cards: Array[CardData] = GameDatabase.load_all_cards()
	var result: Array[CardData] = []
	if all_cards.is_empty():
		push_warning("Tienda: No se encontraron archivos .tres de tipo CardData en res://cards/data")
		return result

	# RNG determinista atado a la semilla de la partida, el piso y la coordenada de la sala
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%d_FLOOR_%d_SHOP_CARDS_%d_%d" % [run.master_seed, run.current_floor, room_pos.x, room_pos.y]))

	for i in range(min(amount, all_cards.size())):
		var target_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, run.current_floor, run.player_luck)
		var candidates: Array[CardData] = all_cards.filter(func(c: CardData): return c.rarity == target_tier)
		if candidates.is_empty():
			candidates = all_cards
		
		var picked: CardData = candidates[rng.randi_range(0, candidates.size() - 1)]
		result.append(picked.duplicate())
		all_cards.erase(picked) # Evita que se repita la misma carta en la tienda

	return result
	
## Responde a la selección (o creación) de una ranura por parte del jugador.
## Si el slot posee una partida en suspensión viva, la restaura y la retoma. 
## Caso contrario, despliega el menú de selección de Héroe para una nueva aventura.
func _on_slot_confirmed() -> void:
	slot_view.visible = false

	# Si el slot tenía una run congelada, restaurarla
	if PersistenceManager.has_active_run():
		if PersistenceManager.load_active_run(run, table.deck):
			_resume_loaded_run(PersistenceManager.current_slot) # <--- ACÁ ESTÁ EL CAMBIO
			return
			
	# Si no hay partida viva, pasar al menú principal de selección de héroe
	main_menu.visible = true
	main_menu.show_menu()
	
## Intercepta el botón de "Cambiar Perfil" del menú principal para volver a mostrar el selector de ranuras.
func _on_change_slot_requested() -> void:
	main_menu.visible = false
	slot_view.refresh_slots()
	slot_view.visible = true

## Captura la pulsación de ESC para pausar la partida si hay una run activa.
func handle_unhandled_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# Solo permitimos pausar si no estamos en los menús de inicio
			if not slot_view.visible and not main_menu.visible and not pause_menu.visible:
				pause_menu.open_pause()
				table.get_viewport().set_input_as_handled()

## Elimina permanentemente la partida en curso del disco duro y computa la derrota en las estadísticas del perfil.
## Purga las vistas actuales y regresa al menú de selección de Héroes.
func _on_pause_abandon_run() -> void:
	# 1. Borramos la partida viva de disco para respetar permadeath
	PersistenceManager.delete_active_run()
	PersistenceManager.record_run_finished(false, run.current_floor)
	
	# 2. Ocultamos las capas de juego
	map_view.visible = false
	shop_view.visible = false
	table.clear_board_visuals()
	
	# 3. Volvemos al menú principal para que elija otro héroe
	main_menu.visible = true
	main_menu.show_menu("Has abandonado la expedición.")

## Dispara un guardado atómico final y cierra de forma segura el ejecutable desde el árbol de escena.
func _on_pause_quit_game() -> void:
	if PersistenceManager.current_slot > 0 and not run.is_player_dead():
		PersistenceManager.save_current_run(run, table.deck, _get_active_board_cards())
	table.get_tree().quit()
	
## Cierra de forma segura el ejecutable directamente desde el menú base.
func _on_main_menu_quit_requested() -> void:
	table.get_tree().quit()

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
	
	if room and not room.cleared:
		if room.room_type == RoomData.Type.COMBAT:
			map_view.visible = false
			table.start_combat_encounter(false)
			return
		elif room.room_type == RoomData.Type.BOSS:
			map_view.visible = false
			table.start_combat_encounter(true)
			return
			
	# Si ya estaba despejada o es cualquier otra sala (hoguera, reliquia), va al mapa
	open_map("Continuando partida anterior (Ranura %d)" % slot)
