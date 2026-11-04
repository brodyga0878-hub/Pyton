shader_type spatial;
render_mode diffuse_burley;
uniform int detail_level = 2;
uniform float building_seed = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7))+building_seed)*43758.5453);}
void vertex() { local_position=VERTEX;local_normal=NORMAL; }
void fragment() {
 vec2 p=vec2(abs(local_normal.x)>0.5?local_position.z:local_position.x,local_position.y);
 vec2 cell=floor(p/vec2(7.0,6.0));
 vec2 f=fract(p/vec2(7.0,6.0));
 vec2 aa=max(fwidth(p/vec2(7.0,6.0)),vec2(0.001));
 vec2 mask=smoothstep(vec2(0.19)-aa,vec2(0.19)+aa,f)*(1.0-smoothstep(vec2(0.81)-aa,vec2(0.81)+aa,f));
 float windows=mask.x*mask.y*(1.0-abs(local_normal.y));
 float lit=step(0.47,hash(cell));
 if(detail_level==0) windows=0.0;
 float panel=1.0-smoothstep(0.015,0.035,min(f.x,f.y));
 vec3 wall=mix(vec3(0.19,0.26,0.3),vec3(0.29,0.37,0.4),hash(vec2(building_seed,0.0)));
 ALBEDO=mix(wall*(1.0-panel*0.22),vec3(0.025,0.07,0.10),windows);
 EMISSION=mix(vec3(0.24,0.65,0.78),vec3(0.96,0.66,0.3),step(0.6,hash(cell+31.0)))*windows*lit*0.65;
 ROUGHNESS=mix(0.83,0.3,windows);
 METALLIC=0.12;
}
