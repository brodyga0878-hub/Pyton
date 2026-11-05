extends SceneTree
# Immutable city render/physics baselines captured from git 8ca06bd in Godot 4.6.3.
# Only UV2.y render-role metadata is excluded; source depth layers remain exact.
const Visual=preload("res://scripts/source_model_visual.gd")
const View=preload("res://scripts/source_city_view.gd")
const Runtime=preload("res://scripts/source_city_runtime.gd")
const Profile=preload("res://scripts/source_city_profile.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const CitySurfaces=preload("res://scripts/city_surface_library.gd")
const BASELINE_COMMIT:="8ca06bd26a78e2ed7758417bc099ff241708701c"
const BASELINE_VISUAL_SOURCE_SHA256:="865d5b6b521c0e2328d91d20993fce79f7fbfe07a69430b3c09326a688d35b2c"
const BASELINE_PROJECTION_SHA256:="82cfef9458cf077afd7b63d408368855d5aef5af5898e98b274ac2c719466a99"
const BASELINE:=[
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "495b87478f19fe4a59d6393db3ea2e983318ba5fc662e89dc7840eaf415d4922",
  "collision_sha256": "165f8cc3548cdd38077d0c4c87888599929c40ad9ec598dd1115bf6aafdcf3a6",
  "compiled_sha256": "66e878f85f87c1f476ff3bda64e96ac13d4c52b44b945a57275fdaf2d23935c5",
  "events_sha256": "203ef4840c4422bbeab2f9a49726afe5c9b7df0b610078931ac1f7ed16820f22",
  "geometry": {
   "children": 2,
   "lit_vertices": 11157,
   "sha256": "ba0267dc922f20e11030a2c33bd58a26dd9e9323a786a9194a1370108f67ced5",
   "unlit_vertices": 2637
  },
  "model": 81,
  "pad_count": 4,
  "pad_index": 3,
  "pad_offset_sha256": "e379efb7ee87be4f690443245eb68767251cfbf628f57b8f419c738f6af3f0d0",
  "physical_metadata_sha256": "52b6d4e07a7404da1b9a80a907f7d6d6175218aa550d3874b461e7987b9b50aa",
  "profile_sha256": "a20cb26cb2b4a724caf5ec34a804d062bf072f741df8cf799e2c3b90122c3b41",
  "source": {
   "name_en": "Epping Newtown",
   "site_id": "site11",
   "system_id": 111466264
  },
  "source_events_sha256": "b776c412e00eb140b37cfda57788497bc7c62b7491de1e1c25b8a6ac1f79f932",
  "triangles": 4598,
  "unresolved_texture_indices_sha256": "cb577c4eb7419ed41e4e7a163229e1f570ef93274189aae9e8b9ec4c07c3d628",
  "visual_bounds_sha256": "495b87478f19fe4a59d6393db3ea2e983318ba5fc662e89dc7840eaf415d4922"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "088636b64dd8157e68ef0dd939d74bb9271364565c169743cf45228d159f2b14",
  "collision_sha256": "213a2602023315bf2e54bafab5a302c0cc0225f4b6046648a79cedbf88fecd2e",
  "compiled_sha256": "3cc110733e2a502a461cfebe09b9289669dc2f539aa87a63e9460e1a6072da77",
  "events_sha256": "7e8f4007f25d7484812857ee519d47e8278b89c0da58caa3b91c74f3a37bb40d",
  "geometry": {
   "children": 2,
   "lit_vertices": 18099,
   "sha256": "5aca325801677dfc68d2eb747a0e52677e058e86831fe3a84a1f648f820dbec2",
   "unlit_vertices": 4038
  },
  "model": 82,
  "pad_count": 4,
  "pad_index": 3,
  "pad_offset_sha256": "9f715d75bcd0c7a6a7a54062ba434775472322cbf158fba388256b27f4aaa044",
  "physical_metadata_sha256": "adca700093c430e98fdfaba9ea635fc81c3ed14248d35b52bebd2fcdecf722a2",
  "profile_sha256": "ac552004673cb94735882aea3d681e4c4c22959ff96c59c098e4df34d89ce8b3",
  "source": {
   "name_en": "Manchester",
   "site_id": "site10",
   "system_id": 111466264
  },
  "source_events_sha256": "cabe420458dd86754b8728cfcf970e20f1a66edc2489e7456b61cacf4053673b",
  "triangles": 7379,
  "unresolved_texture_indices_sha256": "879f59d02c83cbc4ce70afe326437b00e020394bde2ce5b28ad242512f25de57",
  "visual_bounds_sha256": "088636b64dd8157e68ef0dd939d74bb9271364565c169743cf45228d159f2b14"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "55e26a50f0b7fff7cf5f009703d4a84a2bad89c04c095f0291d750239230b980",
  "collision_sha256": "2c20336807b27f267fe96d07b57eac7ff8b5f75da090a3fde3d6d04d031bdbcd",
  "compiled_sha256": "cf7a45dabd4cafd5cc550eab1eed196b53d7da77f25b4c9bdce565a54941dc03",
  "events_sha256": "3229c30b8cfb7d99d132b6bf0764cefd073633e3443c58d0aac7fa16818a4078",
  "geometry": {
   "children": 2,
   "lit_vertices": 57078,
   "sha256": "720845602ea615448b1e6c85399e8ce4d75d4abfcbb9f77bddec01845c504775",
   "unlit_vertices": 10569
  },
  "model": 83,
  "pad_count": 6,
  "pad_index": 5,
  "pad_offset_sha256": "aa95cf57bd865ecf0697000b6b0ed571042a68565b55d118634d13d392478acb",
  "physical_metadata_sha256": "7f8220617cded13cd3672d6a74fac8246f63e3f7d35f79d37aff5ebfcd0eb418",
  "profile_sha256": "3e545df7bca507f12887dbcfca974436d7f2970e3f27653f961fe9bf67d3af63",
  "source": {
   "name_en": "Paris",
   "site_id": "site7",
   "system_id": 44341016
  },
  "source_events_sha256": "52dccbaf34a0db283d0feb82774e9b9111fe5605745f4ad0b6abdee6b401a71c",
  "triangles": 22549,
  "unresolved_texture_indices_sha256": "7975b9b17b9f9a52d5fc7fe97b8d2d3128b91ab1576cd7ee793376d0ecb467ad",
  "visual_bounds_sha256": "55e26a50f0b7fff7cf5f009703d4a84a2bad89c04c095f0291d750239230b980"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "6dd6570a48e77971c75ac75754faf99f4ed7910bfd271093242133bbcd006019",
  "collision_sha256": "6d04475524adffd654f7789a46cffb97df96656329243d728dedb5a308a855f7",
  "compiled_sha256": "667ad9becd0b150ee90f561fcac59ec2ea1dc362e955e4cb08a109525313c629",
  "events_sha256": "2460987963f0d46706dbd198d6899324608373215f8480a890f3669569d7da2f",
  "geometry": {
   "children": 2,
   "lit_vertices": 56535,
   "sha256": "982c10837313743802789c439e8cfa486dea2bd51e962a6697603be8545b1d9e",
   "unlit_vertices": 11061
  },
  "model": 84,
  "pad_count": 6,
  "pad_index": 5,
  "pad_offset_sha256": "2809f582e1dd536d4cddc689c75c78b6357108b0ac904eb09136646cd583f04e",
  "physical_metadata_sha256": "c747f3e5c6646c629246244cbd40c11e0a2f92b8c596ffe80867748e7e9af688",
  "profile_sha256": "0cd4af963ee04cf2818f3ed73d9a297ba6fa4d362ac1af09641844039c6283bf",
  "source": {
   "name_en": "London",
   "site_id": "site6",
   "system_id": 44341016
  },
  "source_events_sha256": "10fc78a3774546e47d370788229764bf54cae4dff34f1b33a53db8ee634c7cb2",
  "triangles": 22532,
  "unresolved_texture_indices_sha256": "24b1f667ed6a6add3836dc55863315c94abdcbf87d5378a6f0759dd54a38142a",
  "visual_bounds_sha256": "6dd6570a48e77971c75ac75754faf99f4ed7910bfd271093242133bbcd006019"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "6ac31e6c2deb2a301df3ad56d0dbc71620bbfbfa1250f3bde8f780752b3bcc02",
  "collision_sha256": "d77069fb8e99b855f1569ae28a05e4355339013429116f94872f917863703eb6",
  "compiled_sha256": "95b03fbf54646d40a84a3072e5a46bbfebda69f620bd2c7f110008431012869b",
  "events_sha256": "22eea137abfea2b049e76d61a5091d1cf4e6720e85089346da716baf7c5c56bf",
  "geometry": {
   "children": 2,
   "lit_vertices": 6000,
   "sha256": "8b8e648383177cca94965b712e8077fc1bc43cbad0e706fa86e301140d6dd41c",
   "unlit_vertices": 1095
  },
  "model": 85,
  "pad_count": 2,
  "pad_index": 1,
  "pad_offset_sha256": "677201b608c2524f04bf64105ea28b1ee2cf3ee0a43cf554f2d17401b3b7380d",
  "physical_metadata_sha256": "d58add95f9970475f6d23f7de96fad3a2fa23a22df27f00732beced156267b65",
  "profile_sha256": "dda9962be82f3d44f0fcd1d4f87b663d1b57483c34a6b2c921a8a52be4c03105",
  "source": {
   "name_en": "Amundsen",
   "site_id": "site5",
   "system_id": 44349207
  },
  "source_events_sha256": "b020155b98a80af5ab97dba342ecef4f25fc79776afc900610de1a4b4df87b11",
  "triangles": 2365,
  "unresolved_texture_indices_sha256": "22c0d7ce75c080bbad7804f5c3969d91260056f7c150038856a432ab333b806d",
  "visual_bounds_sha256": "bc62641a410f5a1c9c55357e2b8af0b98183eea7cd101983fa2dee0de2c929f2"
 },
 {
  "ball_shading_sha256": "031fdadb6f0a9db60709c60bc3d75c08ef1deafab3b5a593d36a44bad85a4eee",
  "bounds_sha256": "cb8a5b18174df022f0a29c24d9bb46b5ce7d3b94fcc344ad4bddd572972e7873",
  "collision_sha256": "dc488e5c552d8d58a1d185b3a6fca297182a32ff75741168237843f3690ea3f6",
  "compiled_sha256": "308153bf840fc7829d7e8e51b8377e9b027b7cd414edc94fca0faed0572c2ffa",
  "events_sha256": "84f6bc4c8cc98df9741346def01307d0da6c187785c4e76d8e41e526d025d85a",
  "geometry": {
   "children": 3,
   "lit_vertices": 7098,
   "sha256": "4134c3daf8059bef358ee200138425819851aabfa6b8dd11da51d90bd9ac9cb3",
   "unlit_vertices": 210
  },
  "model": 86,
  "pad_count": 2,
  "pad_index": 1,
  "pad_offset_sha256": "fa9c21c50d34c4e14faa29af25b8988f7424be8deb14b90273463d40e60f0d71",
  "physical_metadata_sha256": "94f5a8df93a75021f00bb1fe87f616ac43b7667ad73696732c206c8736c228f9",
  "profile_sha256": "f955dff932db5bf9b34a8944ac693356b5e7cc33e573d48f1ea71a6750c1f427",
  "source": {
   "controlled_model": 86,
   "ground_inclination_u16": 0,
   "ground_phase_u16": 0
  },
  "source_events_sha256": "59926aa14cdc0a3580b00b02257c7852f5f13572ac4f0b39c2ce22ebf9c16c4a",
  "triangles": 2436,
  "unresolved_texture_indices_sha256": "39fcc83e4c984c3d6c73cf66a1978367c72c4005b3454bf13cde836c9c0dd9ed",
  "visual_bounds_sha256": "cb8a5b18174df022f0a29c24d9bb46b5ce7d3b94fcc344ad4bddd572972e7873"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "8c41a6a087e165e757e9b19b1049e83baedd2c41d928855424dc27f2d76825cf",
  "collision_sha256": "d70df92642dc8df7cd15f016495a133907deec9bc5a775c15972f17f06a98223",
  "compiled_sha256": "8f0fde7b5454ad4f3548da86cf4fddc2bf5d03df840d1754fc558adc0a4e6b44",
  "events_sha256": "5c53561e69a4b98185dd53050d53453c8114deff55065441005bc9ecc5be4333",
  "geometry": {
   "children": 2,
   "lit_vertices": 7554,
   "sha256": "38eef216c85121f468ea850e56c1f08e44e205ff59aeab2cbf8a33f94078f9d8",
   "unlit_vertices": 3378
  },
  "model": 87,
  "pad_count": 6,
  "pad_index": 5,
  "pad_offset_sha256": "f0fa44151eac7ca523ea34ee206e4bbbaa408119c537f351affa8851d76eb9df",
  "physical_metadata_sha256": "c3801acd86a3d5b01a8df80b84fc59769c5ba5f54248dc4371912e9b00e700f9",
  "profile_sha256": "0059795198842fd3732592309c05489df9c901fed0a0c79e635db29ab61bb6f3",
  "source": {
   "controlled_model": 87,
   "ground_inclination_u16": 0,
   "ground_phase_u16": 0
  },
  "source_events_sha256": "706a47b6f888c0ff01d86a134d7875e2a0ad342bb1a5685c49338e26a37913a6",
  "triangles": 3644,
  "unresolved_texture_indices_sha256": "f43a73bf05723e7aa591bd4e8ea37a4e2a29bcf2474afb4b099604e697f536af",
  "visual_bounds_sha256": "8c41a6a087e165e757e9b19b1049e83baedd2c41d928855424dc27f2d76825cf"
 },
 {
  "ball_shading_sha256": "59646b6404afa0c78e1d62bd1aff0e090ab94b3d18e189c54fcb3f6832e9cd1c",
  "bounds_sha256": "2dd8be755ba826d88035e3594203e89a4d41bbcc79d7bd114f5e7f47ed49828b",
  "collision_sha256": "44309410ae43ba9f4e05e1aca235e9f0b5ee1264726533aa6c1734ac758ecb11",
  "compiled_sha256": "81995a97039fddbe36c184b88c4a88a57e096d5564ba2e67e71d1224e1dc6c4c",
  "events_sha256": "69355b281d0d3c43d105911595f3d2a6b5f8fe4e3b91261d869986dde4467a9c",
  "geometry": {
   "children": 3,
   "lit_vertices": 9966,
   "sha256": "e0fe11db165aad8d530a24c707e4e60dd91f40f2c3c0c6dfdb6d8a4ed0637524",
   "unlit_vertices": 3678
  },
  "model": 88,
  "pad_count": 6,
  "pad_index": 5,
  "pad_offset_sha256": "f0fa44151eac7ca523ea34ee206e4bbbaa408119c537f351affa8851d76eb9df",
  "physical_metadata_sha256": "ef6a388ba3c8eefbd21f0c14fae42047b910accf486fe6ae800f3a3a438a1ff1",
  "profile_sha256": "fad04bdfd5e5ccc67399c3cb1e33dd5175e7e0742f2aeb735cbdb736e3aaf40f",
  "source": {
   "controlled_model": 88,
   "ground_inclination_u16": 0,
   "ground_phase_u16": 0
  },
  "source_events_sha256": "523c653d485335d145e5112a0234710f8cb81af94f992661b373de710671b601",
  "triangles": 4548,
  "unresolved_texture_indices_sha256": "c5a80977d11426a3e71cfe7f1427aaa28e6851fde0558c90dfd27e7394047995",
  "visual_bounds_sha256": "2dd8be755ba826d88035e3594203e89a4d41bbcc79d7bd114f5e7f47ed49828b"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "083662ccb649f625402a060f0566cdc9e116388f3a6f65b2a285d201157f4085",
  "collision_sha256": "c3254927dfeaf80926605082d1d13ee4adeb2b739c8391224eb196e1a9e08ca0",
  "compiled_sha256": "83dcda806bbeac5400e990221793385fb6781480edb8b751b2ded0b57180b09b",
  "events_sha256": "bd532a9be1bc9e13aa8c4fbc7deac1880c96bf5dd768bdc291e88ed15b802769",
  "geometry": {
   "children": 2,
   "lit_vertices": 8538,
   "sha256": "23075fa6a424c8617364908425933544ee279720e96eabde74b2d80d0be420bb",
   "unlit_vertices": 294
  },
  "model": 89,
  "pad_count": 2,
  "pad_index": 1,
  "pad_offset_sha256": "fa9c21c50d34c4e14faa29af25b8988f7424be8deb14b90273463d40e60f0d71",
  "physical_metadata_sha256": "998a4304c65cbe16063860c23b32c959158d2b30f033efe4d1fa7548f2f4fa2c",
  "profile_sha256": "5c0fba72b634f2856e00bfe88604a8628ec0b36ed415cf99b453080bf10ff348",
  "source": {
   "controlled_model": 89,
   "ground_inclination_u16": 0,
   "ground_phase_u16": 0
  },
  "source_events_sha256": "06ab51f0701d42e1e32c65e58ab5bc8932307b3ae320cb846c6f412da8833106",
  "triangles": 2944,
  "unresolved_texture_indices_sha256": "0bf17e943e930e3b2a5216272dbfdeab257ed0a234b5c1e75a62a2cb50d66384",
  "visual_bounds_sha256": "083662ccb649f625402a060f0566cdc9e116388f3a6f65b2a285d201157f4085"
 },
 {
  "ball_shading_sha256": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
  "bounds_sha256": "738f514fc197a29e62fd689759cd8e38e5ce46cfcd8d9aa25ca497b4ae57fc60",
  "collision_sha256": "2695f95bce232a3e009d17fab344808cc8098d94312dacc992ef1ce23a8eaabd",
  "compiled_sha256": "02ddcd8bc9cf806e394dc1565343ce308fce361d6771fdc57d8f61b2ccc9d7c4",
  "events_sha256": "ff6ea39831bc32f35ee5b880f3fbf75f1a7804b53e05ed7ad2b0b70878abb153",
  "geometry": {
   "children": 2,
   "lit_vertices": 58059,
   "sha256": "07889c6c36a685d48880ca27355f3ce13a9ce01e8bd561e9ff477274c256c9d0",
   "unlit_vertices": 10281
  },
  "model": 90,
  "pad_count": 6,
  "pad_index": 5,
  "pad_offset_sha256": "f92d442aeaecac482090f3bcccdede97ceda168392c93994f4d43f5775a6f8ea",
  "physical_metadata_sha256": "414a61143314e5986bc06451ad790d257d8d56ff629ae3c56f1c021113d13042",
  "profile_sha256": "d804c9f4bc3f74a5fc1cbd8a8f33406df23b99597859786dd852420eec9f1280",
  "source": {
   "name_en": "Tokyo",
   "site_id": "site8",
   "system_id": 44341016
  },
  "source_events_sha256": "335aa832b234ad6417f762c098141243f334a408f2249c7836ecf7b9d91fbd47",
  "triangles": 22780,
  "unresolved_texture_indices_sha256": "3cba2d09a99a53b081c7bc7c70ebb35b5f3e225e4ed740c3cbdcb834a46b074a",
  "visual_bounds_sha256": "738f514fc197a29e62fd689759cd8e38e5ce46cfcd8d9aa25ca497b4ae57fc60"
 }
]

