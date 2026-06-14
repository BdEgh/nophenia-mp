shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float alpha = 1.0;
uniform float inner_radius = 0.0;
uniform float outer_radius = 1.0;

void fragment() {
	vec4 node_modulate = COLOR;
	float x = abs(UV.r-.5)*2.0;
	float y = abs(UV.g-.5)*2.0;
	float q = 1.0-(1.0-sqrt(x*x+y*y)/outer_radius)/(1.0-inner_radius);
	COLOR = vec4(target_color.rgb * node_modulate.rgb, q * alpha * target_color.a * node_modulate.a);
}