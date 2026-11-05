shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.28,0.37,0.43,1.0);
uniform float metalness : hint_range(0.0,1.0) = 0.7;
uniform float finish : hint_range(0.0,1.0) = 0.32;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.33;
uniform float material_gain = 1.0;
uniform float normal_strength : hint_range(0.0,1.0) = 0.22;
uniform int detail_level = 2;
uniform bool hull_enabled = false;
uniform sampler2D hull_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D hull_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D hull_orm : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 hull_extent = vec2(42.0);
uniform float hull_gain = 1.0;
varying vec3 object_point;
varying vec3 object_normal;
varying mat3 normal_to_view;
void vertex() {
 object_point = VERTEX;
 object_normal = NORMAL;
 normal_to_view = MODELVIEW_NORMAL_MATRIX;
}
// The authored hull has no tangent stream and its edge UVs can collapse.
// Object-space triplanar sampling gives every existing face the same metre scale.
void fragment() {
 vec3 n = normalize(object_normal);
 vec3 weight = pow(abs(n),vec3(4.0));
 weight /= max(dot(weight,vec3(1.0)),0.0001);
 vec3 p = object_point*material_scale;
 vec3 base = texture(material_albedo,p.zy).rgb*weight.x
           + texture(material_albedo,p.xz).rgb*weight.y
           + texture(material_albedo,p.xy).rgb*weight.z;
 vec3 orm = texture(material_orm,p.zy).rgb*weight.x
          + texture(material_orm,p.xz).rgb*weight.y
          + texture(material_orm,p.xy).rgb*weight.z;
 vec3 finish_colour=base*material_gain;
 float hull_weight=0.0;
 vec2 hull_uv=object_point.xz/hull_extent+vec2(0.5);
 if(hull_enabled && detail_level>0) {
  hull_weight=smoothstep(0.15,0.72,abs(n.y));
  hull_weight*=step(0.0,hull_uv.x)*step(hull_uv.x,1.0)*step(0.0,hull_uv.y)*step(hull_uv.y,1.0);
  finish_colour=mix(finish_colour,texture(hull_albedo,hull_uv).rgb*hull_gain,hull_weight);
  orm=mix(orm,texture(hull_orm,hull_uv).rgb,hull_weight);
 }
 ALBEDO = paint.rgb*clamp(finish_colour,vec3(0.35),vec3(1.6));
 AO = orm.r;
 METALLIC = clamp(metalness*orm.b,0.0,1.0);
 ROUGHNESS = clamp(finish+(orm.g-0.5)*0.32,0.12,0.95);
 SPECULAR = 0.62;
 if(detail_level>0) {
  vec2 x_bump = texture(material_normal,p.zy).rg*2.0-1.0;
  vec2 y_bump = texture(material_normal,p.xz).rg*2.0-1.0;
  vec2 z_bump = texture(material_normal,p.xy).rg*2.0-1.0;
  vec3 bump = vec3(0.0,x_bump.y,x_bump.x)*weight.x
            +vec3(y_bump.x,0.0,y_bump.y)*weight.y
            +vec3(z_bump.x,z_bump.y,0.0)*weight.z;
  if(hull_enabled && detail_level>1) {
   vec2 atlas_bump=texture(hull_normal,hull_uv).rg*2.0-1.0;
   // OpenGL +Y tangent normal: image Y maps to the hull's +Z coordinate.
   // Correct the image-down gradient and reverse relief on the lower skin.
   vec3 object_bump=vec3(atlas_bump.x,0.0,-atlas_bump.y)*sign(n.y);
   bump=mix(bump,object_bump,hull_weight);
  }
  bump -= n*dot(n,bump);
  float footprint = max(length(dFdx(p)),length(dFdy(p)));
  float visibility = 1.0-smoothstep(0.025,0.3,footprint);
  float quality_strength = detail_level==1 ? 0.65 : 1.0;
  NORMAL = normalize(normal_to_view*normalize(n+bump*normal_strength*visibility*quality_strength));
 }
}
