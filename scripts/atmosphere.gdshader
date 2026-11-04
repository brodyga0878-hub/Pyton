shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Thin real-time limb artwork, not a physical atmosphere/chemistry model.
uniform float view_coverage : hint_range(0.0,1.0) = 1.0;
uniform bool coverage_invert = false;
uniform vec3 atmosphere_color : source_color = vec3(0.15,0.43,0.8);
uniform vec3 sun_direction_world = vec3(0.0,1.0,0.0);
varying vec3 world_normal;
void vertex() {world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
float view_dither_threshold(vec2 screen_pixel) {
 ivec2 pixel=ivec2(floor(screen_pixel)) & ivec2(3);
 int low=((pixel.x & 1) ^ (pixel.y & 1))*2+(pixel.y & 1);
 int high=((pixel.x >> 1) ^ (pixel.y >> 1))*2+(pixel.y >> 1);
 return (float(low*4+high)+0.5)/16.0;
}
void fragment() {
 if(view_coverage<1.0) {
  float coverage=clamp(view_coverage,0.0,1.0);
  float threshold=view_dither_threshold(FRAGCOORD.xy);
  if(coverage<=0.0 || (coverage_invert ? threshold<1.0-coverage : threshold>=coverage)) discard;
 }
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float rim=pow(1.0-facing,4.2);
 float sunlight=dot(normalize(world_normal),normalize(sun_direction_world));
 float day=smoothstep(-0.20,0.30,sunlight);
 float twilight=exp(-pow(sunlight*7.0,2.0));
 vec3 colour=mix(atmosphere_color,vec3(0.57,0.77,1.0),pow(1.0-facing,9.0)*0.45);
 colour=mix(colour,vec3(0.76,0.26,0.10),twilight*0.36);
 ALBEDO=colour*1.65;
 ALPHA=clamp(rim*(day*0.67+twilight*0.16),0.0,0.82);
}
