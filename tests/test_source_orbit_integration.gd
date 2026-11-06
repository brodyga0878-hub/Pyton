extends SceneTree
# Frozen 0.11.9 legacy data and separately executed native source controls.
# Requires automated Main mode; no installed player save/settings are opened.
const Galaxy=preload("res://scripts/galaxy.gd")
const World=preload("res://scripts/planetary_system.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Nav=preload("res://scripts/navigation.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
class MemorySettings extends Settings:
	func load_file()->bool:return false
const BASELINE_COMMIT:="c0d6f0153994ce1bd94eae441a4007ab0c6ac33d"
const OLD_WORLD_SHA256:="6c4b6f4fc8018261740c586762a21c38f5275185a532a3677da1a51cfcddc1ca"
const BASELINE_JSON:="""[
	{
		"bodies": "c897acc1b7f27fd721ce19daae8cbb47c897742f6ff4002b56028160bf36fa1a",
		"dates": [
			"50c47f4e9fd11de2272b0121735fc4653058451bfffc20412cf09cafcaed7ccb",
			"8e12881e3447c00d19495bfab660f1dd538454dcb1e0f14675cc5b149a0577e8",
			"85230090e3957f83d9822bb7733bb890cea03e397516b5476390e7a67d85d7a8",
			"d9f50cace53fcc4fc1e54af3e57f1b2429f993382ed436627c4605e504b0ec55"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "322863a52895dc334daf289d64e05200d57b92a033193f31f5988a523cb72061",
		"snapshot": "4fe5dea91a40bcdd0de17c38a7972449d0a2619b5a6b23086aa0f7cd5a5bd1db",
		"snapshot_json": {
			"focus_id": "earth",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "earth",
			"site_id": "",
			"source_digest": "7e9565c29346efe1e9071cbb2b233fe4b88441638a059431bf1313cea741cddd",
			"system_id": 44341016,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "7e9565c29346efe1e9071cbb2b233fe4b88441638a059431bf1313cea741cddd",
		"system_id": 44341016
	},
	{
		"bodies": "98133847b4e43c7718ae46329034124ab6f8a3a32c8d325761d708e4ba326a76",
		"dates": [
			"ef5e1893a51e19d4b103be4ec40df411b15212d7d335b15ebea5245b509c3492",
			"1aebde9932aa456d1f6f0123c86066348af4c7d1bdb09c1c1adc1788a0e4bd94",
			"fd2f7cd532be1485f9bd3abac5e067966f3e701b5830310a23410ba7a9838fd3",
			"39a648f8482c8748e54622431876b4e5a479198db5c89949c175c5748ba25969"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "81c460d20e045ee289b728cb392a59ee0678069d650a5957f19bea41bd2403f7",
		"snapshot": "091d3af6728dc527a9508750a8ceca4acbc0c3548cfae2ae87c5d3e349a5ed6b",
		"snapshot_json": {
			"focus_id": "hc5",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc5",
			"site_id": "",
			"source_digest": "8aa6eb76120f1b3b9bc511e6f68af97e29ca090982c47d83f2bcd4cbf87a2a3a",
			"system_id": 111449880,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "8aa6eb76120f1b3b9bc511e6f68af97e29ca090982c47d83f2bcd4cbf87a2a3a",
		"system_id": 111449880
	},
	{
		"bodies": "b448a025e92a7be876e7979472c57d1d522dcd3334576642b0f7491334020714",
		"dates": [
			"9f24a1d1125ad56eabdf43464f0f0c6ddec6afba8ccfa12231a08cc4067f0d4e",
			"a5e823e9711dbc265a3670e453feaecdc392135d6c0b787cb37265a918f51984",
			"bf44ffb14c3ef9a92dcd457f8b622d6c5a1e80aba179d4b30b1150dc0acf1580",
			"0b30fb0d0d398de3c101b8d4ff61b3a4ef5e11545f6a1927ab852b2559d7c974"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "0b12aa93082c365b68099a8c614b93ad95e13734a5decda2d8db7a638e480e99",
		"snapshot": "265fd79cee87cb8d45088922c4992bf9784d7c5d4edbf8bc3148f59e01188bfb",
		"snapshot_json": {
			"focus_id": "hc6",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc6",
			"site_id": "",
			"source_digest": "af4d558786986145b7638f9a1e5a7fe8389f7fc2d0b88b4764df75cd48e07f0e",
			"system_id": 245659414,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "af4d558786986145b7638f9a1e5a7fe8389f7fc2d0b88b4764df75cd48e07f0e",
		"system_id": 245659414
	},
	{
		"bodies": "300ef281603844ad401fc5e78d86b7069f6ee32dbf3fa86761e81a9de0541e1e",
		"dates": [
			"1203d4a190f7eb3c13af52d158e0e92fcb129bb8ac023df50c78acc3375601af",
			"359f42bdaa1f980bdc528f3ae79c3651400cc956a90b511beb2c04a8c902f903",
			"1b28396fb798a8cfca6ba1cb2ed5e113f336c101e9f24f5535db51935b32a302",
			"acf9457776d680b48d8639704fb91bc2542993ffe25a1c95b341cc18fe829863"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "b5efbed0ee3dec8d00faec83ce558674f21e1b0e594ca1082b2f3f5e77c7c6f9",
		"snapshot": "4cf6e3753f9b598935aa37902938bad4066d6f5a4f088e87d6e150917fc9722e",
		"snapshot_json": {
			"focus_id": "hc4",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc4",
			"site_id": "",
			"source_digest": "ebde0a6eaa550732022585a3850fbe5b59cf935d7430b261e5c0a09ab86b3504",
			"system_id": 44349207,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "ebde0a6eaa550732022585a3850fbe5b59cf935d7430b261e5c0a09ab86b3504",
		"system_id": 44349207
	},
	{
		"bodies": "94b07bbc1e5f5c3aeed75d2823e51d550429959e4973b25b927733c85da18a99",
		"dates": [
			"98b98ec3a6e2d9e8a5d49f4aac4c3b95109abbc00573151ce53cd587b1d358a7",
			"05aac8f3fd573e3ef85332023bb63c2dd647ef07d1f6d4747b27a1b879901cf8",
			"abda949230d9e511fef340e3a014c610e40f0cbd6871fda8b046426e34237a1c",
			"5519db7898e2e2f34c87298b1342642c0589d6eab26d564e985a377beab22066"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "0fb3c547ddfd2450c2a04ee8ca8c77a34c55b611e2fc6497e00381e8a19733d2",
		"snapshot": "e8ff97abab5ba93d623981b046572ad7b91f276f95e3389588b7662c7325d4c8",
		"snapshot_json": {
			"focus_id": "hc4",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc4",
			"site_id": "",
			"source_digest": "0f485a8ca7d353770c814ec554b6b7683f6f8983aa64ff3675f0c910e1446be3",
			"system_id": 44341017,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "0f485a8ca7d353770c814ec554b6b7683f6f8983aa64ff3675f0c910e1446be3",
		"system_id": 44341017
	},
	{
		"bodies": "bdf06be545f66867440cf68553adc469c87ef6edc3bcc128a5e008ff50c3c727",
		"dates": [
			"8851d4566c51d6321833e5f30572038091f422a3419f0f1c107a1b6bf2e61f59",
			"86707c51db648c4c81d96f7253ccad25e2964a937ba22ce4a3b6bf1382fc5663",
			"3f409f5528e0b9f85730a69e50691e553e303485c35a9802b0df2831a95a8279",
			"cffe78b257166b6977a0e1c33701ef4ffd6a01c58822d7d9d18708d4fc1ea3fc"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "9e7e3824a3eb7733610c297e8ee48344afd52e1d63f9a3109d7e9b0ff72a94a4",
		"snapshot": "d75c1a07ad0a5c19b604fc24b1cbee82fadb2f7491efb95801a49a09de86e5c9",
		"snapshot_json": {
			"focus_id": "hc4",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc4",
			"site_id": "",
			"source_digest": "d398322ab9961c26886cc8733d826e309c7703bdfcf0a2d27500e8be6ec7764c",
			"system_id": 111466264,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "d398322ab9961c26886cc8733d826e309c7703bdfcf0a2d27500e8be6ec7764c",
		"system_id": 111466264
	},
	{
		"bodies": "4a44a569dde9f1768e2f491a51fe0ab810f4caca7446dbc8f0dc10a01d780b7a",
		"dates": [
			"db081960561ae085322dda2749e92f055df70ffc4b51b93e2e9a9f2bfce8c4b6",
			"cba5fc5277be37a136cfd1de4cf5f44b6ce2a57a382694167658743ac4c7c91d",
			"cdb205e3be732f028f0b917c8ed2cb94cb83190fe3bd2256aa0c2df5ff863484",
			"4fa3f42456307a68726c130bffef23c619d5ca347feaa26f29cb6079fc3621ba"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "5dc22d884da5c9cd8e865532385776d6b2decab0543c93a2afa2bb1b3154d80b",
		"snapshot": "5c7992d62662a84fd37f3604e123375dfa58a1910f00165c6ceb43aae18af04f",
		"snapshot_json": {
			"focus_id": "hc4",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc4",
			"site_id": "",
			"source_digest": "df8ddf89edb3050424308388d90802fdc95049cb57ac1c1ed6035a864381d2a5",
			"system_id": 111449879,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "df8ddf89edb3050424308388d90802fdc95049cb57ac1c1ed6035a864381d2a5",
		"system_id": 111449879
	},
	{
		"bodies": "9e226c916aa0d98f8aa9ca6a2a9c69cc417df391b4789da6c7c10d789325ba90",
		"dates": [
			"bdd929c5186fef1d4a02d8a8417744d15c14bd81ac1734532b9fc03a27677f86",
			"a37bffc63084f1a705d90d419c255c3a592eff10ffcb74c0705de7baaf4ce533",
			"ff9dcdd89827885ad613157c4ca64ae1ba4095b9670793e765d0dcca09b70abf",
			"42b1ef4dd75e3a040ccf259143495deda75a47fb3509f1b97c4618f06320128e"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "890f4efea6d0c46d2f1ac233163dd0d9aaca85596e8b657ab457cf0c40e26bca",
		"snapshot": "13a3bc6738c85175f42b9fc43d0fc83aee5f26d727fc04fba46aefc9988c8f25",
		"snapshot_json": {
			"focus_id": "hc2",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc2",
			"site_id": "",
			"source_digest": "b28a1907f50e311a751875165a288663ad23f5d4ab7f56498fb63956e8e77f83",
			"system_id": 44291861,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "b28a1907f50e311a751875165a288663ad23f5d4ab7f56498fb63956e8e77f83",
		"system_id": 44291861
	},
	{
		"bodies": "f45dd481012e158dce3e99aed049b3cdd5bc1e5e3d192638aa9514430996bc41",
		"dates": [
			"d447becf0adc8bc721d64003f8a63c03d7ec133c3ee19b023d204e54ed36a927",
			"b7590518dedc41455f372fe4434ee339c68552d49f5e1b88d32ba895af4159f3",
			"a806cd45b451af7aa34e81975f61338aa1146b203b8aa7a227470ff4bd2f4897",
			"d5691854f8f890212ddc6b98e5cb07133b08bffe2502184327ddff5e46224ebf"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "5f695d3f44731b74171d368b44fb4435e4a591ab963ec160dea056e745a8309c",
		"snapshot": "4c1d1d0eb91125dae32788e62fff36e3399b119016c0c71e271bb0413c033746",
		"snapshot_json": {
			"focus_id": "hc2",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc2",
			"site_id": "",
			"source_digest": "20d92ee637617533113f7cbf1e81f8bd277a84a94cad88feb16c761c3eef542e",
			"system_id": 111400725,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "20d92ee637617533113f7cbf1e81f8bd277a84a94cad88feb16c761c3eef542e",
		"system_id": 111400725
	},
	{
		"bodies": "cdec4839b4b7ba0da7c40c2f44a2ae497c9c1e685b7017386c803a53debd73bc",
		"dates": [
			"526e139b29bb246a414b77256d9b695af7c01016460ffda05579a700396da15d",
			"f960476f6ac32175efb56f19ec651a400f499848492f80f283dc55f5f18a057f",
			"ea17f092850f488729f8af8c38836200acfc49a9846277b148b75e15ea75b34e",
			"7c6e915135eff0d2fb9b0d9f3e6c43dc8572712821d2f473327f4f99de06a322"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "a5b4057429529144f1d03ef40892d60f36715cb5bd4e8a48a42d732c5559a178",
		"snapshot": "18fb9926c8ed05e69cf44cff88264ab31c4fbaa5925721897ca1f4bacb640f03",
		"snapshot_json": {
			"focus_id": "hc2",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc2",
			"site_id": "",
			"source_digest": "345292078de3194688274e7fdffb46691a77e7379d7957dfb9bfa32af70d5824",
			"system_id": 245618453,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "345292078de3194688274e7fdffb46691a77e7379d7957dfb9bfa32af70d5824",
		"system_id": 245618453
	},
	{
		"bodies": "f5ccfab3b2a8788cb12dc9b052e095600dbedd69c5f67b71370da494f7422f59",
		"dates": [
			"526e139b29bb246a414b77256d9b695af7c01016460ffda05579a700396da15d",
			"f960476f6ac32175efb56f19ec651a400f499848492f80f283dc55f5f18a057f",
			"ea17f092850f488729f8af8c38836200acfc49a9846277b148b75e15ea75b34e",
			"7c6e915135eff0d2fb9b0d9f3e6c43dc8572712821d2f473327f4f99de06a322"
		],
		"layout": "handcrafted_analytic_rebuild_v1",
		"sites": "3c763aa05fbc87818db6cf334fd4773af82e0e9b473f95b337aec1647b2d2537",
		"snapshot": "f0e06c83b023b099aee2ad56eb6bd69d7ea9b02c19230faf8d7148f22776de58",
		"snapshot_json": {
			"focus_id": "hc2",
			"layout": "handcrafted_analytic_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "hc2",
			"site_id": "",
			"source_digest": "3e976be73c1bde5faae3ec419660e404ef601d646debe88f55ffb2cc2c4e8b48",
			"system_id": 44291862,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "3e976be73c1bde5faae3ec419660e404ef601d646debe88f55ffb2cc2c4e8b48",
		"system_id": 44291862
	}
]"""
const FALLBACK_BASELINE_JSON:="""[
	{
		"bodies": "c25d18725602e22fb7bd31c0b05b669be5c5a94f06660a360e42cd8dee5f467c",
		"dates": [
			"f5ee4b5e1fb8899017fa31bf00b93967b0b23430ec44a29b08598e147875df86",
			"6ae3968ea9f809f687d5eaf64e547efdfb4ae8995c923d2d6e9fb979884636f5",
			"a93a8528fd6f647ece05a608f3d9cc71cb4f0932a38e19bbca65f8b74059f47a",
			"c258265e08ff3a5b3bbfdd21a9ba7399a5e276f8133ef1423b8f992416dc179d"
		],
		"layout": "reconstructed_solar_v1",
		"sites": "a0e51cd84eb50eb741e24584df6fabd9c07c0a48a7642be4ef8ab5aea6a0af4b",
		"snapshot": "3d3869d1e0de8b5e2b9153834c344e8630da8b5a7887ce819978d78f31d1aeb5",
		"snapshot_json": {
			"focus_id": "earth",
			"layout": "reconstructed_solar_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "earth",
			"site_id": "",
			"source_digest": "8e8529b64f3128f885d75ae86913fc0efd11730c5ab3d87e16389f4331730026",
			"system_id": 44341016,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "8e8529b64f3128f885d75ae86913fc0efd11730c5ab3d87e16389f4331730026",
		"system_id": 44341016
	},
	{
		"bodies": "587ae1cecd48573a464dd999b27fdf31efb15ca9a9e578710682a17b3ade6ce9",
		"dates": [
			"1af8b97a165cab7f9bbbd4d36daccdf39bb76d8cce18bb1ff884e8f82ce6630b",
			"1af8b97a165cab7f9bbbd4d36daccdf39bb76d8cce18bb1ff884e8f82ce6630b",
			"1af8b97a165cab7f9bbbd4d36daccdf39bb76d8cce18bb1ff884e8f82ce6630b",
			"1af8b97a165cab7f9bbbd4d36daccdf39bb76d8cce18bb1ff884e8f82ce6630b"
		],
		"layout": "source_unavailable_rebuild_v1",
		"sites": "24b622edac8a21781259f0fc8d4312dfb3d3792d4195c64b093d4182b8dd1fe9",
		"snapshot": "5d6f9a88c99b4a75fee8f867c7c97f631034bc064a2ebf40f3f2329de5733911",
		"snapshot_json": {
			"focus_id": "star",
			"layout": "source_unavailable_rebuild_v1",
			"pending_id": "",
			"pending_site_id": "",
			"schema": "starfrontier-rebuild-world-v1",
			"selected_id": "star",
			"site_id": "",
			"source_digest": "255807f8c0645f29b7d1e12e031cc0bd3a55e72fc20402476582be9c235ada3d",
			"system_id": 270544960,
			"transfer_remaining": 0.0,
			"version": 1
		},
		"source_digest": "255807f8c0645f29b7d1e12e031cc0bd3a55e72fc20402476582be9c235ada3d",
		"system_id": 270544960
	}
]"""
const DATES:=[0.0,0.25,365.25,100000.0]
const SI_FIELDS:=["radius_km","mass_solar","rotation_hours","kind","physical_adapter","model_index","record_hex","runtime_record_hex"]
const EMPTY_ID:=0x10203040
var checks:=0
var failures:=0
var failure_groups:Dictionary={}
var private_directory:=""
var controls:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		failure_groups[message]=int(failure_groups.get(message,0))+1
		if failures<=30:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func catalogue()->Array:
	var parsed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_worlds.json"))
	return parsed.systems
func legacy_collect(world:RefCounted)->Dictionary:
	var dates:Array=[]
	for day in DATES:
		var positions:Array=[]
		for body:Dictionary in world.bodies:
			positions.append([body.id,world.relative_au(body,day),world.position_au(str(body.id),day),world.local_meters(str(body.id),day)])
		dates.append(digest(positions))
	return {"system_id":world.system_id,"layout":world.layout_mode,"source_digest":world.source_digest,"bodies":digest(world.bodies),"sites":digest(world.settlements),"snapshot":digest(world.snapshot()),"dates":dates}
func frozen_legacy()->void:
	var baseline:Array=JSON.parse_string(BASELINE_JSON);var galaxy:=Galaxy.new()
	check(baseline.size()==11 and BASELINE_COMMIT.length()==40 and OLD_WORLD_SHA256.length()==64,"Independent published 0.11.9 baseline contains all eleven worlds")
	for row:Dictionary in baseline:
		var world:=World.new();world.configure(galaxy.get_system(int(row.system_id)))
		var current:=legacy_collect(world)
		for key in ["layout","source_digest","bodies","sites","snapshot","dates"]:
			check(current[key]==row[key],"Legacy world %d retains 0.11.9 %s"%[int(row.system_id),key])
		var native:=World.new();native.configure(galaxy.get_system(int(row.system_id)),World.NATIVE_LAYOUT)
		check(native.restore(row.snapshot_json),"Native world accepts an unmodified old v1 snapshot")
		check(digest(native.snapshot())==row.snapshot and native.preferred_layout()==World.SOURCE_LAYOUT,"Loading old progress explicitly restores its original orbit family")
		check(native._native_positions_raw.is_empty() and native._native_relative_raw.is_empty() and native.native_evaluation_count==0,"Legacy restore clears native caches and evaluation state")
	var fallbacks:Array=JSON.parse_string(FALLBACK_BASELINE_JSON)
	for row:Dictionary in fallbacks:
		var world:=World.new();world.configure(empty_star() if int(row.system_id)==EMPTY_ID else galaxy.get_system(int(row.system_id)),str(row.layout))
		var current:=legacy_collect(world)
		for key in ["layout","source_digest","bodies","sites","snapshot","dates"]:
			check(current[key]==row[key],"Legacy fallback %s retains independent 0.11.9 %s"%[str(row.layout),key])
func fixture_key(system:int,index:int,tick:int,day:int)->String:return "%d:%d:%d:%d"%[system,index,tick,day]
func prepare_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_orbit_native.json"))
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.get("source_variant")=="jjffe-7e54034-q31-orbit","Native controls name uploaded source and explicit JJFFE Q31 variant")
	check(int(fixture.get("fresh_process_runs",0))>=3 and fixture.get("object_canaries_unchanged",false),"Native source controls repeat independently with intact guards")
	for row:Dictionary in fixture.get("epoch_update_cases",[]):
		if row.get("system_id")==null or not str(row.get("source_context","")).ends_with(" / zero destination"):continue
		controls[fixture_key(int(row.system_id),int(row.local_index),int(row.tick_u32),int(row.day_u32))]=row
