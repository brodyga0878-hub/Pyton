shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float power : hint_range(0.0,1.0) = 0.4;
void vertex() {
 // A camera-facing geometric glow at the nozzle, retaining normal depth tests.
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
 float radius = length(UV*2.0-1.0);
 float soft = exp(-radius*radius*5.8) * (1.0-smoothstep(0.72,1.0,radius));
 ALBEDO = mix(vec3(0.08,0.49,1.0),vec3(0.67,0.95,1.0),pow(soft,3.0));
 ALPHA = soft*(0.28+power*0.46);
}
