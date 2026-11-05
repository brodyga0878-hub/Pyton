extends SceneTree
# Independent old-world snapshot plus native F878 controls. Source ephemerides
# are not enabled by this bridge; current analytic flight/surface saves stay put.
const Galaxy=preload("res://scripts/galaxy.gd")
const World=preload("res://scripts/planetary_system.gd")
const Profile=preload("res://scripts/source_city_profile.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Near=preload("res://scripts/near_surface_view.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const Settings=preload("res://scripts/device_settings.gd")
class MemorySettings extends Settings:
	func load_file()->bool:return false
const BASELINE_COMMIT:="5fe9f83a9638ff7cbfeb568738a57e9a1c600d0d"
const ORIGINAL_WORLD_SHA:="83e9d4af51aaf796b0f5366965dc25c8e4d5b25ef82192124f60492573941fd8"
const BASELINE_JSON:="""{
	"baseline_commit": "5fe9f83a9638ff7cbfeb568738a57e9a1c600d0d",
	"engine": "4.6.3-stable (official)",
	"scope": "Current analytic source-world records, positions, gravity, city profiles, shared spin/surface frames and saves; no native ephemeris claim",
	"world_source_sha256": "83e9d4af51aaf796b0f5366965dc25c8e4d5b25ef82192124f60492573941fd8",
	"worlds": [
		{
			"bodies_sha256": "373aab76aa7956e4fcd1b11e4d002c6a5777f2fdbf9c43ee374e35bf261f6f16",
			"body_count": 35,
			"city_profiles_sha256": "cd500961b59dd384dcbfbb2d02cd80092229f27af44f9dc8a889c9c1fbe84b20",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "50389f866205791c65916e104a8f2bf2fda4e78713fa55af617b982b9d50fbbe",
					"positions_sha256": "08c8cbee27b7688305553c429440b88b8f56408e51790eb42918c1429ae61ff2"
				},
				{
					"day": 0.25,
					"gravity_sha256": "7c20d0b717278d82e10cb670eaaaf6ddce0a64d229073c3eade700e2bcb21084",
					"positions_sha256": "171c597d751ec8ed9588d2808f4c467ca82c2a5511329941ffcf756e3b4fc3e3"
				},
				{
					"day": 365.25,
					"gravity_sha256": "7d3190bd625a9e1651ecf965ec43c3ffb6c4fc81f3545592e220d09c948942ed",
					"positions_sha256": "019a25fc55aaee9591629d99daae677ed47962bddf043c63e82675d9e56e86cd"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "c2c055f430cd8607986246f3c15652b1660cd68b7e688bb5b9807ec3fcf5d614",
					"positions_sha256": "4bd2c678b3d13c1106c198b367fdb38e3f51940288feb8ff43910053f5b2a459"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 18,
			"sites_sha256": "ce22d4362ba2caa62b6d32a32e9bece4990794c5f813643e636cb4bc3574dcb5",
			"snapshot_sha256": "ca1d04bda6146befaa1e8f08a8cce785d8b84124fe630cd65702e0c5b48daa3d",
			"source_digest": "7e9565c29346efe1e9071cbb2b233fe4b88441638a059431bf1313cea741cddd",
			"surface_frames_sha256": "4f7a162faa2b3334af5767b9ffc8f00ac65c4be9bb638cbbfef3d18f9537de80",
			"system_id": 44341016
		},
		{
			"bodies_sha256": "ac451372f3e83faf17b10166e63d1403c44a447c512b4620cbed990c8c34c778",
			"body_count": 10,
			"city_profiles_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "524087234fa274ecd2d0a065d08ccec09069d474077a48dca98e38ee1fb6caae",
					"positions_sha256": "82cf5b37747010e6f5f2da34ac48788c008ddbe0ae08c8c78cd2a4add8cc50f2"
				},
				{
					"day": 0.25,
					"gravity_sha256": "0606e138433c0ef5ad2af8c2b1b63261ea872159da12ca611e6b06b2713e7a5c",
					"positions_sha256": "4a4ef2449499b6ea70b80036248c7348c696d334db2ab16a89e02d3b33550838"
				},
				{
					"day": 365.25,
					"gravity_sha256": "07abad41b0a8335ac19ca176cd66523c529e64f3a865e7d5c4d9e3cfd577edaa",
					"positions_sha256": "f99173c34aea02a47b857e8cdab4feb100de9b25bb9efc6bce80aadd14e8ca56"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "1160959d7c0ffa73c696966f8010cd2c76661fb1e15624b67ae8a5c3a5c42679",
					"positions_sha256": "61c67f171acecfeb7618d75c4a48384444b27ae6139f10d81fe4dd35ff761e04"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "d49e41ddf24ba4cb7eaa4b2044161c540ec7c4964f86f10140148aecd790501e",
			"snapshot_sha256": "a4b851fcfd82c0b11e333f2079ea829262c273d620acc19a3d943559c6c2c460",
			"source_digest": "8aa6eb76120f1b3b9bc511e6f68af97e29ca090982c47d83f2bcd4cbf87a2a3a",
			"surface_frames_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"system_id": 111449880
		},
		{
			"bodies_sha256": "99271cceb9ef00a25e3df3847f4b03d0e9ddbd1969cd46ae8f78ff7ccaed78a1",
			"body_count": 9,
			"city_profiles_sha256": "e6d0c84e120b06e9127b6ae1c1a7904159ed3a87eaab2cc310e6bf38b7e006b6",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "5d6c65109d49a0a1780aec9053b20c296e937e6725dcb09d0840a4e48a8bbcff",
					"positions_sha256": "623ab7c8e04f2e3044b19da84b54ea43d238d255f092c5533bf5fdc099ff3aec"
				},
				{
					"day": 0.25,
					"gravity_sha256": "2bb0c5401164b0f46149e63696d3911be8d88bfeb56fe38a7fee7447894445f6",
					"positions_sha256": "19dabfadab791627e107274f4908e368bb24baecf73987d96457c0ed11f6ea37"
				},
				{
					"day": 365.25,
					"gravity_sha256": "28c7582e896a83cfbe01ea00c0f00d271c159d494c125068bd63da0dc301595b",
					"positions_sha256": "8f689cc0a9fb8bf7af9586409f8c831b38bc5459772a9de5d4799736036ff8c7"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "607b66e01469f0b6b56dd5044bd4570a40d1687c3ee8e6848eeeb6acc880531d",
					"positions_sha256": "92001573cbec315b697250d395e7f459811ad4c1d96e0cc04bae277c007c32b7"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 2,
			"sites_sha256": "39e5e6ec38819d0bd3cad4f4cda03b051a5247474cbac7557a53e404d96d5e57",
			"snapshot_sha256": "82457f92a07eef6acb7e51eca51aaa4c6f2a913fc4d3dc92ac1c22c5316121d8",
			"source_digest": "af4d558786986145b7638f9a1e5a7fe8389f7fc2d0b88b4764df75cd48e07f0e",
			"surface_frames_sha256": "3db69bbbcc107cdbcf5016110d6b51558094796104e35bfe4c708ce885fc5eda",
			"system_id": 245659414
		},
		{
			"bodies_sha256": "34de7c0f978a85cf913c443e7a53e8a353624edfd7d1104acfc5c0163362145b",
			"body_count": 9,
			"city_profiles_sha256": "8fa8ac2a0f44637f2e4b4b1e5f060d9bf9aaefd75d18d6ab91942bed30b1e1d4",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "f342179bd383744861f6538801b081a87c670147e0b28cbd744aeeaf5d2afc81",
					"positions_sha256": "47e4ee9f9a76dc579476340b833990e6d45bc9a1b02b1fb63a709fa37328bb24"
				},
				{
					"day": 0.25,
					"gravity_sha256": "6178e51bcae9272880ee6619f2b3c53a89c21242e658839538511888e71f9972",
					"positions_sha256": "ab01acd9c591370adc05981807d77a762a2349e04913d91c3e00fe7e15a43623"
				},
				{
					"day": 365.25,
					"gravity_sha256": "64409cc931833cb8cfb1a1c3b13a9290a37a79506292b2c3d337b2d1f1ad9109",
					"positions_sha256": "94a9a16d8418696a22acd9785f895cf0fbcb6d63d83f2e1cb29f060691ac2b67"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "0560644327652e35b845e2c7335fc5878c296f232488814b44b93a07b1e20aed",
					"positions_sha256": "f6da81dc0b5c5266c6679ccd78bf871e7dc9ec78baf01c14a05c4d4346a5f789"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "aa807d4d0c2cba646052ea01d0f6aff44c88ca258264780d54da560ec92aaca3",
			"snapshot_sha256": "a136a50d6b98dc805af61700cb19d33d597f653d662c2f924d0c77154c3dea38",
			"source_digest": "ebde0a6eaa550732022585a3850fbe5b59cf935d7430b261e5c0a09ab86b3504",
			"surface_frames_sha256": "3f23643c4dac9e273234d6c758f4e9ebd4dae4401411d69e54a9466769cbe54e",
			"system_id": 44349207
		},
		{
			"bodies_sha256": "3fa43922022ccb44f0a2d2f1279eeaf6acaa12b1a9603ef165307e8062d36a4d",
			"body_count": 5,
			"city_profiles_sha256": "cfbbedacc94ec376f499ca87f528bfc0e5db6bf16f30d6666a7999c94cfc854c",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "655c652b44601d63f5d9e6e64e88786afa9d83a641e509508091557cec6a9fa0",
					"positions_sha256": "aaad42097d62a1495b270e82c0696aa433f547fb8ae8f334dd737f9d8f0c1750"
				},
				{
					"day": 0.25,
					"gravity_sha256": "165e1c080725854bc33e270e5dc83cecefb169739fa72e85c7488d11c02fabe8",
					"positions_sha256": "047d3ea217edfae118f1dbc01f3c60252d72570eda262629b9d1ad7394177c94"
				},
				{
					"day": 365.25,
					"gravity_sha256": "53a9f955b351d2e6d3f2f21a84f4c32d4d14e9c4ff485c0e74d323cf93b54c28",
					"positions_sha256": "a5915418f363b99d488391db4e6a11b68edfc52ba62da4b58b9d6a36b3f4db22"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "9bcea5941362e114795aaf4bb26a9f9b183aa2e4fcf09baa384a47c25a682c80",
					"positions_sha256": "66f32e91bad46de1c289d741fe03f7e3c08fc32ea7543d18b7487a0eec27c2c4"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "9b853cd54d56d5d2cb4a15d7b2377b03406f7c4b591dcb507f556967db00ea4e",
			"snapshot_sha256": "33c290d02593e19f2283de5497512ff4a5401b06dd8a6392b04d771aae33ca88",
			"source_digest": "0f485a8ca7d353770c814ec554b6b7683f6f8983aa64ff3675f0c910e1446be3",
			"surface_frames_sha256": "98739db691a05bd2a9ce586e999e966713bf7cd728caf3d521e2baa2ce679e4a",
			"system_id": 44341017
		},
		{
			"bodies_sha256": "e51a2918e7fc15379de866c4c492c44c03f3bc9a840654f8fb8c5b5ca056e834",
			"body_count": 10,
			"city_profiles_sha256": "14a64d10356889817a19313cfb0a474aac89af0ce57cda523543b3ddca3c4b0e",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "286cf4bd2c1f359a7ef24cee26df1614042c939e1530343f8a5f670e40448799",
					"positions_sha256": "d1bc9047001f0b1f315947fc2b146b006f68a32e3c7445a9778839109dc2f90c"
				},
				{
					"day": 0.25,
					"gravity_sha256": "5aedc2a4dbd825ecc684c4b9698cffa937b70c49b7728dfb282de09f746a5d76",
					"positions_sha256": "0f2cdd4ed67c1e6ed7f3002563a9ca26be779f9fef8d386752d20911a0dbabcd"
				},
				{
					"day": 365.25,
					"gravity_sha256": "12f09437622aa1e800dd67be49b81f51d443ba3fc8419f8e74c54b4227d42beb",
					"positions_sha256": "1869479b7ca6db6cd0ea00971df124374836bc87e40d3b8c7b46a90cd8b45db7"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "e6eed9d1a8bd045793e695ee17c25940c45baaeeb46c72f6c229d99589ee1775",
					"positions_sha256": "289b873a9ed46b6c3a2223ae865aeb2e4308034477b78caf03c6442c04ac2c2c"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 10,
			"sites_sha256": "be5fcc7f990d5f36dc4aa0d992152e5a981f440bff55eddbfbf7044004e24e87",
			"snapshot_sha256": "26b8fc605ee2f601937e079f0968fdaac0e207b56520e1970a7d4f54f0b3364a",
			"source_digest": "d398322ab9961c26886cc8733d826e309c7703bdfcf0a2d27500e8be6ec7764c",
			"surface_frames_sha256": "5e662cf9131efa62c5559752cd6340b673e4222ac1045aee06f2303b253cd3ae",
			"system_id": 111466264
		},
		{
			"bodies_sha256": "d33b8591f875f0c9bdbc5ea432d29fc7c00eeaa3cbffcaeff0af78d1b2088350",
			"body_count": 6,
			"city_profiles_sha256": "b88f2fe76275eef2da6d22b58c3ae9b7a926928fcd5be3972cb3c79dd7a32994",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "c5bc36613c63a4e7e46ea005cdc4d8367670003dfc083291fdde5440c97cfd5b",
					"positions_sha256": "37984761365b413be98ab2602b785b4e07fb0cd1fe0b3afcf7c9b370010c845d"
				},
				{
					"day": 0.25,
					"gravity_sha256": "944b5bcc1c3cd418dda269d37cec54f7324b49dd85c0198b251362804d132cce",
					"positions_sha256": "519b9d5d7f87d8cd376e4cf1155e862a19683323abceedc9eaa7e424e79cd9a5"
				},
				{
					"day": 365.25,
					"gravity_sha256": "0bb72101d40fcb34f7af067aedce43224db9b07af64d7b460251ea3bddd73c28",
					"positions_sha256": "69ac2d1a76f985600f4cb53edf5867843bc264de066bcd38de22467b49a881e0"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "706217c9efaef208167caa78f42e1081e7f7ced34f54099b7f0aa2140d56f916",
					"positions_sha256": "69e06edda84868a32ee06d805a4e290414d95ae7b0eba1f26e446a5fccdeeb66"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "6557c1d489b7fe2cf1d7f663722afe2d0f3ccfd0e7ee4a9c1df62e7aadae8235",
			"snapshot_sha256": "ef2ec3bf5fca34c76ba312e9f6f79cfd67465994c516ee66ea3d362fb07ef45e",
			"source_digest": "df8ddf89edb3050424308388d90802fdc95049cb57ac1c1ed6035a864381d2a5",
			"surface_frames_sha256": "63ef590c29415744eeb779f28002331507a472376fabb8314056c5d8cd6c15d1",
			"system_id": 111449879
		},
		{
			"bodies_sha256": "eab6fb5831d666795f5c8d1d48205500df430959fd4ded7f51c28afe4af9d6a5",
			"body_count": 2,
			"city_profiles_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "799b3eb83a39727ad0f0c77feae1df284f997e0ad6cbaea45bdd9a371f9351ae",
					"positions_sha256": "7be789bbc1ff5b7a71de40b8bef1182f247fe9f02921515950f672a536cbd5d4"
				},
				{
					"day": 0.25,
					"gravity_sha256": "a5a76fd9ab886a89615bd92a5d7fa8a405bc2ece96e56ed114d011c080993705",
					"positions_sha256": "008b2c394b4c078a8244dc7e1d7c636b4b8851a25e6005abc86fee1d11e8d60a"
				},
				{
					"day": 365.25,
					"gravity_sha256": "59bd8070bfaf2007942acd65ef758d5d623ee54566aaa41582963896ffb94582",
					"positions_sha256": "3468f58ec1541af79a2a8f784e137006b24716db0748e7ddb71fe6ee188c85bf"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "2fbdffb045d28b3e2d42bbb502616bb5f5b2517e148b39356d46e428c779d533",
					"positions_sha256": "20a1a0712c00eebe2e6068fa5ff9ecb244793c9fc62896cb407685120eb31d40"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "a91037e24f2ae220c86684cddf542b61871064e3bef4263b911a7b39f1d26b0e",
			"snapshot_sha256": "76cbd7c729c191ac6bf937695fd5ff49a15a49bb316c97081c94cb556a1a773d",
			"source_digest": "b28a1907f50e311a751875165a288663ad23f5d4ab7f56498fb63956e8e77f83",
			"surface_frames_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"system_id": 44291861
		},
		{
			"bodies_sha256": "634679476eaeb1a89970b33c2c2705d73425ffbbcc09831c5314b6631bae8432",
			"body_count": 2,
			"city_profiles_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "3feb87287cd5eb454c87d635b2447a6f4e3da65807e1485450222261242a7811",
					"positions_sha256": "4987ff7bd18326d233a620eb823e7fa3cc4296745c23a7d27ffb4b6ea80fd3bc"
				},
				{
					"day": 0.25,
					"gravity_sha256": "d3035949afa7da593f37b9dd5a2eb8687194c56a6a512c4c4897b9b42dee072c",
					"positions_sha256": "fd471b9bb5a349beaa2af5c46a9349fd113cd68868fd4ae23cf7a7a2aa1497bd"
				},
				{
					"day": 365.25,
					"gravity_sha256": "322177b911d88f99ae5bd6aa3cbeef749880ca556c044aaa540b30c64957ccc6",
					"positions_sha256": "567e591abba0ecacff0ae4c4a86669092e443e1954b1045d038289ae06203be6"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "b079c9cb4536083b5b3b39b449a61b668d5769fffdcc117d214aaf262710408f",
					"positions_sha256": "9d848b062fca73a1e71d387a9aea121e85b3bba3cce3b57ca251c23ee53ffe62"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "d6b23db7265fd30538e9146f094d630458854a9aba9212c7fbde734e07d7e59e",
			"snapshot_sha256": "7c7fa3037efd4d4b4862219f145d7335c7f23a1c32a56f3aae4221532f4a01ed",
			"source_digest": "20d92ee637617533113f7cbf1e81f8bd277a84a94cad88feb16c761c3eef542e",
			"surface_frames_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"system_id": 111400725
		},
		{
			"bodies_sha256": "36c7f860d956eb8e0a1bba698842bdbd990c518f4c7730a8eb084366e5477f0b",
			"body_count": 2,
			"city_profiles_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "c0e33c9e0b3b2b933a6b71b55c115403eeb9a1ebc0c81880c6f9b0d2c4171a9b",
					"positions_sha256": "b2e3562d99fd9e2610e2e02e3e3ed4c5f82463808f17b0f7e9587315239f7fc1"
				},
				{
					"day": 0.25,
					"gravity_sha256": "bab57b56ca803503675e62f656ce761e6ea68fcbb820d16697c9a5c320380b81",
					"positions_sha256": "66711c0ed63ca1e1dd342dcb8e6ec42202daf1a4ac356e9995e98e4fc5d3fb21"
				},
				{
					"day": 365.25,
					"gravity_sha256": "59195cc7f1219bed9e861f885d1609d387810c601426ee3c9d58a9b60f4348be",
					"positions_sha256": "3fdba14944e30f3547015b5f968d4eb26e571f2ef2dc1463eeee36e440e333cf"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "ae503be24dab2c6ac9f4e0838726f347db507cb45589528a793ac2d4a7c13904",
					"positions_sha256": "299afb92c3cd2b7d2689884e7fa0cdeef87894cc82f83045f9693a4ef139c2be"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "5cd9b94d974e0d7b01b4c89fd7fa5146b687a167aa8daefc7650929ea53cb89c",
			"snapshot_sha256": "50a8682efe682c93b5c270767ade9df5b6bcada6217f5400959ea104d4eae1ac",
			"source_digest": "345292078de3194688274e7fdffb46691a77e7379d7957dfb9bfa32af70d5824",
			"surface_frames_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"system_id": 245618453
		},
		{
			"bodies_sha256": "81203bfda17a4755c3563235795a0a41ad21c9ffe752ab9363a7e1f417d536a2",
			"body_count": 2,
			"city_profiles_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"dates": [
				{
					"day": 0.0,
					"gravity_sha256": "c0e33c9e0b3b2b933a6b71b55c115403eeb9a1ebc0c81880c6f9b0d2c4171a9b",
					"positions_sha256": "b2e3562d99fd9e2610e2e02e3e3ed4c5f82463808f17b0f7e9587315239f7fc1"
				},
				{
					"day": 0.25,
					"gravity_sha256": "bab57b56ca803503675e62f656ce761e6ea68fcbb820d16697c9a5c320380b81",
					"positions_sha256": "66711c0ed63ca1e1dd342dcb8e6ec42202daf1a4ac356e9995e98e4fc5d3fb21"
				},
				{
					"day": 365.25,
					"gravity_sha256": "59195cc7f1219bed9e861f885d1609d387810c601426ee3c9d58a9b60f4348be",
					"positions_sha256": "3fdba14944e30f3547015b5f968d4eb26e571f2ef2dc1463eeee36e440e333cf"
				},
				{
					"day": 100000.0,
					"gravity_sha256": "ae503be24dab2c6ac9f4e0838726f347db507cb45589528a793ac2d4a7c13904",
					"positions_sha256": "299afb92c3cd2b7d2689884e7fa0cdeef87894cc82f83045f9693a4ef139c2be"
				}
			],
			"layout": "handcrafted_analytic_rebuild_v1",
			"site_count": 1,
			"sites_sha256": "052909f0894af6620a71e52ca948cef30614ab7614317f4181f33be23080c33e",
			"snapshot_sha256": "a85500dabcb897509f086bf7723a8526e7eec89cf63360992ce3c903c71b96d4",
			"source_digest": "3e976be73c1bde5faae3ec419660e404ef601d646debe88f55ffb2cc2c4e8b48",
			"surface_frames_sha256": "3c88bf13b58cba9ca7fe10c55db47931f52b52975cf1e9eaa0c9b0ec29c7c6be",
			"system_id": 44291862
		}
	]
}"""
const DATES:=[0.0,0.25,365.25,100000.0]
const BODY_FIELDS:=["id","name","name_en","parent","kind","radius_km","mass_solar","a_au","eccentricity","inclination","node","periapsis","phase","period_days","rotation_hours","rings","source","physical_adapter","original_index","original_type","model_index","temperature_c","record_hex","source_seed","source_rotation_raw","source_orientation_u16","source_record_source"]
const SITE_FIELDS:=["id","name","name_en","parent","orbit_raw","type_code","model_index","latitude_raw","longitude_raw","original_index","source","ground_phase_u16","ground_inclination_u16","ground_coordinate_source","record_hex","source_seed","source_rotation_raw","source_orientation_u16","source_record_source"]
var checks:=0
var failures:=0
var private_directory:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=25:push_error(message)
func digest(value:Variant)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(value));return hash.finish().hex_encode()
func fields(row:Dictionary,names:Array)->Dictionary:
	var selected:Dictionary={}
	for name in names:
		if row.has(name):selected[name]=row[name]
	return selected
