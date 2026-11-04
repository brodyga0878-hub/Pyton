shader_type spatial;
render_mode diffuse_burley;
uniform int detail_level = 2;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.25;
uniform float material_gain = 1.6;

uniform float building_seed = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7))+building_seed)*43758.5453);}
void vertex() { local_position=VERTEX;local_normal=NORMAL; }
mat3 texture_frame(vec3 normal,vec3 position,vec2 tex_uv) {
 vec3 dx=dFdx(position),dy=dFdy(position);
 vec2 ux=dFdx(tex_uv),uy=dFdy(tex_uv);
 vec3 py=cross(dy,normal),px=cross(normal,dx);
 vec3 tangent=py*ux.x+px*uy.x,bitangent=py*ux.y+px*uy.y;
 float gain=inversesqrt(max(max(dot(tangent,tangent),dot(bitangent,bitangent)),0.0000000001));
 return mat3(tangent*gain,bitangent*gain,normal);
}
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
 vec3 orm=vec3(1.0,0.83,0.12);
 if(detail_level>0) {
  vec2 tex_uv=(abs(local_normal.y)>0.5?local_position.xz:p)*material_scale;
  wall*=clamp(texture(material_albedo,tex_uv).rgb*material_gain,vec3(0.55),vec3(1.35));
  orm=texture(material_orm,tex_uv).rgb;
  if(detail_level>1) {
   vec3 bump=texture(material_normal,tex_uv).rgb*2.0-1.0;bump.xy*=0.45*(1.0-windows);
   NORMAL=normalize(texture_frame(normalize(NORMAL),VERTEX,tex_uv)*normalize(bump));
  }
 }
 ALBEDO=mix(wall*(1.0-panel*0.22),vec3(0.025,0.07,0.10),windows);
 AO=orm.r;
 EMISSION=mix(vec3(0.24,0.65,0.78),vec3(0.96,0.66,0.3),step(0.6,hash(cell+31.0)))*windows*lit*0.65;
 ROUGHNESS=mix(orm.g,0.3,windows);
 METALLIC=mix(orm.b,0.12,windows);
}
