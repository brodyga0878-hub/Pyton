shader_type spatial;
render_mode unshaded;
// Original procedural presentation. Physics, source records and surface terrain
// are not inferred from this artwork. Coverage pairs with the near terrain.
uniform float view_coverage : hint_range(0.0, 1.0) = 1.0;
uniform bool coverage_invert = false;
uniform vec3 ocean : source_color = vec3(0.015,0.09,0.23);
uniform vec3 land : source_color = vec3(0.12,0.28,0.19);
uniform vec3 sun_direction_world = vec3(0.0,1.0,0.0);
uniform int body_kind = 0;
uniform int detail_level = 2;
uniform bool inhabited = false;
uniform float seed_offset = 0.0;
varying vec3 world_normal;
void vertex() { world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz); }
float hash(vec3 p) {
 p=fract(p*0.1031); p+=dot(p,p.yzx+33.33);
 return fract((p.x+p.y)*p.z);
}
float noise(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) {
 float value=noise(p)*0.56+noise(p*2.03+vec3(11.7))*0.28;
 if(detail_level>0) value+=noise(p*4.13+vec3(3.1))*0.12;
 if(detail_level>1) value+=noise(p*8.29+vec3(7.2))*0.04;
 return value;
}
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
 vec3 p=vec3(sin(UV.x*6.283185)*sin(UV.y*3.141593),cos(UV.y*3.141593),cos(UV.x*6.283185)*sin(UV.y*3.141593));
 vec3 q=p+vec3(seed_offset,seed_offset*0.17,2.3);
 vec3 wn=normalize(world_normal);
 vec3 sun=normalize(sun_direction_world);
 float incidence=dot(wn,sun);
 float day=smoothstep(-0.13,0.23,incidence);
 float diffuse=pow(max(0.0,incidence),0.58);
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float rim=pow(1.0-facing,4.0);
 float n=fbm(q*3.15);
 vec3 col=vec3(0.0);
 vec3 lamps=vec3(0.0);
 float water=0.0;
 if(body_kind==0) {
  // Domain-warped continent edges rather than a single noise threshold.
  vec3 warped=q+vec3(noise(q*4.7),noise(q*4.7+vec3(15.0)),noise(q*4.7+vec3(31.0)))*0.22;
  float continent=fbm(warped*3.6);
  float coast=smoothstep(0.526,0.550,continent);
  water=1.0-coast;
  float latitude=abs(p.y);
  float climate=fbm(q*8.0);
  float ridges=pow(1.0-abs(climate*2.0-1.0),3.0);
  vec3 forest=mix(land*0.55,vec3(0.20,0.29,0.13),smoothstep(0.40,0.7,climate));
  float desert=smoothstep(0.48,0.70,climate)*(1.0-smoothstep(0.25,0.53,latitude));
  vec3 ground=mix(forest,vec3(0.48,0.37,0.20),desert*0.86);
  ground=mix(ground,vec3(0.29,0.28,0.24),smoothstep(0.67,0.89,ridges)*0.46);
  float snow=smoothstep(0.76,0.95,latitude+climate*0.13);
  ground=mix(ground,vec3(0.75,0.83,0.83),snow);
  vec3 sea=mix(ocean*0.78+vec3(0.002,0.014,0.032),vec3(0.018,0.20,0.27),smoothstep(0.49,0.545,continent));
  col=mix(sea,ground,coast);
  if(detail_level>0) {
   float drift=TIME*0.00052;
   vec3 cloud_p=vec3(p.x*cos(drift)-p.z*sin(drift),p.y,p.x*sin(drift)+p.z*cos(drift));
   float cloud_field=fbm(cloud_p*9.5+vec3(seed_offset,4.8,1.9));
   float cloud=smoothstep(0.565,0.72,cloud_field);
   float fringe=smoothstep(0.49,0.66,cloud_field)*0.13;
   col*=1.0-cloud*0.17;
   col=mix(col,vec3(0.82,0.88,0.91),clamp(cloud*0.83+fringe,0.0,0.94));
   water*=1.0-cloud;
   if(detail_level>1 && inhabited) {
    float settlement=noise(q*138.0);
    float light=smoothstep(0.80,0.93,settlement)*smoothstep(0.45,0.59,continent)*(1.0-snow);
    // Decorative city lights only, not the locations of FFE settlements.
    lamps=vec3(1.0,0.52,0.17)*light*(1.0-day)*0.38;
   }
  }
  vec3 half_direction=normalize(normalize(VIEW)+normalize((VIEW_MATRIX*vec4(sun,0.0)).xyz)+vec3(0.00001));
  float glint=pow(max(0.0,dot(normalize(NORMAL),half_direction)),85.0)*water*day;
  col=col*(vec3(0.012,0.024,0.045)+vec3(1.32,1.28,1.17)*diffuse)+vec3(0.58,0.70,0.76)*glint;
  col+=vec3(0.055,0.22,0.39)*rim*day*0.36+lamps;
 } else if(body_kind==3 || body_kind==4) {
  float warp=noise(q*8.0)*2.8+sin(p.y*9.0)*0.9;
  float broad=sin(p.y*57.0+warp)*0.5+0.5;
  float thin=sin(p.y*181.0+warp*2.4)*0.5+0.5;
  float bands=broad*0.77+thin*0.23;
  col=mix(vec3(0.22,0.12,0.065),vec3(0.79,0.65,0.44),bands*0.76+n*0.24);
  if(body_kind==4) col=mix(vec3(0.025,0.16,0.26),vec3(0.39,0.70,0.76),bands*0.56+n*0.44);
  float storm=exp(-pow((p.y+0.24)*12.0,2.0)-pow((p.x-0.29)*13.0,2.0));
  col=mix(col,vec3(0.56,0.19,0.075),storm*0.62*(body_kind==3?1.0:0.0));
  col*=vec3(0.015,0.022,0.03)+vec3(1.22,1.19,1.1)*diffuse;
  col+=vec3(0.07,0.19,0.26)*rim*day*0.23;
 } else if(body_kind==6) {
  float granules=detail_level>0?noise(q*63.0):n;
  col=mix(vec3(1.0,0.15,0.025),vec3(1.0,0.84,0.41),n*0.78+granules*0.22);
  col*=2.8-pow(1.0-facing,0.65)*0.9;
 } else {
  vec3 base=body_kind==2?vec3(0.51,0.26,0.12):(body_kind==5?vec3(0.46,0.62,0.68):vec3(0.29,0.28,0.27));
  float detail=detail_level>0?noise(q*93.0):0.5;
  float fractures=pow(abs(noise(q*18.0)*2.0-1.0),0.5);
  col=base*(0.50+n*0.72)*(0.79+detail*0.31)*(0.84+fractures*0.19);
  col*=vec3(0.014,0.02,0.027)+vec3(1.27,1.21,1.10)*diffuse;
 }
 ALBEDO=max(col,vec3(0.0));
}