func expected_au(raw:Array)->Array:
	# Independent calibrated source scalar, retaining double XYZ until rebase.
	var result:Array=[]
	for value in raw:result.append(float(int(value))*(16785.0/16777216.0)/149597870700.0)
	return result
func raw_sum(left:Array,right:Array)->Array:
	# Native signed64 arithmetic wraps; fixture source records are kept as ints.
	return [int(left[0])+int(right[0]),int(left[1])+int(right[1]),int(left[2])+int(right[2])]
func scalar_match(actual:Array,expected:Array)->bool:
	if actual.size()!=3 or expected.size()!=3:return false
	for axis in range(3):
		if not is_finite(float(actual[axis])) or absf(float(actual[axis])-float(expected[axis]))>maxf(1e-18,absf(float(expected[axis]))*3e-16):return false
	return true
func native_worlds()->void:
	var galaxy:=Galaxy.new();var tested_bodies:=0;var tested_hierarchy:=0
	for entry:Dictionary in catalogue():
		var system:=int(entry.system_id);var world:=World.new();world.configure(galaxy.get_system(system),World.NATIVE_LAYOUT)
		var legacy:=World.new();legacy.configure(galaxy.get_system(system))
		check(world.layout_mode==World.NATIVE_LAYOUT and world.preferred_layout()==World.NATIVE_LAYOUT,"Every mapped new world enables the native centre backend")
		check(world.snapshot().get("schema")=="starfrontier-rebuild-world-v2" and world.snapshot().get("preferred_layout")==World.NATIVE_LAYOUT,"New world saves explicitly identify native orbit family")
		check(world.source_digest!=legacy.source_digest and world.orbit_backend_state.get("complete_original_physics")==false,"Native centres receive a distinct digest and retain an honest physics boundary")
		for body:Dictionary in world.bodies:
			var old:Dictionary=legacy.by_id[str(body.id)]
			for field in SI_FIELDS:check(body.get(field)==old.get(field),"Native positions preserve the existing local SI field "+field)
		for day in DATES:
			var clock:=Clock.from_elapsed_days(day);var absolute:Dictionary={}
			for body:Dictionary in world.bodies:
				var key:=fixture_key(system,int(body.original_index)-1,int(clock.tick_u32),int(clock.day_u32))
				check(controls.has(key),"Independent native fixture covers live body at exact source clock "+key)
				if not controls.has(key):continue
				var native:Dictionary=controls[key]
				check(body.runtime_record_hex==native.record_hex,"Live ephemeris consumes actual F878 packed record, not constructor template")
				var relative:Array=native.expected.position_raw;var parent:=str(body.parent)
				if not parent.is_empty() and not absolute.has(parent):check(false,"Native hierarchy fixture is topologically complete");continue
				absolute[str(body.id)]=relative.duplicate() if parent.is_empty() else raw_sum(absolute[parent],relative)
				check(scalar_match(world.relative_au(body,day),expected_au(relative)),"Relative native XYZ matches independent original procedure without axis reflection")
				check(scalar_match(world.position_au(str(body.id),day),expected_au(absolute[str(body.id)])),"Absolute hierarchy sums raw signed64 before converting to AU")
				if not parent.is_empty() and not str(world.by_id[parent].parent).is_empty():tested_hierarchy+=1
				tested_bodies+=1
			var count:int=world.native_evaluation_count;var original:Array=world.position_au(world.focus_id,day);var pristine:=original.duplicate()
			original[0]=1e30
			var relative:Array=world.relative_au(world.by_id[world.focus_id],day);relative[1]=-1e30
			check(world.position_au(world.focus_id,day)==pristine,"Returned coordinate arrays cannot mutate cached native positions")
			world.gravity_at(world.local_meters(world.focus_id,day)+Vector3(20000,30000,40000),day)
			for body:Dictionary in world.bodies:world.position_au(str(body.id),day)
			check(world.native_evaluation_count==count,"Every same-clock position and gravity query shares one all-body cache")
			var centre:Vector3=world.local_meters(world.focus_id,day)
			var offset:Vector3=World.ARRIVAL_DIRECTION.normalized()*maxf(float(world.by_id[world.focus_id].radius_km)*4000.0,3000000.0)
			check(centre.distance_to(offset)<8.0,"Changing native celestial centres retains the existing local arrival frame")
		var count:int=world.native_evaluation_count;var previous_focus:String=world.focus_id
		world.focus_id="star";world.local_meters("star",DATES[-1]);world.focus_id=previous_focus
		check(world.native_evaluation_count==count,"Changing only focus rebases doubles without reevaluating source ephemerides")
		world.position_au(world.focus_id,0.25);count=world.native_evaluation_count
		world.position_au(world.focus_id,0.25+0.25/4294967296.0)
		check(world.native_evaluation_count==count,"Subtick elapsed differences share a source-word cache key")
		world.position_au(world.focus_id,0.25+1.0/4294967296.0)
		check(world.native_evaluation_count==count+world.bodies.size(),"A changed source clock word evaluates exactly one new complete body set")
		var save:=json_copy(world.snapshot());var restored:=World.new();restored.configure(galaxy.get_system(system))
		check(restored.restore(save) and restored.layout_mode==World.NATIVE_LAYOUT,"Default legacy decoder accepts explicit new native v2 world")
		check(json_copy(restored.snapshot())==save,"Native v2 world save round trip preserves all selection and family fields")
		restored.position_au(restored.focus_id,365.25)
		check(restored.restore(save) and scalar_match(restored.position_au(restored.focus_id,0.25),world.position_au(world.focus_id,0.25)),"Native restore discards the previous date cache and returns valid current source centres")
		check(restored.restore(json_copy(legacy.snapshot())) and restored._native_positions_raw.is_empty(),"Native-to-legacy restore clears a warmed backend")
		check(restored.restore(save) and restored.layout_mode==World.NATIVE_LAYOUT and not restored._native_positions_raw.is_empty(),"Legacy-to-native restore rebuilds the appropriate source cache family")
	check(tested_bodies>350 and tested_hierarchy>30,"Independent orbit controls include all mapped worlds and multilevel moon hierarchies")
