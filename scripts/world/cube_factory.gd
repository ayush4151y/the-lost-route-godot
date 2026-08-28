extends RefCounted
# CubeFactory - builds visual block/entity meshes with procedural textures
# (faithful to original per-type colors and simple procedural textures).
# Self-contained: no binary assets, all generated at runtime.

const GRASS := "grass"
const ICE := "ice"
const FIRE := "fire"
const TNT := "tnt"
const HEART := "heart"
const START := "start"
const END := "end"
const DECOY := "decoy"

const COLORS := {
	GRASS: Color(0.30, 0.69, 0.31),
	ICE: Color(0.13, 0.59, 0.95),
	FIRE: Color(1.0, 0.60, 0.0),
	TNT: Color(0.72, 0.11, 0.11),
	HEART: Color(0.91, 0.12, 0.39),
	START: Color(0.30, 0.69, 0.31),
	END: Color(0.9, 0.2, 0.2),
	DECOY: Color(0.35, 0.1, 0.1),
}

const EMISSIVES := {
	GRASS: Color(0.18, 0.49, 0.18),
	ICE: Color(0.08, 0.40, 0.77),
	FIRE: Color(0.9, 0.32, 0.0),
	TNT: Color(0.29, 0.0, 0.0),
	HEART: Color(0.53, 0.05, 0.31),
	START: Color(0.18, 0.49, 0.18),
	END: Color(0.7, 0.1, 0.1),
	DECOY: Color(0.4, 0.0, 0.0),
}

const SHININESS := {
	GRASS: 0.1, ICE: 0.8, FIRE: 0.1, TNT: 0.05, HEART: 0.3,
	START: 0.1, END: 0.1, DECOY: 0.05,
}

# Build a path block cube (rounded-ish box). Returns MeshInstance3D.
func build_block(kind: String, cell_size: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(cell_size, cell_size, cell_size)
	mi.mesh = bm
	var mat := build_material(kind)
	mi.material_override = mat
	mi.set_meta("type", kind)
	mi.set_meta("cell", Vector3.ZERO)
	return mi


func build_material(kind: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var c: Color = COLORS.get(kind, COLORS[GRASS])
	var e: Color = EMISSIVES.get(kind, EMISSIVES[GRASS])
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = e
	mat.emission_energy_multiplier = 0.3
	var s: float = SHININESS.get(kind, 0.1)
	mat.metallic = s
	mat.roughness = 1.0 - s
	mat.vertex_color_use_as_albedo = false
	return mat


# Player body - rounded box with a simple face
func build_player_body() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.55, 0.5)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.61, 0.89, 0.94)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.71, 0.81)
	mat.emission_energy_multiplier = 0.22
	mi.material_override = mat
	return mi


# TNT barrel (slightly rounded, taller than wide)
func build_tnt_barrel() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.8, 0.7)
	mi.mesh = bm
	mi.material_override = build_material(TNT)
	return mi


# explosion flash sphere
func build_boom() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	return mi
