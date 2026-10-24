extends CharacterBody2D
# Taller 3 resuelto, más morir() y sistema de disparo real para el Taller 4.

signal municion_cambiada(balas_actuales, cargador_max, esta_recargando)

const CARGADOR = 15   # balas por cargador

@export var speed = 180.0   # px/s

var bala_escena = preload("res://bala.tscn")

var balas = CARGADOR
var recargando = false
var inicio = Vector2.ZERO
var muriendo = false

@onready var piernas = $Piernas
@onready var torso = $Torso
@onready var punto_disparo = $Torso/PuntoDisparo
@onready var pasos = $Pasos
@onready var disparo = $Disparo
@onready var sonido_recarga = $Recarga
@onready var sonido_muerte = $Muerte


func _ready():
	inicio = position
	torso.animation_finished.connect(_on_torso_animation_finished)
	municion_cambiada.emit(balas, CARGADOR, recargando)


func _physics_process(_delta):
	if muriendo:
		return
	mover()
	actualizar_piernas()
	actualizar_sonido()
	apuntar(get_global_mouse_position())
	if Input.is_action_just_pressed("disparar"):
		disparar()
	if Input.is_action_just_pressed("recargar"):
		recargar()


func mover():
	var direccion = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var rapidez = speed * 0.5 if recargando else speed   # nivel 3: recargando camina a la mitad
	velocity = direccion * rapidez
	move_and_slide()


# Nivel 1 (y nivel 3: speed_scale)
func actualizar_piernas():
	var real = get_real_velocity()
	if real.length() < 1.0:
		piernas.play("quieto")
		piernas.speed_scale = 1.0
	else:
		piernas.play("caminar")
		piernas.rotation = real.angle()      # nivel 2: las piernas miran hacia donde avanza
		piernas.speed_scale = real.length() / speed


# Nivel 2
func apuntar(objetivo: Vector2):
	torso.rotation = angulo_hacia(objetivo)   # la linterna es hija del torso: gira sola


func angulo_hacia(objetivo: Vector2) -> float:
	return (objetivo - global_position).angle()


func actualizar_sonido():
	if get_real_velocity().length() > 1.0 and not pasos.playing:
		pasos.play()


func disparar():
	if recargando:
		return
	if balas == 0:
		recargar()
		return
	balas -= 1
	municion_cambiada.emit(balas, CARGADOR, recargando)
	instanciar_bala()
	torso.play("disparar")
	disparo.play()   # cada disparo es un sonido nuevo: aquí sí se reinicia


func instanciar_bala():
	var bala = bala_escena.instantiate()
	bala.global_position = punto_disparo.global_position
	bala.global_rotation = torso.global_rotation
	get_parent().add_child(bala)


func _on_torso_animation_finished():
	if torso.animation == &"disparar" and not recargando and not muriendo:
		torso.play("normal")


# Nivel 3
func recargar():
	if recargando or balas == CARGADOR:
		return
	recargando = true
	municion_cambiada.emit(balas, CARGADOR, recargando)
	torso.play("recargar")
	sonido_recarga.play()
	await torso.animation_finished
	if muriendo:
		return
	balas = CARGADOR
	recargando = false
	municion_cambiada.emit(balas, CARGADOR, recargando)
	torso.play("normal")


# Para el Taller 4: el Mundo la llama cuando un infectado toca al superviviente.
func morir():
	muriendo = true
	recargando = false
	piernas.play("quieto")
	torso.play("morir")
	sonido_muerte.play()
	await torso.animation_finished
	position = inicio
	balas = CARGADOR
	municion_cambiada.emit(balas, CARGADOR, recargando)
	torso.play("normal")
	muriendo = false
