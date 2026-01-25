#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
from pathlib import Path


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def find_package_name(repo_root: Path) -> str:
    gradle_path = repo_root / "android" / "app" / "build.gradle.kts"
    if not gradle_path.exists():
        raise FileNotFoundError(f"Missing {gradle_path}")
    content = read_text(gradle_path)
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', content)
    if not match:
        raise ValueError("Could not find applicationId in build.gradle.kts")
    return match.group(1)


def read_pubspec_version(pubspec_path: Path) -> str:
    for line in read_text(pubspec_path).splitlines():
        if line.strip().startswith("version:"):
            return line.split(":", 1)[1].strip()
    raise ValueError("version not found in pubspec.yaml")


def bump_version(version: str, bump: str) -> str:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", version)
    if not match:
        raise ValueError(f"Unsupported version format: {version}")
    major, minor, patch, build = map(int, match.groups())
    if bump == "major":
        major += 1
        minor = 0
        patch = 0
    elif bump == "minor":
        minor += 1
        patch = 0
    elif bump == "patch":
        patch += 1
    elif bump == "none":
        pass
    else:
        raise ValueError(f"Unsupported bump: {bump}")
    build += 1
    return f"{major}.{minor}.{patch}+{build}"


def update_pubspec_version(pubspec_path: Path, new_version: str) -> None:
    content = read_text(pubspec_path)
    updated = re.sub(
        r"^version:\s*.+$",
        f"version: {new_version}",
        content,
        flags=re.MULTILINE,
    )
    if content == updated:
        raise ValueError("Failed to update pubspec.yaml version")
    write_text(pubspec_path, updated)


def ensure_release_keystore(repo_root: Path, allow_debug_signing: bool) -> None:
    key_props = repo_root / "android" / "key.properties"
    if key_props.exists():
        return
    if allow_debug_signing:
        print("warning: android/key.properties missing; release build may be debug-signed")
        return
    raise FileNotFoundError(
        "android/key.properties missing. Provide release keystore or pass --allow-debug-signing"
    )


def build_appbundle(repo_root: Path) -> Path:
    subprocess.run(
        ["flutter", "build", "appbundle", "--release"],
        cwd=repo_root,
        check=True,
    )
    aab_path = repo_root / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
    if not aab_path.exists():
        raise FileNotFoundError(f"AAB not found at {aab_path}")
    return aab_path


def upload_to_play(
    *,
    package_name: str,
    service_account_json: Path,
    aab_path: Path,
    version_name: str,
    status: str,
    notes: str | None,
) -> None:
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
    except Exception as exc:  # pragma: no cover - import guard
        raise RuntimeError(
            "Missing Google API deps. Install: pip install -r scripts/requirements.txt"
        ) from exc

    scopes = ["https://www.googleapis.com/auth/androidpublisher"]
    creds = service_account.Credentials.from_service_account_file(
        str(service_account_json),
        scopes=scopes,
    )
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit = service.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]

    bundle = service.edits().bundles().upload(
        packageName=package_name,
        editId=edit_id,
        media_body=MediaFileUpload(str(aab_path), mimetype="application/octet-stream"),
    ).execute()
    version_code = bundle["versionCode"]

    release = {
        "name": f"v{version_name}",
        "versionCodes": [str(version_code)],
        "status": status,
    }
    if notes:
        release["releaseNotes"] = [{"language": "en-US", "text": notes}]

    service.edits().tracks().update(
        packageName=package_name,
        editId=edit_id,
        track="internal",
        body={"releases": [release]},
    ).execute()

    service.edits().commit(packageName=package_name, editId=edit_id).execute()


def main() -> int:
    if sys.version_info < (3, 8):
        raise RuntimeError("Python 3.8+ is required. Run with python3.")
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Bump pubspec version, build AAB, and upload to Play internal track.",
    )
    parser.add_argument(
        "--service-account",
        required=True,
        help="Path to Play Console service account JSON.",
    )
    parser.add_argument(
        "--package-name",
        default=None,
        help="Override package name (default: from build.gradle.kts).",
    )
    parser.add_argument(
        "--bump",
        choices=["major", "minor", "patch", "none"],
        default="minor",
        help="Version bump type (default: minor).",
    )
    parser.add_argument(
        "--status",
        default="draft",
        choices=["draft", "inProgress", "completed"],
        help="Release status (default: draft).",
    )
    parser.add_argument("--notes", default=None, help="Release notes (en-US).")
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Skip flutter build and reuse an existing AAB.",
    )
    parser.add_argument(
        "--aab",
        default=None,
        help="Path to existing AAB (used with --skip-build).",
    )
    parser.add_argument(
        "--allow-debug-signing",
        action="store_true",
        help="Allow missing android/key.properties.",
    )
    args = parser.parse_args()

    service_account_json = Path(args.service_account).expanduser().resolve()
    if not service_account_json.exists():
        raise FileNotFoundError(service_account_json)

    package_name = args.package_name or find_package_name(repo_root)
    pubspec_path = repo_root / "pubspec.yaml"
    current_version = read_pubspec_version(pubspec_path)
    new_version = bump_version(current_version, args.bump)
    update_pubspec_version(pubspec_path, new_version)

    ensure_release_keystore(repo_root, args.allow_debug_signing)
    if args.skip_build:
        if not args.aab:
            raise ValueError("--skip-build requires --aab")
        aab_path = Path(args.aab).expanduser().resolve()
        if not aab_path.exists():
            raise FileNotFoundError(aab_path)
    else:
        aab_path = build_appbundle(repo_root)

    upload_to_play(
        package_name=package_name,
        service_account_json=service_account_json,
        aab_path=aab_path,
        version_name=new_version.split("+", 1)[0],
        status=args.status,
        notes=args.notes,
    )

    print(f"Uploaded {package_name} {new_version} to internal track.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
