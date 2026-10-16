#!/usr/bin/env python3
"""Build the two frozen Godot UI candidates in isolated copies; optionally serve."""
from __future__ import annotations

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
STUDY = ROOT / 'demos' / 'settings-comparison'
VARIANTS = ('without-skill', 'with-skill')


def run(command, cwd, log):
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=cwd, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=180, check=False)
    text = log.read_text(errors='replace')
    if result.returncode or 'SCRIPT ERROR:' in text or 'Parse Error:' in text:
        raise SystemExit('Godot build failed; inspect the local log: ' + str(log))


def prepare_engine(binary, templates, destination):
    version = subprocess.check_output([str(binary), '--headless', '--version'], text=True).strip()
    if not version.startswith('4.6.3.stable'):
        raise SystemExit('The published comparison is frozen to Godot 4.6.3.stable.')
    bundle = next((p for p in binary.parents if p.suffix == '.app'), None)
    if bundle:
        shutil.copytree(bundle, destination / bundle.name)
        isolated = destination / bundle.name / binary.relative_to(bundle)
    else:
        destination.mkdir()
        isolated = destination / binary.name
        shutil.copy2(binary, isolated)
    (destination / '_sc_').touch()
    target = destination / 'editor_data' / 'export_templates' / '4.6.3.stable'
    target.mkdir(parents=True)
    for name in ('web_nothreads_release.zip', 'web_nothreads_debug.zip'):
        source = templates / name
        if not source.is_file():
            raise SystemExit('Supply the directory containing both official non-threaded Web template ZIPs.')
        shutil.copy2(source, target / name)
    return isolated, version


def preset():
    return '''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="*.md"
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
'''


def build(binary, templates, output, probe=False, study=STUDY):
    if output == ROOT or ROOT in output.parents:
        raise SystemExit('Build output must be outside the skill Git checkout.')
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Use a new or empty output directory.')
    output.mkdir(parents=True, exist_ok=True)
    logs = output / 'logs'
    logs.mkdir()
    with tempfile.TemporaryDirectory(prefix='godot-ui-comparison-build-') as temporary:
        work = Path(temporary)
        engine, version = prepare_engine(binary, templates, work / 'engine')
        for variant in VARIANTS:
            project = work / variant
            shutil.copytree(study / 'shared', project)
            shutil.copytree(study / variant, project, dirs_exist_ok=True)
            settings = project / 'project.godot'
            text = settings.read_text().replace('isolated-20261016', 'isolated-' + work.name + '-' + variant)
            if probe:
                shutil.copy2(study / 'harness' / 'probe.gd', project / 'probe.gd')
                text += '\n[autoload]\nStudyProbe="*res://probe.gd"\n'
            settings.write_text(text)
            (project / 'export_presets.cfg').write_text(preset())
            exported = output / variant
            exported.mkdir()
            run([str(engine), '--headless', '--audio-driver', 'Dummy', '--log-file', str(logs / (variant + '-import.godot.log')), '--path', str(project), '--editor', '--import', '--quit'],
                project, logs / (variant + '-import.txt'))
            run([str(engine), '--headless', '--audio-driver', 'Dummy', '--log-file', str(logs / (variant + '-export.godot.log')), '--path', str(project), '--export-release', 'Web',
                 str(exported / 'index.html')], project, logs / (variant + '-export.txt'))
    (output / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Godot UI Fidelity comparison</title>
<style>body{margin:0;background:#10272c;color:#f6eddd;font:15px system-ui}header{height:52px;display:flex;gap:16px;align-items:center;padding:0 18px;box-sizing:border-box}label{margin-left:auto}select{font:inherit;padding:6px;background:#f6eddd;color:#10272c;border:0;border-radius:6px}iframe{display:block;border:0;width:100%;height:calc(100dvh - 52px)}</style>
<header><b>Godot UI Fidelity</b><label>Candidate <select id="candidate"><option value="without-skill">Without skill</option><option value="with-skill">With skill</option></select></label></header>
<iframe id="demo" title="Actual Godot Web implementation" src="without-skill/index.html"></iframe>
<script>document.getElementById('candidate').addEventListener('change',e=>{document.getElementById('demo').src=e.target.value+'/index.html';});</script></html>''')
    (output / 'build-info.json').write_text(json.dumps({'godot': version, 'variants': list(VARIANTS),
                                                      'read_only_probe': probe}, indent=2))
    print('Built both frozen candidates in isolated copies: ' + str(output))


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *_args):
        pass

    def list_directory(self, _path):
        self.send_error(404)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--templates', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--probe', action='store_true', help='add the read-only DOM evidence probe')
    parser.add_argument('--serve', action='store_true')
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--demo', choices=('settings-comparison', 'battle-comparison'),
                        default='settings-comparison')
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error('Port must be in 0..65535.')
    binary = args.godot.expanduser().resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        parser.error('--godot must be an executable.')
    output = args.output.expanduser().resolve()
    build(binary, args.templates.expanduser().resolve(), output, args.probe,
          ROOT / 'demos' / args.demo)
    if args.serve:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), functools.partial(Handler, directory=str(output)))
        print('Local demo: ' + 'http://' + str(server.server_address[0]) + ':' + str(server.server_port) + '/index.html', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()


if __name__ == '__main__':
    main()
