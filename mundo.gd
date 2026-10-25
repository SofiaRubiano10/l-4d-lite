extends "res://bloques.gd"
# Commit 4: Menú de inicio limpio y sencillo, HUD minimalista y pantalla de Victoria / Derrota.

const META_BIDONES = 15
static var saltar_menu_al_reiniciar: bool = false

const MAPA = [
	"############################",
	"#o  #      #    #      #  o#",
	"# ## # #### # ## # #### # ##",
	"# #  E    # #  V #    E  # #",
	"# # ##### # #### # ##### # #",
	"#   #   #    W     #   #   #",
	"### # # #### ## #### # # ###",
	"#   V #      ##      # V   #",
	"# ####### ######## ####### #",
	"# #     #    E     #     # #",
	"# # ### #### ## #### ### # #",
	"#   # #      ##      # #   #",
	"# ### # #### ## #### # ### #",
	"#  E  # #          # #  E  #",
	"###   # # ######## # #   ###",
	"#     #      ##      #     #",
	"# ####  #### ## ####  #### #",
	"# #    E     ##     E    # #",
	"#oP  #                #   o#",
	"############################",
]

var bidon_escena = preload("res://bidon.tscn")
var adrenalina_escena = preload("res://adrenalina.tscn")
var infectado_escena = preload("res://infectado.tscn")
var escopeta_escena = preload("res://escopeta_pickup.tscn")

var puntaje = 0
var vidas = 3
var bidones_recogidos = 0
var modo_poder = false
var partida_iniciada = false
var juego_terminado = false
var texto_arma_hud = "Rifle: 15/15"

var menu_inicio: Control = null
var panel_fin: Control = null
var lbl_titulo_fin: Label = null
var lbl_detalle_fin: Label = null

@onready var jugador = $Superviviente
@onready var timer_poder = $TimerPoder


func _ready():
	randomize()
	construir()
	_construir_interfaz_estetica()
	
	for item in get_tree().get_nodes_in_group("bidones"):
		item.recogido.connect(_on_recogido)
		
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
		enemigo.abatido.connect(_on_enemigo_abatido)
		
	for arma_mapa in get_tree().get_nodes_in_group("armas_mapa"):
		arma_mapa.arma_recogida.connect(_on_arma_recogida)
		
	jugador.municion_cambiada.connect(_on_municion_cambiada)
	jugador.sincronizar_municion()
	
	timer_poder.timeout.connect(_on_timer_poder_timeout)
	
	actualizar_hud()
	
	if saltar_menu_al_reiniciar:
		saltar_menu_al_reiniciar = false
		_iniciar_partida()
	else:
		_cambiar_actividad_mundo(false)


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if not partida_iniciada and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
			_iniciar_partida()
		elif juego_terminado and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_reiniciar_directo()


func _cambiar_actividad_mundo(activo: bool):
	if jugador:
		jugador.set_physics_process(activo)
		jugador.set_process_unhandled_input(activo)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.set_physics_process(activo)


func _iniciar_partida():
	partida_iniciada = true
	if menu_inicio:
		menu_inicio.visible = false
	_cambiar_actividad_mundo(true)


func _reiniciar_directo():
	saltar_menu_al_reiniciar = true
	get_tree().reload_current_scene()


func _volver_al_menu():
	saltar_menu_al_reiniciar = false
	get_tree().reload_current_scene()


