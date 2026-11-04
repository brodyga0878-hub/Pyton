shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 atmosphere_color : source_color = vec3(0.15,0.43,0.8);
uniform vec3 sun_direction_world = vec3(0.0,1.0,0.0);
varying vec3 world_normal;
void vertex() {world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
void fragment() {
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float rim=pow(1.0-facing,3.5);
 float day=smoothstep(-0.23,0.35,dot(normalize(world_normal),sun_direction_world));
 ALBEDO=atmosphere_color;
 ALPHA=rim*day*0.38;
}
