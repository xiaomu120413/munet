"""Verify the unsigned release HAP/APP before handing them to signing or QA."""
import argparse
import hashlib
import io
import json
import struct
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def verify(hap_path, app_path):
    hap_data = hap_path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(hap_data)) as hap:
        require(hap.testzip() is None, "HAP CRC check failed")
        names = hap.namelist()
        metadata = json.loads(hap.read("module.json"))
        application, module = metadata["app"], metadata["module"]
        require(application.get("debug") is False, "Debug HAP cannot be a release candidate")
        require(application.get("buildMode") == "release", "Expected release buildMode")
        expected = json.loads((ROOT / "AppScope/app.json5").read_text(encoding="utf-8"))["app"]
        for key in ("bundleName", "versionName", "versionCode"):
            require(application[key] == expected[key], "Unexpected " + key)
        require(module["name"] == "entry" and module["type"] == "entry", "Expected entry module")
        require(module["deliveryWithInstall"] is True, "Entry module must be delivered with this application")
        require(set(module["deviceTypes"]) == {"phone", "tablet", "2in1"}, "Unexpected device types")
        permissions = sorted(p["name"] for p in module["requestPermissions"])
        require(permissions == sorted([
            "ohos.permission.INTERNET", "ohos.permission.GET_NETWORK_INFO", "ohos.permission.GET_WIFI_INFO"
        ]), "Unexpected permissions: " + str(permissions))
        require(hap.getinfo("ets/modules.abc").file_size > 0, "ArkTS bytecode missing")
        abi_sizes = {}
        for abi, machine in (("arm64-v8a", 183), ("x86_64", 62)):
            data = hap.read("libs/" + abi + "/libnettools.so")
            require(len(data) >= 20, "Truncated ELF header for " + abi)
            require(data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64 for " + abi)
            require(struct.unpack_from("<H", data, 18)[0] == machine, "Wrong native architecture for " + abi)
            abi_sizes[abi] = len(data)
        require(not any("ohosTest" in name or "test_pages" in name for name in names), "Test resources in release HAP")
    with zipfile.ZipFile(app_path) as app:
        require(app.testzip() is None, "APP CRC check failed")
        modules = sorted(name for name in app.namelist() if name.endswith((".hap", ".hsp")))
        require(modules == ["entry-default.hap"], "Unexpected APP modules: " + str(modules))
        # PackageApp enriches pack.info with application-level distribution data.
        # Require every runtime file to match, rather than ZIP bytes/timestamps.
        with zipfile.ZipFile(io.BytesIO(app.read(modules[0]))) as embedded, zipfile.ZipFile(io.BytesIO(hap_data)) as standalone:
            require(set(embedded.namelist()) == set(standalone.namelist()), "APP entry has different files")
            for name in standalone.namelist():
                if name != "pack.info":
                    require(embedded.read(name) == standalone.read(name), "APP entry differs: " + name)
            require(json.loads(embedded.read("pack.info")) == json.loads(standalone.read("pack.info")),
                    "APP entry has different distribution metadata")
    sources = [ROOT / "build-profile.json5", ROOT / "entry/build-profile.json5"]
    sources += sorted((ROOT / "AppScope").rglob("*"))
    sources += sorted((ROOT / "entry/src/main").rglob("*"))
    source_hashes = {p.relative_to(ROOT).as_posix(): sha256(p.read_bytes()) for p in sources if p.is_file()}
    return {
        "status": "verified_unsigned_release_candidate",
        "market_submission_ready": False,
        "bundle": application["bundleName"], "version": application["versionName"],
        "versionCode": application["versionCode"], "debug": False,
        "permissions": permissions, "native_library_bytes": abi_sizes,
        "artifacts": {p.name: {"bytes": p.stat().st_size, "sha256": sha256(p.read_bytes())}
                      for p in (hap_path, app_path)},
        "source_sha256": source_hashes
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hap", type=Path, required=True)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify(args.hap, args.app)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, "Release verification failed: " + str(error) + "\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Release HAP/APP verified; formal signing and store preparation remain separate.")


if __name__ == "__main__":
    main()
