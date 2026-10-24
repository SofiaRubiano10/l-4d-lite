extends Area2D

signal arma_recogida(nombre_arma: String)

var tiempo: float = 0.0


func _ready():
	body_entered.connect(_on_body_entered)


func _process(delta: float):
	tiempo += delta
	# Efecto visual de flotación y pulso suave para destacar en el laberinto
	$Sprite2D.position.y = sin(tiempo * 4.0) * 3.0
	var escala = 1.0 + sin(tiempo * 5.0) * 0.08
	$Sprite2D.scale = Vector2(escala, escala)


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		if body.has_method("desbloquear_escopeta"):
			body.desbloquear_escopeta()
		arma_recogida.emit("Escopeta")
		queue_free()
