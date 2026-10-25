#!/usr/bin/env python3
"""Isolated offscreen file-watcher/animation regression. Never targets production IPC."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HOST = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy'))
QS = os.environ.get('QUICKSHELL_BIN', '/usr/bin/quickshell')


def main():
    with tempfile.TemporaryDirectory(prefix='shibumi-gaming-visualizer-') as temporary:
        stage = Path(temporary)
        assert stage.is_absolute() and stage.resolve() == stage
        for directory in ('runtime', 'home', 'config', 'state/omarchy/gaming-mode', 'services', 'visuals'):
            (stage / directory).mkdir(parents=True, exist_ok=True)
        (stage / 'runtime').chmod(0o700)
        for name in ('GamingPause.qml', 'GamingPauseModel.js'):
            shutil.copy2(ROOT / 'hancore.shibumi.bar/services' / name, stage / 'services' / name)
        shutil.copy2(ROOT / 'hancore.shibumi.bar/styles/shibumi/NowPlayingVisualizer.qml', stage / 'visuals')
        shutil.copy2(ROOT / 'tests/gaming-visualizer-smoke.qml', stage / 'shell.qml')
        for name in ('Commons', 'Ui'):
            shutil.copytree(HOST / 'shell' / name, stage / name)
        env = dict(os.environ, HOME=str(stage / 'home'), XDG_CONFIG_HOME=str(stage / 'config'),
                   XDG_STATE_HOME=str(stage / 'state'), XDG_RUNTIME_DIR=str(stage / 'runtime'),
                   HYPRLAND_INSTANCE_SIGNATURE='fixture-gaming', WAYLAND_DISPLAY='',
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   QML_IMPORT_PATH=str(HOST / 'shell'), QML2_IMPORT_PATH=str(HOST / 'shell'))
        journal = stage / 'state/omarchy/gaming-mode/session.json'
        valid = dict(schemaVersion=1, signature='fixture-gaming', pauseDecorations=True)
        log = (stage / 'fixture.log').open('w+')
        process = subprocess.Popen([QS, '-p', str(stage)], env=env, stdout=log, stderr=subprocess.STDOUT)

        def ipc(method, *arguments):
            # Both PID and private runtime are ours; no default/production selection.
            result = subprocess.run([QS, 'ipc', '--pid', str(process.pid), 'call',
                                     'gaming-pause-fixture', method, *arguments],
                                    env=env, text=True, capture_output=True, timeout=3)
            if result.returncode:
                raise RuntimeError(result.stderr or result.stdout)
            if not result.stdout.strip():
                raise RuntimeError(f'Empty fixture IPC response: {method}, argument lengths {[len(a) for a in arguments]}; {result.stderr[:500]}')
            try:
                return json.loads(result.stdout)
            except ValueError as error:
                raise RuntimeError(f'Non-JSON fixture response: {method}, lengths {[len(a) for a in arguments]}: {result.stdout[:500]!r}; {result.stderr[:500]}') from error

        def wait_for(predicate, label, timeout=5):
            end = time.monotonic() + timeout
            last = None
            while time.monotonic() < end:
                if process.poll() is not None:
                    raise RuntimeError('Fixture exited before ' + label)
                try:
                    last = ipc('snapshot')
                    if predicate(last):
                        return last
                except (RuntimeError, ValueError, subprocess.TimeoutExpired):
                    pass
                time.sleep(.05)
            raise AssertionError(f'Timeout: {label}; last snapshot: {last}')

        def write(value):
            raw = value if isinstance(value, str) else json.dumps(value)
            temporary_path = journal.with_suffix('.new')
            temporary_path.write_text(raw)
            temporary_path.replace(journal)

        try:
            initial = wait_for(lambda s: s['animating'] and len(s['bars']) == 4, 'initial media animation')
            time.sleep(.25)  # Settle the existing 180ms initial width transition.
            initial = ipc('snapshot')
            width = initial['width']
            assert width > 0
            wait_for(lambda s: any(abs(a['height'] - b['height']) > .1 for a, b in zip(initial['bars'], s['bars'])),
                     'animated heights change')
            for case in ('empty', 'missing', 'array', 'malformed', 'version', 'signature', 'string-flag', 'oversized', 'optout'):
                assert ipc('parseCase', case)['paused'] is False
            assert ipc('parseCase', 'valid')['paused'] is True

            # File did not exist when the watcher started; creation must be seen.
            write(valid)
            paused = wait_for(lambda s: s['paused'] and not s['animating'], 'journal creation pauses animation')
            assert paused['playing'] and abs(paused['width'] - width) < .01, (initial, paused)
            assert all(abs(b['height'] - 4) < .01 for b in paused['bars'])
            time.sleep(.2)
            assert ipc('snapshot')['bars'] == paused['bars']

            write(dict(valid, pauseDecorations=False))
            wait_for(lambda s: not s['paused'] and s['animating'], 'atomic opt-out')
            write(valid)
            wait_for(lambda s: s['paused'], 'atomic reenable')
            write('{malformed')
            wait_for(lambda s: not s['paused'] and s['animating'], 'malformed journal fallback')
            write(dict(valid, signature='different-session'))
            wait_for(lambda s: not s['paused'], 'other session ignored')
            write(valid)
            wait_for(lambda s: s['paused'], 'valid state after malformed input')
            journal.unlink()
            wait_for(lambda s: not s['paused'] and s['animating'], 'deletion resumes animation')
            write(valid)
            wait_for(lambda s: s['paused'], 'recreation after deletion')
            ipc('enable', 'false')
            wait_for(lambda s: not s['paused'] and s['animating'], 'owner revocation')
            ipc('enable', 'true')
            wait_for(lambda s: s['paused'], 'owner readmission')
            journal.unlink()
            wait_for(lambda s: not s['paused'] and s['animating'], 'final resume')
            ipc('hideBar', 'true')
            hidden = wait_for(lambda s: not s['animating'], 'hidden bar stops decorative work')
            assert hidden['playing']
            ipc('hideBar', 'false')
            final = wait_for(lambda s: s['animating'], 'visible bar resumes')
            assert final['playing'] and final['width'] == width
            print('gaming visualizer regression passed: file lifecycle, malformed/other-session state, '
                  'owner revocation, stable geometry, real animated heights, playback unchanged')
        except Exception:
            log.flush()
            print((stage / 'fixture.log').read_text())
            raise
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            log.close()
            assert process.poll() is not None


if __name__ == '__main__':
    main()
