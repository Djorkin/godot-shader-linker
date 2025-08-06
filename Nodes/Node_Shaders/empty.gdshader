shader_type spatial;
render_mode  depth_draw_always, unshaded, shadows_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

#ifdef TRANSMISSION
	vec3 screen(vec2 uv) {
		vec3 screen = texture(SCREEN_TEXTURE, uv).rgb;
		return screen;
	}
#endif

void fragment() {
	#ifdef TRANSMISSION
		ALBEDO = screen(SCREEN_UV);
	#endif

}
