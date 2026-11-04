shader_type spatial;
render_mode diffuse_burley;
uniform vec3 ocean : source_color = vec3(0.015,0.09,0.23);
uniform vec3 land : source_color = vec3(0.12,0.28,0.19);
uniform int body_kind = 0;
uniform float seed_offset = 0.0;
float hash(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p) {
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) {return noise(p)*0.53+noise(p*2.02)*0.27+noise(p*4.13)*0.13+noise(p*8.21)*0.07;}
void fragment() {
 vec3 p=vec3(sin(UV.x*6.283185)*sin(UV.y*3.14159),cos(UV.y*3.14159),cos(UV.x*6.283185)*sin(UV.y*3.14159));
 vec3 q=p+vec3(seed_offset,0.0,0.0);
 float n=fbm(q*4.0);
 vec3 col;
 if(body_kind==0) {
  col=mix(ocean,land,smoothstep(0.48,0.53,n));
  float clouds=smoothstep(0.56,0.72,fbm(q*11.0+vec3(1.0,0.0,0.0)));
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
  float detail=noise(q*90.0);
  col*=0.85+detail*0.3;
 }
 ALBEDO=col;ROUGHNESS=body_kind==0?0.65:0.95;
}