class FrameGlobe extends RefCounted:
 var revision:="sphere-source-city-v3"
 var radius:=6371000.0
 var latitude:=0.0
 var longitude:=0.0
class FrameDraw extends RefCounted:
 var active:=true
 var globe:RefCounted
 var city_data:Dictionary={}
var checks:=0
var failures:=0
var game:Node3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<=20:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func geometry(visual:Node3D)->Dictionary:
 var packed:Array=[];var lit:=0;var unlit:=0
 for child in visual.get_children():
  if not child is MeshInstance3D:continue
  var surfaces:Array=[]
  for surface in range(child.mesh.get_surface_count()):
   var arrays:Array=child.mesh.surface_get_arrays(surface)
   var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
   for color in colors:
    if color.a>.5:unlit+=1
    else:lit+=1
   if arrays[Mesh.ARRAY_TEX_UV2]!=null:
    var old:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2];var layers:=PackedFloat32Array()
    for uv in old:layers.append(uv.x)
    arrays[Mesh.ARRAY_TEX_UV2]=layers
   surfaces.append(arrays)
  packed.append([child.mesh.get_class(),child.transform,surfaces])
 return {"sha256":digest(packed),"children":packed.size(),"lit_vertices":lit,"unlit_vertices":unlit}
func ball_shading(visual:Node3D)->String:
 var values:Array=[]
 for child in visual.get_children():
  if child is MeshInstance3D and child.material_override is StandardMaterial3D:
   var material:StandardMaterial3D=child.material_override
   values.append([material.shading_mode,material.albedo_color,material.emission_enabled,material.emission])
 return digest(values)
