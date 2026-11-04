shader_type spatial;
render_mode diffuse_burley, blend_mix, depth_draw_never;
// A complementary screen-space mask avoids transparent-surface sorting.
// Pair normal coverage=t with inverted coverage=1-t on the near terrain.
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
  vec3 finish=(texture(material_albedo,tp.zy).rgb*weights.x+texture(material_albedo,tp.xz).rgb*weights.y+texture(material_albedo,tp.xy).rgb*weights.z)*material_gain;
  orm=texture(material_orm,tp.zy).rgb*weights.x+texture(material_orm,tp.xz).rgb*weights.y+texture(material_orm,tp.xy).rgb*weights.z;
  ground*=clamp(finish,vec3(0.55),vec3(1.35));
  if(detail_level>1) {
   // Dominant projection normal uses the geometric derivatives, so a rebased
   // tangent frame and body-fixed texture coordinates need no axis assumption.
   vec2 tex_uv=weights.y>=max(weights.x,weights.z)?tp.xz:(weights.x>=weights.z?tp.zy:tp.xy);
   vec3 bump=texture(material_normal,tex_uv).rgb*2.0-1.0;
   bump.xy*=0.48;
   NORMAL=normalize(texture_frame(normalize(NORMAL),VERTEX,tex_uv)*normalize(bump));
  }
 }
 // No vertex displacement: the visible triangles stay identical to collision terrain.
 ALBEDO=ground;
 ALPHA=clamp(view_coverage,0.0,1.0);
 AO=orm.r;
 ROUGHNESS=clamp(orm.g,0.28,1.0);
 METALLIC=orm.b;
 SPECULAR=surface_kind==3?0.35:0.12;
}
