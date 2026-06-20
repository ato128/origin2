#!/usr/bin/env python3
"""
Adds DailyCreditsManager.swift, UpdoAIChatStore.swift, UpdoAIView.swift
to the DailyTodo target in project.pbxproj.
Removes any existing (potentially stale) entries first, then re-adds cleanly.
"""

import re, uuid, sys

PBXPROJ = "DailyTodo.xcodeproj/project.pbxproj"

# UUIDs that are stable (reuse what's already in the file if present, else new ones)
FILES = {
    "DailyCreditsManager.swift": {
        "fileref": "554557AFE9EB4CB9ADA26234",
        "buildfile": "64B1EAE52BFA4709BF7A513C",
    },
    "UpdoAIChatStore.swift": {
        "fileref": "EB219E8E9A15445994A4EE17",
        "buildfile": "6374030C3A314EE5A3B8EB6E",
    },
    "UpdoAIView.swift": {
        "fileref": "8AB70EC277DD4C2493233DB3",
        "buildfile": "AC735DB7876D4C6C8991F932",
    },
}

# Known stable UUIDs from the project
AI_GROUP_UUID         = "6D8C3D3B2F65B82300ABF6CA"   # /* AI */ PBXGroup
STUDYCOACHSHEET_BFILE = "134A10DFB98541DA937FC945"   # anchor in Sources phase
STUDYCOACHSHEET_FREF  = "1CD11D78273C4CA79673E23B"   # anchor in FileReference section
STUDYCOACHSTORE_GREF  = "6FEE107C7A3E45739659A30A"   # last existing child in AI group

with open(PBXPROJ, "r", encoding="utf-8") as f:
    content = f.read()

original = content

# ── Step 1: strip all existing entries for our three files ──────────────────

for name, ids in FILES.items():
    fr = ids["fileref"]
    bf = ids["buildfile"]
    # PBXBuildFile line
    content = re.sub(rf"\t\t{bf} /\* {re.escape(name)} in Sources \*/ = \{{[^}}]+\}};\n", "", content)
    # PBXFileReference line
    content = re.sub(rf"\t\t{fr} /\* {re.escape(name)} \*/ = \{{[^}}]+\}};\n", "", content)
    # PBXGroup child reference  (tab-indented UUID comment)
    content = re.sub(rf"\t\t\t\t{fr} /\* {re.escape(name)} \*/,\n", "", content)
    # PBXSourcesBuildPhase entry
    content = re.sub(rf"\t\t\t\t\t{bf} /\* {re.escape(name)} in Sources \*/,\n", "", content)

# ── Step 2: insert PBXBuildFile entries (after StudyCoachSheet anchor) ───────

build_file_anchor = f"\t\t{STUDYCOACHSHEET_BFILE} /* StudyCoachSheet.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {STUDYCOACHSHEET_FREF} /* StudyCoachSheet.swift */; }};"

new_build_files = "\n".join(
    f"\t\t{ids['buildfile']} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ids['fileref']} /* {name} */; }};"
    for name, ids in FILES.items()
)

content = content.replace(
    build_file_anchor,
    build_file_anchor + "\n" + new_build_files,
    1,
)

# ── Step 3: insert PBXFileReference entries (after StudyCoachSheet anchor) ──

fref_anchor = f"\t\t{STUDYCOACHSHEET_FREF} /* StudyCoachSheet.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StudyCoachSheet.swift; sourceTree = \"<group>\"; }};"

new_frefs = "\n".join(
    f"\t\t{ids['fileref']} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
    for name, ids in FILES.items()
)

content = content.replace(
    fref_anchor,
    fref_anchor + "\n" + new_frefs,
    1,
)

# ── Step 4: insert into AI PBXGroup (after StudyCoachStore child) ────────────

group_anchor = f"\t\t\t\t{STUDYCOACHSTORE_GREF} /* StudyCoachStore.swift */,"

new_group_children = "\n".join(
    f"\t\t\t\t{ids['fileref']} /* {name} */,"
    for name, ids in FILES.items()
)

# Find the AI group specifically and insert after StudyCoachStore
# (StudyCoachSheet follows StudyCoachStore, then our files)
ai_group_start = content.find(f"\t\t{AI_GROUP_UUID} /* AI */")
ai_group_end   = content.find("};", ai_group_start) + 2

ai_block = content[ai_group_start:ai_group_end]
new_ai_block = ai_block.replace(
    f"\t\t\t\t{STUDYCOACHSTORE_GREF} /* StudyCoachStore.swift */,",
    f"\t\t\t\t{STUDYCOACHSTORE_GREF} /* StudyCoachStore.swift */,\n" + new_group_children,
    1,
)
content = content[:ai_group_start] + new_ai_block + content[ai_group_end:]

# ── Step 5: insert into PBXSourcesBuildPhase (after StudyCoachSheet) ─────────

sources_anchor = f"\t\t\t\t\t{STUDYCOACHSHEET_BFILE} /* StudyCoachSheet.swift in Sources */,"

new_sources = "\n".join(
    f"\t\t\t\t\t{ids['buildfile']} /* {name} in Sources */,"
    for name, ids in FILES.items()
)

content = content.replace(
    sources_anchor,
    sources_anchor + "\n" + new_sources,
    1,
)

# ── Verify all tokens are present ────────────────────────────────────────────

missing = []
for name, ids in FILES.items():
    for token in [ids["fileref"], ids["buildfile"]]:
        count = content.count(token)
        if count < 3:   # should appear in BuildFile + FileReference + Group + Sources = 4 but group only has fileref
            missing.append(f"{name} UUID {token} appears only {count} times")

if missing:
    print("WARNING — some entries may be missing:")
    for m in missing:
        print(" ", m)
else:
    print("All 3 files verified present in all 4 required sections.")

with open(PBXPROJ, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Wrote {PBXPROJ}")
print("Diff summary:")
orig_lines = set(original.splitlines())
new_lines  = set(content.splitlines())
for line in sorted(new_lines - orig_lines):
    if any(name in line for name in FILES):
        print(" +", line.strip())
for line in sorted(orig_lines - new_lines):
    if any(name in line for name in FILES):
        print(" -", line.strip())
