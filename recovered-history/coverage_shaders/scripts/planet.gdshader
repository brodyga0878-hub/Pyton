shader_type spatial;
render_mode diffuse_burley;
// A complementary screen-space mask avoids transparent-surface sorting.
// Pair normal coverage=t with inverted coverage=1-t on the near terrain.
uniform float view_coverage : hint_range(0.0, 1.0) = 1.0;
uniform bool coverage_invert = false;
uniform vec3 ocean : source_color = vec3(0.015,0.09,0.23);
uniform vec3 land : source_color = vec3(0.12,0.28,0.19);
uniform int body_kind = 0;
uniform int detail_level = 2;
uniform float seed_offset = 0.0;
float hash(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p) {
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) {return noise(p)*0.53+noise(p*2.02)*0.27+noise(p*4.13)*0.13+noise(p*8.21)*0.07;}
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
 vec3 p=vec3(sin(UV.x*6.283185)*sin(UV.y*3.14159),cos(UV.y*3.14159),cos(UV.x*6.283185)*sin(UV.y*3.14159));
 vec3 q=p+vec3(seed_offset,0.0,0.0);
 float n=fbm(q*4.0);
 vec3 col;
 if(body_kind==0) {
  float continents=smoothstep(0.48,0.535,n);
  vec3 shallows=mix(ocean,vec3(0.05,0.31,0.34),smoothstep(0.38,0.50,n)*0.6);
  vec3 ground=mix(land*0.72,land*1.35,smoothstep(0.52,0.72,n));
  col=mix(shallows,ground,continents);
  ROUGHNESS=mix(0.28,0.91,continents);
  SPECULAR=mix(0.6,0.18,continents);
  float clouds=0.0;
  if(detail_level>0) clouds=smoothstep(0.56,0.72,fbm(q*11.0+vec3(1.0,0.0,0.0)));
  col=mix(col,vec3(0.8,0.87,0.93),clouds*0.8);
  col=mix(col,vec3(0.83,0.9,0.95),smoothstep(0.86,0.99,abs(p.y)));
 } else if(body_kind==3 || body_kind==4) {
  float bands=sin(p.y*65.0+noise(q*8.0)*3.0)*0.5+0.5;
  col=mix(vec3(0.32,0.20,0.12),vec3(0.78,0.65,0.43),bands*0.7+n*0.3);
  if(body_kind==4) col=mix(vec3(0.05,0.24,0.38),vec3(0.32,0.64,0.76),bands*0.3+n*0.7);
 } else if(body_kind==6) {
  col=mix(vec3(1.0,0.38,0.08),vec3(1.0,0.92,0.65),n);
  EMISSION=col*2.5;
 } else {
  vec3 base=body_kind==2?vec3(0.46,0.22,0.10):(body_kind==5?vec3(0.52,0.65,0.72):vec3(0.27,0.28,0.29));
  col=base*(0.5+n*0.9);
  float detail=0.5;
  if(detail_level>0) detail=noise(q*90.0);
  col*=0.85+detail*0.3;
 }
 ALBEDO=col;
 if(body_kind!=0) {ROUGHNESS=0.95;SPECULAR=0.18;}
}
