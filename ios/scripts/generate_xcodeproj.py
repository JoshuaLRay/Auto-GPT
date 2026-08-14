#!/usr/bin/env python3
"""Generate XRControl.xcodeproj from the source tree.

The repository ships the generated project so the app can be opened without
extra tooling; run this script after adding or removing source files.

    python3 scripts/generate_xcodeproj.py

Object IDs are derived from an MD5 of a stable key, so regenerating produces an
identical file and diffs stay readable.
"""

from __future__ import annotations

import hashlib
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_NAME = "XRControl"
TEST_TARGET = "XRControlTests"
PROJECT_DIR = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")

DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
BUNDLE_ID = "com.example.xrcontrol"


def oid(key: str) -> str:
    """A deterministic 24-character hex object ID."""
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def collect(directory: str, extensions: tuple[str, ...]) -> list[str]:
    """Repo-relative paths of matching files, sorted for stable output."""
    found = []
    base = os.path.join(ROOT, directory)
    for dirpath, dirnames, filenames in os.walk(base):
        # .xcassets is added as a single folder reference, not file by file.
        dirnames[:] = sorted(d for d in dirnames if not d.endswith(".xcassets"))
        for name in sorted(filenames):
            if name.endswith(extensions):
                full = os.path.join(dirpath, name)
                found.append(os.path.relpath(full, ROOT))
    return sorted(found)


class Tree:
    """Builds the PBXGroup hierarchy that mirrors the folders on disk."""

    def __init__(self) -> None:
        self.children: dict[str, "Tree"] = {}
        self.files: list[str] = []

    def add(self, path: str) -> None:
        parts = path.split(os.sep)
        node = self
        for part in parts[:-1]:
            node = node.children.setdefault(part, Tree())
        node.files.append(path)


class ProjectWriter:
    def __init__(self) -> None:
        self.lines: list[str] = []
        self.groups: list[str] = []

    # -- helpers -----------------------------------------------------------

    def emit(self, text: str = "") -> None:
        self.lines.append(text)

    @staticmethod
    def file_type(path: str) -> str:
        if path.endswith(".swift"):
            return "sourcecode.swift"
        if path.endswith(".plist"):
            return "text.plist.xml"
        if path.endswith(".xcassets"):
            return "folder.assetcatalog"
        if path.endswith(".md"):
            return "net.daringfireball.markdown"
        return "text"

    # -- sections ----------------------------------------------------------

    def build_group(self, name: str, node: Tree, path_component: str | None) -> str:
        """Writes a PBXGroup for `node` and returns its object ID."""
        child_ids: list[tuple[str, str]] = []
        for child_name in sorted(node.children):
            child = node.children[child_name]
            child_id = self.build_group(child_name, child, child_name)
            child_ids.append((child_id, child_name))
        for file_path in node.files:
            child_ids.append((oid(f"file:{file_path}"), os.path.basename(file_path)))

        group_id = oid(f"group:{name}:{path_component}:{','.join(i for i, _ in child_ids)}")
        body = [f"\t\t{group_id} /* {name} */ = {{", "\t\t\tisa = PBXGroup;", "\t\t\tchildren = ("]
        for child_id, child_name in child_ids:
            body.append(f"\t\t\t\t{child_id} /* {child_name} */,")
        body.append("\t\t\t);")
        if path_component:
            body.append(f'\t\t\tpath = "{path_component}";')
        else:
            body.append(f'\t\t\tname = "{name}";')
        body.append("\t\t\tsourceTree = \"<group>\";")
        body.append("\t\t};")
        self.groups.extend(body)
        return group_id