func cache_state(world:RefCounted)->String:
	return digest([world.snapshot(),world.bodies,world.settlements,world.requested_layout,world.orbit_backend_state,world.source_runtime_state,world._native_cache_tick,world._native_cache_day,world._native_positions_raw,world._native_relative_raw,world.native_evaluation_count])
func rejected_restores()->void:
	var galaxy:=Galaxy.new();var world:=World.new();world.configure(galaxy.get_system(Galaxy.SOL_ID),World.NATIVE_LAYOUT)
	world.position_au("moon",365.25);var saved:=json_copy(world.snapshot());var stable:=cache_state(world)
	var corruptions:={"schema":"starfrontier-rebuild-world-v1","version":1,"preferred_layout":World.SOURCE_LAYOUT,"layout":World.SOURCE_LAYOUT,"source_digest":"wrong","system_id":-1,"focus_id":"unknown","selected_id":"unknown","site_id":"site999","pending_id":"earth","pending_site_id":"site10","transfer_remaining":4.0}
	for key in corruptions:
		var invalid:=saved.duplicate(true);invalid[key]=corruptions[key]
		check(not world.restore(invalid),"Invalid native save rejects "+key)
		check(cache_state(world)==stable,"Rejected "+key+" retains the entire warmed orbit backend atomically")
	var absent:=saved.duplicate(true);absent.erase("preferred_layout")
	check(not world.restore(absent) and cache_state(world)==stable,"Native save cannot silently lose its orbit family")
	var legacy:=World.new();legacy.configure(galaxy.get_system(Galaxy.SOL_ID));var old:=json_copy(legacy.snapshot());old.preferred_layout=World.NATIVE_LAYOUT
	check(not world.restore(old) and cache_state(world)==stable,"A v1 save cannot smuggle in native family metadata")
