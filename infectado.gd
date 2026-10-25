extends Area2D
# Commit 3: Máquina de estados de IA para Infectados (Patrulla, Persecución por vista/oído, Regreso y Huida).

signal toco_al_jugador(infectado)
signal abatido(infectado)

enum Eje { HORIZONTAL, VERTICAL }
enum Estado { PATRULLA, PERSECUCION, HUIDA, REGRESO }

@export var speed: float = 82.0
@export var speed_persecucion: float = 124.0
@export var distancia: float = 96.0
@export var rango_vision: float = 260.0
@export var rango_oido: float = 330.0
@export var eje: Eje = Eje.HORIZONTAL
@export var max_hp: int = 3

var estado_actual: Estado = Estado.PATRULLA
var inicio: Vector2 = Vector2.ZERO
var direccion: int = 1
var hp: int = 3
var abatido_estado: bool = false
var modo_poder_activo: bool = false
var color_base: Color = Color(1.0, 1.0, 1.0, 1.0)

var ultima_pos_vista: Vector2 = Vector2.ZERO
var tiempo_memoria: float = 0.0
const RADIO_COLISION_MURO: float = 17.0


func _ready():
	inicio = position
	ultima_pos_vista = position
	hp = max_hp
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float):
	if abatido_estado or speed <= 0.0:
		return
		
	var jugador = _obtener_jugador()
	_actualizar_estado_ia(jugador, delta)
	
	match estado_actual:
		Estado.HUIDA:
			if jugador:
				var dir_huida = (global_position - jugador.global_position).normalized()
				_mover_con_deslizamiento(dir_huida, speed * 0.78, delta)
		Estado.PERSECUCION:
			var hacia_objetivo = ultima_pos_vista - global_position
			if hacia_objetivo.length() > 6.0:
				_mover_con_deslizamiento(hacia_objetivo.normalized(), speed_persecucion, delta)
			else:
				tiempo_memoria = 0.0
		Estado.REGRESO:
			var hacia_inicio = inicio - position
			if hacia_inicio.length() > 6.0:
				var movido = _mover_con_deslizamiento(hacia_inicio.normalized(), speed, delta)
				# Si un muro le impide regresar en línea recta, vuelve a patrullar desde donde está
				if not movido:
					inicio = position
					estado_actual = Estado.PATRULLA
			else:
				position = inicio
				estado_actual = Estado.PATRULLA
		Estado.PATRULLA:
			_procesar_patrulla(delta)


func _actualizar_estado_ia(jugador: Node2D, delta: float):
	if not jugador or jugador.get("muriendo"):
		tiempo_memoria = 0.0
		estado_actual = Estado.REGRESO if position.distance_to(inicio) > 10.0 else Estado.PATRULLA
		return
		
	var dist_jugador = global_position.distance_to(jugador.global_position)
	
	# 1. Si el jugador tiene adrenalina activa, los infectados cercanos huyen
	if modo_poder_activo:
		if dist_jugador < rango_vision * 0.95:
			estado_actual = Estado.HUIDA
			return
		estado_actual = Estado.PATRULLA
		return
		
	# 2. Comprobar visión directa (si la linterna está apagada, el rango visual se reduce)
	var linterna_encendida = true
	if jugador.has_node("Torso/Linterna"):
		linterna_encendida = jugador.get_node("Torso/Linterna").visible
	var alcance_vista_actual = rango_vision if linterna_encendida else rango_vision * 0.58
	
	if dist_jugador <= alcance_vista_actual and _tiene_linea_vision(jugador.global_position):
		ultima_pos_vista = jugador.global_position
		tiempo_memoria = 2.8
		estado_actual = Estado.PERSECUCION
		return
		
	# 3. Mantener persecución hacia la última posición conocida mientras dure la memoria
	if tiempo_memoria > 0.0:
		tiempo_memoria = max(0.0, tiempo_memoria - delta)
		estado_actual = Estado.PERSECUCION
	else:
		if position.distance_to(inicio) > 10.0:
			estado_actual = Estado.REGRESO
		else:
			estado_actual = Estado.PATRULLA


func _procesar_patrulla(delta: float):
	var vec_dir = Vector2(direccion, 0) if eje == Eje.HORIZONTAL else Vector2(0, direccion)
	var avance = vec_dir * speed * delta
	
	var fuera_de_rango = false
	if eje == Eje.HORIZONTAL:
		fuera_de_rango = abs((position.x + avance.x) - inicio.x) >= distancia
	else:
		fuera_de_rango = abs((position.y + avance.y) - inicio.y) >= distancia
		
	if fuera_de_rango or _chocaria_con_muro(global_position + avance, vec_dir):
		direccion *= -1
	else:
		position += avance
		_rotar_sprite(vec_dir, delta)


