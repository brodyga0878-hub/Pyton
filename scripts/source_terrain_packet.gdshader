shader_type spatial;
render_mode diffuse_burley;
// A complementary screen-space mask avoids transparent-surface sorting.
// Pair normal coverage=t with inverted coverage=1-t on the near terrain.
// v4 only: old body-fixed far geometry must not cover the published fine core.
uniform bool source_clip_core = false;
uniform mat3 source_core_from_packet_basis = mat3(1.0);
uniform vec3 source_core_from_packet_origin = vec3(0.0);
uniform vec2 source_core_center = vec2(0.0);
uniform float source_core_half_width = 2000.0;
varying vec2 source_core_position;
uniform float view_coverage : hint_range(0.0, 1.0) = 1.0;
uniform bool coverage_invert = false;
uniform int detail_level = 2;
uniform int surface_kind = 0;
uniform bool spherical_coordinates = false;
uniform sampler2D material_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_scale = 0.0625;
uniform float material_gain = 1.6;
// Integer tile-sized body-fixed origin reduces varying precision loss near the
// 6,000-km radius; subtraction does not touch the rendered/physical vertices.
uniform vec3 material_origin = vec3(0.0);
varying vec3 material_position;
varying vec3 material_axis;
varying vec3 local_position;
varying float slope;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float hash3(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p) {
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
 source_core_position=(source_core_from_packet_basis*VERTEX+source_core_from_packet_origin).xz;
 local_position=spherical_coordinates?vec3(UV.x,UV.y,UV2.x):VERTEX;
 material_position=local_position-material_origin;
 material_axis=spherical_coordinates?normalize(local_position):NORMAL;
 slope=1.0-clamp(NORMAL.y,0.0,1.0);
}
mat3 texture_frame(vec3 normal,vec3 position,vec2 tex_uv) {
 vec3 dx=dFdx(position),dy=dFdy(position);
 vec2 ux=dFdx(tex_uv),uy=dFdy(tex_uv);
 vec3 py=cross(dy,normal),px=cross(normal,dx);
 vec3 tangent=py*ux.x+px*uy.x,bitangent=py*ux.y+px*uy.y;
 float gain=inversesqrt(max(max(dot(tangent,tangent),dot(bitangent,bitangent)),0.0000000001));
 return mat3(tangent*gain,bitangent*gain,normal);
}
vec3 world_decode_srgb(vec3 colour) {
 return mix(colour/12.92,pow((colour+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),colour));
}
vec3 world_encode_srgb(vec3 colour) {
 colour=max(colour,vec3(0.0));
 return mix(colour*12.92,1.055*pow(colour,vec3(1.0/2.4))-vec3(0.055),step(vec3(0.0031308),colour));
}
vec3 world_colour_sample(vec2 uv,vec2 grad_x,vec2 grad_y) {
 vec3 colour=textureGrad(material_albedo,uv,grad_x,grad_y).rgb;
 // Compatibility's custom fragment uses sRGB; the manifest's mean is linear.
 // Forward/Mobile already decode source_color samples and must not decode twice.
 return OUTPUT_IS_SRGB?world_decode_srgb(colour):colour;
}
// Stable Bayer 4x4 thresholds (pixel centres); no time-dependent noise.
float view_dither_threshold(vec2 screen_pixel) {
 ivec2 pixel=ivec2(floor(screen_pixel)) & ivec2(3);
 int low=((pixel.x & 1) ^ (pixel.y & 1))*2+(pixel.y & 1);
 int high=((pixel.x >> 1) ^ (pixel.y >> 1))*2+(pixel.y >> 1);
 return (float(low*4+high)+0.5)/16.0;
}
void fragment() {
 // Derivatives must be evaluated before per-pixel coverage discard.
 float footprint=max(length(dFdx(local_position)),length(dFdy(local_position)));
 vec2 p=local_position.xz;
 // Fade frequencies above the pixel footprint, including the broad pattern on the horizon.
 float broad_weight=1.0-smoothstep(0.05,0.25,footprint*0.012);
 float broad=0.5;
 if(broad_weight>0.01) broad=mix(0.5,spherical_coordinates?noise3(local_position*0.012):noise(p*0.012),broad_weight);
 float grain=0.5;
 if(detail_level>0) {
  float medium_weight=1.0-smoothstep(0.35,0.9,footprint*0.24);
  float fine_weight=1.0-smoothstep(0.35,0.9,footprint*0.73);
  float medium=0.5;float fine=0.5;
  if(medium_weight>0.01) medium=mix(0.5,spherical_coordinates?noise3(local_position*0.24):noise(p*0.24),medium_weight);
  if(fine_weight>0.01) fine=mix(0.5,spherical_coordinates?noise3(local_position*0.73):noise(p*0.73),fine_weight);
  grain=medium*0.65+fine*0.35;
 }
 vec3 base=COLOR.rgb;
 vec3 stone=vec3(0.22,0.25,0.27);
 if(surface_kind==2) stone=vec3(0.35,0.24,0.18);
 if(surface_kind==3) stone=vec3(0.56,0.67,0.72);
 vec3 ground=base*(0.73+broad*0.42+grain*0.19);
 ground=mix(ground,stone,smoothstep(0.015,0.16,slope)*0.65);
 vec3 orm=vec3(1.0,surface_kind==3?0.63:0.96,0.0);
 if(detail_level>0) {
  vec3 weights=pow(abs(normalize(material_axis)),vec3(4.0));
  weights/=max(weights.x+weights.y+weights.z,0.00001);
  vec3 tp=material_position*material_scale;
  // Continuous body-fixed coordinates are differentiated before any coverage
  // discard. A conservative footprint fades detail that no longer fits a pixel.
  vec2 map_size=vec2(textureSize(material_albedo,0));
  vec3 texture_dx=dFdx(tp),texture_dy=dFdy(tp);
  float texel_footprint=max(length(texture_dx),length(texture_dy))*max(map_size.x,map_size.y);
  float detail_visibility=1.0-smoothstep(4.0,16.0,texel_footprint);
  vec2 tex_uv=weights.y>=max(weights.x,weights.z)?tp.xz:(weights.x>=weights.z?tp.zy:tp.xy);
  vec2 normal_dx=weights.y>=max(weights.x,weights.z)?texture_dx.xz:(weights.x>=weights.z?texture_dx.zy:texture_dx.xy);
  vec2 normal_dy=weights.y>=max(weights.x,weights.z)?texture_dy.xz:(weights.x>=weights.z?texture_dy.zy:texture_dy.xy);
  mat3 projected_frame=mat3(1.0);
  if(detail_level>1) projected_frame=texture_frame(normalize(NORMAL),VERTEX,tex_uv);
  if(detail_visibility>0.0) {
   // Decode each triplanar albedo sample before blending and linear gain.
   vec3 finish=(world_colour_sample(tp.zy,texture_dx.zy,texture_dy.zy)*weights.x+world_colour_sample(tp.xz,texture_dx.xz,texture_dy.xz)*weights.y+world_colour_sample(tp.xy,texture_dx.xy,texture_dy.xy)*weights.z)*material_gain;
   finish=mix(vec3(1.0),clamp(finish,vec3(0.50),vec3(1.50)),detail_visibility);
   vec3 sampled_orm=textureGrad(material_orm,tp.zy,texture_dx.zy,texture_dy.zy).rgb*weights.x+textureGrad(material_orm,tp.xz,texture_dx.xz,texture_dy.xz).rgb*weights.y+textureGrad(material_orm,tp.xy,texture_dx.xy,texture_dy.xy).rgb*weights.z;
   orm=mix(orm,sampled_orm,detail_visibility);
   // Keep the existing neutral procedural tint; modulate it in linear light.
   ground=OUTPUT_IS_SRGB?world_encode_srgb(world_decode_srgb(ground)*finish):ground*finish;
   if(detail_level>1) {
    vec3 bump=textureGrad(material_normal,tex_uv,normal_dx,normal_dy).rgb*2.0-1.0;
    // This cotangent frame follows increasing image V, while OpenGL +Y points up.
    bump.y=-bump.y;
    bump.xy*=0.48*detail_visibility;
    NORMAL=normalize(projected_frame*normalize(bump));
   }
  }
 }
 // Defaults preserve full opaque coverage; endpoints do not leave stray pixels.
 if(view_coverage<1.0) {
  float coverage=clamp(view_coverage,0.0,1.0);
  float threshold=view_dither_threshold(FRAGCOORD.xy);
  if(coverage<=0.0 || (coverage_invert ? threshold<1.0-coverage : threshold>=coverage)) discard;
 }
 // No vertex displacement: the visible triangles stay identical to collision terrain.
 if(source_clip_core && max(abs(source_core_position.x-source_core_center.x),abs(source_core_position.y-source_core_center.y))<source_core_half_width-0.001) discard;
 ALBEDO=ground;
 AO=orm.r;
 ROUGHNESS=clamp(orm.g,0.28,1.0);
 METALLIC=orm.b;
 SPECULAR=surface_kind==3?0.35:0.12;
}
