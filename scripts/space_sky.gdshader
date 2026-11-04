shader_type sky;
// New authored backdrop. Static sky also supplies cheap environment reflections.
// The dust band is presentation, not an astronomical map or a gameplay object.
float hash3(vec3 p) {
 p=fract(p*vec3(0.1031,0.1030,0.0973));
 p+=dot(p,p.yxz+33.33);
 return fract((p.x+p.y)*p.z);
}
float noise3(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void sky() {
 vec3 d=normalize(EYEDIR);
 vec3 q=mat3(vec3(0.91,0.25,-0.33),vec3(-0.36,0.84,-0.4),vec3(0.18,0.48,0.86))*d;
 float cloud=noise3(q*5.0)*0.56+noise3(q*12.0)*0.29+noise3(q*27.0)*0.15;
 float band=exp(-abs(q.y+0.04)*9.5);
 float tendrils=smoothstep(0.34,0.8,cloud)*band;
 vec3 blue=vec3(0.09,0.25,0.39)*tendrils;
 vec3 warm=vec3(0.18,0.048,0.07)*pow(max(0.0,q.x+0.1),2.0)*tendrils;
 COLOR=vec3(0.0014,0.003,0.008)+blue+warm;
}
