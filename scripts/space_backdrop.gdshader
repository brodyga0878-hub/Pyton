shader_type sky;
uniform float nebula_intensity:hint_range(0.0,2.0)=0.65;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 vec3 d=normalize(EYEDIR);
 vec2 uv=vec2(atan(d.z,d.x)/6.2831853+0.5,asin(clamp(d.y,-1.0,1.0))/3.14159265+0.5);
 float lane=d.y*0.77+d.x*0.49+d.z*0.35;
 float cloud=noise(uv*vec2(25.0,15.0))+noise(uv*vec2(62.0,35.0))*0.4;
 float band=exp(-abs(lane+0.07*sin(d.z*4.0))*7.0);
 float dust=exp(-abs(lane+0.035)*28.0)*smoothstep(0.3,0.85,cloud);
 vec3 colour=vec3(0.0015,0.003,0.008)+nebula_intensity*band*(vec3(0.025,0.061,0.098)*cloud+vec3(0.016,0.008,0.025));
 colour*=1.0-dust*0.72;
 vec2 grid=uv*vec2(1700.0,850.0);vec2 cell=floor(grid);vec2 point=fract(grid)-0.5;
 float key=hash(cell);
 float star=smoothstep(0.19,0.015,length(point))*step(0.9982,key);
 float halo=smoothstep(0.46,0.0,length(point))*step(0.99983,key)*0.27;
 vec3 tint=mix(vec3(0.58,0.76,1.0),vec3(1.0,0.83,0.58),hash(cell+12.0));
 COLOR=colour+tint*(star*1.8+halo);
}
