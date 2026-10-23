extends CharacterBody2D
# Taller 3 resuelto, más morir() para el Taller 4.

const CARGADOR = 15   # balas por cargador

@export var speed = 180.0   # px/s

var balas = CARGADOR
var recargando = false
var inicio = Vector2.ZERO
var muriendo = false

@onready var piernas = $Piernas
@onready var torso = $Torso
@onready var pasos = $Pasos
@onready var disparo = $Disparo
@onready var sonido_recarga = $Recarga
@onready var sonido_muerte = $Muerte


func _ready():
	inicio = position


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
	torso.play("disparar")
	disparo.play()   # cada disparo es un sonido nuevo: aquí sí se reinicia


# Nivel 3
func recargar():
	if recargando or balas == CARGADOR:
		return
	recargando = true
	torso.play("recargar")
	sonido_recarga.play()
	await torso.animation_finished
	balas = CARGADOR
	recargando = false
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
	torso.play("normal")
	muriendo = false