func mesh_refs(visual:Node3D)->Array:
 var refs:Array=[]
 for child in visual.get_children():
  if child is MeshInstance3D:refs.append(child.mesh)
 return refs
func cached_atlases()->int:
 var count:=0
 for channel in ["albedo","normal","orm"]:
  if ResourceLoader.has_cached("res://assets/city_surfaces/"+channel+".png"):count+=1
 return count
func cold_bindings(visual:Node3D,enabled:bool)->bool:
 var materials:=0
 for child in visual.get_children():
  if not child is MeshInstance3D or not child.material_override is ShaderMaterial:continue
  materials+=1
  for channel in ["albedo","normal","orm"]:
   var map:Variant=child.material_override.get_shader_parameter("city_"+channel)
   if enabled:
    if not map is Texture2D or map.resource_path!="res://assets/city_surfaces/"+channel+".png":return false
   elif map!=null:return false
 return materials==2
func cold_quality()->void:
 # Metadata and imported files on disk must not force 2048-pixel maps into RAM.
 check(cached_atlases()==0 and CitySurfaces._textures.is_empty(),"Fresh process starts without city atlases in the resource cache")
 var metadata:=CitySurfaces.metadata()
 check(int(metadata.get("resolution",0))==2048 and cached_atlases()==0 and CitySurfaces._textures.is_empty(),"Reading city atlas metadata alone does not load image resources")
 var compiled:={"ok":true,"model_index":84,"source_events":[],"triangles_raw":[
  {"vertices":[[0,0,0],[1000000,0,0],[0,0,1000000]],"material_code":0x0444},
  {"vertices":[[0,1000000,0],[1000000,1000000,0],[0,1000000,1000000]],"material_code":0x2444}
 ]}
 var visual:=Visual.new();visual.set_quality(0);root.add_child(visual)
 var configured:=visual.configure(compiled)
 check(configured,"Cold minimum-quality source visual builds real lit and unlit batches")
 if not configured:visual.queue_free();await process_frame;return
 check(cached_atlases()==0 and CitySurfaces._textures.is_empty() and cold_bindings(visual,false),"Cold quality0 creates geometry with no loaded or bound city atlases")
 var refs:=mesh_refs(visual);var original:=geometry(visual)
 visual.set_quality(2)
 check(cached_atlases()==3 and CitySurfaces._textures.size()==3 and cold_bindings(visual,true),"First higher-quality selection lazily binds exactly three city image resources")
 check(mesh_refs(visual)==refs and geometry(visual)==original,"Lazy atlas binding preserves the original mesh resources and arrays")
 visual.set_quality(0)
 check(cold_bindings(visual,false),"Returning to minimum quality clears every city atlas material reference")
 check(mesh_refs(visual)==refs and geometry(visual)==original,"Returning to minimum quality retains geometry after lazy atlas use")
 visual.queue_free();await process_frame
