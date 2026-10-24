extends Area2D

signal toco_al_jugador(infectado)
signal abatido(infectado)

enum Eje { HORIZONTAL, VERTICAL }
enum Estado { PATRULLA, PERSECUCION, ATURDIDO }

@export var speed: float = 80.0
@export var distancia: float = 64.0
@export var eje: Eje = Eje.HORIZONTAL
@export var rango_deteccion: float = 190.0
@export var vida_max: int = 2
@export var tiempo_reaparicion: float = 2.0

var inicio: Vector2 = Vector2.ZERO
var direccion: int = 1
var estado: Estado = Estado.PATRULLA
var vida_actual: int = 2
var timer_aturdido: float = 0.0
var timer_flash: float = 0.0
var en_modo_poder: bool = false
var objetivo: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	inicio = position
	vida_actual = vida_max
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if timer_flash > 0.0:
		timer_flash -= delta
		if timer_flash <= 0.0:
			actualizar_color()

	if estado == Estado.ATURDIDO:
		timer_aturdido -= delta
		if timer_aturdido <= 0.0:
			estado = Estado.PATRULLA
			actualizar_color()
		return

	if speed <= 0.0:
		return

	actualizar_estado()

	var vector_mov = Vector2.ZERO
	if estado == Estado.PERSECUCION and is_instance_valid(objetivo):
		var hacia_jugador = (objetivo.global_position - global_position).normalized()
		if en_modo_poder:
			# Con adrenalina activa, el infectado intenta huir más lento
			var dir_huida = -hacia_jugador
			if puede_avanzar(dir_huida, speed * 0.75 * delta):
				vector_mov = dir_huida * (speed * 0.75)
		else:
			# Persigue al superviviente con un impulso de agresividad
			if puede_avanzar(hacia_jugador, speed * 1.25 * delta):
				vector_mov = hacia_jugador * (speed * 1.25)

	if vector_mov == Vector2.ZERO:
		vector_mov = calcular_movimiento_patrulla(delta)

	position += vector_mov * delta

	if vector_mov.length_squared() > 1.0:
		sprite.rotation = lerp_angle(sprite.rotation, vector_mov.angle(), 12.0 * delta)


func actualizar_estado():
	if not is_instance_valid(objetivo) or objetivo.get("muriendo"):
		estado = Estado.PATRULLA
		return

	var dist_jugador = global_position.distance_to(objetivo.global_position)
	if dist_jugador <= rango_deteccion and tiene_linea_de_vision(objetivo):
		estado = Estado.PERSECUCION
	else:
		estado = Estado.PATRULLA


func calcular_movimiento_patrulla(delta: float) -> Vector2:
	# Si se alejó de su carril por perseguir al jugador, regresa primero hacia su punto de inicio
	if eje == Eje.HORIZONTAL and abs(position.y - inicio.y) > 4.0:
		var dir_retorno = (inicio - position).normalized()
		if puede_avanzar(dir_retorno, speed * delta):
			return dir_retorno * speed
	elif eje == Eje.VERTICAL and abs(position.x - inicio.x) > 4.0:
		var dir_retorno = (inicio - position).normalized()
		if puede_avanzar(dir_retorno, speed * delta):
			return dir_retorno * speed

	if eje == Eje.HORIZONTAL:
		if abs(position.x - inicio.x) >= distancia:
			direccion = -1 if position.x > inicio.x else 1
		var dir_vec = Vector2(direccion, 0.0)
		if not puede_avanzar(dir_vec, speed * delta):
			direccion *= -1
			dir_vec = Vector2(direccion, 0.0)
		return dir_vec * speed
	else:
		if abs(position.y - inicio.y) >= distancia:
			direccion = -1 if position.y > inicio.y else 1
		var dir_vec = Vector2(0.0, direccion)
		if not puede_avanzar(dir_vec, speed * delta):
			direccion *= -1
			dir_vec = Vector2(0.0, direccion)
		return dir_vec * speed


func tiene_linea_de_vision( blanco: Node2D ) -> bool:
	var espacio = get_world_2d().direct_space_state
	var consulta = PhysicsRayQueryParameters2D.create(global_position, blanco.global_position)
	consulta.exclude = [get_rid()]
	var resultado = espacio.intersect_ray(consulta)
	if resultado.is_empty():
		return true
	return resultado.collider == blanco


func puede_avanzar(dir: Vector2, paso: float) -> bool:
	var espacio = get_world_2d().direct_space_state
	var destino = global_position + dir.normalized() * (20.0 + paso)
	var consulta = PhysicsRayQueryParameters2D.create(global_position, destino)
	consulta.exclude = [get_rid()]
	var resultado = espacio.intersect_ray(consulta)
	if resultado.is_empty():
		return true
	return resultado.collider.is_in_group("jugador")


func _on_body_entered(body):
	if estado == Estado.ATURDIDO:
		return
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func set_modo_poder(activo: bool):
	en_modo_poder = activo
	actualizar_color()


func actualizar_color():
	var base = Color(0.3, 0.6, 1.0, 1.0) if en_modo_poder else Color(1.0, 1.0, 1.0, 1.0)
	if estado == Estado.ATURDIDO:
		base.a = 0.45
	modulate = base


func esta_aturdido() -> bool:
	return estado == Estado.ATURDIDO


func volver_a_casa():
	position = inicio
	vida_actual = vida_max
	estado = Estado.ATURDIDO
	timer_aturdido = tiempo_reaparicion
	actualizar_color()


func recibir_disparo():
	if estado == Estado.ATURDIDO:
		return
	vida_actual -= 1
	if vida_actual <= 0:
		volver_a_casa()
		abatido.emit(self)
	else:
		# Feedback de impacto y leve retroceso
		modulate = Color(1.0, 0.3, 0.3, 1.0)
		timer_flash = 0.15
		var dir_retroceso = -Vector2.RIGHT.rotated(sprite.rotation)
		if puede_avanzar(dir_retroceso, 12.0):
			position += dir_retroceso * 12.0