func _mover_con_deslizamiento(dir: Vector2, rapidez_mov: float, delta: float) -> bool:
	if dir.length_squared() < 0.001:
		return false
		
	var paso = dir.normalized() * rapidez_mov * delta
	# Intento 1: Movimiento completo en la dirección deseada
	if not _chocaria_con_muro(global_position + paso, dir.normalized()):
		position += paso
		_rotar_sprite(dir, delta)
		return true
		
	# Intento 2: Deslizar horizontalmente si el paso diagonal chocó
	var paso_x = Vector2(paso.x, 0.0)
	if abs(paso.x) > 0.05 and not _chocaria_con_muro(global_position + paso_x, Vector2(sign(paso.x), 0.0)):
		position += paso_x
		_rotar_sprite(paso_x.normalized(), delta)
		return true
		
	# Intento 3: Deslizar verticalmente
	var paso_y = Vector2(0.0, paso.y)
	if abs(paso.y) > 0.05 and not _chocaria_con_muro(global_position + paso_y, Vector2(0.0, sign(paso.y))):
		position += paso_y
		_rotar_sprite(paso_y.normalized(), delta)
		return true
		
	return false


func _chocaria_con_muro(pos_futura: Vector2, dir_unitaria: Vector2) -> bool:
	var espacio = get_world_2d().direct_space_state
	# Comprobamos frontal y laterales para no atravesar las paredes delgadas
	var perpendicular = Vector2(-dir_unitaria.y, dir_unitaria.x) * (RADIO_COLISION_MURO * 0.65)
	var puntos_prueba = [
		pos_futura + dir_unitaria * RADIO_COLISION_MURO,
		pos_futura + dir_unitaria * (RADIO_COLISION_MURO * 0.8) + perpendicular,
		pos_futura + dir_unitaria * (RADIO_COLISION_MURO * 0.8) - perpendicular
	]
	for p in puntos_prueba:
		var query = PhysicsRayQueryParameters2D.create(global_position, p)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var res = espacio.intersect_ray(query)
		if res and res.collider and res.collider.is_in_group("paredes"):
			return true
	return false


func _tiene_linea_vision(objetivo: Vector2) -> bool:
	var espacio = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, objetivo)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var res = espacio.intersect_ray(query)
	if res and res.collider and res.collider.is_in_group("paredes"):
		return false
	return true


func _rotar_sprite(dir: Vector2, delta: float):
	if has_node("Sprite2D") and dir.length_squared() > 0.001:
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, dir.angle(), 11.0 * delta)


func _obtener_jugador() -> Node2D:
	var nodos = get_tree().get_nodes_in_group("jugador")
	return nodos[0] if nodos.size() > 0 else null


func escuchar_disparo(pos_disparo: Vector2):
	if abatido_estado or modo_poder_activo:
		return
	if global_position.distance_to(pos_disparo) <= rango_oido:
		ultima_pos_vista = pos_disparo
		tiempo_memoria = 3.2
		estado_actual = Estado.PERSECUCION


func _on_body_entered(body):
	if abatido_estado:
		return
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func recibir_dano(cantidad: int, dir_impacto: Vector2 = Vector2.ZERO):
	if abatido_estado:
		return
		
	hp -= cantidad
	# Empuje por el impacto de la bala (solo si no atraviesa un muro)
	var empuje = dir_impacto * 6.0
	if not _chocaria_con_muro(global_position + empuje, dir_impacto.normalized()):
		position += empuje
		
	# Al recibir un disparo, el infectado se alerta hacia donde vino el tiro
	var jugador = _obtener_jugador()
	if jugador and not modo_poder_activo:
		ultima_pos_vista = jugador.global_position
		tiempo_memoria = 3.5
		estado_actual = Estado.PERSECUCION
		
	if hp <= 0:
		abatido.emit(self)
		desactivar_temporalmente()
	else:
		modulate = Color(1.0, 0.25, 0.25, 1.0)
		await get_tree().create_timer(0.1).timeout
		if not abatido_estado:
			modulate = color_base


func desactivar_temporalmente():
	abatido_estado = true
	tiempo_memoria = 0.0
	estado_actual = Estado.PATRULLA
	set_deferred("monitoring", false)
	visible = false
	position = inicio
	
	await get_tree().create_timer(4.0).timeout
	hp = max_hp
	abatido_estado = false
	visible = true
	modulate = color_base
	set_deferred("monitoring", true)


func cambiar_color_poder(activo: bool):
	modo_poder_activo = activo
	color_base = Color(0.3, 0.6, 1.0, 1.0) if activo else Color(1.0, 1.0, 1.0, 1.0)
	if not abatido_estado:
		modulate = color_base


func volver_a_casa():
	position = inicio
	hp = max_hp
	tiempo_memoria = 0.0
	estado_actual = Estado.PATRULLA