func resolve(row:Dictionary)->Dictionary:
 var source:Dictionary=row.source
 if source.has("system_id"):
  var galaxy:=Galaxy.new();var world:=World.new();world.configure(galaxy.get_system(int(source.system_id)))
  var site:Dictionary=world.get_site(str(source.site_id))
  var radius:=float(world.by_id[str(site.parent)].radius_km)*1000.0
  return {"profile":Profile.describe(site,radius),"radius":radius}
 var model:=int(source.controlled_model)
 var site:=Ground.from_record(int(source.ground_phase_u16),int(source.ground_inclination_u16))
 site.merge({"id":"controlled-root%d"%model,"name_en":"controlled root%d"%model,"type_code":35,"model_index":model,"source_seed":0xbdd3aa2e})
 return {"profile":Profile.describe(site,6371000.0),"radius":6371000.0}
func physical_metadata(data:Dictionary)->String:return digest([data.footprint_m,data.cruise_height_m,data.collision_profile,data.decorative_collision])
func assert_maps(visual:Node3D)->void:
 var materials:=0;var roles:Array=[0,0,0,0]
 for child in visual.get_children():
  if not child is MeshInstance3D or not child.material_override is ShaderMaterial:continue
  materials+=1
  for channel in ["albedo","normal","orm"]:
   check(child.material_override.get_shader_parameter("city_"+channel)==CitySurfaces.texture(channel),"Existing city batch uses the shared authored atlas "+channel)
  var arrays:Array=child.mesh.surface_get_arrays(0)
  var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  var colours:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  var roles_valid:=uv2.size()%3==0;var clean_valid:=true
  for index in range(0,uv2.size(),3):
   var value:float=uv2[index].y
   roles_valid=roles_valid and is_finite(value) and value==floorf(value) and int(value) in [0,1,2,3,8,9,10,11]
   roles_valid=roles_valid and uv2[index+1].y==value and uv2[index+2].y==value
   if is_finite(value) and int(value) in [0,1,2,3,8,9,10,11]:roles[int(value)%8]+=1
   if value>=8:clean_valid=clean_valid and colours[index].a==1.0 and colours[index+1].a==1.0 and colours[index+2].a==1.0
  check(roles_valid,"Render roles are finite and flat per original triangle, including clean-light flags")
  check(clean_valid,"Clean emission metadata only decorates original unlit source faces")
 check(materials==2,"Existing lit/unlit batches remain separate without extra city draw batches")
 check(roles[0]>0 and roles[1]>0 and roles[2]>0 and roles[3]>0,"Actual persistent city renders facade, road, pad and roof roles: model%d %s"%[visual.source_model_index,str(roles)])
 print("CITY_SURFACE roles model%d %s"%[visual.source_model_index,str(roles)])