func catalogue()->Array:
	var parsed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_worlds.json"))
	return parsed.systems
func physics_snapshot(world:RefCounted)->Dictionary:
	var body_data:Array=[];var site_data:Array=[];var profiles:Array=[];var frames:Array=[]
	for body:Dictionary in world.bodies:body_data.append(fields(body,BODY_FIELDS))
	for site:Dictionary in world.settlements:
		site_data.append(fields(site,SITE_FIELDS))
		if int(site.type_code)!=35:continue
		var body:Dictionary=world.by_id[str(site.parent)]
		var profile:=Profile.describe(site,float(body.radius_km)*1000.0)
		profiles.append([str(site.id),profile])
		var previous:String=world.focus_id;world.focus_id=str(site.parent)
		var globe:=Sphere.new();globe.configure(world,str(site.parent),str(site.id),Sphere.CURRENT_REVISION)
		var values:Array=[]
		for day in DATES:values.append([day,Near.world_frame(globe,world,day),Link.spin(body,day)])
		frames.append([str(site.id),values]);world.focus_id=previous
	var dates:Array=[]
	for day in DATES:
		var positions:Array=[]
		for body:Dictionary in world.bodies:
			var id:=str(body.id)
			positions.append([id,world.relative_au(body,day),world.position_au(id,day),world.local_meters(id,day),Link.spin(body,day)])
		var centre:Vector3=world.local_meters(world.focus_id,day)
		var gravity:Array=[]
		for offset in [Vector3(123456,345678,567890),Vector3(-3e7,2e7,1e7),Vector3(2e9,-1e9,3e9)]:gravity.append(world.gravity_at(centre+offset,day))
		dates.append({"day":day,"positions_sha256":digest(positions),"gravity_sha256":digest(gravity)})
	return {"system_id":world.system_id,"body_count":world.bodies.size(),"site_count":world.settlements.size(),"layout":world.layout_mode,"source_digest":world.source_digest,"bodies_sha256":digest(body_data),"sites_sha256":digest(site_data),"city_profiles_sha256":digest(profiles),"surface_frames_sha256":digest(frames),"snapshot_sha256":digest(world.snapshot()),"dates":dates}
