#!/usr/bin/env python3
"""Inventory the pinned JJFFE source; references are not proof of a full port.

This is a static audit, not execution of the original game. It deliberately
does not turn source mentions, fixture hashes or test counts into a percentage
of game completion. Runtime integration is assessed in the accompanying docs.
"""
import argparse
import bisect
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path
import re

ASM_SHA = 'd4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DEFINITION = re.compile(r'^(FUNC_(\d{6})(?:_\w+)?)\s*:', re.M)
REFERENCE = re.compile(r'FUNC_(\d{6})')
DIRECT = re.compile(r'^\s*(?:call|jmp)\s+(?:(?:near|short|far|dword)\s+)*FUNC_(\d{6})(?:_\w+)?(?!\w)', re.M | re.I)
MENTION = re.compile(r'(?<![A-Za-z0-9])F(\d{1,4})(?!\d)|FUNC_(\d{6})')
HASH_MAPS = ('source_procedure_hashes', 'source_procedure_sha256',
             'source_function_sha256', 'source_function_hashes',
             'pinned_procedure_hashes', 'procedures_sha256')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, default=Path('validation/parity-audit-2026-11-07'))
    args = parser.parse_args()
    raw = args.source.read_bytes()
    if sha(raw) != ASM_SHA:
        raise SystemExit('Unrecognised assembly revision; choose and document the reference before auditing')
    text = raw.decode('utf-8').replace('\r\n', '\n')
    starts = [0] + [match.end() for match in re.finditer('\n', text)]
    definitions = list(DEFINITION.finditer(text))
    ids = {int(match[2]) for match in definitions}
    if len(ids) != len(definitions):
        raise SystemExit('Duplicate function IDs need explicit handling')
    mentions = {identifier: [] for identifier in ids}
    runtime = []
    for folder in ('scripts', 'scenes', 'data'):
        for path in sorted((args.project/folder).rglob('*')):
            if not path.is_file():
                continue
            relative = str(path.relative_to(args.project))
            runtime.append({'path': relative, 'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes())})
            if path.suffix not in ('.gd', '.gdshader'):
                continue
            for number, line in enumerate(path.read_text().splitlines(), 1):
                for match in MENTION.finditer(line):
                    identifier = int(match[1] or match[2])
                    if identifier in ids:
                        mentions[identifier].append({'path': relative, 'line': number,
                            'kind': 'source_mention_only_not_parity_proof'})
    fixture_references = {identifier: [] for identifier in ids}
    fixtures = []
    for path in sorted((args.project/'tests/fixtures').glob('*.json')):
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            continue
        found = False
        for field in HASH_MAPS:
            mapping = data.get(field)
            if not isinstance(mapping, dict):
                continue
            for key, digest in mapping.items():
                match = re.fullmatch(r'(?:F|FUNC_)?0*(\d+)', str(key))
                if not match or int(match[1]) not in ids or not isinstance(digest, str):
                    continue
                if not re.fullmatch('[0-9a-f]{64}', digest):
                    continue
                found = True
                fixture_references[int(match[1])].append({'path': str(path.relative_to(args.project)),
                    'field': field, 'declared_sha256': digest,
                    'kind': 'fixture_declares_source_reference_not_live_integration'})
        if found:
            fixtures.append({'path': str(path.relative_to(args.project)), 'sha256': sha(path.read_bytes()),
                'case_count_declared': data.get('case_count'),
                'scope': data.get('scope'), 'executed_during_this_static_audit': False})
    functions = []
    for index, match in enumerate(definitions):
        end = definitions[index+1].start() if index+1 < len(definitions) else len(text)
        block = text[match.start():end]
        identifier = int(match[2])
        calls = sorted({int(m[1]) for m in DIRECT.finditer(block)})
        references = sorted({int(m[1]) for m in REFERENCE.finditer(block)} - {identifier})
        lines = block.splitlines()
        functions.append({'id': identifier, 'label': match[1],
            'source_line': bisect.bisect_right(starts, match.start()),
            'source_end_line': bisect.bisect_right(starts, max(match.start(), end-1)),
            'block_lines': len(lines), 'normalised_lf_block_sha256': sha(block.encode()),
            'direct_call_or_jump_ids': calls,
            'other_function_reference_ids': references,
            'comment_lines_containing_fix': [line.strip() for line in lines if re.search(r';.*\bFIX(?:ED)?\b', line, re.I)],
            'current_runtime_source_mentions': mentions[identifier],
            'fixture_reference_declarations': fixture_references[identifier],
            'semantic_parity_status': 'not_automatically_assessed',
            'live_port_completeness': 'requires_individual_contract_and_integration_review'})
    exports = {int(m[1]) for m in re.finditer(r'^GLOBAL\s+FUNC_(\d{6})', text, re.M)}
    upstream_files = []
    data_blocks = []
    extensions = {'.asm','.c','.cpp','.h','.txt','.cfg','.mak','.dsp','.dsw'}
    for path in sorted(args.source.parent.rglob('*')):
        if not path.is_file() or '.git' in path.parts or path.suffix not in extensions:
            continue
        payload = path.read_bytes()
        upstream_files.append({'path':str(path.relative_to(args.source.parent)),
            'bytes':len(payload),'sha256':sha(payload)})
        if path.suffix == '.asm':
            for number, line in enumerate(payload.decode('utf-8', errors='replace').splitlines(), 1):
                match = re.match(r'^(DATA_\d{6}[^\s:]*)\s*:', line)
                if match:
                    data_blocks.append({'file':str(path.relative_to(args.source.parent)),
                        'label':match[1],'source_line':number,
                        'declaration_line_sha256':sha(line.encode())})
    report = {'schema': 1, 'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'scope': 'Complete static inventory of labelled FUNC definitions in this one pinned ffe.asm plus current runtime source mentions and declared native-fixture references. Not an inventory of every possible routine in the DOS executable, not full instruction semantics, not original-vs-JJFFE binary equivalence and not a game completion percentage.',
        'reference_source': {'path': str(args.source), 'raw_bytes': len(raw), 'sha256': sha(raw),
            'normalised_source_lines': len(text.splitlines()),
            'jjffe_commit': '7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
            'jjffe_is_identical_to_user_dos_executable': False,
            'known_fix_comments_require_separate_binary_patch_review': True},
        'function_count': len(functions), 'global_function_ids_without_definition_in_this_file': sorted(exports-ids),
        'functions_with_runtime_mentions': sum(bool(row['current_runtime_source_mentions']) for row in functions),
        'functions_with_fixture_references': sum(bool(row['fixture_reference_declarations']) for row in functions),
        'functions_with_fix_comments': sum(bool(row['comment_lines_containing_fix']) for row in functions),
        'mentions_and_fixtures_are_not_full_port_counts': True,
        'semantic_review_documents': ['docs/PARITY_AUDIT_RU.md',
            'docs/PARITY_AUDIT_SYSTEM_INFO_RU.md','docs/PARITY_AUDIT_PHYSICS_RU.md',
            'docs/PARITY_AUDIT_SHIPS_ECONOMY_COMBAT_RU.md',
            'docs/PARITY_AUDIT_CAMPAIGN_CONTENT_RU.md',
            'docs/PARITY_AUDIT_RESOURCES_GRAPHICS_RU.md'],
        'upstream_file_inventory': upstream_files,
        'runtime_inputs': runtime, 'fixture_reference_inputs': fixtures, 'functions': functions}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'original-function-catalog.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    (args.output/'original-data-block-catalog.json').write_text(json.dumps({
        'scope':'Static labelled DATA declarations from all assembly files in the pinned JJFFE source tree. A declaration, extraction or hash does not prove live game integration or byte equality with the user DOS executable.',
        'upstream_file_inventory':upstream_files,'labelled_data_declarations':len(data_blocks),
        'blocks':data_blocks},ensure_ascii=False,indent=2)+'\n')
    with (args.output/'original-function-catalog.csv').open('w', newline='') as output:
        writer = csv.writer(output)
        writer.writerow(['id','label','source_line','block_lines','runtime_mentions','fixture_references','status'])
        for row in functions:
            writer.writerow([row['id'],row['label'],row['source_line'],row['block_lines'],
                len(row['current_runtime_source_mentions']),len(row['fixture_reference_declarations']),row['semantic_parity_status']])
    print(json.dumps({key:report[key] for key in ('function_count','functions_with_runtime_mentions',
        'functions_with_fixture_references','functions_with_fix_comments','mentions_and_fixtures_are_not_full_port_counts')}, indent=2))


if __name__ == '__main__':
    main()
