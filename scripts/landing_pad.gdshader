shader_type spatial;
render_mode diffuse_burley;
uniform int detail_level = 2;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.25;
uniform float material_gain = 1.6;
varying vec3 local_position;
varying float top;
float line(float distance_to_line, float half_width) {
 float aa=max(fwidth(distance_to_line),0.08);
 return 1.0-smoothstep(half_width-aa,half_width+aa,abs(distance_to_line));
}
void vertex() {local_position=VERTEX;top=max(NORMAL.y,0.0);}
mat3 texture_frame(vec3 normal,vec3 position,vec2 tex_uv) {
 vec3 dx=dFdx(position),dy=dFdy(position);
 vec2 ux=dFdx(tex_uv),uy=dFdy(tex_uv);
 vec3 py=cross(dy,normal),px=cross(normal,dx);
 vec3 tangent=py*ux.x+px*uy.x,bitangent=py*ux.y+px*uy.y;
 float gain=inversesqrt(max(max(dot(tangent,tangent),dot(bitangent,bitangent)),0.0000000001));
 return mat3(tangent*gain,bitangent*gain,normal);
}
void fragment() {
 vec2 p=local_position.xz;
 float edge=line(max(abs(p.x),abs(p.y))-43.0,0.7);
 float ring=line(length(p)-27.0,0.65);
 float h=max(line(abs(p.x)-10.0,1.5)*step(abs(p.y),17.0),line(p.y,1.5)*step(abs(p.x),10.0));
 float lane=line(p.x,0.45)*step(30.0,abs(p.y))*step(0.45,fract(abs(p.y)/7.0));
 float grid=max(line(mod(p.x+5.0,10.0)-5.0,0.04),line(mod(p.y+5.0,10.0)-5.0,0.04));
 float paint=max(max(edge,ring),max(h,lane))*top;
 vec3 finish=vec3(1.0),orm=vec3(1.0,0.88,0.0);
 if(detail_level>0) {
  vec2 tex_uv=p*material_scale;
  finish=clamp(texture(material_albedo,tex_uv).rgb*material_gain,vec3(0.55),vec3(1.35));
  orm=texture(material_orm,tex_uv).rgb;
  if(detail_level>1 && top>0.5) {
   vec3 bump=texture(material_normal,tex_uv).rgb*2.0-1.0;bump.xy*=0.4;
   NORMAL=normalize(texture_frame(normalize(NORMAL),VERTEX,tex_uv)*normalize(bump));
  }
 }
 ALBEDO=mix(vec3(0.07,0.105,0.13)*(1.0-grid*0.2)*finish,vec3(0.86,0.73,0.38)*mix(finish,vec3(1.0),0.6),paint);
 AO=orm.r;
 METALLIC=orm.b;
 EMISSION=vec3(0.1,0.29,0.28)*edge*top*0.35;
 ROUGHNESS=mix(orm.g,0.65,paint);
}
