shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
varying float top;
float line(float distance_to_line, float half_width) {
 float aa=max(fwidth(distance_to_line),0.08);
 return 1.0-smoothstep(half_width-aa,half_width+aa,abs(distance_to_line));
}
void vertex() {local_position=VERTEX;top=max(NORMAL.y,0.0);}
void fragment() {
 vec2 p=local_position.xz;
 float edge=line(max(abs(p.x),abs(p.y))-43.0,0.7);
 float ring=line(length(p)-27.0,0.65);
 float h=max(line(abs(p.x)-10.0,1.5)*step(abs(p.y),17.0),line(p.y,1.5)*step(abs(p.x),10.0));
 float lane=line(p.x,0.45)*step(30.0,abs(p.y))*step(0.45,fract(abs(p.y)/7.0));
 float grid=max(line(mod(p.x+5.0,10.0)-5.0,0.04),line(mod(p.y+5.0,10.0)-5.0,0.04));
 float paint=max(max(edge,ring),max(h,lane))*top;
 ALBEDO=mix(vec3(0.07,0.105,0.13)*(1.0-grid*0.2),vec3(0.86,0.73,0.38),paint);
 EMISSION=vec3(0.1,0.29,0.28)*edge*top*0.35;
 ROUGHNESS=mix(0.88,0.65,paint);
}
