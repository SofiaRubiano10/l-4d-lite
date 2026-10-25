extends CharacterBody2D
# Commit 1: Combate real con trazas de disparo, daño a infectados y segunda arma (Escopeta).

signal municion_cambiada(nombre_arma: String, balas_actuales: int, cargador_max: int, esta_recargando: bool)

enum TipoArma { RIFLE, ESCOPETA }

const DATOS_ARMAS = {
	TipoArma.RIFLE: {
		"nombre": "Rifle",
		"cargador": 15,
		"perdigones": 1,
		"dispersion_grados": 1.5,
		"alcance": 580.0,
		"dano": 1,
		"cadencia": 0.14,
		"color_traza": Color(1.0, 0.92, 0.45, 0.9)
	},
	TipoArma.ESCOPETA: {
		"nombre": "Escopeta",
		"cargador": 6,
		"perdigones": 5,
		"dispersion_grados": 16.0,
		"alcance": 270.0,
		"dano": 1,
		"cadencia": 0.55,
		"color_traza": Color(1.0, 0.65, 0.25, 0.95)
	}
}

@export var speed = 180.0   # px/s
@export var escopeta_desbloqueada: bool = false

var arma_actual: TipoArma = TipoArma.RIFLE
var municion = {
	TipoArma.RIFLE: 15,
	TipoArma.ESCOPETA: 6
}
var balas = 15   # Compatibilidad directa con la variable del taller
var recargando = false
var inicio = Vector2.ZERO
var muriendo = false
var tiempo_cadencia: float = 0.0

@onready var piernas = $Piernas
@onready var torso = $Torso
@onready var pasos = $Pasos
@onready var disparo = $Disparo
@onready var sonido_recarga = $Recarga
@onready var sonido_muerte = $Muerte


func _ready():
	inicio = position
	sincronizar_municion()


func establecer_inicio(nueva_pos: Vector2):
	position = nueva_pos
	inicio = nueva_pos


func _unhandled_input(event: InputEvent):
	if muriendo:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			cambiar_arma(TipoArma.RIFLE)
		elif event.keycode == KEY_2 and escopeta_desbloqueada:
			cambiar_arma(TipoArma.ESCOPETA)
		elif event.keycode == KEY_Q and escopeta_desbloqueada:
			var siguiente = TipoArma.ESCOPETA if arma_actual == TipoArma.RIFLE else TipoArma.RIFLE
			cambiar_arma(siguiente)
		elif event.keycode == KEY_F and torso.has_node("Linterna"):
			$Torso/Linterna.visible = not $Torso/Linterna.visible


func _physics_process(delta):
	if muriendo:
		return
	tiempo_cadencia = max(0.0, tiempo_cadencia - delta)
	mover()
	actualizar_piernas()
	actualizar_sonido()
	apuntar(get_global_mouse_position())
	
	if Input.is_action_pressed("disparar") and tiempo_cadencia <= 0.0:
		disparar()
	if Input.is_action_just_pressed("recargar"):
		recargar()


func cambiar_arma(nueva_arma: TipoArma):
	if recargando or arma_actual == nueva_arma:
		return
	arma_actual = nueva_arma
	sincronizar_municion()


func desbloquear_escopeta():
	escopeta_desbloqueada = true
	municion[TipoArma.ESCOPETA] = DATOS_ARMAS[TipoArma.ESCOPETA]["cargador"]
	cambiar_arma(TipoArma.ESCOPETA)


func sincronizar_municion():
	var info = DATOS_ARMAS[arma_actual]
	balas = municion[arma_actual]
	municion_cambiada.emit(info["nombre"], balas, info["cargador"], recargando)


func mover():
	var direccion = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var rapidez = speed * 0.5 if recargando else speed
	velocity = direccion * rapidez
	move_and_slide()


func actualizar_piernas():
	var real = get_real_velocity()
	if real.length() < 1.0:
		piernas.play("quieto")
		piernas.speed_scale = 1.0
	else:
		piernas.play("caminar")
		piernas.rotation = real.angle()
		piernas.speed_scale = real.length() / speed


func apuntar(objetivo: Vector2):
	torso.rotation = angulo_hacia(objetivo)


