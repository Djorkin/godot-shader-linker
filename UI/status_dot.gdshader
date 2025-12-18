shader_type canvas_item;

uniform vec4 dot_color : source_color = vec4(0.3, 0.9, 0.3, 1.0);
uniform float radius = 0.45;
uniform float edge_smooth = 0.02;

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float alpha = smoothstep(radius + edge_smooth, radius - edge_smooth, dist);
    if (alpha <= 0.0) {
        discard;
    }
    COLOR = vec4(dot_color.rgb, dot_color.a * alpha);
}


