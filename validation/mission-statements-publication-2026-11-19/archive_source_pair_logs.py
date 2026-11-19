import hashlib,json,shutil
from pathlib import Path
r=Path('/workspace/Pyton');out=r/'deliverables/mission-statements-core-0.32.0-2026-11-19';dest=r/'validation/mission-statements-source-pair-2026-11-19'
d=json.loads((out/'source-pair-verification.json').read_text());assert d['ok']and d['status']=='verified'
assert len(d['features'])==d['unique_feature_scripts_separate']
assert len(d['native_reproductions'])==d['native_generator_count']
assert len(d['resource_reproductions'])==d['resource_replay_count']
rows=[d['import'],d['startup'],*d['features'],*d['native_reproductions'],*d['resource_reproductions']]
assert len(rows)==d['unique_feature_scripts_separate']+d['native_generator_count']+d['resource_replay_count']+2
assert len({row['log_file']for row in rows})==len(rows)
dest.mkdir(exist_ok=False)
for row in rows:
    p=out/row['log_file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['log_sha256'];shutil.move(p,dest/p.name)
shutil.copyfile(out/'source-pair-verification.json',dest/'verification.json')
(dest/'README.md').write_text(f'''# Fresh mission statements source-pair verification

Sealed source commit: {d['source_commit']}.
The exact full0.28 base plus cumulative0.32 update reconstructed all
{d['source_actual_files']} source files. Startup: {d['startup_checks']}/0.
All {d['unique_feature_scripts_separate']} suites: {d['unique_feature_checks_separate']}/0.
All {d['native_generator_count']} native commands reproduced pinned fixtures
without private original inputs. Main DOS cases: {d['native_DOS_control_cases_separate']};
separate JJFFE diagnostics: {d['native_JJFFE_copy_diagnostics_separate']};
separate compositions: {d['supplemental_native_composition_cases_separate']}.
All {d['resource_replay_count']} resource replays are counted separately from
native arithmetic. This directory contains {len(rows)} fresh command logs.

All source files stayed unchanged; {d['runtime_inputs_verified']} runtime inputs
match freeze. Only BuildInfo/export version metadata changes among585 previous
runtime inputs. All583 other previous and473 published game inputs stay exact.
The log_file basenames in verification.json refer to this directory.
Private saves/caches, executables and original EXE/ASM inputs are excluded.

This repeats validation without adding functional checks. The source-pair proof
does not build an APK. A separate Android proof records the later build, actual
embedded metadata and independent compiled-script reproduction. New kernels
remain outside Main; remaining formatter/world provider bodies
and physical S23 Ultra/FPS are not claimed.
''')
print('Archived',len(rows),'fresh logs and verification.json')
