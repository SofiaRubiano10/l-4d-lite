extends "res://bloques.gd"
# Commit 2: Laberinto amplio con paredes delgadas, Escopeta ("W") y 15 bidones generados al azar.

const META_BIDONES = 15

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
var juego_terminado = false
var texto_arma_hud = "Rifle: 15/15"

@onready var jugador = $Superviviente
@onready var timer_poder = $TimerPoder


func _ready():
	randomize()
	construir()
	
	# Conectar cada bidón y adrenalina del grupo "bidones"
	for item in get_tree().get_nodes_in_group("bidones"):
		item.recogido.connect(_on_recogido)
		
	# Conectar cada infectado del grupo "enemigos"
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
		enemigo.abatido.connect(_on_enemigo_abatido)
		
	# Conectar armas coleccionables en el laberinto
	for arma_mapa in get_tree().get_nodes_in_group("armas_mapa"):
		arma_mapa.arma_recogida.connect(_on_arma_recogida)
		
	# Conectar actualización de munición y arma del jugador
	jugador.municion_cambiada.connect(_on_municion_cambiada)
	jugador.sincronizar_municion()
	
	# Conectar la señal timeout del TimerPoder
	timer_poder.timeout.connect(_on_timer_poder_timeout)
	
	actualizar_hud()


func _on_arma_recogida(nombre_arma: String):
	if juego_terminado:
		return
	puntaje += 75
	actualizar_hud()
	mostrar_aviso_temporal("¡%s desbloqueada! (Teclas 1/2 o Q)" % nombre_arma, 3.5)


func mostrar_aviso_temporal(texto: String, duracion: float):
	if juego_terminado:
		return
	$HUD/Mensaje.text = texto
	await get_tree().create_timer(duracion).timeout
	if not juego_terminado and $HUD/Mensaje.text == texto:
		$HUD/Mensaje.text = ""


func _on_municion_cambiada(nombre_arma: String, balas_actuales: int, cargador_max: int, esta_recargando: bool):
	if esta_recargando:
		texto_arma_hud = "%s [RECARGANDO...]" % nombre_arma
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
		juego_terminado = true
		$HUD/Mensaje.text = "¡Rescate en camino!"


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
	if jugador.muriendo or juego_terminado:
		return
		
	if modo_poder:
		enemigo.volver_a_casa()
		puntaje += 200
		actualizar_hud()
	else:
		vidas -= 1
		actualizar_hud()
		if vidas <= 0:
			juego_terminado = true
			$HUD/Mensaje.text = "Perdiste"
			jugador.set_physics_process(false)
		else:
			jugador.morir()


func actualizar_hud():
	$HUD/Puntaje.text = "Puntaje: %d | Vidas: %d | Bidones: %d/%d | %s" % [
		puntaje,
		vidas,
		bidones_recogidos,
		META_BIDONES,
		texto_arma_hud
	]


func construir():
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
				
	# Filtrar celdas muy cercanas al inicio del jugador y elegir 15 ubicaciones al azar
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
