#!/usr/bin/env python3
"""Check XcodeGen in an isolated copy without changing the working project."""

import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def project_settings(path):
    project = json.loads(subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", str(path)]
    ))
    objects = project["objects"]
    root = objects[project["rootObject"]]
    result = {}
    for target in [root] + [objects[key] for key in root["targets"]]:
        name = target.get("name", "PROJECT")
        configs = objects[target["buildConfigurationList"]]["buildConfigurations"]
        for key in configs:
            config = objects[key]
            result[f"{name}/{config['name']}"] = config["buildSettings"]
    return result


def changed_settings(before, after):
    differences = []
    for config, settings in before.items():
        for key, value in settings.items():
            generated = after.get(config, {}).get(key)
            if generated != value:
                differences.append(f"{config}: {key}: {value!r} -> {generated!r}")
    return differences


def main():
    root = Path(__file__).resolve().parent.parent
    project = Path("Rowivo.xcodeproj/project.pbxproj")
    before = project_settings(root / project)
    with tempfile.TemporaryDirectory(prefix="rowivo-project-check-") as directory:
        candidate = Path(directory) / "project"
        shutil.copytree(root, candidate, ignore=shutil.ignore_patterns(
            ".git", ".build", "build", "DerivedData", "__pycache__",
            "xcuserdata", "*.xcuserstate", "*-output.log", "*.xcresult"
        ))
        plists = {
            path.relative_to(candidate): plistlib.loads(path.read_bytes())
            for pattern in ("*.plist", "*.entitlements")
            for path in candidate.rglob(pattern) if path.is_file()
        }
        subprocess.run([
            "xcodegen", "generate", "--spec", str(candidate / "project.yml"),
            "--project-root", str(candidate), "--project", str(candidate)
        ], cwd=candidate, check=True, stdout=subprocess.PIPE)
        differences = changed_settings(before, project_settings(candidate / project))
        for relative, contents in plists.items():
            path = candidate / relative
            if not path.exists() or plistlib.loads(path.read_bytes()) != contents:
                differences.append(f"{relative}: existing plist/entitlements would change")
        # A save in Xcode while this check ran requires another comparison.
        if project_settings(root / project) != before:
            differences.append("The working project changed during the check; run it again.")
        if differences:
            print("STOP: Reconcile Xcode changes into project.yml before generation.")
            print("\n".join(f"- {difference}" for difference in differences))
            return 1
    print("OK: All existing Debug/Release build settings and plist/entitlement contents preserved.")
    print("Only a temporary copy was generated; the working project was not changed.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Project settings check failed: {error}", file=sys.stderr)
        sys.exit(1)
