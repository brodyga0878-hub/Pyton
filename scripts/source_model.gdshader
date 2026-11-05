shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform int detail_level = 2;
// A single padded atlas carries four surfaces: facade, road, pad and roof.
// Explicit bounded LOD avoids sampling another material at distant mip levels.
uniform sampler2D city_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D city_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D city_orm : filter_linear_mipmap, repeat_disable;
uniform vec4 city_gains = vec4(1.6);
uniform vec4 city_scales = vec4(0.125,0.0625,0.0625,0.125);
uniform vec4 city_roughness = vec4(0.7,0.9,0.8,0.5);
uniform vec4 city_metallic = vec4(0.0,0.0,0.0,0.25);
uniform float city_atlas_size = 2048.0;
uniform float city_tile_size = 1024.0;
uniform float city_gutter = 16.0;
uniform float city_max_lod = 3.0;
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
vec3 city_decode_srgb(vec3 colour) {
 return mix(colour/12.92,pow((colour+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),colour));
}
vec3 city_encode_srgb(vec3 colour) {
 colour=max(colour,vec3(0.0));
 return mix(colour*12.92,1.055*pow(colour,vec3(1.0/2.4))-vec3(0.055),step(vec3(0.0031308),colour));
}
void fragment() {
 float unlit = clamp(COLOR.a, 0.0, 1.0);
 vec3 finish=vec3(1.0),orm=vec3(1.0,0.66,0.14);
 if(detail_level>0) {
  // Face-local planar projection needs no original UV reconstruction. The same
  // source-root metre coordinate on adjacent faces keeps tiles stable on rebase.
  vec3 axis=abs(material_face_normal);
  vec2 projection=axis.y>=max(axis.x,axis.z)?material_position.xz:(axis.x>=axis.z?material_position.zy:material_position.xy);
  float code=floor(material_slot+0.5);
  bool preserve_emission=code>=8.0;
  int role=int(clamp(mod(code,8.0),0.0,3.0));
  vec2 local_uv=projection*city_scales[role];
  float atlas_size=max(city_atlas_size,2.0);
  float tile_size=max(city_tile_size,1.0);
  float gutter=clamp(city_gutter,0.0,(tile_size-1.0)*0.5);
  float content_size=max(1.0,tile_size-2.0*gutter);
  // Derive the footprint BEFORE wrapping or the protected-face branch. fract()
  // discontinuities must not force a coarse mip at every material tile edge.
  float footprint=max(length(dFdx(local_uv)),length(dFdy(local_uv)))*content_size;
  float detail_visibility=1.0-smoothstep(8.0,16.0,footprint);
  float safe_lod=min(max(city_max_lod,0.0),log2(max(gutter,1.0)));
  float lod=clamp(log2(max(footprint,1.0)),0.0,safe_lod);
  vec2 tile_origin=vec2(float(role%2),floor(float(role)*0.5))*tile_size;
  vec2 atlas_uv=(tile_origin+vec2(gutter)+fract(local_uv)*content_size)/atlas_size;
  mat3 projected_frame=mat3(1.0);
  if(detail_level>1) projected_frame=texture_frame(normalize(NORMAL),VERTEX,local_uv);
  if(!preserve_emission) {
   orm=vec3(1.0,city_roughness[role],city_metallic[role]);
   if(detail_visibility>0.0) {
    vec3 sampled_colour=textureLod(city_albedo,atlas_uv,lod).rgb;
    // Compatibility's custom fragment contract is sRGB. Forward/Mobile use
    // linear source_color samples. Normalize every atlas in its measured linear
    // domain, otherwise road gain clips almost the entire texture to one value.
    if(OUTPUT_IS_SRGB) sampled_colour=city_decode_srgb(sampled_colour);
    finish=mix(vec3(1.0),sampled_colour*city_gains[role],detail_visibility);
    // Unlit source surfaces keep their original illumination mode. They need
    // colour texture only; physical normal/roughness maps affect lit faces.
    if(unlit<0.5) {
     orm=mix(orm,textureLod(city_orm,atlas_uv,lod).rgb,detail_visibility);
     if(detail_level>1) {
      vec3 bump=textureLod(city_normal,atlas_uv,lod).rgb*2.0-1.0;
      // The cotangent frame follows increasing image V; OpenGL +Y points up
      // the image, hence its green component is reversed in this custom frame.
      bump.y=-bump.y;
      bump.xy*=0.55*detail_visibility;
      NORMAL=normalize(projected_frame*normalize(bump));
     }
    }
   }
  }
 }
 vec3 source_colour=COLOR.rgb*clamp(finish,vec3(0.35),vec3(1.6));
 // Keep the existing neutral source tint, economy mode and clean lamps. Apply
 // texture contrast in linear light before returning Compatibility's sRGB value.
 if(OUTPUT_IS_SRGB && detail_level>0 && material_slot<7.5) {
  source_colour=city_encode_srgb(city_decode_srgb(COLOR.rgb)*clamp(finish,vec3(0.35),vec3(1.6)));
 }
 ALBEDO = source_colour * (1.0 - unlit);
 EMISSION = source_colour * unlit;
 AO=orm.r;
 METALLIC = orm.b * (1.0 - unlit);
 ROUGHNESS = clamp(orm.g,0.12,1.0);
}
