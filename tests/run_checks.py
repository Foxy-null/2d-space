"""Run Godot checks in a copied project with disposable user data."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--smoke', action='store_true')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('checks', nargs='*')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    for check in args.checks:
        relative = check.removeprefix('res://') if check.startswith('res://') else 'tests/' + check
        if not (source / relative).is_file():
            parser.error('Check does not exist: ' + relative)
    output = source / 'deliverables' / 'tutorial-validation'
    output.mkdir(parents=True, exist_ok=True)
    failed = False
    with tempfile.TemporaryDirectory(prefix='codex-2d-space-') as temporary:
        project = Path(temporary).resolve()
        assert project.parent == Path(tempfile.gettempdir()).resolve()
        for folder in ('assets', 'scripts', 'scenes', 'tests'):
            shutil.copytree(source / folder, project / folder)
        reference = Path('docs/stage-2-redesign/layout-reference.png')
        (project / reference).parent.mkdir(parents=True)
        shutil.copy2(source / reference, project / reference)
        original = (source / 'project.godot').read_text(encoding='utf-8')
        original = re.sub(r'config/name="[^"]*"', 'config/name="Codex 2D Space Validation"', original, count=1)
        run_id = uuid.uuid4().hex
        def configure(suffix):
            directory = 'codex-2d-space-tests/' + run_id + '-' + suffix
            config = original.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory + '"', 1)
            (project / 'project.godot').write_text(config, encoding='utf-8')
            return directory

        def run(label, arguments, render=False):
            nonlocal failed
            directory = configure(label)
            command = [args.godot, '--path', str(project), '--fixed-fps', '60']
            command += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--resolution', '1280x720'] if render else ['--headless']
            command += arguments
            startup = None
            if os.name == 'nt' and render:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = 0
            try:
                result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8', errors='replace', timeout=args.timeout, startupinfo=startup)
                log = result.stdout
                bad = result.returncode != 0 or 'SCRIPT ERROR:' in log or 'FAILED' in log
            except subprocess.TimeoutExpired as error:
                log = (error.stdout or b'').decode('utf-8', errors='replace') if isinstance(error.stdout, bytes) else (error.stdout or '')
                log += '\nTIMEOUT\n'
                bad = True
            (output / (label + '.log')).write_text(log, encoding='utf-8')
            lines = [line for line in log.splitlines() if line.strip()]
            print(('FAIL ' if bad else 'PASS ') + label, flush=True)
            print('\n'.join(lines[-50:] if bad else [line for line in lines if 'TEST_' in line or 'tests:' in line or 'checks)' in line][-3:]), flush=True)
            failed |= bad
            if os.name == 'nt':
                user_path = Path(os.environ['APPDATA']) / directory
                expected_parent = (Path(os.environ['APPDATA']) / 'codex-2d-space-tests').resolve()
                if user_path.exists():
                    assert user_path.resolve().parent == expected_parent
                    shutil.rmtree(user_path)

        run('import', ['--editor', '--import'])
        if not failed:
            if args.smoke:
                for scene in ('start_screen', 'stage_select', 'tutorial', 'stage_2', 'stage_3', 'stage_4', 'stage_5', 'stage_6', 'gallery'):
                    run('smoke-' + scene, ['--scene', 'res://scenes/' + scene + '.tscn', '--quit-after', '6'])
            for check in args.checks:
                path = check if check.startswith('res://') else 'res://tests/' + check
                arguments = ['--script', path]
                if Path(check).stem == 'game_audio_test':
                    arguments += ['--scene', 'res://scenes/start_screen.tscn']
                run(Path(check).stem, arguments)
            if args.render:
                run('render', ['--script', 'res://tests/tutorial_redesign_test.gd', '--', '--capture', str(output)], render=True)
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
