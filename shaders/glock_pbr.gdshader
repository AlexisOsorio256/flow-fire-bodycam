shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Material PBR del arma, con la MISMA convencion de canales que glTF usa para
// su metallicRoughnessTexture: verde = rugosidad, azul = metalico.
//
// POR QUE UN SHADER Y NO StandardMaterial3D
// -----------------------------------------
// `StandardMaterial3D` en Godot 4 no tiene una propiedad ORM: expone
// `roughness_texture` (que lee el ROJO) y `metallic_texture` (que lee el AZUL),
// pero NO deja elegir el canal. Un mapa glTF empaquetado pone la rugosidad en el
// VERDE, asi que con el material estandar la rugosidad saldria del rojo, que en
// este atlas es oclusion. Intentar `orm_texture` (que no existe) fue el bug que
// dejo el arma con el material por defecto de Godot: un blob blanco.
//
// Tres lineas de shader resuelven el canal sin inventar nada.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 1.0) = 1.0;

// NO HAY `emission_tex` NI `emission_energy`, y el motivo es una medida: el mapa
// de emision que traia el asset (`g19_pistol_Image_5.png`, 2048 px) tiene media
// medida 0,0/0,0/0,0 — negro exacto en los tres canales. La linea
// `EMISSION = texture(emission_tex, UV).rgb * emission_energy` costaba un
// sampler, una textura en VRAM y un fetch por fragmento del arma para escribir

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = albedo;
	// Canal VERDE del mapa empaquetado: rugosidad.
	ROUGHNESS = clamp(orm.g * roughness_scale, 0.04, 1.0);
	// Canal AZUL: metalico.
	METALLIC = clamp(orm.b * metallic_scale, 0.0, 1.0);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
