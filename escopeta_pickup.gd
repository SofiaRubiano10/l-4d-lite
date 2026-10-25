extends Area2D

signal arma_recogida(nombre_arma: String)


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		if body.has_method("desbloquear_escopeta"):
			body.desbloquear_escopeta()
		arma_recogida.emit("Escopeta")
		queue_free()
