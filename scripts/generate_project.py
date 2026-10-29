#!/usr/bin/env python3
"""Generate a self-contained Xcode project with no CocoaPods or XcodeGen."""
from pathlib import Path
import hashlib
import json
import os

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()
def quote(value):
    return json.dumps(str(value), ensure_ascii=False)
def obj(label, body):
    key = uid(label)
    objects[key] = body
    return key
def arr(values):
    return '(' + ', '.join(values) + (',' if values else '') + ')'
def settings(values):
    return '{' + '\n'.join(f'{k} = {v};' for k,v in values.items()) + '}'

sources = sorted([*ROOT.glob('App/*.swift'), *ROOT.glob('App/*.mm'), *ROOT.glob('Engine/*.cpp')])
headers = sorted([*ROOT.glob('App/*.h'), *ROOT.glob('Engine/*.h'), *ROOT.glob('Engine/*.hpp')])
resources = [ROOT/'App/Assets.xcassets', ROOT/'App/PrivacyInfo.xcprivacy', ROOT/'LICENSE.txt', ROOT/'THIRD_PARTY_NOTICES.md']
source_builds, resource_builds, all_refs = [], [], []
for path in sources + headers + resources:
    rel = path.relative_to(ROOT).as_posix()
    types = {'.swift':'sourcecode.swift', '.mm':'sourcecode.cpp.objcpp', '.cpp':'sourcecode.cpp.cpp',
             '.h':'sourcecode.c.h', '.hpp':'sourcecode.cpp.h', '.xcassets':'folder.assetcatalog',
             '.xcprivacy':'text.xml', '.md':'text', '.txt':'text'}
    ref = obj('file:'+rel, f'isa = PBXFileReference; lastKnownFileType = {quote(types[path.suffix])}; path = {quote(rel)}; sourceTree = "<group>";')
    all_refs.append(ref)
    if path in sources or path in resources:
        build = obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};')
        (source_builds if path in sources else resource_builds).append(build)

product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = OrigamiReference.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = {arr([product])}; name = Products; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = {arr(all_refs+[products])}; sourceTree = "<group>";')
src_phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(source_builds)}; runOnlyForDeploymentPostprocessing = 0;')
res_phase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')

project_configs, target_configs = [], []
for mode in ['Debug','Release']:
    common = {'SDKROOT':'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET':'16.0', 'CLANG_ENABLE_MODULES':'YES',
              'CLANG_ENABLE_OBJC_ARC':'YES', 'CLANG_CXX_LANGUAGE_STANDARD':quote('c++17'),
              'CLANG_CXX_LIBRARY':quote('libc++'), 'GCC_C_LANGUAGE_STANDARD':'gnu11',
              'GCC_ENABLE_CPP_EXCEPTIONS':'YES', 'SWIFT_VERSION':'5.0',
              'DEBUG_INFORMATION_FORMAT':quote('dwarf' if mode=='Debug' else 'dwarf-with-dsym'),
              'GCC_OPTIMIZATION_LEVEL':'0' if mode=='Debug' else '2',
              'SWIFT_OPTIMIZATION_LEVEL':quote('-Onone' if mode=='Debug' else '-O'),
              'ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO'}
    if mode == 'Debug': common['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    project_configs.append(obj('project:'+mode, f'isa = XCBuildConfiguration; buildSettings = {settings(common)}; name = {mode};'))
    target = {'PRODUCT_NAME':quote('$(TARGET_NAME)'), 'PRODUCT_BUNDLE_IDENTIFIER':quote(os.environ.get('BUNDLE_ID', 'es.angelsoto.origamireferencefinder')),
              'MARKETING_VERSION':'1.1', 'CURRENT_PROJECT_VERSION':'1', 'VERSIONING_SYSTEM':quote('apple-generic'),
              'INFOPLIST_FILE':quote('App/Info.plist'), 'GENERATE_INFOPLIST_FILE':'NO',
              'SWIFT_OBJC_BRIDGING_HEADER':quote('App/OrigamiReference-Bridging-Header.h'),
              'HEADER_SEARCH_PATHS':quote('$(SRCROOT)/Engine'),
              'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
              'TARGETED_DEVICE_FAMILY':quote('1,2'), 'CODE_SIGN_STYLE':'Automatic',
              'SUPPORTED_PLATFORMS':quote('iphoneos iphonesimulator'),
              'SUPPORTS_MACCATALYST':'NO', 'LD_RUNPATH_SEARCH_PATHS':quote('$(inherited) @executable_path/Frameworks')}
    target_configs.append(obj('target:'+mode, f'isa = XCBuildConfiguration; buildSettings = {settings(target)}; name = {mode};'))
def config_list(label, configs):
    return obj(label, f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_list = config_list('target-configs', target_configs)
project_list = config_list('project-configs', project_configs)
target_id = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {target_list}; buildPhases = {arr([src_phase,frameworks,res_phase])}; buildRules = (); dependencies = (); name = OrigamiReference; productName = OrigamiReference; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {project_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([target_id])};')
dest = ROOT/'OrigamiReference.xcodeproj'
dest.mkdir(exist_ok=True)
body = '\n'.join(f'{key} = {{ {value} }};' for key,value in objects.items())
(dest/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+body+'\n}; rootObject = '+project+'; }\n')
scheme = dest/'xcshareddata/xcschemes/OrigamiReference.xcscheme'
scheme.parent.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="OrigamiReference.app" BlueprintName="OrigamiReference" ReferencedContainer="container:OrigamiReference.xcodeproj"/>'
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated', dest.name)
