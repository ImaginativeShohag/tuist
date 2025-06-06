import Foundation
import Mockable
import Path
import TuistCore
import XcodeGraph
import XcodeProj
import XCTest
@testable import TuistGenerator
@testable import TuistTesting

final class ProjectFileElementsTests: TuistUnitTestCase {
    private var subject: ProjectFileElements!
    private var groups: ProjectGroups!
    private var pbxproj: PBXProj!
    private var cacheDirectoriesProvider: MockCacheDirectoriesProviding!

    override func setUpWithError() throws {
        super.setUp()
        cacheDirectoriesProvider = .init()
        pbxproj = PBXProj()
        groups = ProjectGroups.generate(
            project: .test(path: "/path", sourceRootPath: "/path", xcodeProjPath: "/path/Project.xcodeproj"),
            pbxproj: pbxproj
        )

        given(cacheDirectoriesProvider)
            .cacheDirectory()
            .willReturn(try! temporaryPath())

        subject = ProjectFileElements(cacheDirectoriesProvider: cacheDirectoriesProvider)
    }

    override func tearDown() {
        cacheDirectoriesProvider = nil
        pbxproj = nil
        groups = nil
        subject = nil
        super.tearDown()
    }

    func test_projectFiles() {
        // Given
        let settings = Settings(
            base: [:],
            configurations: [
                .debug: Configuration(xcconfig: try! AbsolutePath(validating: "/project/debug.xcconfig")),
                .release: Configuration(xcconfig: try! AbsolutePath(validating: "/project/release.xcconfig")),
            ]
        )

        let project = Project.test(
            path: try! AbsolutePath(validating: "/project/"),
            settings: settings,
            schemes: [
                .test(
                    runAction: .test(
                        options: .init(storeKitConfigurationPath: "/path/to/configuration.storekit")
                    )
                ),
            ],
            additionalFiles: [
                .file(path: "/path/to/file"),
                .folderReference(path: "/path/to/folder"),
            ]
        )

        // When
        let files = subject.projectFiles(project: project)

        // Then
        XCTAssertTrue(files.isSuperset(of: [
            GroupFileElement(path: "/project/debug.xcconfig", group: project.filesGroup),
            GroupFileElement(path: "/project/release.xcconfig", group: project.filesGroup),
            GroupFileElement(path: "/path/to/file", group: project.filesGroup),
            GroupFileElement(path: "/path/to/folder", group: project.filesGroup, isReference: true),
            GroupFileElement(path: "/path/to/configuration.storekit", group: project.filesGroup),
        ]))
    }

