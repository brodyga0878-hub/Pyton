shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.2;
uniform float material_gain = 1.0;
uniform int detail_level = 2;
varying vec3 local_position;
varying vec3 object_normal;
varying mat3 normal_to_view;
void vertex(){
 // Instances use a unit source mesh. Restore physical metres without sampling
 // world translation, so floating-origin shifts cannot move the rock texture.
 vec3 metres=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 local_position=VERTEX*metres;
 object_normal=NORMAL;
 normal_to_view=MODELVIEW_NORMAL_MATRIX;
}
void fragment(){
 vec3 n=normalize(object_normal);
 vec3 weight=pow(abs(n),vec3(4.0));weight/=max(dot(weight,vec3(1.0)),0.0001);
 vec3 p=local_position*material_scale;
 vec3 stone=texture(material_albedo,p.zy).rgb*weight.x+texture(material_albedo,p.xz).rgb*weight.y+texture(material_albedo,p.xy).rgb*weight.z;
 vec3 orm=texture(material_orm,p.zy).rgb*weight.x+texture(material_orm,p.xz).rgb*weight.y+texture(material_orm,p.xy).rgb*weight.z;
 ALBEDO=vec3(0.37,0.385,0.395)*clamp(stone*material_gain,vec3(0.35),vec3(1.6))*COLOR.rgb;
 AO=orm.r;ROUGHNESS=clamp(orm.g,0.65,1.0);METALLIC=orm.b*0.025;SPECULAR=0.24;
 if(detail_level>0){
  vec2 bx=texture(material_normal,p.zy).rg*2.0-1.0;
  vec2 by=texture(material_normal,p.xz).rg*2.0-1.0;
  vec2 bz=texture(material_normal,p.xy).rg*2.0-1.0;
  vec3 bump=vec3(0.0,bx.y,bx.x)*weight.x+vec3(by.x,0.0,by.y)*weight.y+vec3(bz.x,bz.y,0.0)*weight.z;
  bump-=n*dot(n,bump);
  float visibility=1.0-smoothstep(0.035,0.32,max(length(dFdx(p)),length(dFdy(p))));
  NORMAL=normalize(normal_to_view*normalize(n+bump*0.42*visibility*(detail_level==1 ? 0.65 : 1.0)));
 }
}
