extends "res://bloques.gd"
# Base del Taller 4. construir() arma el nivel a partir del MAPA:
# "#" bloque, "." bidon, "o" adrenalina, "E" infectado.

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

@onready var jugador = $Superviviente
@onready var timer_poder = $TimerPoder


func _ready():
	construir()
	
	# Nivel 2: Conectar cada bidón y adrenalina del grupo "bidones"
	for item in get_tree().get_nodes_in_group("bidones"):
		item.recogido.connect(_on_recogido)
		
	# Nivel 3: Conectar cada infectado del grupo "enemigos"
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.objetivo = jugador
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
		enemigo.abatido.connect(_on_enemigo_abatido)
		
	# Nivel 3: Conectar la señal timeout del TimerPoder
	timer_poder.timeout.connect(_on_timer_poder_timeout)
	
	# Conectar señal de munición del superviviente
	jugador.municion_cambiada.connect(_on_municion_cambiada)
	
	actualizar_hud()


func _on_recogido(valor, da_poder):
	if juego_terminado:
		return
		
	puntaje += valor
	actualizar_hud()
	
	if da_poder:
		activar_poder()
		
	# Comprobación de victoria (al recoger el último, el grupo queda en 0)
	if get_tree().get_nodes_in_group("bidones").size() == 0:
		juego_terminado = true
		$HUD/Mensaje.text = "¡Rescate en camino!"


func activar_poder():
	modo_poder = true
	print("poder: si")
	# Nivel 3: Reinicia la alarma de 6 segundos desde cero aunque ya estuviera corriendo
	timer_poder.start()
	
	# Extra 1: Cambiar el color y comportamiento de los infectados mientras dura el poder
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.set_modo_poder(true)


func _on_timer_poder_timeout():
	modo_poder = false
	print("poder: no")
	
	# Extra 1: Devolver a los infectados a su estado y color original al terminar el poder
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.set_modo_poder(false)


func _on_enemigo_toco(enemigo):
	# 1. Si el superviviente está muriendo, el infectado está aturdido o el juego terminó, no hacer nada.
	if jugador.muriendo or juego_terminado or enemigo.esta_aturdido():
		return
		
	# 2. Con poder: el infectado vuelve a casa y suman 200.
	if modo_poder:
		enemigo.volver_a_casa()
		puntaje += 200
		actualizar_hud()
	else:
		# 3. Sin poder: una vida menos.
		vidas -= 1
		actualizar_hud()
		if vidas <= 0:
			juego_terminado = true
			$HUD/Mensaje.text = "Perdiste"
			jugador.set_physics_process(false)
		else:
			jugador.morir()


func _on_enemigo_abatido(_enemigo):
	if juego_terminado:
		return
	puntaje += 100
	actualizar_hud()


func _on_municion_cambiada(_balas_actuales, _cargador_max, _esta_recargando):
	actualizar_hud()


func actualizar_hud():
	var estado_armas = "RECARGANDO..." if jugador.recargando else "%d/%d" % [jugador.balas, jugador.CARGADOR]
	$HUD/Puntaje.text = "Puntaje: %d | Vidas: %d | Balas: %s" % [puntaje, vidas, estado_armas]


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
				# Extra 2: El infectado de la fila 6 se mueve en vaivén vertical usando el @export eje
				if MAPA[fila][col] == "E" and fila == 6:
					nodo.eje = nodo.Eje.VERTICAL
				$Mapa.add_child(nodo)