func actual_city(row:Dictionary)->void:
 var model:=int(row.model);var context:=resolve(row);var profile:Dictionary=context.profile
 check(not profile.is_empty() and int(profile.model_index)==model,"Original city profile resolves for model%d"%model)
 if profile.is_empty():return
 check(digest(profile)==str(row.profile_sha256),"Original F650 placement/profile stays byte-identical for model%d"%model)
 check(int(profile.pad_index)==int(row.pad_index) and int(profile.pad_count)==int(row.pad_count) and digest(profile.pad_offset_local_m)==str(row.pad_offset_sha256),"Selected native pad is unchanged for model%d"%model)
 var data:=Runtime.prepare(profile)
 check(data.get("ok",false),"Actual source city compiles for model%d"%model)
 if not data.get("ok",false):return
 check(digest(data.compiled)==str(row.compiled_sha256),"Full original compiled packet matches independent0.11.6 baseline for model%d"%model)
 check(digest(data.triangles)==str(row.collision_sha256) and digest(data.bounds)==str(row.bounds_sha256) and physical_metadata(data)==str(row.physical_metadata_sha256),"Physical triangles/bounds/cruise policy remain byte-identical for model%d"%model)
 var draw:=FrameDraw.new();draw.globe=FrameGlobe.new();draw.globe.radius=context.radius;draw.globe.latitude=profile.root_latitude;draw.globe.longitude=profile.root_longitude;draw.city_data=data
 var view:=View.new();root.add_child(view)
 check(view.configure(draw,Transform3D.IDENTITY),"Actual compiled geometry enters the persistent city view")
 var visual:Node3D=view.current_visual()
 check(visual!=null,"Current actual city visual is available")
 if visual==null:view.queue_free();await process_frame;return
 check(geometry(visual)==row.geometry,"All original mesh arrays/ball placements/palette/depth layers match frozen baseline for model%d"%model)
 check(visual.triangle_count==int(row.triangles) and digest(visual.local_bounds)==str(row.visual_bounds_sha256),"Original triangle count and complete visual bounds are unchanged")
 check(digest(visual.retained_event_kinds)==str(row.events_sha256) and digest(visual.unresolved_texture_indices)==str(row.unresolved_texture_indices_sha256) and ball_shading(visual)==str(row.ball_shading_sha256),"Events, unresolved source texture IDs and ball illumination/palette remain intact")
 assert_maps(visual)
 var refs:=mesh_refs(visual);var build_count:int=view.build_count
 for quality in [0,1,2]:
  view.set_quality(quality);check(view.configure(draw,Transform3D.IDENTITY),"Quality selection keeps actual source city valid")
  check(view.current_visual()==visual and mesh_refs(visual)==refs and view.build_count==build_count,"Quality changes never allocate new city geometry")
  check(geometry(visual)==row.geometry,"Quality change preserves all geometry arrays and source appearance")
  var detail_valid:=true;var bindings_valid:=true
  for child in visual.get_children():
   if child is MeshInstance3D and child.material_override is ShaderMaterial:
    detail_valid=detail_valid and int(child.material_override.get_shader_parameter("detail_level"))==quality
    for channel in ["albedo","normal","orm"]:
     var expected:Texture2D=CitySurfaces.texture(channel) if quality>0 else null
     bindings_valid=bindings_valid and child.material_override.get_shader_parameter("city_"+channel)==expected
  check(detail_valid,"Current quality reaches each original city batch")
  check(bindings_valid,"Minimum quality releases atlas bindings and higher qualities restore shared maps")
 draw.globe.latitude+=0.00001;draw.globe.longitude+=0.00002
 var outer:=Transform3D(Basis.from_euler(Vector3(.1,.2,-.15)),Vector3(173,49,-82))
 check(view.configure(draw,outer) and view.transform==outer,"Rebased body-frame view accepts a finite scene transform")
 check(view.current_visual()==visual and mesh_refs(visual)==refs and geometry(visual)==row.geometry and view.build_count==build_count,"Body rebasing changes placement only, preserving actual mesh identity")
 check(view.configure(draw,outer,0.49) and not view.visible and view.build_count==build_count,"Distant terrain preview hides the existing city without new geometry")
 check(view.configure(draw,outer,0.51) and view.visible and view.current_visual()==visual and mesh_refs(visual)==refs,"Preview to descent reuses the same actual city and mesh resources")
 draw.active=false;check(view.configure(draw,outer) and not view.visible,"Inactive surface releases visible city presentation")
 draw.active=true;check(view.configure(draw,outer) and view.current_visual()==visual and view.build_count==build_count,"Surface return reuses the same cached source visual")
 check(digest(data.compiled)==str(row.compiled_sha256) and digest(data.compiled.source_events)==str(row.source_events_sha256) and digest(data.triangles)==str(row.collision_sha256) and physical_metadata(data)==str(row.physical_metadata_sha256),"Rendering/quality/rebase never mutate native packets or collision data")
 view.queue_free();await process_frame
