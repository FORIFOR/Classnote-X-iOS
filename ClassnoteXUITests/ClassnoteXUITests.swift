import XCTest

final class ClassnoteXUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAuthScreenShowsSignInOptions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["heroTitle"].waitForExistence(timeout: 5), "ブランドタイトルが表示されません")

        let googleButton = app.buttons["googleSignInButton"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 5), "Googleサインインボタンが表示されません")

        let appleButton = app.buttons["appleSignInButton"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 5), "Appleサインインボタンが表示されません")
        appleButton.tap()

        XCTAssertTrue(app.staticTexts["Apple IDでのサインインは準備中です"].waitForExistence(timeout: 2), "準備中アラートが表示されません")
    }
}
