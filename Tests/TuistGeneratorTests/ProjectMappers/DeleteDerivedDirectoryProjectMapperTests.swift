import Foundation
import TuistCore
import TuistSupport
import XcodeGraph
import XCTest
@testable import TuistGenerator
@testable import TuistTesting

public final class DeleteDerivedDirectoryProjectMapperTests: TuistUnitTestCase {
    var subject: DeleteDerivedDirectoryProjectMapper!

    override public func setUp() {
        super.setUp()
        subject = DeleteDerivedDirectoryProjectMapper()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map_returns_sideEffectsToDeleteDerivedDirectories() async throws {
        // Given
        let projectPath = try temporaryPath()
        let derivedDirectory = projectPath.appending(component: Constants.DerivedDirectory.name)
        let projectA = Project.test(path: projectPath)
        try fileHandler.createFolder(derivedDirectory)
        try fileHandler.createFolder(derivedDirectory.appending(component: "InfoPlists"))
        try fileHandler.touch(derivedDirectory.appending(component: "TargetA.modulemap"))

        // When
        let (_, sideEffects) = try await subject.map(project: projectA)

        // Then
        XCTAssertEqual(sideEffects, [
            .directory(.init(path: derivedDirectory.appending(component: "InfoPlists"), state: .absent)),
        ])
    }
}
