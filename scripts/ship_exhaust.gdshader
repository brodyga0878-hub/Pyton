shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 jet_colour : source_color = vec4(0.16,0.65,1.0,1.0);
uniform float power : hint_range(0.0,1.0) = 0.5;
void fragment() {
 float base = pow(clamp(UV.y,0.0,1.0),0.8);
 float fingers = 0.72 + 0.28*sin(UV.x*50.26548 + TIME*13.0 + UV.y*17.0);
 float pulse = 0.90 + 0.1*sin(TIME*23.0-UV.y*32.0);
 vec3 colour = mix(jet_colour.rgb,vec3(0.8,0.95,1.0),pow(base,5.0));
 ALBEDO = colour * (1.8+power*2.4);
 ALPHA = base*fingers*pulse*(0.36+power*0.52);
}
