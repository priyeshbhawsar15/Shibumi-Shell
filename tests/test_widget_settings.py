"""A widget must receive array settings as real arrays from its layout entry."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required")
class WidgetSettingsTests(unittest.TestCase):
    def test_entry_settings_keep_real_arrays_through_model_data(self) -> None:
        with tempfile.TemporaryDirectory(prefix="shibumi-settings-") as directory:
            shell = Path(directory) / "shell"
            core = shell / "hancore.shibumi.bar/core"
            core.mkdir(parents=True)
            shutil.copy(ROOT / "hancore.shibumi.bar/core/EntrySettings.js", core)
            shutil.copy(ROOT / "tests/widget-settings-smoke.qml", shell / "shell.qml")
            runtime = Path(directory) / "r"
            runtime.mkdir(mode=0o700)
            env = {key: value for key, value in os.environ.items()
                   if key != "WAYLAND_DISPLAY"}
            env.update(HOME=directory, QT_QPA_PLATFORM="offscreen",
                       XDG_RUNTIME_DIR=str(runtime))
            result = subprocess.run(
                ["quickshell", "-p", str(shell), "--no-color"], env=env,
                capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("widget settings smoke passed", output)


if __name__ == "__main__":
    unittest.main()