func _construir_interfaz_estetica():
	# 1. HUD limpio y discreto
	$HUD/Puntaje.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	$HUD/Puntaje.add_theme_font_size_override("font_size", 20)
	$HUD/Mensaje.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	$HUD/Mensaje.add_theme_font_size_override("font_size", 24)
	
	# 2. Menú de Inicio minimalista y estético
	menu_inicio = Control.new()
	menu_inicio.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(menu_inicio)
	
	var fondo_oscuro = ColorRect.new()
	fondo_oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.color = Color(0.04, 0.05, 0.07, 0.78)
	menu_inicio.add_child(fondo_oscuro)
	
	var centro_inicio = CenterContainer.new()
	centro_inicio.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_inicio.add_child(centro_inicio)
	
	var tarjeta = PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(400, 230)
	var estilo_tarjeta = StyleBoxFlat.new()
	estilo_tarjeta.bg_color = Color(0.09, 0.1, 0.12, 0.95)
	estilo_tarjeta.border_width_left = 2
	estilo_tarjeta.border_width_top = 2
	estilo_tarjeta.border_width_right = 2
	estilo_tarjeta.border_width_bottom = 2
	estilo_tarjeta.border_color = Color(0.78, 0.2, 0.2, 0.9)
	estilo_tarjeta.corner_radius_top_left = 12
	estilo_tarjeta.corner_radius_top_right = 12
	estilo_tarjeta.corner_radius_bottom_left = 12
	estilo_tarjeta.corner_radius_bottom_right = 12
	estilo_tarjeta.content_margin_left = 28
	estilo_tarjeta.content_margin_right = 28
	estilo_tarjeta.content_margin_top = 26
	estilo_tarjeta.content_margin_bottom = 26
	tarjeta.add_theme_stylebox_override("panel", estilo_tarjeta)
	centro_inicio.add_child(tarjeta)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	tarjeta.add_child(vbox)
	
	var lbl_sub = Label.new()
	lbl_sub.text = "MINI LEFT 4 DEAD"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 14)
	lbl_sub.add_theme_color_override("font_color", Color(0.88, 0.32, 0.32))
	vbox.add_child(lbl_sub)
	
	var lbl_titulo = Label.new()
	lbl_titulo.text = "LEFT 4 DEAD"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_font_size_override("font_size", 32)
	lbl_titulo.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	vbox.add_child(lbl_titulo)
	
	var lbl_mision = Label.new()
	lbl_mision.text = "Recoge los 15 bidones para escapar"
	lbl_mision.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mision.add_theme_font_size_override("font_size", 15)
	lbl_mision.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	vbox.add_child(lbl_mision)
	
	var btn_jugar = _crear_boton_estilizado("JUGAR", Color(0.75, 0.18, 0.18), Color(0.88, 0.25, 0.25))
	btn_jugar.pressed.connect(_iniciar_partida)
	vbox.add_child(btn_jugar)
	
	# 3. Panel de Fin de Partida limpio y compacto
	panel_fin = Control.new()
	panel_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_fin.visible = false
	$HUD.add_child(panel_fin)
	
	var fondo_fin = ColorRect.new()
	fondo_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_fin.color = Color(0.03, 0.04, 0.06, 0.78)
	panel_fin.add_child(fondo_fin)
	
	var centro_fin = CenterContainer.new()
	centro_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_fin.add_child(centro_fin)
	
	var tarjeta_fin = PanelContainer.new()
	tarjeta_fin.custom_minimum_size = Vector2(380, 220)
	tarjeta_fin.add_theme_stylebox_override("panel", estilo_tarjeta.duplicate())
	centro_fin.add_child(tarjeta_fin)
	
	var vbox_fin = VBoxContainer.new()
	vbox_fin.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_fin.add_theme_constant_override("separation", 14)
	tarjeta_fin.add_child(vbox_fin)
	
	lbl_titulo_fin = Label.new()
	lbl_titulo_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo_fin.add_theme_font_size_override("font_size", 28)
	vbox_fin.add_child(lbl_titulo_fin)
	
	lbl_detalle_fin = Label.new()
	lbl_detalle_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_detalle_fin.add_theme_font_size_override("font_size", 16)
	lbl_detalle_fin.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox_fin.add_child(lbl_detalle_fin)
	
	var hbox_botones = HBoxContainer.new()
	hbox_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_botones.add_theme_constant_override("separation", 12)
	vbox_fin.add_child(hbox_botones)
	
	var btn_reintentar = _crear_boton_estilizado("REINTENTAR", Color(0.2, 0.55, 0.28), Color(0.26, 0.68, 0.35))
	btn_reintentar.pressed.connect(_reiniciar_directo)
	hbox_botones.add_child(btn_reintentar)
	
	var btn_menu = _crear_boton_estilizado("MENÚ", Color(0.22, 0.25, 0.3), Color(0.32, 0.36, 0.42))
	btn_menu.pressed.connect(_volver_al_menu)
	hbox_botones.add_child(btn_menu)


func _crear_boton_estilizado(texto: String, color_normal: Color, color_hover: Color) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(150, 42)
	btn.add_theme_font_size_override("font_size", 15)
	
	var st_normal = StyleBoxFlat.new()
	st_normal.bg_color = color_normal
	st_normal.corner_radius_top_left = 8
	st_normal.corner_radius_top_right = 8
	st_normal.corner_radius_bottom_left = 8
	st_normal.corner_radius_bottom_right = 8
	
	var st_hover = st_normal.duplicate()
	st_hover.bg_color = color_hover
	
	btn.add_theme_stylebox_override("normal", st_normal)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_hover)
	return btn