func capture_baseline()->void:
	if FileAccess.get_sha256("res://scripts/planetary_system.gd")!=ORIGINAL_WORLD_SHA:
		push_error("Baseline capture requires immutable published0.11.8 world source");quit(1);return
	var galaxy:=Galaxy.new();var worlds:Array=[]
	for entry:Dictionary in catalogue():
		var world:=World.new();world.configure(galaxy.get_system(int(entry.system_id)))
		worlds.append(physics_snapshot(world))
	var report:={"baseline_commit":BASELINE_COMMIT,"engine":Engine.get_version_info().string,"world_source_sha256":ORIGINAL_WORLD_SHA,"scope":"Current analytic source-world records, positions, gravity, city profiles, shared spin/surface frames and saves; no native ephemeris claim","worlds":worlds}
	var path:="/workspace/recovery/source-world-bridge-0118.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SOURCE WORLD BASELINE CAPTURED: independent published0.11.8 source");quit()
func frozen_physics()->void:
	var expected:Dictionary=JSON.parse_string(BASELINE_JSON)
	var galaxy:=Galaxy.new();var entries:=catalogue()
	check(expected.get("baseline_commit")==BASELINE_COMMIT and expected.get("worlds",[]).size()==11,"Independent published0.11.8 baseline contains eleven original mapped worlds")
	check(entries.size()==11,"The runtime bridge does not invent procedural catalogue entries")
	for row:Dictionary in expected.get("worlds",[]):
		var world:=World.new();world.configure(galaxy.get_system(int(row.system_id)))
		var actual:=physics_snapshot(world)
		for key in ["body_count","site_count","layout","source_digest","bodies_sha256","sites_sha256","city_profiles_sha256","surface_frames_sha256","snapshot_sha256"]:
			check(actual[key]==row[key],"World%d preserves independent old %s"%[int(row.system_id),key])
		for index in range(DATES.size()):
			check(actual.dates[index]==row.dates[index],"World%d position/gravity/spin state is unchanged atday%s"%[int(row.system_id),str(DATES[index])])