def generate() -> str:
    app_sources = collect(PROJECT_NAME, (".swift",))
    test_sources = collect(TEST_TARGET, (".swift",))
    info_plist = os.path.join(PROJECT_NAME, "Resources", "Info.plist")
    assets = os.path.join(PROJECT_NAME, "Resources", "Assets.xcassets")

    all_files = app_sources + test_sources + [info_plist, assets]

    writer = ProjectWriter()

    # --- Group hierarchy ---------------------------------------------------
    app_tree = Tree()
    for path in app_sources + [info_plist, assets]:
        app_tree.add(path)
    test_tree = Tree()
    for path in test_sources:
        test_tree.add(path)

    app_group_id = writer.build_group(PROJECT_NAME, app_tree.children[PROJECT_NAME], PROJECT_NAME)
    test_group_id = writer.build_group(TEST_TARGET, test_tree.children[TEST_TARGET], TEST_TARGET)

    products_group_id = oid("group:Products")
    root_group_id = oid("group:root")

    app_product_id = oid("product:app")
    test_product_id = oid("product:tests")

    app_target_id = oid("target:app")
    test_target_id = oid("target:tests")
    project_id = oid("project")

    lines: list[str] = []
    add = lines.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")

    # --- PBXBuildFile ------------------------------------------------------
    add("")
    add("/* Begin PBXBuildFile section */")
    for path in app_sources:
        add(f"\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {oid('file:' + path)} /* {os.path.basename(path)} */; }};")
    for path in test_sources:
        add(f"\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {oid('file:' + path)} /* {os.path.basename(path)} */; }};")
    add(f"\t\t{oid('build:' + assets)} /* Assets.xcassets in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {oid('file:' + assets)} /* Assets.xcassets */; }};")
    add("/* End PBXBuildFile section */")

    # --- PBXContainerItemProxy --------------------------------------------
    proxy_id = oid("proxy:tests")
    add("")
    add("/* Begin PBXContainerItemProxy section */")
    add(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
    add("\t\t\tisa = PBXContainerItemProxy;")
    add(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    add("\t\t\tproxyType = 1;")
    add(f"\t\t\tremoteGlobalIDString = {app_target_id};")
    add(f"\t\t\tremoteInfo = {PROJECT_NAME};")
    add("\t\t};")
    add("/* End PBXContainerItemProxy section */")

    # --- PBXFileReference --------------------------------------------------
    add("")
    add("/* Begin PBXFileReference section */")
    for path in all_files:
        name = os.path.basename(path)
        kind = ProjectWriter.file_type(path)
        last = "lastKnownFileType" if not path.endswith(".xcassets") else "lastKnownFileType"
        add(f"\t\t{oid('file:' + path)} /* {name} */ = {{isa = PBXFileReference; "
            f"{last} = {kind}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
    add(f"\t\t{app_product_id} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.application; includeInIndex = 0; "
        f"path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    add(f"\t\t{test_product_id} /* {TEST_TARGET}.xctest */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.cfbundle; includeInIndex = 0; "
        f"path = {TEST_TARGET}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    add("/* End PBXFileReference section */")

    # --- PBXFrameworksBuildPhase ------------------------------------------
    app_frameworks_id = oid("frameworks:app")
    test_frameworks_id = oid("frameworks:tests")
    add("")
    add("/* Begin PBXFrameworksBuildPhase section */")
    for phase_id, label in ((app_frameworks_id, PROJECT_NAME), (test_frameworks_id, TEST_TARGET)):
        add(f"\t\t{phase_id} /* Frameworks */ = {{")
        add("\t\t\tisa = PBXFrameworksBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    # --- PBXGroup ----------------------------------------------------------
    add("")
    add("/* Begin PBXGroup section */")
    add(f"\t\t{root_group_id} = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{app_group_id} /* {PROJECT_NAME} */,")
    add(f"\t\t\t\t{test_group_id} /* {TEST_TARGET} */,")
    add(f"\t\t\t\t{products_group_id} /* Products */,")
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    add(f"\t\t{products_group_id} /* Products */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{app_product_id} /* {PROJECT_NAME}.app */,")
    add(f"\t\t\t\t{test_product_id} /* {TEST_TARGET}.xctest */,")
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    lines.extend(writer.groups)
    add("/* End PBXGroup section */")

    # --- PBXNativeTarget ---------------------------------------------------
    app_sources_phase = oid("sources:app")
    test_sources_phase = oid("sources:tests")
    app_resources_phase = oid("resources:app")
    app_config_list = oid("configlist:app")
    test_config_list = oid("configlist:tests")
    project_config_list = oid("configlist:project")
    dependency_id = oid("dependency:tests")

    add("")
    add("/* Begin PBXNativeTarget section */")
    add(f"\t\t{app_target_id} /* {PROJECT_NAME} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{app_sources_phase} /* Sources */,")
    add(f"\t\t\t\t{app_frameworks_id} /* Frameworks */,")
    add(f"\t\t\t\t{app_resources_phase} /* Resources */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add(f"\t\t\tname = {PROJECT_NAME};")
    add(f"\t\t\tproductName = {PROJECT_NAME};")
    add(f"\t\t\tproductReference = {app_product_id} /* {PROJECT_NAME}.app */;")
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add(f"\t\t{test_target_id} /* {TEST_TARGET} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{test_sources_phase} /* Sources */,")
    add(f"\t\t\t\t{test_frameworks_id} /* Frameworks */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add(f"\t\t\t\t{dependency_id} /* PBXTargetDependency */,")
    add("\t\t\t);")
    add(f"\t\t\tname = {TEST_TARGET};")
    add(f"\t\t\tproductName = {TEST_TARGET};")
    add(f"\t\t\tproductReference = {test_product_id} /* {TEST_TARGET}.xctest */;")
    add("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")

    # --- PBXProject --------------------------------------------------------
    add("")
    add("/* Begin PBXProject section */")
    add(f"\t\t{project_id} /* Project object */ = {{")
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    add("\t\t\t\tLastUpgradeCheck = 1500;")
    add("\t\t\t\tTargetAttributes = {")
    add(f"\t\t\t\t\t{app_target_id} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add("\t\t\t\t\t};")
    add(f"\t\t\t\t\t{test_target_id} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add(f"\t\t\t\t\t\tTestTargetID = {app_target_id};")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list */;")
    add("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    add("\t\t\tdevelopmentRegion = en;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f"\t\t\tmainGroup = {root_group_id};")
    add(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add("\t\t\ttargets = (")
    add(f"\t\t\t\t{app_target_id} /* {PROJECT_NAME} */,")
    add(f"\t\t\t\t{test_target_id} /* {TEST_TARGET} */,")
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    # --- PBXResourcesBuildPhase -------------------------------------------
    add("")
    add("/* Begin PBXResourcesBuildPhase section */")
    add(f"\t\t{app_resources_phase} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add(f"\t\t\t\t{oid('build:' + assets)} /* Assets.xcassets in Resources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    # --- PBXSourcesBuildPhase ---------------------------------------------
    add("")
    add("/* Begin PBXSourcesBuildPhase section */")
    for phase_id, sources in ((app_sources_phase, app_sources), (test_sources_phase, test_sources)):
        add(f"\t\t{phase_id} /* Sources */ = {{")
        add("\t\t\tisa = PBXSourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for path in sources:
            add(f"\t\t\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Sources */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    # --- PBXTargetDependency ----------------------------------------------
    add("")
    add("/* Begin PBXTargetDependency section */")
    add(f"\t\t{dependency_id} /* PBXTargetDependency */ = {{")
    add("\t\t\tisa = PBXTargetDependency;")
    add(f"\t\t\ttarget = {app_target_id} /* {PROJECT_NAME} */;")
    add(f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;")
    add("\t\t};")
    add("/* End PBXTargetDependency section */")

    # --- XCBuildConfiguration ---------------------------------------------
    project_settings = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_STRICT_CONCURRENCY": "minimal",
        "SWIFT_VERSION": SWIFT_VERSION,
    }
    project_debug = dict(project_settings, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    project_release = dict(project_settings, **{
        "DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    })
    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f"{PROJECT_NAME}/Resources/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t)",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": "\"1,2\"",
    }
    test_settings = {
        "BUNDLE_LOADER": "\"$(TEST_HOST)\"",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}.tests",
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "TARGETED_DEVICE_FAMILY": "\"1,2\"",
        "TEST_HOST": f"\"$(BUILT_PRODUCTS_DIR)/{PROJECT_NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{PROJECT_NAME}\"",
    }

    def config_block(config_id: str, name: str, settings: dict[str, str]) -> None:
        add(f"\t\t{config_id} /* {name} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        for key in sorted(settings):
            add(f"\t\t\t\t{key} = {settings[key]};")
        add("\t\t\t};")
        add(f"\t\t\tname = {name};")
        add("\t\t};")

    add("")
    add("/* Begin XCBuildConfiguration section */")
    config_block(oid("config:project:Debug"), "Debug", project_debug)
    config_block(oid("config:project:Release"), "Release", project_release)
    config_block(oid("config:app:Debug"), "Debug", app_settings)
    config_block(oid("config:app:Release"), "Release", app_settings)
    config_block(oid("config:tests:Debug"), "Debug", test_settings)
    config_block(oid("config:tests:Release"), "Release", test_settings)
    add("/* End XCBuildConfiguration section */")

    # --- XCConfigurationList ----------------------------------------------
    add("")
    add("/* Begin XCConfigurationList section */")
    for list_id, scope, label in (
        (project_config_list, "project", f"PBXProject \"{PROJECT_NAME}\""),
        (app_config_list, "app", f"PBXNativeTarget \"{PROJECT_NAME}\""),
        (test_config_list, "tests", f"PBXNativeTarget \"{TEST_TARGET}\""),
    ):
        add(f"\t\t{list_id} /* Build configuration list for {label} */ = {{")
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        add(f"\t\t\t\t{oid(f'config:{scope}:Debug')} /* Debug */,")
        add(f"\t\t\t\t{oid(f'config:{scope}:Release')} /* Release */,")
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f"\trootObject = {project_id} /* Project object */;")
    add("}")
    return "\n".join(lines) + "\n"


def scheme_xml() -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{oid('target:app')}"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{oid('target:tests')}"
               BuildableName = "{TEST_TARGET}.xctest"
               BlueprintName = "{TEST_TARGET}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{oid('target:app')}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{oid('target:app')}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
"""


def workspace_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""


def main() -> None:
    if os.path.isdir(PROJECT_DIR):
        shutil.rmtree(PROJECT_DIR)
    schemes = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
    workspace = os.path.join(PROJECT_DIR, "project.xcworkspace")
    os.makedirs(schemes)
    os.makedirs(workspace)

    with open(os.path.join(PROJECT_DIR, "project.pbxproj"), "w") as handle:
        handle.write(generate())
    with open(os.path.join(schemes, f"{PROJECT_NAME}.xcscheme"), "w") as handle:
        handle.write(scheme_xml())
    with open(os.path.join(workspace, "contents.xcworkspacedata"), "w") as handle:
        handle.write(workspace_xml())

    print(f"Wrote {os.path.relpath(PROJECT_DIR, ROOT)}")


if __name__ == "__main__":
    main()