func _mostrar_pantalla_final(victoria: bool):
	juego_terminado = true
	_cambiar_actividad_mundo(false)
	
	if victoria:
		$HUD/Mensaje.text = "¡Rescate en camino!"
		lbl_titulo_fin.text = "¡RESCATE EN CAMINO!"
		lbl_titulo_fin.add_theme_color_override("font_color", Color(0.35, 0.95, 0.52))
	else:
		$HUD/Mensaje.text = "Perdiste"
		lbl_titulo_fin.text = "PERDISTE"
		lbl_titulo_fin.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
		
	lbl_detalle_fin.text = "Puntaje: %d  |  Bidones: %d/%d" % [puntaje, bidones_recogidos, META_BIDONES]
	panel_fin.visible = true


func _on_arma_recogida(nombre_arma: String):
	if juego_terminado:
		return
	puntaje += 75
	actualizar_hud()
	mostrar_aviso_temporal("¡%s obtenida!" % nombre_arma, 2.5)


func mostrar_aviso_temporal(texto: String, duracion: float):
	if juego_terminado:
		return
	$HUD/Mensaje.text = texto
	await get_tree().create_timer(duracion).timeout
	if not juego_terminado and $HUD/Mensaje.text == texto:
		$HUD/Mensaje.text = ""


func _on_municion_cambiada(nombre_arma: String, balas_actuales: int, cargador_max: int, esta_recargando: bool):
	if esta_recargando:
		texto_arma_hud = "%s [Recargando]" % nombre_arma
	else:
		texto_arma_hud = "%s: %d/%d" % [nombre_arma, balas_actuales, cargador_max]
	actualizar_hud()


func _on_enemigo_abatido(_enemigo):
	if juego_terminado:
		return
	puntaje += 100
	actualizar_hud()


func _on_recogido(valor, da_poder):
	if juego_terminado:
		return
		
	puntaje += valor
	if da_poder:
		activar_poder()
	else:
		bidones_recogidos += 1
		
	actualizar_hud()
	
	if bidones_recogidos >= META_BIDONES:
		_mostrar_pantalla_final(true)


func activar_poder():
	modo_poder = true
	print("poder: si")
	timer_poder.start()
	
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.has_method("cambiar_color_poder"):
			enemigo.cambiar_color_poder(true)
		else:
			enemigo.modulate = Color(0.3, 0.6, 1.0, 1.0)


func _on_timer_poder_timeout():
	modo_poder = false
	print("poder: no")
	
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.has_method("cambiar_color_poder"):
			enemigo.cambiar_color_poder(false)
		else:
			enemigo.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_enemigo_toco(enemigo):
	if jugador.muriendo or juego_terminado or not partida_iniciada:
		return
		
	if modo_poder:
		enemigo.volver_a_casa()
		puntaje += 200
		actualizar_hud()
	else:
		vidas -= 1
		actualizar_hud()
		if vidas <= 0:
			_mostrar_pantalla_final(false)
		else:
			jugador.morir()


func actualizar_hud():
	$HUD/Puntaje.text = "Puntaje: %d  |  Vidas: %d  |  Bidones: %d/%d  |  %s" % [
		puntaje,
		vidas,
		bidones_recogidos,
		META_BIDONES,
		texto_arma_hud
	]


func construir():
	# Oscuridad ambiental para limitar la visión a la linterna y el halo cercano
	var oscuridad = CanvasModulate.new()
	oscuridad.name = "OscuridadAmbiental"
	oscuridad.color = Color(0.035, 0.04, 0.055, 1.0)
	add_child(oscuridad)
	
	construir_bloques(MAPA, Color(0.45, 0.47, 0.42, 1))
	
	var pos_jugador = Vector2(2.5, 18.5) * CELDA
	var celdas_libres: Array[Vector2] = []
	
	for fila in MAPA.size():
		for col in MAPA[fila].length():
			var celda_pos = Vector2(col + 0.5, fila + 0.5) * CELDA
			var simbolo = MAPA[fila][col]
			var escena = null
			match simbolo:
				"o":
					escena = adrenalina_escena
				"E", "V":
					escena = infectado_escena
				"W":
					escena = escopeta_escena
				"P":
					pos_jugador = celda_pos
					if jugador:
						jugador.establecer_inicio(celda_pos)
				" ":
					celdas_libres.append(celda_pos)
			if escena:
				var nodo = escena.instantiate()
				nodo.position = celda_pos
				if simbolo == "V":
					nodo.eje = nodo.Eje.VERTICAL
				$Mapa.add_child(nodo)
				
	var candidatas: Array[Vector2] = []
	for pos in celdas_libres:
		if pos.distance_to(pos_jugador) > CELDA * 2.2:
			candidatas.append(pos)
			
	candidatas.shuffle()
	var cantidad = min(META_BIDONES, candidatas.size())
	for i in range(cantidad):
		var bidon = bidon_escena.instantiate()
		bidon.position = candidatas[i]
		$Mapa.add_child(bidon)
