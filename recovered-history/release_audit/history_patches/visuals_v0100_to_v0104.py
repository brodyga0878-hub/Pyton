from pathlib import Path
root=Path('/workspace/recovery/from-agent-history/release_audit')
p=root/'scripts/celestial_renderer.gd';s=(root/'versions/v0.10.0-read/scripts/celestial_renderer.gd').read_text()
s=s.replace('const PlanetShader', '''var quality:=2
const AtmosphereShader=preload("res://scripts/atmosphere.gdshader")
func set_quality(value:int)->void:
\tquality=clampi(value,0,2)
\tfor entry in visuals.values():
\t\tentry.mesh.material_override.set_shader_parameter("detail_level",quality)
\t\tif entry.has("air"):entry.air.visible=quality>0

const PlanetShader''',1).replace('mat.shader = PlanetShader','mat.shader = PlanetShader\n\t\tmat.set_shader_parameter("detail_level",quality)',1)
s=s.replace('if kind in ["earth","desert","gas","ice_gas"]:', 'var atmosphere:MeshInstance3D\n\t\tif kind in ["earth","gas","ice_gas"]:')
s=s.replace('am.shader = Shader.new()\n\t\t\tam.shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_back, depth_draw_never; void fragment(){ float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0); ALBEDO=vec3(0.1,0.4,0.8); ALPHA=rim*0.22; }"','''am.shader = AtmosphereShader
\t\t\tam.set_shader_parameter("atmosphere_color",Color("72b6e5") if kind=="earth" else (Color("cfad7c") if kind=="gas" else Color("63c0d4")))
\t\t\tair.visible=quality>0;atmosphere=air''')
s=s.replace('visuals[str(body.id)] = {"anchor":anchor,"mesh":mesh}', 'visuals[str(body.id)] = {"anchor":anchor,"mesh":mesh}\n\t\tif atmosphere:visuals[str(body.id)].air=atmosphere')
s=s.replace('entry.mesh.rotation.y =', '''if entry.has("air"):
\t\t\tvar to_sun:Vector3=context.local_meters("star",days)-center
\t\t\tentry.air.material_override.set_shader_parameter("sun_direction_world",to_sun.normalized())
\t\tentry.mesh.rotation.y =''')
p.write_text(s)
p=root/'scripts/planet.gdshader';s=(root/'versions/v0.10.0-read/scripts/planet.gdshader').read_text().replace('uniform int body_kind = 0;','uniform int body_kind = 0;\nuniform int detail_level = 2;')
s=s.replace('col=mix(ocean,land,smoothstep(0.48,0.53,n));','''float continents=smoothstep(0.48,0.535,n);
  vec3 shallows=mix(ocean,vec3(0.05,0.31,0.34),smoothstep(0.38,0.50,n)*0.6);
  vec3 ground=mix(land*0.72,land*1.35,smoothstep(0.52,0.72,n));
  col=mix(shallows,ground,continents);
  ROUGHNESS=mix(0.28,0.91,continents);
  SPECULAR=mix(0.6,0.18,continents);''')
s=s.replace('float clouds=smoothstep(0.56,0.72,fbm(q*11.0+vec3(1.0,0.0,0.0)));','''float clouds=0.0;
  if(detail_level>0) clouds=smoothstep(0.56,0.72,fbm(q*11.0+vec3(1.0,0.0,0.0)));''')
s=s.replace('float detail=noise(q*90.0);','float detail=0.5;\n  if(detail_level>0) detail=noise(q*90.0);')
s=s.replace('ALBEDO=col;ROUGHNESS=body_kind==0?0.65:0.95;','ALBEDO=col;\n if(body_kind!=0) {ROUGHNESS=0.95;SPECULAR=0.18;}')
p.write_text(s)
p=root/'scripts/surface_visual.gd';s=p.read_text().replace('\tvar heights:=PackedFloat64Array()','\tvar heights:=PackedFloat64Array()\n\tvar samples:Array[PackedFloat64Array]=[]',1).replace('\t\theights.resize((count+3)*(count+3))','\t\theights.resize((count+3)*(count+3));samples.resize(heights.size())',1)
s=s.replace('heights[z*(count+3)+x]=surface.raw_height_at(-width/2+(x-1)*cell,-width/2+(z-1)*cell)', '''var sampled:PackedFloat64Array=surface.globe.sample(-width/2+(x-1)*cell,-width/2+(z-1)*cell)
\t\t\t\tsamples[z*(count+3)+x]=sampled;heights[z*(count+3)+x]=sampled[0]''',1)
a=s.index('\t\t\t\tvar ll:Array=surface.globe.coordinates(point.x,point.z)');b=s.index('\n\t\t\tvertices.append',a)
s=s[:a]+'''\t\t\t\tvar sampled:PackedFloat64Array=samples[(z+1)*(count+3)+x+1]
\t\t\t\tuvs.append(Vector2(sampled[2],sampled[3]));uv2s.append(Vector2(sampled[4],0))'''+s[b:]
a=s.index('\t\t\t\tvar height:float=surface.raw_height_at(p.x,p.y)');b=s.index('\n\t\tfor row in range(RADIAL):',a)
s=s[:a]+'''\t\t\t\tvar sampled:PackedFloat64Array=surface.globe.sample(p.x,p.y)
\t\t\t\tvar angle:=p.length()/float(surface.globe.radius)
\t\t\t\tvar direction:=p.normalized()*sin(angle)
\t\t\t\tvertices.append(Vector3(p.x,sampled[0],p.y));normals.append(Vector3(direction.x,cos(angle),direction.y).normalized())
\t\t\t\tcolors.append(base.lightened(clampf(sampled[1]/400.0,-0.2,0.3)))
\t\t\t\tuv.append(Vector2(sampled[2],sampled[3]));uv2.append(Vector2(sampled[4],0))'''+s[b:]
v=root/'versions/v0.10.3-history-patches/scripts';v.mkdir(parents=True,exist_ok=True);(v/p.name).write_text(s)
s=s.replace('add_child(_far_ring(surface,inner,outer,mat,base));inner=outer','''add_child(_far_ring(surface,inner,outer,mat,base));inner=outer
\t\tif surface.get("extended_flight")==true:
\t\t\tvar outer:float=minf(512000.0,float(surface.globe.radius)*0.7)
\t\t\tif outer>inner:add_child(_far_ring(surface,inner,outer,mat,base))''',1)
s=s.replace('colors.append(base.lightened(clampf(sampled[1]/400.0,-0.2,0.3)))','''var shade:float=clampf(sampled[1]/400.0,-0.2,0.3)
\t\t\t\tif surface.get("extended_flight")==true:shade*=1.0-smoothstep(4000.0,24000.0,p.length())
\t\t\t\tcolors.append(base.lightened(shade))''',1)
p.write_text(s)
