shader_type sky;
// Original six Source skybox textures, mapped onto the sky sphere.
uniform sampler2D face_rt : source_color, filter_linear, repeat_disable;
uniform sampler2D face_lf : source_color, filter_linear, repeat_disable;
uniform sampler2D face_ft : source_color, filter_linear, repeat_disable;
uniform sampler2D face_bk : source_color, filter_linear, repeat_disable;
uniform sampler2D face_up : source_color, filter_linear, repeat_disable;
uniform sampler2D face_dn : source_color, filter_linear, repeat_disable;
void sky() {
	vec3 d = normalize(vec3(EYEDIR.x, -EYEDIR.z, EYEDIR.y));
	vec3 a = abs(d); vec3 c;
	if (a.z >= a.x && a.z >= a.y) {
		vec2 uv = vec2(d.x, -d.y) / a.z * 0.5 + 0.5;
		c = d.z > 0.0 ? texture(face_up, uv).rgb : texture(face_dn, uv).rgb;
	} else if (a.x >= a.y) {
		vec2 uv = vec2(d.x > 0.0 ? -d.y : d.y, -d.z) / a.x * 0.5 + 0.5;
		c = d.x > 0.0 ? texture(face_rt, uv).rgb : texture(face_lf, uv).rgb;
	} else {
		vec2 uv = vec2(d.y > 0.0 ? d.x : -d.x, -d.z) / a.y * 0.5 + 0.5;
		c = d.y > 0.0 ? texture(face_bk, uv).rgb : texture(face_ft, uv).rgb;
	}
	COLOR = c;
}
