extends Area2D

signal recogido(valor, da_poder)

@export var valor = 10
@export var da_poder = false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		# Arreglo de victoria: sacamos el bidón del grupo antes de emitir la señal
		# para que el conteo con get_nodes_in_group sea exactamente 0 en el último
		remove_from_group("bidones")
		recogido.emit(valor, da_poder)
		queue_free()