func angulo_hacia(objetivo: Vector2) -> float:
	return (objetivo - global_position).angle()


func actualizar_sonido():
	if get_real_velocity().length() > 1.0 and not pasos.playing:
		pasos.play()


func disparar():
	if recargando:
		return
	if municion[arma_actual] <= 0:
		recargar()
		return
		
	var info = DATOS_ARMAS[arma_actual]
	municion[arma_actual] -= 1
	tiempo_cadencia = info["cadencia"]
	sincronizar_municion()
	
	torso.play("disparar")
	disparo.pitch_scale = 0.82 if arma_actual == TipoArma.ESCOPETA else 1.0
	disparo.play()
	
	# Alertar por sonido a los infectados cercanos al disparar
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.has_method("escuchar_disparo"):
			enemigo.escuchar_disparo(global_position)
	
	# Lanzar rayos por cada perdigón/bala del arma actual
	var origen_arma = global_position + Vector2.RIGHT.rotated(torso.rotation) * 24.0
	var perdigones: int = info["perdigones"]
	var disp_rad: float = deg_to_rad(info["dispersion_grados"])
	
	for i in range(perdigones):
		var desvio = randf_range(-disp_rad, disp_rad)
		if perdigones > 1:
			var t = float(i) / float(perdigones - 1) - 0.5
			desvio = t * disp_rad * 2.0 + randf_range(-0.03, 0.03)
		var angulo_final = torso.rotation + desvio
		lanzar_proyectil_rayo(origen_arma, angulo_final, info["alcance"], info["dano"], info["color_traza"])


func lanzar_proyectil_rayo(origen: Vector2, angulo: float, alcance: float, dano: int, color_traza: Color):
	var dir = Vector2.RIGHT.rotated(angulo)
	var destino = origen + dir * alcance
	var punto_final = destino
	
	var espacio = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(origen, destino)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	# Excluir al propio jugador, los bidones/adrenalinas y armas en el suelo para que las balas no choquen con ítems
	var excluidos: Array[RID] = [get_rid()]
	for item in get_tree().get_nodes_in_group("bidones"):
		if item is CollisionObject2D:
			excluidos.append(item.get_rid())
	for arma_suelo in get_tree().get_nodes_in_group("armas_mapa"):
		if arma_suelo is CollisionObject2D:
			excluidos.append(arma_suelo.get_rid())
	query.exclude = excluidos
	
	var resultado = espacio.intersect_ray(query)
	if resultado:
		punto_final = resultado.position
		var colisionador = resultado.collider
		if colisionador and colisionador.is_in_group("enemigos"):
			if colisionador.has_method("recibir_dano"):
				colisionador.recibir_dano(dano, dir)
				
	dibujar_traza_disparo(origen, punto_final, color_traza)


func dibujar_traza_disparo(inicio_traza: Vector2, fin_traza: Vector2, color: Color):
	var linea = Line2D.new()
	linea.width = 2.2
	linea.default_color = color
	linea.points = PackedVector2Array([inicio_traza, fin_traza])
	get_parent().add_child(linea)
	
	var tween = create_tween()
	tween.tween_property(linea, "modulate:a", 0.0, 0.08)
	tween.tween_callback(linea.queue_free)


func recargar():
	var info = DATOS_ARMAS[arma_actual]
	if recargando or municion[arma_actual] == info["cargador"]:
		return
	recargando = true
	sincronizar_municion()
	torso.play("recargar")
	sonido_recarga.play()
	await torso.animation_finished
	if muriendo:
		return
	municion[arma_actual] = info["cargador"]
	recargando = false
	torso.play("normal")
	sincronizar_municion()


func morir():
	muriendo = true
	recargando = false
	piernas.play("quieto")
	torso.play("morir")
	sonido_muerte.play()
	await torso.animation_finished
	position = inicio
	municion[TipoArma.RIFLE] = DATOS_ARMAS[TipoArma.RIFLE]["cargador"]
	municion[TipoArma.ESCOPETA] = DATOS_ARMAS[TipoArma.ESCOPETA]["cargador"]
	torso.play("normal")
	muriendo = false
	sincronizar_municion()