func decode_records(encoded:Array)->Array:
	var records:Array=[]
	for value in encoded:records.append(str(value).hex_decode())
	return records
func native_fixture()->Dictionary:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/handcrafted_runtime_native.json"))
	return parsed if parsed is Dictionary else {}
func native_builder_controls(fixture:Dictionary)->void:
	var builder:Script=load("res://scripts/handcrafted_runtime_builder.gd")
	check(builder!=null,"Source F878 runtime builder is available")
	if builder==null:return
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.get("mapped_systems")==11,"Native oracle belongs to the uploaded original and the eleven mapped source windows")
	check(int(fixture.get("fresh_process_runs",0))==3 and fixture.get("fresh_process_outputs_identical",false),"Native controls repeat in three original-procedure processes")
	for row:Dictionary in fixture.get("cases",[]):
		var templates:=decode_records(row.templates_hex);var destination:=decode_records(row.destination_hex)
		var counts:Dictionary=row.initial_counts.duplicate(true)
		var before:=digest([templates,destination,counts])
		var result:Dictionary=builder.build(templates,destination,counts)
		check(result.get("ok",false),"Native source suffix input is accepted: "+str(row.name))
		if not result.get("ok",false):continue
		check(result.records==decode_records(row.expected.records_hex),"All sixty records including unwritten bytes and partial sentinel match real F878: "+str(row.name))
		for key in ["count","next_index","body_count_byte","port_count_byte","orbital_port_count_byte"]:
			check(result[key]==int(row.expected[key]),"Source suffix state %s matches original: %s"%[key,str(row.name)])
		check(digest([templates,destination,counts])==before,"Source suffix leaves caller records and counters unchanged: "+str(row.name))
	var example:Dictionary={}
	for row:Dictionary in fixture.get("cases",[]):
		if row.has("system_id") and not row.templates_hex.is_empty():example=row;break
	if example.is_empty():check(false,"A real source window exists for invalid-input guards");return
	var templates:=decode_records(example.templates_hex);var destination:=decode_records(example.destination_hex)
	var stable:=digest([templates,destination])
	var too_many:Array=[]
	for index in range(60):too_many.append(templates[0].duplicate())
	check(builder.build(too_many,destination).is_empty(),"Sixty active records are rejected before the original unguarded sentinel could overflow")
	var bad:Array=templates.duplicate(true);bad[0]=PackedByteArray([0,1])
	check(builder.build(bad,destination).is_empty(),"Short input record is rejected atomically")
	bad=templates.duplicate(true);bad[0].encode_u32(0,0)
	check(builder.build(bad,destination).is_empty(),"An active source template cannot contain the zero-mass terminator")
	bad=templates.duplicate(true);bad[0].encode_u16(8,1)
	check(builder.build(bad,destination).is_empty(),"Forward/self parent is rejected before reading an unbuilt source record")
	bad=templates.duplicate(true)
	for offset in range(38,62):bad[0][offset]=65
	check(builder.build(bad,destination).is_empty(),"Unterminated source name cannot overwrite another record")
	var short_destination:Array=destination.duplicate(true);short_destination.pop_back()
	check(builder.build(templates,short_destination).is_empty(),"Short destination cannot hold the complete native record bank")
	for value in [-1,256,0.5,NAN]:
		check(builder.build(templates,destination,{"body_count_byte":value}).is_empty(),"Invalid byte counter cannot enter native suffix conversion")
	check(digest([templates,destination])==stable,"All rejected builder calls retain original caller buffers")
