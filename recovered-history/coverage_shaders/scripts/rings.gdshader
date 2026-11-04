shader_type spatial;
render_mode diffuse_burley;
uniform vec3 ring_color : source_color = vec3(0.7490196,0.6627451,0.5176471);
uniform float view_coverage : hint_range(0.0,1.0) = 1.0;
uniform bool coverage_invert = false;
// Stable Bayer 4x4 thresholds (pixel centres); no time-dependent noise.
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
 ALBEDO=ring_color;
 ROUGHNESS=1.0;
}
