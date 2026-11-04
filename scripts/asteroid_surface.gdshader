shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
// Polynomial hashing avoids the precision loss of large sine hashes on mobile.
float hash(vec3 p){p=fract(p*vec3(0.1031,0.1030,0.0973));p+=dot(p,p.yxz+33.33);return fract((p.x+p.y)*p.z);}
float noise(vec3 p){
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){local_position=VERTEX;}
void fragment(){
 vec3 p=local_position;
 float pixel_span=max(length(dFdx(p)),length(dFdy(p)));
 float middle_weight=1.0-smoothstep(0.035,0.11,pixel_span);
 float fine_weight=1.0-smoothstep(0.012,0.045,pixel_span);
 float broad=mix(0.5,noise(p*3.7),1.0-smoothstep(0.07,0.25,pixel_span));
 float middle=mix(0.5,noise(p*11.0),middle_weight);
 float fine=mix(0.5,noise(p*27.0),fine_weight);
 vec3 stone=mix(vec3(0.26,0.275,0.285),vec3(0.49,0.5,0.5),broad);
 stone*=mix(0.88,1.08,middle)*mix(0.96,1.04,fine);
 float mineral=smoothstep(0.67,0.87,middle)*smoothstep(0.48,0.74,broad);
 ALBEDO=(stone+vec3(0.075,0.07,0.06)*mineral)*COLOR.rgb;
 ROUGHNESS=0.9;METALLIC=0.025;SPECULAR=0.24;
 // Surface-gradient relief stays coherent across UV seams. Filtering removes
 // detail once it becomes subpixel, instead of producing a shimmering normal.
 float height=middle*0.38+fine*0.035;
 vec3 dx=dFdx(VERTEX);vec3 dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL);vec3 r2=cross(NORMAL,dx);
 float determinant=dot(dx,r1);
 vec3 gradient=(r1*dFdx(height)+r2*dFdy(height))*sign(determinant);
 if(abs(determinant)>0.000001)NORMAL=normalize(abs(determinant)*NORMAL-gradient*0.38);
}
