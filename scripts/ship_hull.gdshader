shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.28,0.37,0.43,1.0);
uniform float metalness : hint_range(0.0,1.0) = 0.7;
uniform float finish : hint_range(0.0,1.0) = 0.32;
varying vec3 object_point;
void vertex() { object_point = VERTEX; }
float grain(vec3 p) { return fract(sin(dot(floor(p),vec3(127.1,311.7,74.7)))*43758.5453); }
void fragment() {
 float brushed = sin(object_point.x*410.0 + sin(object_point.z*17.0)*2.0)*0.5+0.5;
 float footprint = max(length(dFdx(object_point)),length(dFdy(object_point)));
 float micro_visibility = 1.0-smoothstep(0.0015,0.012,footprint);
 float fleck = mix(0.5,grain(object_point*180.0),micro_visibility);
 brushed = mix(0.5,brushed,micro_visibility);
 ALBEDO = paint.rgb * (0.955 + fleck*0.055 + brushed*0.018);
 METALLIC = metalness;
 ROUGHNESS = clamp(finish + (fleck-0.5)*0.055 + brushed*0.035,0.12,0.95);
 SPECULAR = 0.62;
}
