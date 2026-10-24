extends Area2D

signal toco_al_jugador(infectado)
signal abatido(infectado)

enum Eje { HORIZONTAL, VERTICAL }

@export var speed: float = 80.0
@export var distancia: float = 64.0
@export var eje: Eje = Eje.HORIZONTAL
@export var max_hp: int = 3

var inicio: Vector2 = Vector2.ZERO
var direccion: int = 1
var hp: int = 3
var abatido_estado: bool = false
var color_base: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready():
	inicio = position
	hp = max_hp
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if abatido_estado or speed <= 0.0:
		return
	if eje == Eje.HORIZONTAL:
		position.x += speed * direccion * delta
		if abs(position.x - inicio.x) >= distancia:
			direccion = -1 if (position.x - inicio.x) > 0 else 1
	else:
		position.y += speed * direccion * delta
		if abs(position.y - inicio.y) >= distancia:
			direccion = -1 if (position.y - inicio.y) > 0 else 1


func _on_body_entered(body):
	if abatido_estado:
		return
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func recibir_dano(cantidad: int, dir_impacto: Vector2 = Vector2.ZERO):
	if abatido_estado:
		return
		
	hp -= cantidad
	# Pequeño empuje por el impacto de la bala
	position += dir_impacto * 6.0
	
	if hp <= 0:
		abatido.emit(self)
		desactivar_temporalmente()
	else:
		# Parpadeo rojo de daño recibido
		modulate = Color(1.0, 0.25, 0.25, 1.0)
		await get_tree().create_timer(0.1).timeout
		if not abatido_estado:
			modulate = color_base


func desactivar_temporalmente():
	abatido_estado = true
	set_deferred("monitoring", false)
	visible = false
	position = inicio
	
	# Reaparece en su punto inicial tras 4 segundos
	await get_tree().create_timer(4.0).timeout
	hp = max_hp
	abatido_estado = false
	visible = true
	modulate = color_base
	set_deferred("monitoring", true)


func cambiar_color_poder(activo: bool):
	color_base = Color(0.3, 0.6, 1.0, 1.0) if activo else Color(1.0, 1.0, 1.0, 1.0)
	if not abatido_estado:
		modulate = color_base


func volver_a_casa():
	position = inicio
	hp = max_hp
