extends "res://bloques.gd"
# Commit 1: Conexión de daño por balas a infectados, puntos por baja y HUD con arma y munición.

const MAPA = [
	"##################",
	"#o.    .     .  o#",
	"#  ##   E    ##  #",
	"#  ##        ##  #",
	"#  .   .  .    . #",
	"#       ##       #",
	"#  .    ##   E   #",
	"#    .      .    #",
	"#  ###      ###  #",
	"#   .    E    .  #",
	"# .   .     .    #",
	"##################",
]

var bidon_escena = preload("res://bidon.tscn")
var adrenalina_escena = preload("res://adrenalina.tscn")
var infectado_escena = preload("res://infectado.tscn")

var puntaje = 0
var vidas = 3
var modo_poder = false
var juego_terminado = false
var texto_arma_hud = "Rifle: 15/15"

@onready var jugador = $Superviviente
@onready var timer_poder = $TimerPoder


func _ready():
	construir()
	
	# Conectar cada bidón y adrenalina del grupo "bidones"
	for item in get_tree().get_nodes_in_group("bidones"):
		item.recogido.connect(_on_recogido)
		
	# Conectar cada infectado del grupo "enemigos" (contacto y ser abatido por balas)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
		enemigo.abatido.connect(_on_enemigo_abatido)
		
	# Conectar actualización de munición y arma del jugador
	jugador.municion_cambiada.connect(_on_municion_cambiada)
	jugador.sincronizar_municion()
	
	# Conectar la señal timeout del TimerPoder
	timer_poder.timeout.connect(_on_timer_poder_timeout)
	
	actualizar_hud()


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
	actualizar_hud()
	
	if da_poder:
		activar_poder()
		
	if get_tree().get_nodes_in_group("bidones").size() == 0:
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
	$HUD/Puntaje.text = "Puntaje: %d | Vidas: %d | %s" % [puntaje, vidas, texto_arma_hud]


func construir():
	construir_bloques(MAPA, Color(0.45, 0.47, 0.42, 1))
	for fila in MAPA.size():
		for col in MAPA[fila].length():
			var escena = null
			match MAPA[fila][col]:
				".":
					escena = bidon_escena
				"o":
					escena = adrenalina_escena
				"E":
					escena = infectado_escena
			if escena:
				var nodo = escena.instantiate()
				nodo.position = Vector2(col + 0.5, fila + 0.5) * CELDA
				if MAPA[fila][col] == "E" and fila == 6:
					nodo.eje = nodo.Eje.VERTICAL
				$Mapa.add_child(nodo)