func empty_star()->Dictionary:
	return {"id":EMPTY_ID,"name":"Native-family empty fixture","original_name":"Native-family empty fixture","position_ly":[1.0,0.0,0.0],"has_station":false}
func unknown_family()->void:
	var galaxy:=Galaxy.new();var world:=World.new();world.configure(galaxy.get_system(Galaxy.SOL_ID),World.NATIVE_LAYOUT)
	world.configure(empty_star(),world.preferred_layout())
	check(world.layout_mode==World.EMPTY_LAYOUT and world.preferred_layout()==World.NATIVE_LAYOUT,"Unknown world retains requested native family while using star-only fallback")
	var saved:=json_copy(world.snapshot());var restored:=World.new();restored.configure(empty_star())
	check(saved.get("version")==2 and saved.get("preferred_layout")==World.NATIVE_LAYOUT and restored.restore(saved),"Empty native-family world has a restorable explicit v2 save")
	check(restored.preferred_layout()==World.NATIVE_LAYOUT and restored._native_positions_raw.is_empty(),"Empty restored native family contains no stale previous-system positions")
	restored.configure(galaxy.get_system(Galaxy.SOL_ID),restored.preferred_layout())
	check(restored.layout_mode==World.NATIVE_LAYOUT,"Returning from empty fallback reactivates native centres")
