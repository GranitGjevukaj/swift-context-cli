import XCTest
@testable import DemoApp

final class AppModelTests: XCTestCase {
    func testTitle() {
        XCTAssertEqual(AppModel(title: "Hi").title, "Hi")
    }
}
