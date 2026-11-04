#!/usr/bin/env python3
"""Compare preserved terrain modules with regenerated independent native controls.

Runs a disposable Godot project: this deliberately does not install the recovered
terrain modules into the Android game or assign metres/geography to raw frames.
"""
from __future__ import annotations
import argparse,json,os,shutil,subprocess,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
HARNESS=r'''extends SceneTree
const Query=preload("res://scripts/terrain_query.gd")
const Point=preload("res://scripts/terrain_surface_point.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12:push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
	var kernel:=Query.new()
	var point_query:=Point.new()
	var empty:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_query_reference.json"))
	check(empty.cases.size()==336,"Independent native raw fixture has 336 cases")
	for index in range(empty.cases.size()):
		var row:Dictionary=empty.cases[index]
		var actual:Dictionary=kernel.query_raw(int(row.seed),int(row.style),Query._vector(row.matrix_raw),Query._vector(row.center_raw),int(row.query_limit_raw),int(row.graphics_level_raw),PackedByteArray())
		check(not actual.is_empty(),"Raw query executes %d"%index)
		for key in row.result:
			check(actual.get(key)==int(row.result[key]),"Raw native case %d field %s: expected %s got %s"%[index,key,str(row.result[key]),str(actual.get(key))])
	for fixture_name in ["terrain_game_query_reference.json","rebuild_terrain_all_models_reference.json"]:
		var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture_name))
		check(fixture.cases.size()==(510 if fixture_name.begins_with("rebuild_") else 120),"Independent native F581 fixture count")
		for index in range(fixture.cases.size()):
			var row:Dictionary=fixture.cases[index]
			var expected:Dictionary=row.result
			var observer:=Query._vector(row.observer_model_local_raw)
			var before:=observer.duplicate()
			var actual:Dictionary=point_query.query_point_raw(int(row.model_index),int(row.seed),observer,int(row.vector_scale))
			check(not actual.is_empty(),"F581 point executes model %d case %d"%[row.model_index,index])
			check(observer==before,"Observer input remains unchanged")
			check(actual.get("query_matrix_raw")==Query._vector(expected.query_matrix_raw),"Native matrix model %d case %d"%[row.model_index,index])
			check(actual.get("query_center_raw")==Query._vector(expected.query_center_raw),"Native center model %d case %d"%[row.model_index,index])
			for key in ["query_style_raw","query_limit_raw","collision_status","recorded_intersection_raw","pending_query_flag","terrain_query_calls","altitude_raw_i64"]:
				check(actual.get(key)==int(expected[key]),"F581 native model %d case %d field %s: expected %s got %s"%[row.model_index,index,key,str(expected[key]),str(actual.get(key))])
	print("REBUILT TERRAIN NATIVE CONTROLS: %d checks, %d failures; 336 raw and 630 F581 caller cases"%[checks,failures])
	quit(1 if failures else 0)
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    scripts=PROJECT/'recovered-history/source_terrain_revision/scripts'
    fixtures=['terrain_query_reference.json','terrain_game_query_reference.json','rebuild_terrain_all_models_reference.json']
    for name in fixtures:
        data=json.loads((PROJECT/'tests/fixtures'/name).read_text())
        if data['source_sha256']!='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72':
            raise SystemExit('Unsupported original native fixture: '+name)
    with tempfile.TemporaryDirectory(prefix='ffe-terrain-validation-') as directory:
        work=Path(directory)
        for child in ['scripts','data','tests/fixtures']:(work/child).mkdir(parents=True)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="FFE terrain research validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in ['terrain_query.gd','terrain_surface_point.gd','terrain_math.gd']:
            shutil.copyfile(scripts/name,work/'scripts'/name)
        shutil.copyfile(scripts/'ground_coordinates.gd',work/'scripts/ground_coordinates.gd')
        shutil.copyfile(PROJECT/'scripts/ffe_math.gd',work/'scripts/ffe_math.gd')
        for name in ['ffe_math.json','ffe_ground_coordinates.json','ffe_terrain_query.json']:
            shutil.copyfile(PROJECT/'data'/name,work/'data'/name)
        for name in fixtures:shutil.copyfile(PROJECT/'tests/fixtures'/name,work/'tests/fixtures'/name)
        (work/'tests/native_controls.gd').write_text(HARNESS)
        environment=dict(os.environ,XDG_DATA_HOME=str(work/'userdata'),XDG_CACHE_HOME=str(work/'cache'),XDG_CONFIG_HOME=str(work/'config'))
        result=subprocess.run([args.godot,'--headless','--path',str(work),'--script','res://tests/native_controls.gd'],env=environment,timeout=240)
        raise SystemExit(result.returncode)

if __name__=='__main__':main()
