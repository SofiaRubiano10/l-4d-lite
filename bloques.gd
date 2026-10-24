extends Node2D
# Construye el suelo urbano y paredes delgadas continuas (horizontales y verticales)
# para dejar mucho más espacio libre de movimiento en los pasillos.

const CELDA = 64
const GROSOR_MURO = 22.0


func construir_bloques(mapa: Array, color: Color):
	var alto_celdas = mapa.size()
	var ancho_celdas = mapa[0].length() if alto_celdas > 0 else 0
	
	# Suelo de asfalto oscuro para todo el laberinto
	var suelo = ColorRect.new()
	suelo.color = Color(0.14, 0.15, 0.17, 1.0)
	suelo.size = Vector2(ancho_celdas * CELDA, alto_celdas * CELDA)
	suelo.z_index = -10
	add_child(suelo)
	
	# 1. Tramos horizontales continuos (y pilares aislados)
	for fila in alto_celdas:
		var col = 0
		var linea: String = mapa[fila]
		while col < linea.length():
			if linea[col] == "#":
				var fin = col
				while fin + 1 < linea.length() and linea[fin + 1] == "#":
					fin += 1
				var tiene_vecino_v = _es_muro(mapa, col, fila - 1) or _es_muro(mapa, col, fila + 1)
				if fin > col or not tiene_vecino_v:
					var largo = (fin - col) * CELDA + GROSOR_MURO
					var centro = Vector2(((col + fin) * 0.5 + 0.5) * CELDA, (fila + 0.5) * CELDA)
					crear_segmento_muro(centro, Vector2(largo, GROSOR_MURO), color)
				col = fin + 1
			else:
				col += 1
				
	# 2. Tramos verticales continuos
	for col in ancho_celdas:
		var fila = 0
		while fila < alto_celdas:
			if _es_muro(mapa, col, fila):
				var fin = fila
				while fin + 1 < alto_celdas and _es_muro(mapa, col, fin + 1):
					fin += 1
				if fin > fila:
					var alto = (fin - fila) * CELDA + GROSOR_MURO
					var centro = Vector2((col + 0.5) * CELDA, ((fila + fin) * 0.5 + 0.5) * CELDA)
					crear_segmento_muro(centro, Vector2(GROSOR_MURO, alto), color)
				fila = fin + 1
			else:
				fila += 1


func _es_muro(mapa: Array, col: int, fila: int) -> bool:
	if fila < 0 or fila >= mapa.size():
		return false
	var linea: String = mapa[fila]
	if col < 0 or col >= linea.length():
		return false
	return linea[col] == "#"


func crear_segmento_muro(centro: Vector2, tamano: Vector2, color: Color):
	var cuerpo = StaticBody2D.new()
	cuerpo.add_to_group("paredes")
	cuerpo.position = centro
	
	var forma = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = tamano
	forma.shape = rect
	cuerpo.add_child(forma)
	
	# Borde oscuro del muro delgado
	var borde = ColorRect.new()
	borde.color = color.darkened(0.35)
	borde.size = tamano
	borde.position = -tamano / 2.0
	cuerpo.add_child(borde)
	
	# Relleno interior del muro delgado
	var dibujo = ColorRect.new()
	dibujo.color = color
	var margen = Vector2(4.0, 4.0)
	dibujo.size = (tamano - margen).max(Vector2(4.0, 4.0))
	dibujo.position = -dibujo.size / 2.0
	cuerpo.add_child(dibujo)
	
	add_child(cuerpo)