func mapped_native_rows(fixture:Dictionary)->Dictionary:
	var result:Dictionary={}
	for row:Dictionary in fixture.get("cases",[]):
		if row.has("system_id") and str(row.name).ends_with(" / zero destination"):
			result[int(row.system_id)]=row
	return result
func runtime_metadata(fixture:Dictionary)->void:
	var rows:=mapped_native_rows(fixture);var galaxy:=Galaxy.new();var total:=0
	check(rows.size()==11,"Eleven native zero-initialized windows are independent runtime bridge controls")
	var worlds_before:=FileAccess.get_sha256("res://data/ffe_worlds.json")
	var templates_before:=FileAccess.get_sha256("res://data/ffe_handcrafted_records.json")
	for entry:Dictionary in catalogue():
		var id:=int(entry.system_id)
		if not rows.has(id):check(false,"Mapped source world has native output "+str(id));continue
		var native:Dictionary=rows[id];var world:=World.new();world.configure(galaxy.get_system(id))
		var state:Dictionary=world.source_runtime_state
		check(state.get("source")=="ffe_f878_handcrafted_suffix" and state.get("record_domain")=="packed_runtime_records" and state.get("physical_layout_changed")==false,"Source runtime summary distinguishes packed native records from live SI physics")
		for key in ["count","body_count_byte","port_count_byte","orbital_port_count_byte"]:
			check(state.get(key,-1)==int(native.expected[key]),"World%d source runtime %s matches native"%[id,key])
		var native_records:=decode_records(native.expected.records_hex)
		check(state.get("records_sha256")==var_to_bytes(native_records).hex_encode().sha256_text(),"World%d complete packed record bank matches original suffix"%id)
		var live_rows:Array=world.bodies.duplicate();live_rows.append_array(world.settlements)
		for row:Dictionary in live_rows:
			var local_index:=int(row.original_index)-1
			var packed:String=native.expected.records_hex[local_index]
			check(row.get("runtime_record_hex","")==packed and row.get("runtime_record_source")=="ffe_f878_handcrafted_suffix" and row.get("runtime_record_domain")=="packed_runtime_records","Mapped object has exact independent original packed runtime bytes")
			check(row.get("source_record_domain")=="constructor_template" and str(row.record_hex)==str(native.templates_hex[local_index]),"Original F873/F874 template remains a separate unchanged record domain")
			var decoded:=packed.hex_decode()
			check(int(decoded.decode_u32(4))==int(row.source_seed) and int(decoded.decode_u16(12))==int(row.model_index),"Runtime bridge preserves native UID and source model")
			total+=1
		var saved:Dictionary=JSON.parse_string(JSON.stringify(world.snapshot()))
		world.source_runtime_state={"stale":true}
		check(world.restore(saved) and world.source_runtime_state==state,"Successful save restore rebuilds source runtime metadata without persisting duplicate native banks")
		var stable:=digest([world.snapshot(),world.source_runtime_state]);var invalid:Dictionary=saved.duplicate(true);invalid.source_digest="wrong"
		check(not world.restore(invalid) and digest([world.snapshot(),world.source_runtime_state])==stable,"Rejected saved world does not partially replace native runtime metadata")
	check(total==130,"All130 mapped source objects receive packed records; three unmatched Riedquat controls are not added to the live catalogue")
	var world:=World.new();world.configure(galaxy.get_system(Galaxy.SOL_ID))
	var legacy:=World.new();legacy.configure(galaxy.get_system(Galaxy.SOL_ID),World.SOLAR_LAYOUT)
	var legacy_save:Dictionary=JSON.parse_string(JSON.stringify(legacy.snapshot()))
	check(world.restore(legacy_save) and world.layout_mode==World.SOLAR_LAYOUT and world.source_runtime_state.is_empty(),"Restoring a previous Solar-adapter save clears source-only packed metadata")
	check(FileAccess.get_sha256("res://data/ffe_worlds.json")==worlds_before and FileAccess.get_sha256("res://data/ffe_handcrafted_records.json")==templates_before,"Runtime bridge never rewrites original source data files")
