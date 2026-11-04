shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.6;
uniform float material_gain = 1.0;
uniform int detail_level = 2;
varying vec3 object_point;
varying vec3 object_normal;
varying mat3 normal_to_view;
void vertex(){object_point=VERTEX;object_normal=NORMAL;normal_to_view=MODELVIEW_NORMAL_MATRIX;}
void fragment(){
 vec2 grid=UV*vec2(16.0,10.0);
 vec2 cell=fract(grid);
 vec2 pixel=max(fwidth(grid),vec2(0.0001));
 vec2 inside=smoothstep(vec2(0.045)-pixel,vec2(0.045)+pixel,cell)
            *(vec2(1.0)-smoothstep(vec2(0.955)-pixel,vec2(0.955)+pixel,cell));
 float edge=inside.x*inside.y;
 edge=mix(edge,0.8281,smoothstep(0.15,0.65,max(pixel.x,pixel.y)));
 // Filter the cell variation and busbars before they become subpixel.
 float shimmer_phase=UV.x*185.0+UV.y*47.0;
 float shimmer=0.5+0.5*sin(shimmer_phase)*(1.0-smoothstep(0.5,2.0,fwidth(shimmer_phase)));
 vec3 n=normalize(object_normal);
 vec3 weight=pow(abs(n),vec3(4.0));weight/=max(dot(weight,vec3(1.0)),0.0001);
 vec3 p=object_point*material_scale;
 vec3 base=texture(material_albedo,p.zy).rgb*weight.x+texture(material_albedo,p.xz).rgb*weight.y+texture(material_albedo,p.xy).rgb*weight.z;
 vec3 orm=texture(material_orm,p.zy).rgb*weight.x+texture(material_orm,p.xz).rgb*weight.y+texture(material_orm,p.xy).rgb*weight.z;
 vec3 blue=mix(vec3(0.012,0.04,0.11),vec3(0.045,0.17,0.27),shimmer*0.5);
 ALBEDO=mix(vec3(0.16,0.22,0.28),blue,edge)*clamp(base*material_gain,vec3(0.65),vec3(1.2));
 METALLIC=mix(0.7,0.18,edge)*orm.b;
 ROUGHNESS=clamp(mix(0.35,0.22,edge)+(orm.g-0.5)*0.14,0.15,0.55);
 AO=orm.r;SPECULAR=0.65;CLEARCOAT=edge*0.45;CLEARCOAT_ROUGHNESS=0.2;
 if(detail_level>0){
  vec2 bx=texture(material_normal,p.zy).rg*2.0-1.0;
  vec2 by=texture(material_normal,p.xz).rg*2.0-1.0;
  vec2 bz=texture(material_normal,p.xy).rg*2.0-1.0;
  vec3 bump=vec3(0.0,bx.y,bx.x)*weight.x+vec3(by.x,0.0,by.y)*weight.y+vec3(bz.x,bz.y,0.0)*weight.z;
  bump-=n*dot(n,bump);
  float visibility=1.0-smoothstep(0.03,0.3,max(length(dFdx(p)),length(dFdy(p))));
  NORMAL=normalize(normal_to_view*normalize(n+bump*0.12*visibility));
 }
}
