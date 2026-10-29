#!/usr/bin/env python3
"""Compile and test real searches, expressions, diagrams and DB rebuilds."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile, xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
compiler = os.environ.get('CXX') or shutil.which('clang++') or shutil.which('g++')
if not compiler:
    raise SystemExit('C++ compiler required')
with tempfile.TemporaryDirectory() as tmp:
    exe = str(Path(tmp)/'regression')
    sources = [str(p) for p in (root/'Engine').glob('*.cpp')]
    subprocess.run([compiler, '-std=c++17', '-O2', '-pthread', '-I', str(root/'Engine'),
                    *sources, str(root/'Tests/regression.cpp'), '-o', exe], check=True)
    result = subprocess.run([exe], check=True, capture_output=True, text=True, timeout=60)
    cases = {name: json.loads(data) for name,data in (line.split('\t',1) for line in result.stdout.splitlines())}
    failures = {'same_point','outside','zero_divide','sqrt_negative','set_rejected','unknown','invalid_rank','invalid_paper'}
    for name, response in cases.items():
        if name in failures:
            assert response.get('error'), (name, response)
        else:
            assert not response.get('error'), (name, response)
            assert 0 < len(response['solutions']) <= 5, name
            for solution in response['solutions']:
                assert solution['error'] >= 0, name
                assert solution['rank'] <= (2 if name=='rank2' else 3 if name=='rank3' else 4), name
                for step in solution['steps']:
                    svg = ET.fromstring(step['svg'])
                    assert svg.tag.endswith('svg') and len(list(svg)) > 0, name
                    assert 'nan' not in step['svg'].lower() and 'inf' not in step['svg'].lower(), name
        print('PASS', name)
    for name in ['thirds','edge_third','line','corner']:
        assert min(x['error'] for x in cases[name]['solutions']) < 1e-8, name
    assert cases['rebuild4']['marks'] == cases['thirds']['marks']
    print(f'{len(cases)} search cases passed; exact constructions and SVG validated.')
