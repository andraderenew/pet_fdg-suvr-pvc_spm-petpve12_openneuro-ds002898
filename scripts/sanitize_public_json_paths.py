from __future__ import annotations

import json
import os
import sys
from pathlib import Path


summary_dir = Path(sys.argv[1]).resolve()
project_root = Path(
    os.environ.get(
        "PET_PROJECT_ROOT",
        str(Path(__file__).resolve().parents[1]),
    )
).resolve()

spm12_value = os.environ.get("SPM12_DIR", "")
spm12_dir = Path(spm12_value).resolve() if spm12_value else None
home = Path.home().resolve()


def replace_prefix(value: str, prefix: Path, token: str) -> str:
    prefix_text = str(prefix)

    if value == prefix_text:
        return token

    if value.startswith(prefix_text + os.sep):
        suffix = value[len(prefix_text) + 1 :]
        if token == ".":
            return suffix.replace(os.sep, "/")
        return token.rstrip("/") + "/" + suffix.replace(os.sep, "/")

    return value


def sanitize(value):
    if isinstance(value, dict):
        return {
            key: sanitize(item)
            for key, item in value.items()
        }

    if isinstance(value, list):
        return [sanitize(item) for item in value]

    if not isinstance(value, str):
        return value

    value = replace_prefix(value, project_root, ".")

    if spm12_dir is not None:
        value = replace_prefix(
            value,
            spm12_dir,
            "<SPM12_DIR>",
        )

    value = replace_prefix(
        value,
        home,
        "<HOME>",
    )

    return value


def find_absolute(value, path=""):
    findings = []

    if isinstance(value, dict):
        for key, item in value.items():
            findings.extend(
                find_absolute(
                    item,
                    path + "/" + str(key),
                )
            )

    elif isinstance(value, list):
        for index, item in enumerate(value):
            findings.extend(
                find_absolute(
                    item,
                    path + "/" + str(index),
                )
            )

    elif isinstance(value, str) and value.startswith("/"):
        findings.append((path, value))

    return findings


for path in sorted(summary_dir.glob("*.json")):
    original = json.loads(
        path.read_text(encoding="utf-8")
    )

    cleaned = sanitize(original)

    findings = find_absolute(cleaned)

    if findings:
        for key, value in findings:
            print(
                f"ABSOLUTE_PATH {path.name} {key} {value}",
                file=sys.stderr,
            )
        raise SystemExit(
            f"ERROR: absolute filesystem path remains in {path}"
        )

    path.write_text(
        json.dumps(cleaned, indent=2) + "\n",
        encoding="utf-8",
    )

    print("SANITIZED", path.name)