func shader_contract()->void:
 var source:=FileAccess.get_file_as_string("res://scripts/source_model.gdshader")
 var projection:=RegEx.new();projection.compile("(?s)vec4\\s+clip\\b.*?POSITION\\s*=\\s*clip\\s*;")
 var match_projection:=projection.search(source)
 check(match_projection!=null,"Painter-depth vertex projection remains explicit in the city shader")
 if match_projection!=null:
  var whitespace:=RegEx.new();whitespace.compile("\\s+")
  check(whitespace.sub(match_projection.get_string(),"",true).sha256_text()==BASELINE_PROJECTION_SHA256,"Original painter-depth projection and UV2.x bias are unchanged")
 var displacement:=RegEx.new();displacement.compile("\\bVERTEX\\s*(?:[.+*/-]?=|\\+\\+|--)")
 check(displacement.search(source)==null,"City texture shader cannot displace physical vertices")
func live_main()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 await process_frame
 game.active=true;game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
 await game._enter_surface()
 check(game.surface.active and int(game.surface.city_data.profile.model_index)==84,"Actual Main enters original New Moscow84 with the new city material")
 if not game.surface.active:game.queue_free();await process_frame;return
 game._sync_scene();var visual:Node3D=game.city_view.current_visual()
 check(visual!=null,"Real Main owns the persistent native city visual")
 if visual==null:game.queue_free();await process_frame;return
 var before:=digest(game._payload());var geometry_before:=geometry(visual);var physical_before:=digest(game.surface.city_data.triangles);var refs:=mesh_refs(visual);var original_builds:int=game.city_view.build_count
 for quality in [0,1,2]:
  game.settings.quality=quality;game._apply_settings();game._sync_scene()
  check(digest(game._payload())==before and digest(game.surface.city_data.triangles)==physical_before,"Actual Main material quality leaves flight, navigation, surface and collision payload unchanged")
  check(game.city_view.current_visual()==visual and mesh_refs(visual)==refs and geometry(visual)==geometry_before and game.city_view.build_count==original_builds,"Actual Main quality does not rebuild or alter the city")
 assert_maps(visual)
 check(not game.saving_enabled and game.automated,"Live city checks leave user progress persistence disabled")
 game.queue_free();await process_frame
func run()->void:
 if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs --rebuild-capture");quit(1);return
 await cold_quality()
 shader_contract()
 for row in BASELINE:await actual_city(row)
 await live_main()
 print("CITY SURFACE INVARIANT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
