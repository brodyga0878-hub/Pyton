shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// A complementary screen-space mask avoids transparent-surface sorting.
// Pair normal coverage=t with inverted coverage=1-t on the near terrain.
uniform float view_coverage : hint_range(0.0, 1.0) = 1.0;
uniform bool coverage_invert = false;
uniform vec3 atmosphere_color : source_color = vec3(0.15,0.43,0.8);
uniform vec3 sun_direction_world = vec3(0.0,1.0,0.0);
varying vec3 world_normal;
void vertex() {world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
// Stable Bayer 4x4 thresholds (pixel centres); no time-dependent noise.
float view_dither_threshold(vec2 screen_pixel) {
 ivec2 pixel=ivec2(floor(screen_pixel)) & ivec2(3);
 int low=((pixel.x & 1) ^ (pixel.y & 1))*2+(pixel.y & 1);
 int high=((pixel.x >> 1) ^ (pixel.y >> 1))*2+(pixel.y >> 1);
 return (float(low*4+high)+0.5)/16.0;
}
void fragment() {
 // Defaults preserve full opaque coverage; endpoints do not leave stray pixels.
 if(view_coverage<1.0) {
  float coverage=clamp(view_coverage,0.0,1.0);
  float threshold=view_dither_threshold(FRAGCOORD.xy);
  if(coverage<=0.0 || (coverage_invert ? threshold<1.0-coverage : threshold>=coverage)) discard;
 }
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float rim=pow(1.0-facing,3.5);
 float day=smoothstep(-0.23,0.35,dot(normalize(world_normal),sun_direction_world));
 ALBEDO=atmosphere_color;
 ALPHA=rim*day*0.38;
}