func remove_private(path:String)->void:
	if private_directory.is_empty() or not (path==private_directory or path.begins_with(private_directory+"/")):return
	if not DirAccess.dir_exists_absolute(path):return
	for name in DirAccess.get_directories_at(path):remove_private(path+"/"+name)
	for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path+"/"+name)
	DirAccess.remove_absolute(path)
func actual_main()->void:
	var game:Node3D=load("res://scenes/main.tscn").instantiate();var settings:=MemorySettings.new();settings.quality=0;game.settings=settings
	root.add_child(game);game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled,"Actual Main starts without reading or writing the user's progress")
	check(not game.world.source_runtime_state.is_empty() and game.world.by_id.earth.has("runtime_record_hex"),"Actual default flight owns original packed world records")
	var examples:=[{ "days":0.0,"label":"12:00:00 1-янв-3250"},{"days":0.5,"label":"00:00:00 2-янв-3250"},{"days":1.5,"label":"00:00:00 3-янв-3250"},{"days":0.5-1.0/4294967296.0,"label":"24:00:00 1-янв-3250"}]
	for example:Dictionary in examples:
		game.nav.elapsed_days=float(example.days);var before:=digest(game._payload());game._refresh_hud()
		check(game.flight_console.labels.clock.text==str(example.label),"Actual classic console shows independently known FFE calendar/time "+str(example.label))
		check(digest(game._payload())==before,"Source clock presentation cannot advance or mutate actual flight/navigation/save state")
	game.nav.elapsed_days=1.5;game._refresh_hud()
	private_directory="user://source-world-bridge-%d"%OS.get_process_id();game.saves.directory=private_directory
	var payload:Dictionary=game._payload();var before:Dictionary=JSON.parse_string(JSON.stringify(payload));var records_before:=digest(game.world.source_runtime_state)
	check(str(payload.schema)=="starfrontier-rebuild-game-v1" and not JSON.stringify(payload).contains("runtime_record_hex"),"Existing save schema stores elapsed progress instead of duplicating derived native records")
	game.saving_enabled=true
	check(game._save_game(),"Current native-record flight writes only the private test save")
	game.saving_enabled=false
	var loaded:Dictionary=game.saves.load_valid(game._decode_state)
	check(not loaded.is_empty(),"Existing complete save decoder rebuilds current source runtime metadata")
	if not loaded.is_empty():
		game._commit_state(loaded);game._apply_system();game._refresh_hud()
		check(JSON.parse_string(JSON.stringify(game._payload()))==before and digest(game.world.source_runtime_state)==records_before,"Save/load preserves JSON-equivalent existing flight values while rebuilding native packed world data")
		check(game.flight_console.labels.clock.text=="00:00:00 3-янв-3250","Loaded elapsed progress returns the same original calendar label")
	check(not game.saving_enabled,"Native clock/save test leaves original persistence disabled")
	game.queue_free();await process_frame;remove_private(private_directory)
	check(not DirAccess.dir_exists_absolute(private_directory),"All private source-world save fixtures are cleaned")
func run()->void:
	if "--source-world-baseline-capture" in OS.get_cmdline_user_args():capture_baseline();return
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs --rebuild-capture to isolate user progress");quit(1);return
	frozen_physics()
	var fixture:=native_fixture();native_builder_controls(fixture);runtime_metadata(fixture)
	await actual_main()
	print("SOURCE WORLD BRIDGE TESTS: %d checks, %d failures; independent F878 native records and published-world physics, actual Main/save/clock"%[checks,failures])
	quit(1 if failures else 0)
