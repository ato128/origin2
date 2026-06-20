#!/usr/bin/env python3
"""Adds new Swift source files to project.pbxproj."""
import re

PROJECT_PATH = "/Users/atakanortac/Desktop/origin2/DailyTodo.xcodeproj/project.pbxproj"

# Group UUIDs
APP_GROUP   = "6DF0C92A2F557AE90043B887"   # path = App
PREMIUM_GRP = "6DF0C9352F557BFF0043B887"   # path = Premium (for PaywallView)

# New files – (fileRefUUID, buildFileUUID, filename, group)
NEW_FILES = [
    ("CC100001CC100001CC100001", "CC100002CC100002CC100002", "SubscriptionManager.swift", APP_GROUP),
    ("CC100003CC100003CC100003", "CC100004CC100004CC100004", "Analytics.swift",           APP_GROUP),
    ("CC100005CC100005CC100005", "CC100006CC100006CC100006", "PaywallView.swift",         PREMIUM_GRP),
]

with open(PROJECT_PATH, "r") as f:
    content = f.read()

if "CC100001CC100001CC100001" in content:
    print("Source files already added – nothing to do.")
    exit(0)

# ── 1. PBXFileReference entries ──────────────────────────────────────────────
file_refs = ""
for fileRef, _, filename, _ in NEW_FILES:
    file_refs += f'\t\t{fileRef} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

content = content.replace(
    "/* End PBXFileReference section */",
    file_refs + "/* End PBXFileReference section */"
)

# ── 2. PBXBuildFile entries ──────────────────────────────────────────────────
build_files = ""
for fileRef, buildFile, filename, _ in NEW_FILES:
    build_files += f'\t\t{buildFile} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileRef} /* {filename} */; }};\n'

content = content.replace(
    "/* End PBXBuildFile section */",
    build_files + "/* End PBXBuildFile section */"
)

# ── 3. Add to PBXSourcesBuildPhase (Sources) ─────────────────────────────────
sources_entries = ""
for _, buildFile, filename, _ in NEW_FILES:
    sources_entries += f'\t\t\t\t{buildFile} /* {filename} in Sources */,\n'

# Insert before end of sources build phase – find a reliable anchor
# The sources phase ends with '/* End PBXSourcesBuildPhase section */'
content = content.replace(
    "/* End PBXSourcesBuildPhase section */",
    sources_entries + "/* End PBXSourcesBuildPhase section */"
)

# ── 4. Add to PBXGroup children ──────────────────────────────────────────────
# App group: insert after AppSecrets.swift
app_files = [f for f in NEW_FILES if f[3] == APP_GROUP]
for fileRef, _, filename, _ in app_files:
    content = content.replace(
        "\t\t\t\t6DB004762F99A1D1009F2F3B /* AppSecrets.swift */,",
        f"\t\t\t\t6DB004762F99A1D1009F2F3B /* AppSecrets.swift */,\n\t\t\t\t{fileRef} /* {filename} */,"
    )

# Premium group: insert into its (currently empty) children list
premium_files = [f for f in NEW_FILES if f[3] == PREMIUM_GRP]
for fileRef, _, filename, _ in premium_files:
    content = content.replace(
        f"\t\t{PREMIUM_GRP} /* Premium */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t);",
        f"\t\t{PREMIUM_GRP} /* Premium */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{fileRef} /* {filename} */,\n\t\t\t);"
    )

with open(PROJECT_PATH, "w") as f:
    f.write(content)

print("Source files added to project.pbxproj.")