func remove_private(path:String)->void:
	if private_directory.is_empty() or not (path==private_directory or path.begins_with(private_directory+"/")):return
	if not DirAccess.dir_exists_absolute(path):return
	for name in DirAccess.get_directories_at(path):remove_private(path+"/"+name)
	for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path+"/"+name)
	DirAccess.remove_absolute(path)
func jump(game:Node3D,target:int)->bool:
	game.ship.docked=false;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	if not game.nav.select(target) or not game.nav.begin_jump(game.ship):return false
	game._tick(Nav.CHARGE_SECONDS,Vector2.ZERO,0)
	return game.nav.current_id==target and game.nav.remaining==0
func actual_main()->void:
	var game:Node3D=load("res://scenes/main.tscn").instantiate();var settings:=MemorySettings.new();settings.quality=0;game.settings=settings
	root.add_child(game);game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled,"Actual Main is isolated from player saves and settings")
	check(game.world.layout_mode==World.PORT_LAYOUT,"Actual first new game, rather than only helper models, enables source centres")
	private_directory="user://source-orbit-integration-%d"%OS.get_process_id();game.saves.directory=private_directory
	var payload:=json_copy(game._payload());game.saving_enabled=true
	check(game._save_game(),"Actual Main writes the full new v3 world into a private test save")
	game.saving_enabled=false
	var loaded:Dictionary=game.saves.load_valid(game._decode_state)
	check(not loaded.is_empty(),"Actual Main reads its new native-family full save")
	if not loaded.is_empty():
		game._commit_state(loaded);game._apply_system()
		check(json_copy(game._payload())==payload and game.world.preferred_layout()==World.PORT_LAYOUT,"Full new save restores identical progress with explicit source orbit family")
	check(jump(game,111449880) and game.world.layout_mode==World.PORT_LAYOUT,"Actual Main hyperjump preserves native family in another known source system")
	game.nav.galaxy.by_id[EMPTY_ID]=empty_star()
	check(jump(game,EMPTY_ID) and game.world.layout_mode==World.EMPTY_LAYOUT and game.world.preferred_layout()==World.PORT_LAYOUT,"Actual Main hyperjump retains native family in an unavailable source system")
	var nav_save:=json_copy(game.nav.snapshot());var nav_copy:=Nav.new();nav_copy.galaxy.by_id[EMPTY_ID]=empty_star()
	check(nav_copy.restore(nav_save) and nav_copy.current_id==EMPTY_ID,"Navigation round trip retains an empty-system journey with the same explicit test catalogue")
	check(jump(game,Galaxy.SOL_ID) and game.world.layout_mode==World.PORT_LAYOUT,"Actual Main returns from empty fallback to native Solar centres")
	game._confirm_new_game();var activated:=false
	for control in game.menu_rows.get_children():
		if control is Button and control.text=="Начать новый полёт":control.pressed.emit();activated=true;break
	game.saving_enabled=false
	check(activated and game.world.layout_mode==World.PORT_LAYOUT and game.nav.current_id==Galaxy.SOL_ID,"Actual new-game menu starts a fresh native-family flight")
	var old_world:=World.new();old_world.configure(game.nav.current());var old_payload:=json_copy(game._payload());old_payload.planetary=old_world.snapshot()
	var old_loaded:Dictionary=game._decode_state(old_payload)
	check(not old_loaded.is_empty(),"Actual complete decoder still accepts an old unmodified v1 world save")
	if not old_loaded.is_empty():
		game._commit_state(old_loaded);game._apply_system()
		check(game.world.layout_mode==World.SOURCE_LAYOUT and game.world.preferred_layout()==World.SOURCE_LAYOUT,"Old progress retains original legacy positions after complete load")
		check(jump(game,111449880) and game.world.layout_mode==World.SOURCE_LAYOUT,"Hyperjump from old progress retains its old orbit family")
	game._new_models();game.world.configure(game.nav.current(),World.SOLAR_LAYOUT);game._apply_system()
	check(game.world.layout_mode==World.SOLAR_LAYOUT and game.world.preferred_layout()==World.SOURCE_LAYOUT,"Legacy Solar fallback retains the historic current-layout policy for its next journey")
	check(jump(game,111449880) and game.world.layout_mode==World.SOURCE_LAYOUT,"Leaving a legacy Solar adapter still uses the historic current source world at arrival")
	game._new_models();game._apply_system();game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	check(game.surface.active and game.surface.globe!=null,"Actual new native world can enter an existing original city district")
	if game.surface.active:
		game.ship.position=Vector3(300,game.surface.height_at(300,200)+game.surface.clearance(game.ship)+0.5,200);game.ship.velocity=Vector3.ZERO
		check(game.surface.touch_down(game.ship) and game.surface.pad_distance(game.ship)>80,"Native-world city supports a genuine manual off-pad landing")
		check(game._begin_departure_action(),"Actual native-world controller starts departure from manual landing")
		var airborne:Dictionary=game._decode_state(json_copy(game._payload()))
		check(not airborne.is_empty(),"Native-family full save can restore immediate city departure")
		if not airborne.is_empty():game._commit_state(airborne);game._apply_system()
		for tick in range(10000):
			game._tick(0.05,Vector2.ZERO,0)
			if not game.surface.active:break
		check(not game.surface.active and game.ship.hull==100 and game.world.layout_mode==World.PORT_LAYOUT,"City ascent completes a healthy geographic orbit handoff in the native port-capable centre frame")
		check(Link.valid(game.surface.orbit_link,game.world) and not game._decode_state(json_copy(game._payload())).is_empty(),"Completed native orbit handoff preserves a valid source-anchor link and full save")
	check(not game.saving_enabled,"All flight and departure work finishes with user persistence disabled")
	game.queue_free();await process_frame;remove_private(private_directory)
	check(not DirAccess.dir_exists_absolute(private_directory),"Private test saves are removed")
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs --rebuild-capture to isolate player progress");quit(1);return
	var world_script:Script=load("res://scripts/planetary_system.gd")
	if world_script==null or not world_script.can_instantiate():push_error("Planetary world script must compile before integration testing");quit(1);return
	var originals:=[FileAccess.get_sha256("res://data/ffe_worlds.json"),FileAccess.get_sha256("res://data/ffe_handcrafted_records.json")]
	frozen_legacy();prepare_controls();native_worlds();rejected_restores();unknown_family();await actual_main()
	check(originals==[FileAccess.get_sha256("res://data/ffe_worlds.json"),FileAccess.get_sha256("res://data/ffe_handcrafted_records.json")],"Integration tests leave original source world data untouched")
	print("SOURCE ORBIT INTEGRATION TESTS: %d checks, %d failures; independent 0.11.9 baseline, native centres, caches, Main, saves, city departure"%[checks,failures])
	if failures:print("SOURCE ORBIT INTEGRATION FAILURE GROUPS: "+JSON.stringify(failure_groups))
	quit(1 if failures else 0)
