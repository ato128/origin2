#!/usr/bin/env python3
"""Adds RevenueCat and PostHog SPM packages to project.pbxproj."""

PROJECT_PATH = "/Users/atakanortac/Desktop/origin2/DailyTodo.xcodeproj/project.pbxproj"

# UUIDs – chosen to be clearly distinct from existing ones
RC_PKG_REF   = "AA000001AA000001AA000001"  # XCRemoteSwiftPackageReference
RC_PROD_DEP  = "AA000002AA000002AA000002"  # XCSwiftPackageProductDependency
RC_BUILD     = "AA000003AA000003AA000003"  # PBXBuildFile (Frameworks phase)

PH_PKG_REF   = "BB000001BB000001BB000001"
PH_PROD_DEP  = "BB000002BB000002BB000002"
PH_BUILD     = "BB000003BB000003BB000003"

with open(PROJECT_PATH, "r") as f:
    content = f.read()

# Guard against running twice
if RC_PKG_REF in content:
    print("Packages already added – nothing to do.")
    exit(0)

# ── 1. PBXBuildFile entries ──────────────────────────────────────────────────
build_files = (
    f'\t\t{RC_BUILD} /* RevenueCat in Frameworks */ = {{isa = PBXBuildFile; productRef = {RC_PROD_DEP} /* RevenueCat */; }};\n'
    f'\t\t{PH_BUILD} /* PostHog in Frameworks */ = {{isa = PBXBuildFile; productRef = {PH_PROD_DEP} /* PostHog */; }};\n'
)
content = content.replace(
    "/* End PBXBuildFile section */",
    build_files + "/* End PBXBuildFile section */"
)

# ── 2. Frameworks build phase entries ───────────────────────────────────────
frameworks_entries = (
    f'\t\t\t\t{RC_BUILD} /* RevenueCat in Frameworks */,\n'
    f'\t\t\t\t{PH_BUILD} /* PostHog in Frameworks */,\n'
)
content = content.replace(
    "/* End PBXFrameworksBuildPhase section */",
    frameworks_entries + "/* End PBXFrameworksBuildPhase section */"
)

# ── 3. packageProductDependencies in DailyTodo target ───────────────────────
content = content.replace(
    "\t\t\t\t6D605D262F7743330052C76B /* FirebaseStorageCombine-Community */,\n\t\t\t);",
    (
        "\t\t\t\t6D605D262F7743330052C76B /* FirebaseStorageCombine-Community */,\n"
        f"\t\t\t\t{RC_PROD_DEP} /* RevenueCat */,\n"
        f"\t\t\t\t{PH_PROD_DEP} /* PostHog */,\n"
        "\t\t\t);"
    )
)

# ── 4. packageReferences in PBXProject object ────────────────────────────────
content = content.replace(
    '\t\t\t\t6D605CF72F7743330052C76B /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,\n\t\t\t);',
    (
        '\t\t\t\t6D605CF72F7743330052C76B /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,\n'
        f'\t\t\t\t{RC_PKG_REF} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */,\n'
        f'\t\t\t\t{PH_PKG_REF} /* XCRemoteSwiftPackageReference "posthog-ios" */,\n'
        "\t\t\t);"
    )
)

# ── 5. XCRemoteSwiftPackageReference entries ─────────────────────────────────
rc_pkg = (
    f'\t\t{RC_PKG_REF} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */ = {{\n'
    f'\t\t\tisa = XCRemoteSwiftPackageReference;\n'
    f'\t\t\trepositoryURL = "https://github.com/RevenueCat/purchases-ios-spm.git";\n'
    f'\t\t\trequirement = {{\n'
    f'\t\t\t\tkind = upToNextMajorVersion;\n'
    f'\t\t\t\tminimumVersion = 5.26.0;\n'
    f'\t\t\t}};\n'
    f'\t\t}};\n'
)
ph_pkg = (
    f'\t\t{PH_PKG_REF} /* XCRemoteSwiftPackageReference "posthog-ios" */ = {{\n'
    f'\t\t\tisa = XCRemoteSwiftPackageReference;\n'
    f'\t\t\trepositoryURL = "https://github.com/PostHog/posthog-ios.git";\n'
    f'\t\t\trequirement = {{\n'
    f'\t\t\t\tkind = upToNextMajorVersion;\n'
    f'\t\t\t\tminimumVersion = 3.17.0;\n'
    f'\t\t\t}};\n'
    f'\t\t}};\n'
)
content = content.replace(
    "/* End XCRemoteSwiftPackageReference section */",
    rc_pkg + ph_pkg + "/* End XCRemoteSwiftPackageReference section */"
)

# ── 6. XCSwiftPackageProductDependency entries ───────────────────────────────
rc_dep = (
    f'\t\t{RC_PROD_DEP} /* RevenueCat */ = {{\n'
    f'\t\t\tisa = XCSwiftPackageProductDependency;\n'
    f'\t\t\tpackage = {RC_PKG_REF} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */;\n'
    f'\t\t\tproductName = RevenueCat;\n'
    f'\t\t}};\n'
)
ph_dep = (
    f'\t\t{PH_PROD_DEP} /* PostHog */ = {{\n'
    f'\t\t\tisa = XCSwiftPackageProductDependency;\n'
    f'\t\t\tpackage = {PH_PKG_REF} /* XCRemoteSwiftPackageReference "posthog-ios" */;\n'
    f'\t\t\tproductName = PostHog;\n'
    f'\t\t}};\n'
)
content = content.replace(
    "/* End XCSwiftPackageProductDependency section */",
    rc_dep + ph_dep + "/* End XCSwiftPackageProductDependency section */"
)

with open(PROJECT_PATH, "w") as f:
    f.write(content)

print("project.pbxproj updated successfully.")
