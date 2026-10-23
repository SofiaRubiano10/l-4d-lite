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
var modo_poder = false


func _ready():
	construir()
	# Conectamos las señales de los bidones DESPUÉS de llamar a construir()
	for item in get_tree().get_nodes_in_group("bidones"):
		item.recogido.connect(_on_recogido)


func _on_recogido(valor, da_poder):
	puntaje += valor
	$HUD/Puntaje.text = "Puntaje: %d" % puntaje
	
	if da_poder:
		activar_poder()
		
	# Comprobación de victoria (al recoger el último, el grupo queda en 0)
	if get_tree().get_nodes_in_group("bidones").size() == 0:
		$HUD/Mensaje.text = "¡Rescate en camino!"


func activar_poder():
	modo_poder = true
	print("poder: si")
	await get_tree().create_timer(6.0).timeout
	modo_poder = false
	print("poder: no")


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
				$Mapa.add_child(nodo)
