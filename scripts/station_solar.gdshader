shader_type spatial;
render_mode diffuse_burley;
void fragment(){
 vec2 cell=fract(UV*vec2(16.0,10.0));
 float edge=step(0.045,cell.x)*step(0.045,cell.y)*step(cell.x,0.955)*step(cell.y,0.955);
 float shimmer=0.5+0.5*sin(UV.x*185.0+UV.y*47.0);
 ALBEDO=mix(vec3(0.16,0.22,0.28),mix(vec3(0.012,0.04,0.11),vec3(0.045,0.17,0.27),shimmer*0.5),edge);
 METALLIC=0.7;ROUGHNESS=0.3;SPECULAR=0.65;
}
