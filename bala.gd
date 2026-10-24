extends Area2D

@export var speed: float = 650.0
@export var distancia_maxima: float = 600.0

var distancia_recorrida: float = 0.0


func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta):
	var desplazamiento = speed * delta
	position += Vector2.RIGHT.rotated(rotation) * desplazamiento
	distancia_recorrida += desplazamiento
	if distancia_recorrida >= distancia_maxima:
		queue_free()


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		return
	queue_free()


func _on_area_entered(area):
	if area.is_in_group("enemigos"):
		if area.has_method("recibir_disparo"):
			area.recibir_disparo()
		queue_free()
