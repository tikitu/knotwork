#!/usr/bin/env python3
#
# check-app-intents-skip-targets.py — the per-target half of
# check-app-intents-skip.sh, which runs it. Not meant to be run on its own.
#
# Imported by peru from the app-tooling pattern `build-warnings`
# (https://github.com/tikitu/app-tooling). Never edit it here: `peru sync`
# refuses to overwrite a changed copy, and the change belongs in app-tooling.
# docs/app-tooling/build-warnings/ says what it is for.
#
# Usage: check-app-intents-skip-targets.py PATTERN NAME...
#
# Run from the project directory. Each NAME is the <Target> of an
# LM_SKIP_METADATA_EXTRACTION_<Target> setting: a TARGET_NAME made a C
# identifier, as $(TARGET_NAME:c99extidentifier) does. That is an Xcode
# project's target name, or a local package's target or product name (Xcode
# shows a test bundle as `T-product`, but its TARGET_NAME is `T`). Every
# target a NAME could mean counts.
#
# For each, works out every source directory and file it compiles: its
# own, and those of every target it depends on, through the project's own
# Xcode projects and local Swift packages (a package product it links counts
# as all that product's targets, transitively). Dependencies from outside the
# project are not followed. Then reports each Swift file among them that
# matches PATTERN.
#
# Errs towards failing: a target name it cannot find, or anything it cannot
# read, is an error.
#
# Prints `ok` as its last line when no skipped target compiles App Intents
# code; anything else is a failure, with a non-zero exit.

import json
import os
import re
import subprocess
import sys


def fail(message):
    print(f"✗ check-app-intents-skip: {message}")
    sys.exit(2)


def run(args, cwd="."):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        fail(f"{' '.join(args)} failed ({result.returncode}) in {cwd}:\n{result.stderr}")
    return result.stdout


def project_files(name):
    """Tracked and untracked, not ignored, files with this basename."""
    out = run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", f"*{name}"])
    return sorted({p for p in out.splitlines() if os.path.basename(p) == name})


# Each node is a target, as (kind, key). nodes[node] = (paths, dependencies).
nodes = {}
names = {}  # target name -> nodes
products = {}  # package product name -> nodes


def c99(name):
    """Xcode's :c99extidentifier."""
    name = re.sub(r"[^A-Za-z0-9_]", "_", name)
    return "_" + name if name[:1].isdigit() else name


def add(node, xcode_names, paths, deps):
    nodes[node] = (paths, deps)
    for name in xcode_names:
        names.setdefault(c99(name), []).append(node)


def read_packages():
    default_dirs = {"test": ["Tests"]}
    for manifest in project_files("Package.swift"):
        pkg = os.path.dirname(manifest) or "."
        d = json.loads(run(["swift", "package", "dump-package", "--package-path", pkg]))
        local = {t["name"] for t in d["targets"]}
        for t in d["targets"]:
            if t.get("type") in ("binary", "system"):
                continue
            if t.get("path") is not None:
                path = os.path.normpath(os.path.join(pkg, t["path"]))
            else:
                candidates = [
                    os.path.join(pkg, base, t["name"])
                    for base in default_dirs.get(t["type"], ["Sources", "Source", "src", "srcs"])
                ]
                found = [c for c in candidates if os.path.isdir(c)]
                if not found:
                    fail(f"cannot find the sources of target {t['name']} in {manifest}")
                path = os.path.normpath(found[0])
            deps = []
            for dep in t["dependencies"]:
                (kind, value), = dep.items()
                if kind in ("byName", "target") and value[0] in local:
                    deps.append(("package", pkg, value[0]))
                elif kind in ("byName", "product"):
                    deps.append(("product", value[0]))
            add(("package", pkg, t["name"]), [t["name"]], [path], deps)
        for p in d["products"]:
            targets = [("package", pkg, t) for t in p["targets"]]
            products.setdefault(p["name"], []).extend(targets)
            names.setdefault(c99(p["name"]), []).extend(targets)


def read_xcode_projects():
    for pbxproj in project_files("project.pbxproj"):
        xcodeproj = os.path.dirname(pbxproj)
        if not xcodeproj.endswith(".xcodeproj"):
            continue
        objects = json.loads(run(["plutil", "-convert", "json", "-o", "-", pbxproj]))["objects"]
        root = next(o for o in objects.values() if o["isa"] == "PBXProject")
        base = os.path.normpath(os.path.join(os.path.dirname(xcodeproj), root.get("projectDirPath", "")))

        parent = {}
        for key, o in objects.items():
            for child in o.get("children", []):
                parent[child] = key

        def path_of(key):
            o = objects[key]
            tree = o.get("sourceTree", "<group>")
            own = o.get("path", "")
            if tree == "<absolute>":
                return own
            if tree == "SOURCE_ROOT":
                return os.path.join(base, own)
            if tree == "<group>":
                up = parent.get(key)
                return os.path.join(path_of(up) if up else base, own)
            return None  # built products, the SDK: not the project's sources

        for key, t in objects.items():
            if t["isa"] != "PBXNativeTarget":
                continue
            paths = [path_of(g) for g in t.get("fileSystemSynchronizedGroups", [])]
            for phase in t.get("buildPhases", []):
                if objects[phase]["isa"] != "PBXSourcesBuildPhase":
                    continue
                for build_file in objects[phase].get("files", []):
                    ref = objects[build_file].get("fileRef")
                    if ref:
                        paths.append(path_of(ref))
            deps = [("product", objects[p]["productName"]) for p in t.get("packageProductDependencies", [])]
            for dep in t.get("dependencies", []):
                target = objects[dep].get("target")
                if target:
                    deps.append(("xcode", pbxproj, target))
            add(("xcode", pbxproj, key), [t["name"]], [os.path.normpath(p) for p in paths if p], deps)


def closure(start):
    seen, stack = set(), list(start)
    while stack:
        node = stack.pop()
        if node in seen:
            continue
        if node[0] == "product":
            # A product from outside the project's own packages is a
            # dependency, which this check does not read.
            stack.extend(products.get(node[1], []))
            continue
        seen.add(node)
        stack.extend(nodes[node][1])
    return seen


def main():
    pattern, targets = sys.argv[1], sys.argv[2:]
    read_packages()
    read_xcode_projects()

    found = []
    for target in targets:
        if target not in names:
            fail(
                f"the App Intents skip names target {target}, which is in none of this "
                "project's Xcode projects or Swift packages, so what it compiles cannot be checked"
            )
        paths = sorted({p for node in closure(names[target]) for p in nodes[node][0]})
        if not paths:
            continue
        out = subprocess.run(
            ["git", "grep", "--untracked", "-I", "-n", "-w", "-E", pattern, "--"]
            + [f":(literal){p}" for p in paths],
            capture_output=True, text=True,
        )
        if out.returncode > 1:
            fail(f"git grep failed ({out.returncode}):\n{out.stderr}")
        found += [f"{target}: {line}" for line in out.stdout.splitlines()
                  if line.split(":", 1)[0].endswith(".swift")]

    if found:
        print("\n".join(found))
        sys.exit(1)
    print("ok")


main()
