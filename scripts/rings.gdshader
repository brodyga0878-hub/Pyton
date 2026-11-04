shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 ring_color : source_color = vec3(0.7490196,0.6627451,0.5176471);
uniform vec3 sun_direction_local = vec3(0.2,0.6,0.7);
uniform int detail_level = 2;
uniform float view_coverage : hint_range(0.0,1.0) = 1.0;
uniform bool coverage_invert = false;
varying vec3 ring_position;
void vertex() {ring_position=VERTEX;}
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
 float radial=clamp((length(ring_position.xz)-1.25),0.0,1.0);
 float broad=sin(radial*43.0+sin(radial*17.0))*0.5+0.5;
 float fine=detail_level>0?sin(radial*237.0)*0.5+0.5:0.5;
 float gap=1.0-smoothstep(0.015,0.031,abs(radial-0.61));
 if(gap>0.88) discard;
 vec3 colour=ring_color*(0.47+broad*0.33+fine*0.20);
 colour=mix(colour,ring_color*0.15,gap);
 vec3 sun=normalize(sun_direction_local);
 vec3 point=vec3(ring_position.x,ring_position.y*0.025,ring_position.z);
 float t=dot(point,sun);
 float shadow=t<0.0 && length(point-sun*t)<0.98?0.11:1.0;
 float light=0.28+abs(sun.y)*0.72;
 ALBEDO=colour*shadow*light;
}
