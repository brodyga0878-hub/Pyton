shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform int detail_level = 2;
uniform sampler2D concrete_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_alloy_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_alloy_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_alloy_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brushed_metal_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brushed_metal_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brushed_metal_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float concrete_gain = 1.6;
uniform float asphalt_gain = 1.6;
uniform float painted_alloy_gain = 1.6;
uniform float brushed_metal_gain = 1.6;
varying vec3 material_position;
varying vec3 material_face_normal;
varying float material_slot;
// Original painter primitives may be coplanar. UV2.x is a render-only layer;
// the source vertices and the physical triangle soup stay unchanged.
void vertex() {
 material_position=VERTEX;
 material_face_normal=NORMAL;
 material_slot=UV2.y;
 vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 vec4 close_clip = PROJECTION_MATRIX * vec4(0.0, 0.0, -1.0, 1.0);
 vec4 distant_clip = PROJECTION_MATRIX * vec4(0.0, 0.0, -2.0, 1.0);
 float nearer_direction = sign(close_clip.z / close_clip.w - distant_clip.z / distant_clip.w);
 clip.z += nearer_direction * UV2.x * 0.00000014 * clip.w;
 POSITION = clip;
}
mat3 texture_frame(vec3 normal,vec3 position,vec2 tex_uv) {
 vec3 dx=dFdx(position),dy=dFdy(position);
 vec2 ux=dFdx(tex_uv),uy=dFdy(tex_uv);
 vec3 perpendicular_y=cross(dy,normal),perpendicular_x=cross(normal,dx);
 vec3 tangent=perpendicular_y*ux.x+perpendicular_x*uy.x;
 vec3 bitangent=perpendicular_y*ux.y+perpendicular_x*uy.y;
 float gain=inversesqrt(max(max(dot(tangent,tangent),dot(bitangent,bitangent)),0.0000000001));
 return mat3(tangent*gain,bitangent*gain,normal);
}
void fragment() {
 float unlit = clamp(COLOR.a, 0.0, 1.0);
 vec3 finish=vec3(1.0),orm=vec3(1.0,0.66,0.14);
 if(detail_level>0 && unlit<0.5) {
  // Face-local planar projection needs no original UV reconstruction. The same
  // source-root metre coordinate on adjacent faces keeps tiles stable on rebase.
  vec3 axis=abs(material_face_normal);
  vec2 tex_uv=axis.y>=max(axis.x,axis.z)?material_position.xz:(axis.x>=axis.z?material_position.zy:material_position.xy);
  vec3 tex_normal=vec3(0.5,0.5,1.0);
  if(material_slot<0.5) {
   tex_uv*=0.16;
   finish=texture(concrete_albedo,tex_uv).rgb*concrete_gain;
   orm=texture(concrete_orm,tex_uv).rgb;
   tex_normal=texture(concrete_normal,tex_uv).rgb;
  } else if(material_slot<1.5) {
   tex_uv*=0.40;
   finish=texture(asphalt_albedo,tex_uv).rgb*asphalt_gain;
   orm=texture(asphalt_orm,tex_uv).rgb;
   tex_normal=texture(asphalt_normal,tex_uv).rgb;
  } else if(material_slot<2.5) {
   tex_uv*=0.25;
   finish=texture(painted_alloy_albedo,tex_uv).rgb*painted_alloy_gain;
   orm=texture(painted_alloy_orm,tex_uv).rgb;
   tex_normal=texture(painted_alloy_normal,tex_uv).rgb;
  } else {
   tex_uv*=0.35;
   finish=texture(brushed_metal_albedo,tex_uv).rgb*brushed_metal_gain;
   orm=texture(brushed_metal_orm,tex_uv).rgb;
   tex_normal=texture(brushed_metal_normal,tex_uv).rgb;
  }
  // Medium uses maps for colour/AO/roughness; high adds subpixel-filtered normals.
  if(detail_level>1) {
   vec3 bump=tex_normal*2.0-1.0;
   bump.xy*=0.55;
   NORMAL=normalize(texture_frame(normalize(NORMAL),VERTEX,tex_uv)*normalize(bump));
  }
 }
 ALBEDO = COLOR.rgb * clamp(finish,vec3(0.45),vec3(1.4)) * (1.0 - unlit);
 EMISSION = COLOR.rgb * unlit;
 AO=orm.r;
 METALLIC = orm.b * (1.0 - unlit);
 ROUGHNESS = clamp(orm.g,0.12,1.0);
}
