import XCTest

class TodoUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUI() {
		let text = UUID().uuidString
		let isEnabled = NSPredicate(format: "isEnabled == true")

		let app = XCUIApplication()

		let addButton = app.navigationBars["Tasks"].buttons["Add"]

		wait(for: [expectation(for: isEnabled, evaluatedWith: addButton)], timeout: 10/*seconds*/)

		XCTAssertTrue(addButton.isEnabled)

		addButton.tap()

		let saveButton = app.navigationBars["New Task"].buttons["Save"]

		XCTAssertFalse(saveButton.isEnabled)

		app.textFields["Enter task description"].tap()
		app.typeText(text)
		app.typeText("\n") // end editing

		XCTAssertTrue(saveButton.isEnabled)

		saveButton.tap()

		// <#TODO#> Assert that element appears in list "Open"

		let taskSwitch = app.switches[text]

		XCTAssertTrue(taskSwitch.value as! Bool)

		taskSwitch.tap() // Mark task as completed

		// <#TODO#> Assert that element appears in list "Completed"

		// <#TODO#> Remove task

		sleep(10) // Wait for item to be uploaded to server
    }
    
}