    func test_addElement() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/myfolder/resources/a.png",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "myfolder/resources/a.png",
        ])
    }

    func test_addElement_withDotFolders() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/my.folder/resources/a.png",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "my.folder/resources/a.png",
        ])
    }

    func test_addElement_fileReference() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/myfolder/resources/generated_images",
            group: .group(name: "Project"),
            isReference: true
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "myfolder/resources/generated_images",
        ])
    }

    func test_addElement_parentDirectories() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/another/path/resources/a.png",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path/project"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "another/path/resources/a.png",
        ])
    }

    func test_addElement_xcassets() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/myfolder/resources/assets.xcassets",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "myfolder/resources/assets.xcassets",
        ])
    }

    func test_addElement_docc() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/myfolder/resources/ImportantDocumentation.docc",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "myfolder/resources/ImportantDocumentation.docc",
        ])
    }

    func test_addElement_scnassets() throws {
        // Given
        let element = GroupFileElement(
            path: "/path/myfolder/resources/assets.scnassets",
            group: .group(name: "Project")
        )

        // When
        try subject.generate(
            fileElement: element,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: "/path"
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "myfolder/resources/assets.scnassets",
        ])
    }

    func test_addElement_lproj_multiple_files() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let resources = try await createFiles([
            "resources/en.lproj/App.strings",
            "resources/en.lproj/App.stringsdict",
            "resources/en.lproj/Extension.strings",
            "resources/fr.lproj/App.strings",
            "resources/fr.lproj/App.stringsdict",
            "resources/fr.lproj/Extension.strings",
        ])

        let elements = resources.map {
            GroupFileElement(
                path: $0,
                group: .group(name: "Project"),
                isReference: true
            )
        }

        // When
        for element in elements {
            try subject.generate(
                fileElement: element,
                groups: groups,
                pbxproj: pbxproj,
                sourceRootPath: temporaryPath
            )
        }

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "resources/App.strings/en",
            "resources/App.strings/fr",
            "resources/App.stringsdict/en",
            "resources/App.stringsdict/fr",
            "resources/Extension.strings/en",
            "resources/Extension.strings/fr",
        ])

        XCTAssertEqual(projectGroup?.debugVariantGroupPaths, [
            "resources/App.strings",
            "resources/App.stringsdict",
            "resources/Extension.strings",
        ])
    }

    func test_addElement_lproj_variant_groups() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let resources = try await createFiles([
            "resources/Base.lproj/Controller.xib",
            "resources/Base.lproj/Intents.intentdefinition",
            "resources/Base.lproj/Storyboard.storyboard",
            "resources/en.lproj/Controller.xib",
            "resources/en.lproj/Intents.strings",
            "resources/en.lproj/Storyboard.strings",
            "resources/fr.lproj/Controller.strings",
            "resources/fr.lproj/Intents.strings",
            "resources/fr.lproj/Storyboard.strings",
        ])

        let elements = resources.map {
            GroupFileElement(
                path: $0,
                group: .group(name: "Project"),
                isReference: true
            )
        }

        // When
        for element in elements {
            try subject.generate(
                fileElement: element,
                groups: groups,
                pbxproj: pbxproj,
                sourceRootPath: temporaryPath
            )
        }

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [
            "resources/Controller.xib/Base",
            "resources/Controller.xib/en",
            "resources/Controller.xib/fr",
            "resources/Intents.intentdefinition/Base",
            "resources/Intents.intentdefinition/en",
            "resources/Intents.intentdefinition/fr",
            "resources/Storyboard.storyboard/Base",
            "resources/Storyboard.storyboard/en",
            "resources/Storyboard.storyboard/fr",
        ])

        XCTAssertEqual(projectGroup?.debugVariantGroupPaths, [
            "resources/Controller.xib",
            "resources/Intents.intentdefinition",
            "resources/Storyboard.storyboard",
        ])
    }

    func test_addElement_lproj_knownRegions() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let resources = try await createFiles([
            "resources/en.lproj/App.strings",
            "resources/en.lproj/Extension.strings",
            "resources/fr.lproj/App.strings",
            "resources/fr.lproj/Extension.strings",
            "resources/Base.lproj/App.strings",
            "resources/Base.lproj/Extension.strings",
        ])

        let elements = resources.map {
            GroupFileElement(
                path: $0,
                group: .group(name: "Project"),
                isReference: true
            )
        }

        // When
        for element in elements {
            try subject.generate(
                fileElement: element,
                groups: groups,
                pbxproj: pbxproj,
                sourceRootPath: temporaryPath
            )
        }

        // Then

        XCTAssertEqual(subject.knownRegions, Set([
            "en",
            "fr",
            "Base",
        ]))
    }

    func test_targetFiles() throws {
        // Given
        let settings = Settings.test(
            base: [:],
            debug: Configuration(
                settings: ["Configuration": "A"],
                xcconfig: try AbsolutePath(validating: "/project/debug.xcconfig")
            ),
            release: Configuration(
                settings: ["Configuration": "B"],
                xcconfig: try AbsolutePath(validating: "/project/release.xcconfig")
            )
        )

        let target = Target.test(
            name: "name",
            platform: .iOS,
            product: .app,
            bundleId: "com.bundle.id",
            infoPlist: .file(path: try AbsolutePath(validating: "/project/info.plist")),
            entitlements: .file(path: try AbsolutePath(validating: "/project/app.entitlements")),
            settings: settings,
            sources: [SourceFile(path: try AbsolutePath(validating: "/project/file.swift"))],
            resources: .init(
                [
                    .file(path: try AbsolutePath(validating: "/project/image.png")),
                    .folderReference(path: try AbsolutePath(validating: "/project/reference")),
                ]
            ),
            copyFiles: [
                CopyFilesAction(
                    name: "Copy Templates",
                    destination: .sharedSupport,
                    subpath: "Templates",
                    files: [
                        .file(path: "/project/tuist.rtfd"),
                        .file(path: "/project/tuist.rtfd/TXT.rtf"),
                    ]
                ),
            ],
            coreDataModels: [CoreDataModel(
                path: try AbsolutePath(validating: "/project/model.xcdatamodeld"),
                versions: [try AbsolutePath(validating: "/project/model.xcdatamodeld/1.xcdatamodel")],
                currentVersion: "1"
            )],
            headers: Headers(
                public: [try AbsolutePath(validating: "/project/public.h")],
                private: [try AbsolutePath(validating: "/project/private.h")],
                project: [try AbsolutePath(validating: "/project/project.h")]
            ),
            dependencies: [],
            playgrounds: ["/project/MyPlayground.playground"],
            additionalFiles: [.file(path: try AbsolutePath(validating: "/project/README.md"))]
        )

        // When
        let files = try subject.targetFiles(target: target)

        // Then
        XCTAssertTrue(files.isSuperset(of: [
            GroupFileElement(path: "/project/debug.xcconfig", group: target.filesGroup),
            GroupFileElement(path: "/project/release.xcconfig", group: target.filesGroup),
            GroupFileElement(path: "/project/file.swift", group: target.filesGroup),
            GroupFileElement(path: "/project/MyPlayground.playground", group: target.filesGroup),
            GroupFileElement(path: "/project/image.png", group: target.filesGroup),
            GroupFileElement(path: "/project/reference", group: target.filesGroup, isReference: true),
            GroupFileElement(path: "/project/public.h", group: target.filesGroup),
            GroupFileElement(path: "/project/project.h", group: target.filesGroup),
            GroupFileElement(path: "/project/private.h", group: target.filesGroup),
            GroupFileElement(path: "/project/model.xcdatamodeld/1.xcdatamodel", group: target.filesGroup),
            GroupFileElement(path: "/project/model.xcdatamodeld", group: target.filesGroup),
            GroupFileElement(path: "/project/tuist.rtfd", group: target.filesGroup),
            GroupFileElement(path: "/project/tuist.rtfd/TXT.rtf", group: target.filesGroup),
            GroupFileElement(path: "/project/README.md", group: target.filesGroup),
        ]))
    }

    func test_generateProduct() throws {
        // Given
        let pbxproj = PBXProj()
        let project = Project.test(
            path: .root,
            sourceRootPath: .root,
            xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj"),
            targets: [
                .test(name: "App", product: .app),
                .test(name: "Framework", product: .framework),
                .test(name: "Library", product: .staticLibrary),
            ]
        )
        let graph = Graph.test()
        let graphTraverser = GraphTraverser(graph: graph)
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        // When
        try subject.generateProjectFiles(
            project: project,
            graphTraverser: graphTraverser,
            groups: groups,
            pbxproj: pbxproj
        )

        // Then
        XCTAssertEqual(groups.products.flattenedChildren, [
            "App.app",
            "Framework.framework",
            "libLibrary.a",
        ])
    }

    func test_generateProducts_stableOrder() throws {
        for _ in 0 ..< 5 {
            let pbxproj = PBXProj()
            let subject = ProjectFileElements()
            let targets: [Target] = [
                .test(name: "App1", product: .app),
                .test(name: "App2", product: .app),
                .test(name: "Framework1", product: .framework),
                .test(name: "Framework2", product: .framework),
                .test(name: "Library1", product: .staticLibrary),
                .test(name: "Library2", product: .staticLibrary),
            ].shuffled()

            let project = Project.test(
                path: .root,
                sourceRootPath: .root,
                xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj"),
                targets: targets
            )
            let graph = Graph.test()
            let graphTraverser = GraphTraverser(graph: graph)
            let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

            // When
            try subject.generateProjectFiles(
                project: project,
                graphTraverser: graphTraverser,
                groups: groups,
                pbxproj: pbxproj
            )

            // Then
            XCTAssertEqual(groups.products.flattenedChildren, [
                "App1.app",
                "App2.app",
                "Framework1.framework",
                "Framework2.framework",
                "libLibrary1.a",
                "libLibrary2.a",
            ])
        }
    }

    func test_generateProduct_fileReferencesProperties() throws {
        // Given
        let pbxproj = PBXProj()
        let project = Project.test(
            path: .root,
            sourceRootPath: .root,
            xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj"),
            targets: [
                .test(name: "App", product: .app),
            ]
        )
        let graph = Graph.test()
        let graphTraverser = GraphTraverser(graph: graph)
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        // When
        try subject.generateProjectFiles(
            project: project,
            graphTraverser: graphTraverser,
            groups: groups,
            pbxproj: pbxproj
        )

        // Then
        let fileReference = subject.product(target: "App")
        XCTAssertEqual(fileReference?.sourceTree, .buildProductsDir)
    }

    func test_generateDependencies_whenPrecompiledNode() throws {
        let pbxproj = PBXProj()
        let sourceRootPath = try AbsolutePath(validating: "/")
        let target = Target.test()
        let projectGroupName = "Project"
        let projectGroup: ProjectGroup = .group(name: projectGroupName)
        let project = Project.test(
            path: .root,
            sourceRootPath: .root,
            xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj"),
            filesGroup: projectGroup,
            targets: [target]
        )
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)
        var dependencies: Set<GraphDependencyReference> = Set()
        let precompiledNode = GraphDependencyReference.testFramework(path: project.path.appending(component: "waka.framework"))
        dependencies.insert(precompiledNode)

        try subject.generate(
            dependencyReferences: dependencies,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: sourceRootPath,
            filesGroup: project.filesGroup
        )

        let fileReference = groups.sortedMain.group(named: projectGroupName)?.children.first as? PBXFileReference
        XCTAssertEqual(fileReference?.path, "waka.framework")
        XCTAssertEqual(fileReference?.path, "waka.framework")
        XCTAssertNil(fileReference?.name)
    }

    func test_generatePath_whenGroupIsSpecified() throws {
        // Given
        let pbxproj = PBXProj()
        let path = try AbsolutePath(validating: "/a/b/c/file.swift")
        let fileElement = GroupFileElement(path: path, group: .group(name: "SomeGroup"))
        let project = Project.test(
            path: .root,
            sourceRootPath: .root,
            xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj"),
            filesGroup: .group(name: "SomeGroup")
        )
        let sourceRootPath = try AbsolutePath(validating: "/a/project/")
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        // When
        try subject.generate(
            fileElement: fileElement,
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: sourceRootPath
        )

        // Then
        let group = groups.sortedMain.group(named: "SomeGroup")

        let bGroup: PBXGroup = group?.children.first! as! PBXGroup
        XCTAssertEqual(bGroup.name, "b")
        XCTAssertEqual(bGroup.path, "../b")
        XCTAssertEqual(bGroup.sourceTree, .group)

        let cGroup: PBXGroup = bGroup.children.first! as! PBXGroup
        XCTAssertEqual(cGroup.path, "c")
        XCTAssertNil(cGroup.name)
        XCTAssertEqual(cGroup.sourceTree, .group)

        let file: PBXFileReference = cGroup.children.first! as! PBXFileReference
        XCTAssertEqual(file.path, "file.swift")
        XCTAssertNil(file.name)
        XCTAssertEqual(file.sourceTree, .group)
    }

    func test_addLocalizedFile() throws {
        // Given
        let pbxproj = PBXProj()
        let group = PBXGroup()
        let file: AbsolutePath = "/path/to/resources/en.lproj/App.strings"

        // When
        subject.addLocalizedFile(
            localizedFile: file,
            toGroup: group,
            pbxproj: pbxproj
        )

        // Then
        let variantGroup = group.children.first as? PBXVariantGroup
        XCTAssertEqual(variantGroup?.name, "App.strings")
        XCTAssertNil(variantGroup?.path)
        XCTAssertEqual(variantGroup?.children.map(\.name), ["en"])
        XCTAssertEqual(variantGroup?.children.map(\.path), ["en.lproj/App.strings"])
        XCTAssertEqual(variantGroup?.children.map { ($0 as? PBXFileReference)?.lastKnownFileType }, [
            Xcode.filetype(extension: "strings"),
        ])
    }

    func test_addPlayground() throws {
        // Given
        let from = try AbsolutePath(validating: "/project/")
        let fileAbsolutePath = try AbsolutePath(validating: "/project/MyPlayground.playground")
        let fileRelativePath = try RelativePath(validating: "./MyPlayground.playground")
        let group = PBXGroup()
        let pbxproj = PBXProj()
        pbxproj.add(object: group)

        // When
        subject.addFileElementRelativeToGroup(
            from: from,
            fileAbsolutePath: fileAbsolutePath,
            fileRelativePath: fileRelativePath,
            name: nil,
            toGroup: group,
            pbxproj: pbxproj
        )

        // Then
        let file: PBXFileReference? = group.children.first as? PBXFileReference
        XCTAssertEqual(file?.path, "MyPlayground.playground")
        XCTAssertEqual(file?.sourceTree, .group)
        XCTAssertNil(file?.name)
        XCTAssertEqual(file?.lastKnownFileType, Xcode.filetype(extension: fileAbsolutePath.extension!))
    }

    func test_addVersionGroupElement() throws {
        // Given
        let from = try AbsolutePath(validating: "/project/")
        let folderAbsolutePath = try AbsolutePath(validating: "/project/model.xcdatamodeld")
        let folderRelativePath = try RelativePath(validating: "./model.xcdatamodeld")
        let group = PBXGroup()
        let pbxproj = PBXProj()
        pbxproj.add(object: group)

        // When
        _ = subject.addVersionGroupElement(
            from: from,
            folderAbsolutePath: folderAbsolutePath,
            folderRelativePath: folderRelativePath,
            name: nil,
            toGroup: group,
            pbxproj: pbxproj
        )

        // Then
        let versionGroup = try XCTUnwrap(group.children.first as? XCVersionGroup)
        XCTAssertEqual(versionGroup.path, "model.xcdatamodeld")
        XCTAssertEqual(versionGroup.sourceTree, .group)
        XCTAssertNil(versionGroup.name)
        XCTAssertEqual(versionGroup.versionGroupType, "wrapper.xcdatamodel")
    }

    func test_addFileElement() throws {
        let from = try AbsolutePath(validating: "/project/")
        let fileAbsolutePath = try AbsolutePath(validating: "/project/file.swift")
        let fileRelativePath = try RelativePath(validating: "./file.swift")
        let group = PBXGroup()
        let pbxproj = PBXProj()
        pbxproj.add(object: group)
        subject.addFileElementRelativeToGroup(
            from: from,
            fileAbsolutePath: fileAbsolutePath,
            fileRelativePath: fileRelativePath,
            name: nil,
            toGroup: group,
            pbxproj: pbxproj
        )
        let file: PBXFileReference? = group.children.first as? PBXFileReference
        XCTAssertEqual(file?.path, "file.swift")
        XCTAssertEqual(file?.sourceTree, .group)
        XCTAssertNil(file?.name)
        XCTAssertEqual(file?.lastKnownFileType, Xcode.filetype(extension: "swift"))
    }

    func test_group() {
        let group = PBXGroup()
        let path = try! AbsolutePath(validating: "/path/to/folder")
        subject.elements[path] = group
        XCTAssertEqual(subject.group(path: path), group)
    }

    func test_file() {
        let file = PBXFileReference()
        let path = try! AbsolutePath(validating: "/path/to/folder")
        subject.elements[path] = file
        XCTAssertEqual(subject.file(path: path), file)
    }

    func test_isLocalized() {
        let path = try! AbsolutePath(validating: "/path/to/es.lproj")
        XCTAssertTrue(subject.isLocalized(path: path))
    }

    func test_isVersionGroup() {
        let path = try! AbsolutePath(validating: "/path/to/model.xcdatamodeld")
        XCTAssertTrue(subject.isVersionGroup(path: path))
    }

    func test_normalize_whenLocalized() {
        let path = try! AbsolutePath(validating: "/test/es.lproj/Main.storyboard")
        let normalized = subject.normalize(path)
        XCTAssertEqual(normalized, try AbsolutePath(validating: "/test/es.lproj"))
    }

    func test_normalize() {
        let path = try! AbsolutePath(validating: "/test/file.swift")
        let normalized = subject.normalize(path)
        XCTAssertEqual(normalized, path)
    }

    func test_closestRelativeElementPath() throws {
        let pathRelativeToSourceRoot = try! AbsolutePath(validating: "/a/framework/framework.framework")
            .relative(to: try! AbsolutePath(validating: "/a/b/c/project"))
        let got = try subject.closestRelativeElementPath(pathRelativeToSourceRoot: pathRelativeToSourceRoot)
        XCTAssertEqual(got, try RelativePath(validating: "../../../framework"))
    }

    func test_generateDependencies_sdks() throws {
        // Given
        let pbxproj = PBXProj()
        let sourceRootPath = try AbsolutePath(validating: "/a/project/")
        let project = Project.test(
            path: sourceRootPath,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: sourceRootPath.appending(component: "Project.xcodeproj")
        )
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        let sdkPath = try temporaryPath().appending(component: "ARKit.framework")
        let sdkStatus: LinkingStatus = .required
        let sdkSource: SDKSource = .developer
        let sdkDependency = GraphDependencyReference.sdk(
            path: sdkPath,
            status: sdkStatus,
            source: sdkSource
        )

        // When
        try subject.generate(
            dependencyReferences: [sdkDependency],
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: sourceRootPath,
            filesGroup: .group(name: "Project")
        )

        // Then
        XCTAssertEqual(groups.frameworks.flattenedChildren, [
            "ARKit.framework",
        ])

        let sdkElement = subject.compiled[sdkPath]
        XCTAssertNotNil(sdkElement)
        XCTAssertEqual(sdkElement?.sourceTree, .developerDir)
        XCTAssertEqual(sdkElement?.path, sdkPath.relative(to: "/").pathString)
        XCTAssertEqual(sdkElement?.name, sdkPath.basename)
    }

    func test_generateDependencies_when_cacheCompiledArtifacts() throws {
        // Given
        let pbxproj = PBXProj()
        let sourceRootPath = try AbsolutePath(validating: "/a/project/")
        let project = Project.test(
            path: sourceRootPath,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: sourceRootPath.appending(component: "Project.xcodeproj")
        )
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        let frameworkPath = cacheDirectoriesProvider.cacheDirectory().appending(component: "Test.framework")
        let binaryPath = frameworkPath.appending(component: "Test")

        let frameworkDependency = GraphDependencyReference.framework(
            path: frameworkPath,
            binaryPath: binaryPath,
            dsymPath: nil,
            bcsymbolmapPaths: [],
            linking: .static,
            architectures: [.arm64],
            product: .framework,

            status: .required
        )

        // When
        try subject.generate(
            dependencyReferences: [frameworkDependency],
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: sourceRootPath,
            filesGroup: .group(name: "Project")
        )

        // Then
        XCTAssertEqual(groups.cachedFrameworks.flattenedChildren, [
            "Test.framework",
        ])

        let frameworkElement = subject.compiled[frameworkPath]
        XCTAssertNotNil(frameworkElement)
        XCTAssertEqual(frameworkElement?.sourceTree, .absolute)
        XCTAssertEqual(frameworkElement?.path, frameworkPath.pathString)
        XCTAssertEqual(frameworkElement?.name, frameworkPath.basename)
    }

    func test_generateDependencies_when_cacheCompiledArtifacts_and_sdk() throws {
        // Given
        let pbxproj = PBXProj()
        let sourceRootPath = try AbsolutePath(validating: "/a/project/")
        let project = Project.test(
            path: sourceRootPath,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: sourceRootPath.appending(component: "Project.xcodeproj")
        )
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)

        let frameworkPath = cacheDirectoriesProvider.cacheDirectory().appending(component: "Test.framework")
        let binaryPath = frameworkPath.appending(component: "Test")

        let frameworkDependency = GraphDependencyReference.framework(
            path: frameworkPath,
            binaryPath: binaryPath,
            dsymPath: nil,
            bcsymbolmapPaths: [],
            linking: .static,
            architectures: [.arm64],
            product: .framework,
            status: .required
        )

        let sdkPath = try temporaryPath().appending(component: "ARKit.framework")
        let sdkStatus: LinkingStatus = .required
        let sdkSource: SDKSource = .developer
        let sdkDependency = GraphDependencyReference.sdk(
            path: sdkPath,
            status: sdkStatus,
            source: sdkSource
        )

        // When
        try subject.generate(
            dependencyReferences: [frameworkDependency, sdkDependency],
            groups: groups,
            pbxproj: pbxproj,
            sourceRootPath: sourceRootPath,
            filesGroup: .group(name: "Project")
        )

        // Then
        XCTAssertEqual(groups.cachedFrameworks.flattenedChildren, [
            "Test.framework",
        ])

        let frameworkElement = subject.compiled[frameworkPath]
        XCTAssertNotNil(frameworkElement)
        XCTAssertEqual(frameworkElement?.sourceTree, .absolute)
        XCTAssertEqual(frameworkElement?.path, frameworkPath.pathString)
        XCTAssertEqual(frameworkElement?.name, frameworkPath.basename)

        // Then
        XCTAssertEqual(groups.frameworks.flattenedChildren, [
            "ARKit.framework",
        ])

        let sdkElement = subject.compiled[sdkPath]
        XCTAssertNotNil(sdkElement)
        XCTAssertEqual(sdkElement?.sourceTree, .developerDir)
        XCTAssertEqual(sdkElement?.path, sdkPath.relative(to: "/").pathString)
        XCTAssertEqual(sdkElement?.name, sdkPath.basename)
    }

    func test_generateDependencies_remoteSwiftPackage_doNotGenerateElements() throws {
        // Given
        let pbxproj = PBXProj()
        let target = Target.empty(name: "TargetA")
        let project = Project.empty(
            path: "/a/project",
            targets: [target],
            packages: [.remote(url: "url", requirement: .branch("master"))]
        )
        let graphTarget: GraphTarget = .test(path: project.path, target: target, project: project)
        let groups = ProjectGroups.generate(
            project: .test(
                path: .root,
                sourceRootPath: .root,
                xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj")
            ),
            pbxproj: pbxproj
        )

        let graph = Graph.test(
            projects: [project.path: project],
            packages: [
                project.path: [
                    "A": .remote(url: "url", requirement: .branch("master")),
                ],
            ],
            dependencies: [
                .target(name: graphTarget.target.name, path: graphTarget.path): [
                    .packageProduct(path: project.path, product: "A", type: .runtime),
                ],
            ]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        // When
        try subject.generateProjectFiles(
            project: project,
            graphTraverser: graphTraverser,
            groups: groups,
            pbxproj: pbxproj
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [])
    }

    func test_gpxFilesForRunAction() {
        // Given
        let schemes: [Scheme] = [
            .test(runAction: nil),
            .test(runAction: .test(
                options: RunActionOptions(simulatedLocation: .gpxFile("/gpx/A"))
            )),
            .test(runAction: .test(
                options: RunActionOptions(simulatedLocation: .gpxFile("/gpx/B"))
            )),
            .test(runAction: .test(
                options: RunActionOptions(simulatedLocation: .reference("London, England"))
            )),
            .test(runAction: .test(
                options: RunActionOptions(simulatedLocation: .gpxFile("/gpx/C"))
            )),
        ]
        let filesGroup: ProjectGroup = .group(name: "Project")

        // When
        let gpxFiles = subject.gpxFilesForRunAction(in: schemes, filesGroup: filesGroup)

        // Then
        XCTAssertEqual(gpxFiles, [
            GroupFileElement(path: "/gpx/A", group: filesGroup),
            GroupFileElement(path: "/gpx/B", group: filesGroup),
            GroupFileElement(path: "/gpx/C", group: filesGroup),
        ])
    }

    func test_gpxFilesForTestAction() {
        // Given
        let schemes: [Scheme] = [
            .test(testAction: nil),
            .test(testAction: .test(targets: [
                .test(simulatedLocation: .gpxFile("/gpx/A")),
            ])),
            .test(testAction: .test(targets: [
                .test(simulatedLocation: .gpxFile("/gpx/B")),
                .test(simulatedLocation: .reference("London, England")),
            ])),
            .test(testAction: .test(targets: [
                .test(simulatedLocation: .gpxFile("/gpx/C")),
                .test(simulatedLocation: .gpxFile("/gpx/D")),
            ])),
        ]
        let filesGroup: ProjectGroup = .group(name: "Project")

        // When
        let gpxFiles = subject.gpxFilesForTestAction(in: schemes, filesGroup: filesGroup)

        // Then
        XCTAssertEqual(gpxFiles, [
            GroupFileElement(path: "/gpx/A", group: filesGroup),
            GroupFileElement(path: "/gpx/B", group: filesGroup),
            GroupFileElement(path: "/gpx/C", group: filesGroup),
            GroupFileElement(path: "/gpx/D", group: filesGroup),
        ])
    }

    func test_generateDependencies_localSwiftPackageEmbedded_doNotGenerateElements() throws {
        // Given
        let pbxproj = PBXProj()
        let localPackagePath = try AbsolutePath(validating: "/LocalPackages/LocalPackageA")
        let target = Target.empty(name: "TargetA")
        let project = Project.empty(
            path: "/a/project",
            targets: [target],
            packages: [.local(path: localPackagePath)]
        )
        let graphTarget: GraphTarget = .test(path: project.path, target: target, project: project)
        let groups = ProjectGroups.generate(
            project: .test(
                path: .root,
                sourceRootPath: .root,
                xcodeProjPath: AbsolutePath.root.appending(component: "Project.xcodeproj")
            ),
            pbxproj: pbxproj
        )

        let graph = Graph.test(
            projects: [project.path: project],
            packages: [
                project.path: [
                    "A": .local(path: localPackagePath),
                ],
            ],
            dependencies: [
                .target(name: graphTarget.target.name, path: graphTarget.path): [
                    .packageProduct(path: project.path, product: "A", type: .runtimeEmbedded),
                ],
            ]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        // When
        try subject.generateProjectFiles(
            project: project,
            graphTraverser: graphTraverser,
            groups: groups,
            pbxproj: pbxproj
        )

        // Then
        let projectGroup = groups.sortedMain.group(named: "Project")
        XCTAssertEqual(projectGroup?.flattenedChildren, [])
    }
}

extension PBXGroup {
    /// Retuns all the child variant groups (recursively)
    fileprivate var debugVariantGroupPaths: [String] {
        children.flatMap { (element: PBXFileElement) -> [String] in
            switch element {
            case let group as PBXVariantGroup:
                return [group.nameOrPath]
            case let group as PBXGroup:
                return group.debugVariantGroupPaths.map { group.nameOrPath + "/" + $0 }
            default:
                return []
            }
        }
    }
}
