import Foundation
import Path
import XCTest

@testable import TuistSupport
@testable import TuistTesting

final class OpeningErrorTests: XCTestCase {
    func test_type() {
        let path = try! AbsolutePath(validating: "/test")
        XCTAssertEqual(OpeningError.notFound(path).type, .bug)
    }

    func test_description() {
        let path = try! AbsolutePath(validating: "/test")
        XCTAssertEqual(OpeningError.notFound(path).description, "Couldn't open file at path /test")
    }
}

final class OpenerTests: TuistUnitTestCase {
    var subject: Opener!

    override func setUp() {
        super.setUp()
        subject = Opener()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_open_when_path_doesnt_exist() async throws {
        let temporaryPath = try temporaryPath()
        let path = temporaryPath.appending(component: "tool")

        await XCTAssertThrowsSpecific(
            try await subject.open(path: path), OpeningError.notFound(path)
        )
    }

    func test_open_when_wait_is_false() async throws {
        let temporaryPath = try temporaryPath()
        let path = temporaryPath.appending(component: "tool")
        try FileHandler.shared.touch(path)
        system.succeedCommand(["/usr/bin/open", path.pathString])
        try await subject.open(path: path)
    }
}
