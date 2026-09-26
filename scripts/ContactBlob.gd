class_name ContactBlob
extends RefCounted

## SOMBRA DE CONTACTO de un prop ESTATICO: un disco en el suelo con degradado
## por COLOR DE VERTICE. Sin textura propia (usa la radial compartida), sin luz
## (unshaded), sin cambios en el bake de LightmapGI: coste ~0, un draw por mapa.
##
## Existe como clase y no como codigo en `World.gd` porque lo usan DOS mapas: el
## banco de calibracion y el de combate. Una sola autoridad para el disco.
##
## Solo props quietos: el Jolt tira las latas y las hace rodar, y ahi el disco
## se quedaria pegado en el aire.

## La radial se genera UNA vez y la comparten todos los mapas del proceso: es
## el mismo camino alpha que los decals de `ImpactFX`. Alfa 0,68 plano hasta
## d=0,62 -> 0 en d=1.
static var _mat: StandardMaterial3D

const SEGMENTS := 16
const INNER := 0.62
const OUTER := 0.17
const PEAK := 0.68
const SIZE := 64

var _pts := PackedVector3Array()
var _uv := PackedVector2Array()
var _idx := PackedInt32Array()


func is_empty() -> bool:
	return _idx.is_empty()


## `fx`/`fz` = media del prop: el anillo INTERNO (UV radio 0,62) va en su borde,
## que es lo unico visible (debajo esta la propia pieza); el EXTERNO (+17 cm,
## UV radio 1) cierra el disco.
func add(x: float, z: float, fx: float, fz: float, rot_y := 0.0) -> void:
	var y := 0.006
	var cos_r := cos(rot_y)
	var sin_r := sin(rot_y)
	var ci := _pts.size()
	_pts.append(Vector3(x, y, z))
	_uv.append(Vector2(0.5, 0.5))
	for s in SEGMENTS:
		var a := TAU * float(s) / float(SEGMENTS)
		_ring(x, z, y, cos(a) * fx, sin(a) * fz, cos_r, sin_r, 0.5 + cos(a) * 0.31, 0.5 + sin(a) * 0.31)
	for s in SEGMENTS:
		var a := TAU * float(s) / float(SEGMENTS)
		_ring(x, z, y, cos(a) * (fx + OUTER), sin(a) * (fz + OUTER), cos_r, sin_r,
			0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5)
	for s in SEGMENTS:
		# abanico centro -> anillo interno
		_idx.append(ci)
		_idx.append(ci + 1 + ((s + 1) % SEGMENTS))
		_idx.append(ci + 1 + s)
		# cinta anillo interno -> externo
		var i0 := ci + 1 + s
		var i1 := ci + 1 + ((s + 1) % SEGMENTS)
		var o0 := ci + 1 + SEGMENTS + s
		var o1 := ci + 1 + SEGMENTS + ((s + 1) % SEGMENTS)
		_idx.append(i0)
		_idx.append(i1)
		_idx.append(o1)
		_idx.append(i0)
		_idx.append(o1)
		_idx.append(o0)


func _ring(x: float, z: float, y: float, px: float, pz: float,
		cos_r: float, sin_r: float, u: float, v: float) -> void:
	_pts.append(Vector3(x + px * cos_r + pz * sin_r, y, z - px * sin_r + pz * cos_r))
	_uv.append(Vector2(u, v))


## UN solo MeshInstance3D con TODOS los discos del mapa: una submission, sin
## sombras propias y sin depth-write (transparente), con depth-test contra el
## suelo.
func build() -> MeshInstance3D:
	if is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pts
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "ContactBlobs"
	mi.mesh = mesh
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
	for yy in SIZE:
		for xx in SIZE:
			var d := Vector2(float(xx) - SIZE * 0.5 + 0.5, float(yy) - SIZE * 0.5 + 0.5).length() / (SIZE * 0.5 - 0.5)
			var a := 0.0
			if d <= INNER:
				a = PEAK
			elif d < 1.0:
				a = PEAK * (1.0 - (d - INNER) / (1.0 - INNER))
			img.set_pixel(xx, yy, Color(0.0, 0.0, 0.0, a))
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_texture = ImageTexture.create_from_image(img)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat
