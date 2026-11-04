shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Original painter primitives may be coplanar. UV2.x is a render-only layer;
// the source vertices and the physical triangle soup stay unchanged.
void vertex() {
 vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 vec4 close_clip = PROJECTION_MATRIX * vec4(0.0, 0.0, -1.0, 1.0);
 vec4 distant_clip = PROJECTION_MATRIX * vec4(0.0, 0.0, -2.0, 1.0);
 float nearer_direction = sign(close_clip.z / close_clip.w - distant_clip.z / distant_clip.w);
 clip.z += nearer_direction * UV2.x * 0.00000014 * clip.w;
 POSITION = clip;
}
void fragment() {
 float unlit = clamp(COLOR.a, 0.0, 1.0);
 ALBEDO = COLOR.rgb * (1.0 - unlit);
 EMISSION = COLOR.rgb * unlit;
 METALLIC = 0.14 * (1.0 - unlit);
 ROUGHNESS = 0.66;
}
