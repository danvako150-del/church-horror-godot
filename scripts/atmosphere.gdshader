shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool nightmare = false;
uniform bool enabled = true;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.024;
uniform float color_steps : hint_range(24.0, 128.0) = 64.0;
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.22;
uniform float pixel_scale : hint_range(0.5, 1.0) = 0.75;
float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float bayer4(vec2 pixel) {
	vec2 p = mod(floor(pixel), 4.0);
	float low = mod(p.x, 2.0) * 2.0 + mod(p.y, 2.0) * 3.0;
	low = mod(low, 4.0);
	vec2 hi = floor(p * 0.5);
	float high = mod(hi.x * 2.0 + hi.y * 3.0, 4.0);
	return (low * 4.0 + high + 0.5) / 16.0 - 0.5;
}
vec3 bright(vec2 uv) {
	vec3 c = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	return c * smoothstep(0.70, 0.97, luminance(c));
}
void fragment() {
	// Sample a lower-resolution digital image without temporal AA or blur.
	vec2 resolution = min(vec2(960.0, 540.0), (1.0 / SCREEN_PIXEL_SIZE) * pixel_scale);
	vec2 pixel = floor(SCREEN_UV * resolution);
	vec2 uv = (pixel + 0.5) / resolution;
	float night = nightmare ? 1.0 : 0.0;
	uv.x += sin(uv.y * 35.0 + TIME * 2.0) * 0.0015 * night;
	vec4 src = texture(screen_texture, uv);
	float lum = luminance(src.rgb);
	float warm = clamp((src.r - src.b) * 3.0, 0.0, 1.0) * smoothstep(0.2, 0.7, lum);
	vec3 c = mix(src.rgb, vec3(lum), (0.33 + night * 0.16) * (1.0 - warm * 0.70));
	float shadow = 1.0 - smoothstep(0.06, 0.50, lum);
	// Muted grey-green shadows, nicotine-coloured lamps; preserve real black.
	c *= mix(vec3(1.0), vec3(0.94, 1.00, 0.91), shadow * 0.70);
	c = max((c - 0.18) * 1.10 + 0.18, vec3(0.0));
	vec2 d = 2.0 / resolution;
	vec3 glow = bright(uv+vec2(d.x,0)) + bright(uv-vec2(d.x,0));
	glow += bright(uv+vec2(0,d.y)) + bright(uv-vec2(0,d.y));
	c += glow * 0.012;
	vec2 q = SCREEN_UV * 2.0 - 1.0;
	c *= 1.0 - (vignette_strength + night * 0.15) * smoothstep(0.35, 1.7, dot(q,q));
	float tick = floor(TIME * 24.0);
	float grain = fract(52.9829189 * fract(dot(pixel + tick * vec2(17,29),vec2(0.06711056,0.00583715)))) - 0.5;
	// Sensor grain refreshed at 24 Hz, subtle ordered quantisation, no CRT lines.
	c += grain * (grain_strength + night * 0.025) * mix(0.28, 1.0, smoothstep(0.01, 0.25, lum));
	c = floor(clamp(c, vec3(0.0), vec3(1.0)) * color_steps + bayer4(pixel) * 0.65 + 0.5) / color_steps;
	COLOR = enabled ? vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0) : texture(screen_texture, SCREEN_UV);
}
