extends Area2D

signal toco_al_jugador(infectado)
signal abatido(infectado)

enum Eje { HORIZONTAL, VERTICAL }

@export var speed: float = 80.0
@export var distancia: float = 64.0
@export var eje: Eje = Eje.HORIZONTAL

var inicio: Vector2 = Vector2.ZERO
var direccion: int = 1


func _ready():
	inicio = position
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if speed <= 0.0:
		return
	if eje == Eje.HORIZONTAL:
		position.x += speed * direccion * delta
		if abs(position.x - inicio.x) >= distancia:
			direccion *= -1
	else:
		position.y += speed * direccion * delta
		if abs(position.y - inicio.y) >= distancia:
			direccion *= -1


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func volver_a_casa():
	position = inicio


func recibir_disparo():
	volver_a_casa()
	abatido.emit(self)
