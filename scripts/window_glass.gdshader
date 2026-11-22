shader_type spatial;
render_mode cull_back, diffuse_lambert;

// One opaque pass: analytical room depth behind a dirty reflecting glass layer.
// COLOR.rgb is the window's light tint, COLOR.a its intensity. UV2.x is a seed,
// UV2.y the aperture aspect ratio. No room geometry, transparency or SSR.
uniform samplerCube exterior_reflection : source_color, filter_linear_mipmap;
uniform bool has_reflection = false;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float rectangle(vec2 p, vec2 a, vec2 b) {
	return step(a.x,p.x)*step(a.y,p.y)*step(p.x,b.x)*step(p.y,b.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float seed = fract(UV2.x);
	bool hall = UV2.x > 1.0;
	vec3 normal_world = normalize(world_normal);
	vec3 right = normalize(cross(vec3(0,1,0), normal_world));
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 eye_local = vec3(dot(eye,right),eye.y,dot(eye,normal_world));
	float variant = floor(hash(vec2(seed,2.1))*4.0);
	float room_depth = mix(1.1,1.8,hash(vec2(seed,4.0)));
	vec3 origin = vec3(mix(vec2(0.15,0.08),vec2(0.85,0.92),UV),0.001);
	vec3 ray = vec3(-eye_local.x/max(UV2.y*1.43,0.2),-eye_local.y/1.19,max(eye_local.z,0.001)/room_depth);
	vec3 safe_ray = sign(ray + vec3(0.000001))*max(abs(ray),vec3(0.00001));
	vec3 far_t = (step(vec3(0.0),safe_ray)-origin)/safe_ray;
	float distance_hit = min(far_t.x,min(far_t.y,far_t.z));
	vec3 hit = clamp(origin+ray*max(distance_hit,0.0),vec3(0),vec3(1));
	vec3 wall_color = mix(vec3(0.20,0.18,0.145),vec3(0.155,0.19,0.17),hash(vec2(seed,8.0)));
	float wallpaper = 0.94 + 0.06*step(0.5,fract(hit.x*24.0 + hit.z*21.0));
	vec3 room = wall_color*wallpaper;
	bool ceiling = far_t.y < far_t.x && far_t.y < far_t.z && ray.y > 0.0;
	bool floor_hit = far_t.y < far_t.x && far_t.y < far_t.z && ray.y <= 0.0;
	bool back_wall = far_t.z <= far_t.x && far_t.z <= far_t.y;
	if (floor_hit) {
		float boards = 0.72 + 0.28*step(0.04,fract(hit.x*9.0));
		room = vec3(0.095,0.071,0.047)*boards;
	}
	if (ceiling) {
		room = vec3(0.27,0.255,0.215);
		float lamp = 1.0-smoothstep(0.045,0.075,length((hit.xz-vec2(0.5,0.48))*vec2(1.0,1.25)));
		room = mix(room,vec3(1.9,1.65,1.23),lamp);
	}
	if (back_wall && !hall) {
		// Four restrained room arrangements: a picture, cabinet, doorway or shelf.
		float picture = rectangle(hit.xy,vec2(0.52,0.49),vec2(0.76,0.73));
		float picture_inside = rectangle(hit.xy,vec2(0.54,0.51),vec2(0.74,0.71));
		room = mix(room,vec3(0.042,0.032,0.024),picture);
		room = mix(room,vec3(0.10,0.125,0.105),picture_inside);
		if (variant < 1.0 || variant > 2.5) {
			float door = rectangle(hit.xy,vec2(0.10,0.0),vec2(0.32,0.69));
			room = mix(room,vec3(0.055,0.046,0.035),door);
		} else {
			float cabinet = rectangle(hit.xy,vec2(0.77,0.0),vec2(0.96,0.60));
			room = mix(room,vec3(0.066,0.048,0.031),cabinet);
			float shelf = rectangle(hit.xy,vec2(0.34,0.25),vec2(0.74,0.28));
			room = mix(room,vec3(0.045,0.034,0.025),shelf);
		}
	}
	float corner = min(min(hit.x,1.0-hit.x),min(hit.y,1.0-hit.y));
	room *= 0.55+0.45*smoothstep(0.0,0.16,corner);
	room *= 0.62+0.55*exp(-length(hit-vec3(0.5,0.98,0.48))*1.15);
	// Curtains are on a shallow plane, distinct from the deep room surfaces.
	vec2 curtain_uv = UV-eye_local.xy/max(eye_local.z,0.15)*vec2(0.025/max(UV2.y,0.3),0.025);
	float left_edge = mix(0.12,0.25,hash(vec2(seed,12.0)));
	float right_edge = mix(0.74,0.90,hash(vec2(seed,17.0)));
	if (variant > 1.5 && variant < 2.5 && COLOR.a < 0.55) { left_edge=0.46; right_edge=0.54; }
	float curtain = max(1.0-step(left_edge,curtain_uv.x),step(right_edge,curtain_uv.x));
	float fold = 0.56+0.24*sin(curtain_uv.x*87.0+seed*6.0)+0.10*sin(curtain_uv.x*173.0);
	vec3 cloth = vec3(0.29,0.265,0.215)*fold*(0.72+0.28*curtain_uv.y);
	room = mix(room,cloth,curtain*(hall?0.55:0.91));
	vec2 cell = fract(UV*vec2(2.0,2.0));
	float border = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
	float pane = step(0.028,border)*(1.0-rectangle(UV,vec2(0.488,0.0),vec2(0.512,1.0)))*(1.0-rectangle(UV,vec2(0.0,0.481),vec2(1.0,0.503)));
	float pane_edge = min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y));
	float dust = hash(floor(UV*vec2(83,119))+seed*29.0);
	float streak = smoothstep(0.77,0.98,hash(vec2(floor(UV.x*61.0),seed*19.0)))*(0.4+0.6*UV.y);
	float dirt = clamp(dust*0.16+streak*0.45+(1.0-smoothstep(0.0,0.12,pane_edge))*0.25,0.0,0.8);
	float fresnel = 0.045+0.61*pow(1.0-clamp(eye_local.z,0.0,1.0),5.0);
	vec3 reflected_direction = reflect(-eye,normal_world);
	vec3 reflection = vec3(0.018,0.026,0.023)*(0.6+0.4*max(reflected_direction.y,0.0));
	if (has_reflection) { reflection = textureLod(exterior_reflection,reflected_direction,1.2+dirt*3.0).rgb; }
	float brightness = COLOR.a*(0.84+0.16*hash(vec2(seed,28.0)));
	vec3 frame = vec3(0.055,0.051,0.042);
	ALBEDO = mix(frame,vec3(0.018,0.025,0.023)+dirt*0.028,pane);
	EMISSION = pane*(room*COLOR.rgb*brightness*(1.0-fresnel)*(1.0-dirt*0.45)+reflection*fresnel*1.15);
	EMISSION += (1.0-pane)*COLOR.rgb*brightness*0.014;
	ROUGHNESS = mix(0.87,0.16+dirt*0.48,pane);
	SPECULAR = mix(0.08,0.78,pane);
	METALLIC = 0.0;
}
