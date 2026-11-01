"""Build current local sources in a colon-free macOS cache, keeping one repo."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys


source = Path(__file__).resolve().parents[2]
cache = Path(subprocess.check_output(["getconf", "DARWIN_USER_CACHE_DIR"], text=True).strip())
key = hashlib.sha256(str(source).encode()).hexdigest()
workspace = cache / "zloader" / "build-workspaces" / key
assert ":" not in str(workspace), "Build cache path must not contain a colon"
workspace.mkdir(parents=True, exist_ok=True)

# Copy the current working files, including uncommitted edits. Git metadata,
# outputs and build caches are separate, so this is not another checkout.
subprocess.run([
    "rsync", "-a", "--delete", "--exclude=/.build/", "--exclude=/outputs/",
    "--exclude=/build/", "--exclude=.git", "--exclude=.DS_Store",
    str(source) + "/", str(workspace) + "/",
], check=True)

# Seed portable dependency downloads once; APFS clones avoid duplicating their
# file data. Xcode intermediates must be regenerated for the new source path.
build = workspace / ".build"
build.mkdir(exist_ok=True)
for name in ("SourcePackages", "PatchedIdevice", "LiveContainerOpenSSL", "RustToolchain"):
    existing = source / ".build" / name
    destination = build / name
    if existing.exists() and not destination.exists():
        subprocess.run(["cp", "-cR", str(existing), str(destination)], check=True)

state = build / "SourcePackages" / "workspace-state.json"
if state.exists():
    state.write_text(state.read_text().replace(str(source), str(workspace)))

print(f"Building current sources in {workspace}", flush=True)
command = sys.argv[1:] or ["sh", "zLoader/scripts/build-unsigned.sh"]
subprocess.run(command, cwd=workspace, check=True)
if sys.argv[1:]:
    # Test-specific products stay in the cache; do not copy stale app products.
    raise SystemExit(0)

# Keep the usual local output and packaging locations available to callers.
for relative in ("outputs", ".build/Device/Build/Products", ".build/PatchedIdevice"):
    generated = workspace / relative
    if not generated.exists():
        continue
    destination = source / relative
    destination.mkdir(parents=True, exist_ok=True)
    extra = ["--exclude=source/"] if relative == ".build/PatchedIdevice" else []
    subprocess.run(["rsync", "-a", *extra, str(generated) + "/", str(destination) + "/"], check=True)

(source / ".build" / "build-workspace.json").write_text(json.dumps({
    "source": str(source), "workspace": str(workspace),
    "reason": "Xcode dependency files do not support colons in source paths",
}, indent=2) + "\n")
print(f"Build artifacts copied to {source / 'outputs'}", flush=True)
